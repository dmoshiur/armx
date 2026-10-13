// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meta/meta.dart';

import '../errors/app_exception.dart';

/// An access/refresh token pair plus the moment the access token stops being valid.
@immutable
class AuthTokens {
  /// Creates a token pair.
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
  });

  /// Bearer token for API calls.
  final String accessToken;

  /// Long-lived token exchanged at `/auth/refresh`.
  final String refreshToken;

  /// When [accessToken] expires. Used to refresh *before* a call fails, so a normal
  /// interaction never eats a 401.
  final DateTime accessExpiresAt;

  /// True when the access token is expired or within [skew] of expiring.
  bool isExpired({Duration skew = const Duration(seconds: 30), DateTime? now}) {
    final DateTime reference = now ?? DateTime.now().toUtc();
    return accessExpiresAt.subtract(skew).isBefore(reference);
  }

  /// Serialises for secure storage. Never logged.
  String encode() => jsonEncode(<String, Object?>{
        'access': accessToken,
        'refresh': refreshToken,
        'expires': accessExpiresAt.toUtc().toIso8601String(),
      });

  /// Parses a stored blob.
  ///
  /// Throws [StorageException] on anything unexpected: a corrupted credential store must
  /// not silently become "signed out with a blank token".
  static AuthTokens decode(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        throw const StorageException(message: 'Stored session is not an object.');
      }
      final String? access = decoded['access'] as String?;
      final String? refresh = decoded['refresh'] as String?;
      final String? expires = decoded['expires'] as String?;
      if (access == null || refresh == null || expires == null) {
        throw const StorageException(message: 'Stored session is incomplete.');
      }
      return AuthTokens(
        accessToken: access,
        refreshToken: refresh,
        accessExpiresAt: DateTime.parse(expires).toUtc(),
      );
    } on StorageException {
      rethrow;
    } on Object catch (error) {
      throw StorageException(message: 'Stored session could not be read: $error');
    }
  }
}

/// Where credentials live.
///
/// ## Security rule (§8)
///
/// Tokens are written to `flutter_secure_storage` — Keychain on Apple platforms, the
/// Android Keystore-backed `EncryptedSharedPreferences`, libsecret on Linux, DPAPI on
/// Windows. They are **never** written to `SharedPreferences` in plaintext and never
/// appear in a log line, an error message or an analytics payload.
///
/// Non-secret preferences (theme, language, notification toggles) do not belong here;
/// they go through `PreferencesStore`.
abstract interface class TokenStore {
  /// Reads the stored pair, or `null` when there is no session.
  Future<AuthTokens?> read();

  /// Persists [tokens], replacing any previous pair.
  Future<void> write(AuthTokens tokens);

  /// Deletes the session. Called on sign-out, on a rejected refresh token, and after a
  /// kill-switch engagement that ends the session server-side.
  Future<void> clear();

  /// True when a session exists, without decoding it. Used by the splash bootstrap.
  Future<bool> hasSession();
}

/// Platform-backed implementation.
class SecureTokenStore implements TokenStore {
  /// Creates a store. [storage] is injectable so tests use an in-memory fake.
  const SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'armx.auth.tokens.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthTokens?> read() async {
    final String? raw;
    try {
      raw = await _storage.read(key: _key);
    } on Object catch (error) {
      throw StorageException(message: 'Secure storage is unavailable: $error');
    }
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return AuthTokens.decode(raw);
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    try {
      await _storage.write(key: _key, value: tokens.encode());
    } on Object catch (error) {
      throw StorageException(message: 'Session could not be persisted: $error');
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on Object catch (error) {
      throw StorageException(message: 'Session could not be cleared: $error');
    }
  }

  @override
  Future<bool> hasSession() async {
    try {
      final String? raw = await _storage.read(key: _key);
      return raw != null && raw.isNotEmpty;
    } on Object {
      // A broken keystore must not brick the launch: treat it as "no session" and let the
      // user sign in again, which re-creates the entry.
      return false;
    }
  }
}

/// In-memory store for tests and for a build with no secure storage available.
///
/// Deliberately loud in the UI: `Settings → Diagnostics` reports when the app is running
/// without persistent secure storage, so a session that vanishes on restart is explained
/// rather than mysterious.
class InMemoryTokenStore implements TokenStore {
  AuthTokens? _tokens;

  @override
  Future<AuthTokens?> read() async => _tokens;

  @override
  Future<void> write(AuthTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;

  @override
  Future<bool> hasSession() async => _tokens != null;
}
