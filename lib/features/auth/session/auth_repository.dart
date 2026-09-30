// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:convert';

import 'package:logger/logger.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/security/secure_store.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/validators.dart';
import '../../../data/api/armx_api.dart';
import '../../../data/models/auth.dart';
import '../../../data/repositories/preferences_repository.dart';

/// Owns everything about a sign-in session: token storage, restore, refresh and
/// teardown.
///
/// Secrets (access/refresh tokens) live **only** in [SecureStore]; the non-secret
/// profile JSON and the "Remember this device" flag go to the Drift preferences table.
/// Refreshes are single-flight so concurrent callers (dio interceptor + timer) share
/// one network round-trip.
class AuthRepository {
  /// Creates the repository over the platform services.
  AuthRepository({
    required ArmxApi api,
    required SecureStore store,
    required PreferencesRepository preferences,
    required Clock clock,
    required Logger logger,
  })  : _api = api,
        _store = store,
        _preferences = preferences,
        _clock = clock,
        _logger = logger;

  final ArmxApi _api;
  final SecureStore _store;
  final PreferencesRepository _preferences;
  final Clock _clock;
  final Logger _logger;

  Future<AuthTokens>? _refreshInFlight;

  /// Signs in with username/password and persists the returned token pair.
  ///
  /// Throws [AuthException] with a typed reason (invalid credentials, account locked,
  /// unpaired device) or a transport error; the screen maps each to its own copy.
  Future<AuthSession> signIn({
    required String username,
    required String password,
    required bool rememberDevice,
  }) async {
    final serverUrl = await _requireServerUrl();
    final deviceKey = await _store.read(SecureKeys.deviceKey);
    if (deviceKey == null || deviceKey.isEmpty) {
      throw const AuthException(AuthFailureReason.pairingRejected);
    }
    final session = await _api.login(
      serverUrl: serverUrl,
      username: username,
      password: password,
      deviceKey: deviceKey,
    );
    await _writeTokens(session.tokens);
    await _preferences.setRememberDevice(rememberDevice);
    await _preferences.setSessionUser(jsonEncode(session.user.toJson()));
    return session;
  }

  /// Rebuilds the session after a cold start, or `null` when there is nothing to
  /// restore (no tokens, unreadable data, or "Remember this device" switched off).
  Future<AuthSession?> restoreSession() async {
    final prefs = await _preferences.load();
    if (!prefs.rememberDevice) {
      await clearTokens();
      return null;
    }
    final access = await _store.read(SecureKeys.accessToken);
    final refresh = await _store.read(SecureKeys.refreshToken);
    final expiryRaw = await _store.read(SecureKeys.accessTokenExpiry);
    if (access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty ||
        expiryRaw == null) {
      return null;
    }
    final expiresAt = DateTime.tryParse(expiryRaw)?.toUtc();
    if (expiresAt == null) {
      await clearTokens();
      return null;
    }
    if (prefs.sessionUserJson.isEmpty) {
      // Fail closed: without the profile a restored session would be a half-truth.
      await clearTokens();
      return null;
    }
    try {
      final decoded = jsonDecode(prefs.sessionUserJson);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Session profile is not an object');
      }
      return AuthSession(
        accessToken: access,
        refreshToken: refresh,
        expiresAt: expiresAt,
        user: UserProfile.fromJson(decoded),
        deviceId: await _store.read(SecureKeys.deviceId) ?? '',
      );
    } on Object catch (error) {
      _logger.w('auth: stored profile unreadable (${error.runtimeType}); signing out');
      await clearTokens();
      return null;
    }
  }

  /// Exchanges the stored refresh token for a fresh pair (single-flight).
  ///
  /// Throws `AuthException(refreshRejected/sessionExpired/serverUrlRejected)` when the
  /// exchange cannot happen — the caller must sign the user out. Transport errors
  /// ([NetworkException] et al.) propagate unchanged so callers can retry later.
  Future<AuthTokens> refreshSession() =>
      _refreshInFlight ??= _performRefresh().whenComplete(() => _refreshInFlight = null);

  Future<AuthTokens> _performRefresh() async {
    final refresh = await _store.read(SecureKeys.refreshToken);
    if (refresh == null || refresh.isEmpty) {
      throw const AuthException(AuthFailureReason.sessionExpired);
    }
    final serverUrl = await _requireServerUrl();
    try {
      final tokens = await _api.refresh(serverUrl: serverUrl, refreshToken: refresh);
      await _writeTokens(tokens);
      return tokens;
    } on AuthException {
      rethrow;
    }
  }

  /// Best-effort server logout, then wipes the local token pair (pairing is kept).
  Future<void> signOut() async {
    try {
      await _api.logout();
    } on AppException catch (error) {
      _logger.w('auth: logout best-effort failed (${error.code})');
    }
    await clearTokens();
  }

  /// Full teardown: server-side unpair (best effort), then local keypair + tokens and
  /// the pairing metadata are erased so the pairing screen appears again.
  Future<void> unpair() async {
    final deviceId = await _store.read(SecureKeys.deviceId) ?? '';
    if (deviceId.isNotEmpty) {
      try {
        final serverUrl = await _serverUrlOrNull();
        if (serverUrl != null) {
          await _api.unpair(serverUrl: serverUrl, deviceId: deviceId);
        }
      } on AppException catch (error) {
        _logger.w('auth: unpair best-effort failed (${error.code})');
      }
    }
    await _store.deleteKeys(const <String>[
      SecureKeys.deviceKey,
      SecureKeys.deviceId,
      SecureKeys.devicePrivateKey,
      SecureKeys.devicePublicKey,
    ]);
    await _preferences.setPairingStatus('unpaired');
    await _preferences.setPairingDeviceName('');
    await _preferences.setPairingPairedAt('');
    await clearTokens();
  }

  /// Deletes the token pair and the stored profile (pairing material is kept).
  Future<void> clearTokens() async {
    await _store.deleteKeys(const <String>[
      SecureKeys.accessToken,
      SecureKeys.refreshToken,
      SecureKeys.accessTokenExpiry,
    ]);
    await _preferences.setSessionUser('');
  }

  /// Raw access token for the dio interceptor (never logged).
  Future<String?> readAccessToken() => _store.read(SecureKeys.accessToken);

  /// Parsed expiry of the stored access token, or `null` when absent/unreadable.
  Future<DateTime?> readAccessTokenExpiry() async {
    final raw = await _store.read(SecureKeys.accessTokenExpiry);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  /// True when the stored access token is inside [leeway] of its expiry.
  Future<bool> accessTokenNeedsRefresh({Duration leeway}) async {
    final expiry = await readAccessTokenExpiry();
    if (expiry == null) {
      return false;
    }
    return !expiry.subtract(leeway).isAfter(_clock.now());
  }

  Future<void> _writeTokens(AuthTokens tokens) async {
    await _store.write(SecureKeys.accessToken, tokens.accessToken);
    await _store.write(SecureKeys.refreshToken, tokens.refreshToken);
    await _store.write(
      SecureKeys.accessTokenExpiry,
      tokens.expiresAt.toUtc().toIso8601String(),
    );
  }

  Future<Uri> _requireServerUrl() async {
    final uri = await _serverUrlOrNull();
    if (uri == null) {
      throw const AuthException(AuthFailureReason.serverUrlRejected);
    }
    return uri;
  }

  Future<Uri?> _serverUrlOrNull() async {
    final prefs = await _preferences.load();
    final raw = prefs.lastServerUrl.trim();
    if (raw.isEmpty) {
      return null;
    }
    try {
      return Validators.normaliseServerUrl(raw);
    } on FormatException {
      return null;
    }
  }
}
