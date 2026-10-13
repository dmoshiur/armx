// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api/armx_api.dart';
import '../data/api/mock/mock_armx_api.dart';
import '../data/api/rest_armx_api.dart';
import 'config/app_config.dart';
import 'errors/app_exception.dart';
import 'network/api_client.dart';
import 'network/token_store.dart';
import 'network/websocket_client.dart';
import 'preferences/preferences_store.dart';

/// Compile-time configuration.
///
/// **Must be overridden** in `main()` with `AppConfig.fromEnvironment()` (or with a test
/// configuration). Reading it without an override is a programming error, so the failure
/// is loud rather than a silently-defaulted staging URL.
final Provider<AppConfig> appConfigProvider = Provider<AppConfig>(
  (Ref ref) => throw StateError(
    'appConfigProvider must be overridden in main() with '
    'AppConfig.fromEnvironment().',
  ),
);

/// Secure credential storage. Tokens only, never preferences.
final Provider<TokenStore> tokenStoreProvider = Provider<TokenStore>(
  (Ref ref) => const SecureTokenStore(),
);

/// The single HTTP client. Every repository receives it; no screen ever builds one.
final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((Ref ref) {
  final AppConfig config = ref.watch(appConfigProvider);
  return ApiClient.create(
    config: config,
    tokenStore: ref.watch(tokenStoreProvider),
    onAuthFailure: (AppException error) {
      // The auth controller listens for this and moves the session to
      // `sessionExpired`, which the router turns into a redirect to sign-in.
      ref.read(authFailureSinkProvider.notifier).state = error;
    },
  );
});

/// A one-slot sink the API client writes auth failures into.
///
/// Kept as its own provider so `ApiClient` does not need to import the auth feature
/// (which would be a cycle: auth depends on the client).
final NotifierProvider<AuthFailureSink, AppException?> authFailureSinkProvider =
    NotifierProvider<AuthFailureSink, AppException?>(AuthFailureSink.new);

/// Holds the most recent auth failure observed by the transport.
class AuthFailureSink extends Notifier<AppException?> {
  @override
  AppException? build() => null;

  /// Clears the slot after the auth layer has consumed the failure.
  void clear() => state = null;
}

/// The backend contract: the mock by default, the REST/WebSocket transport otherwise.
///
/// `--dart-define=ARMX_USE_MOCK_BACKEND=false` switches to the real transport. There is no
/// third option: a build that cannot reach a backend fails loudly instead of pretending to
/// be connected.
final Provider<ArmxApi> armxApiProvider = Provider<ArmxApi>((Ref ref) {
  final AppConfig config = ref.watch(appConfigProvider);
  if (config.useMockBackend) {
    return MockArmxApi(clock: () => DateTime.now());
  }
  return RestArmxApi(
    client: ref.watch(apiClientProvider),
    socket: null,
    config: config,
  );
});

/// The assistant/telemetry socket, created lazily because it needs a token source.
final Provider<WebSocketClient> webSocketProvider = Provider<WebSocketClient>((Ref ref) {
  final AppConfig config = ref.watch(appConfigProvider);
  final WebSocketClient client = WebSocketClient(
    baseUrl: config.webSocketUrl,
    tokenProvider: () async {
      final AuthTokens? tokens = await ref.read(tokenStoreProvider).read();
      return tokens?.accessToken;
    },
  );
  ref.onDispose(client.dispose);
  return client;
});

/// User preferences, loaded once at launch.
///
/// Exposed as a `Notifier` rather than an async value because `MaterialApp` needs the
/// theme mode and locale synchronously on the very first frame; the splash screen holds
/// the UI until [build] has loaded them.
final NotifierProvider<PreferencesController, AppPreferences>
    preferencesProvider =
    NotifierProvider<PreferencesController, AppPreferences>(PreferencesController.new);

/// Loads and updates [AppPreferences].
class PreferencesController extends Notifier<AppPreferences> {
  bool _loaded = false;

  /// True once the stored values have been read.
  bool get loaded => _loaded;

  @override
  AppPreferences build() => const AppPreferences();

  /// Reads the stored preferences. Called by the splash bootstrap.
  Future<void> load({PreferencesStore? store}) async {
    final PreferencesStore effective = store ?? const SharedPreferencesStore();
    final AppPreferences loaded = await effective.load();
    state = loaded;
    _loaded = true;
  }

  /// Applies and persists a change.
  Future<void> update(
    AppPreferences Function(AppPreferences current) transform, {
    PreferencesStore? store,
  }) async {
    final AppPreferences next = transform(state);
    if (next == state) {
      return;
    }
    // Update in memory first so the UI responds immediately, then persist. A failed write
    // is surfaced by the caller's error handling rather than silently losing the change.
    state = next;
    final PreferencesStore effective = store ?? const SharedPreferencesStore();
    await effective.save(next);
  }

  /// Switches theme mode.
  Future<void> setThemeMode(ThemeMode mode) =>
      update((AppPreferences p) => p.copyWith(themeMode: mode));

  /// Switches language. Only `en` and `bn` ship.
  Future<void> setLocale(String code) =>
      update((AppPreferences p) => p.copyWith(localeCode: code == 'bn' ? 'bn' : 'en'));

  /// Collapses or expands the medium-layout rail.
  Future<void> setRailCollapsed({required bool collapsed}) =>
      update((AppPreferences p) => p.copyWith(railCollapsed: collapsed));

  /// Engages or releases the guest-greeter camera kill-switch.
  Future<void> setGuestKillEngaged({required bool engaged}) =>
      update((AppPreferences p) => p.copyWith(guestGreeterKillEngaged: engaged));

  /// Switches an interrupt-on-this-device preference.
  Future<void> setNotification({
    bool? alarms,
    bool? toolCalls,
    bool? deployments,
  }) =>
      update(
        (AppPreferences p) => p.copyWith(
          notifyAlarms: alarms,
          notifyToolCalls: toolCalls,
          notifyDeployments: deployments,
        ),
      );
}

/// A convenience handle used by the diagnostics screen.
///
/// Returns the same [SharedPreferences] instance the platform cache holds, without
/// exposing any of its values.
final FutureProvider<Map<String, Object?>> preferenceDiagnosticsProvider =
    FutureProvider<Map<String, Object?>>((Ref ref) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return <String, Object?>{
    'keys': prefs.getKeys().length,
    'containsTokens': prefs.getKeys().any(
          (String key) => key.contains('token') || key.contains('secret'),
        ),
  };
});
