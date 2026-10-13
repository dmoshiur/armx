// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/foundation.dart';

/// Compile-time configuration.
///
/// ## Security rule (§8)
///
/// Nothing secret ever lives in Dart source or `pubspec.yaml`. The **only** value that
/// crosses the build boundary is the backend's *public* base URL and the mock switch, both
/// supplied with `--dart-define`:
///
/// ```bash
/// flutter run \
///   --dart-define=ARMX_API_BASE_URL=https://armx.local:8443 \
///   --dart-define=ARMX_USE_MOCK_BACKEND=false
/// ```
///
/// API keys, signing keys and client secrets are **not** representable by this class: the
/// client authenticates with a user session only. Release builds refuse a cleartext base
/// URL outright (see [AppConfig.httpsBaseUrl]).
@immutable
class AppConfig {
  /// Creates a configuration.
  const AppConfig({
    required this.apiBaseUrl,
    required this.webSocketUrl,
    required this.useMockBackend,
    required this.environment,
    this.requestTimeout = const Duration(seconds: 20),
    this.connectTimeout = const Duration(seconds: 12),
    this.allowCleartextInDebug = false,
  });

  /// Reads the configuration from the compile-time environment.
  factory AppConfig.fromEnvironment() {
    const String rawBase = String.fromEnvironment(
      'ARMX_API_BASE_URL',
      defaultValue: _defaultBase,
    );
    const String rawSocket = String.fromEnvironment('ARMX_WS_URL', defaultValue: '');
    const bool mock = bool.fromEnvironment(
      'ARMX_USE_MOCK_BACKEND',
      defaultValue: true,
    );
    const String env = String.fromEnvironment(
      'ARMX_ENVIRONMENT',
      defaultValue: 'development',
    );

    final Uri base = Uri.parse(rawBase);
    return AppConfig(
      apiBaseUrl: base,
      webSocketUrl: rawSocket.isEmpty ? _socketFrom(base) : Uri.parse(rawSocket),
      useMockBackend: mock,
      environment: env,
      // Cleartext is tolerated in a debug *mock* build only, so `flutter run` works on a
      // LAN address; it is never tolerated in release (asserted in AppConfig.httpsBaseUrl
      // and by test/unit/core/config/app_config_test.dart).
      allowCleartextInDebug: kDebugMode && mock,
    );
  }

  /// Product name, shown in About and used by the Android package label.
  static const String appName = 'A.R.M.X AI';

  /// Version string. Kept in step with `pubspec.yaml`'s `version:` field by hand, because
  /// `package_info_plus` would add a plugin for one constant.
  static const String appVersion = '1.0.0';

  /// Build label. `dev` on a working tree, a tag in CI.
  static const String buildLabel = String.fromEnvironment(
    'ARMX_BUILD_LABEL',
    defaultValue: 'dev',
  );

  /// Owner. Copyright holder for the whole tree.
  static const String owner = 'Md. Moshiur Rahman Mohi';

  /// Brand.
  static const String brand = 'THAMJJ13.TOP';

  /// Default base URL for a local development server.
  static const String _defaultBase = 'https://armx.local:8443';

  /// Backend REST base URL.
  final Uri apiBaseUrl;

  /// Assistant/telemetry WebSocket URL.
  final Uri webSocketUrl;

  /// When true the app runs against the deterministic in-app mock backend.
  ///
  /// The mock implements the same contract as the server (see `docs/api.md`) so every
  /// screen, flow and widget test is exercisable with no hardware and no network.
  final bool useMockBackend;

  /// Free-form environment name, shown in Diagnostics.
  final String environment;

  /// Per-request timeout for REST calls.
  final Duration requestTimeout;

  /// Timeout for establishing the WebSocket.
  final Duration connectTimeout;

  /// Whether a cleartext (`http://`) base URL is tolerated. Debug + mock builds only.
  final bool allowCleartextInDebug;

  /// The base URL, validated.
  ///
  /// Throws [ArgumentError] when the URL is cleartext and this build is not an explicitly
  /// permitted debug/mock build: an assistant that carries camera frames, transcripts and
  /// unlock tokens must never silently talk to the server in the clear.
  Uri get httpsBaseUrl {
    if (apiBaseUrl.scheme == 'https') {
      return apiBaseUrl;
    }
    if (allowCleartextInDebug) {
      return apiBaseUrl;
    }
    throw ArgumentError.value(
      apiBaseUrl.toString(),
      'apiBaseUrl',
      'Cleartext base URLs are rejected outside debug mock builds. '
          'Pass --dart-define=ARMX_API_BASE_URL=https://…',
    );
  }

  /// True when the configured transport is TLS.
  bool get isSecure => apiBaseUrl.scheme == 'https';

  /// A short summary for Diagnostics. Contains no secret and no token.
  Map<String, Object?> describe() => <String, Object?>{
        'baseUrl': apiBaseUrl.toString(),
        'socket': webSocketUrl.toString(),
        'mock': useMockBackend,
        'environment': environment,
        'secure': isSecure,
      };

  static Uri _socketFrom(Uri base) {
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '${base.path.isEmpty ? '' : base.path}/ws',
    );
  }
}
