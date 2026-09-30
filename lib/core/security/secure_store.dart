// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../errors/app_exception.dart';
import '../logging/log_redactor.dart';

/// Every key A.R.M.X writes into platform secure storage.
///
/// Tokens and key material live **only** here: never in the drift database, never in
/// `--dart-define`, never in a log line.
abstract final class SecureKeys {
  /// Short-lived API access token (JWT).
  static const String accessToken = 'armx.auth.access_token';

  /// Refresh token used to mint new access tokens.
  static const String refreshToken = 'armx.auth.refresh_token';

  /// Absolute expiry of [accessToken] (ISO-8601).
  static const String accessTokenExpiry = 'armx.auth.access_token_expiry';

  /// Device key issued during pairing; sent as `X-Armx-Device-Key`.
  static const String deviceKey = 'armx.device.key';

  /// Server-assigned device identifier.
  static const String deviceId = 'armx.device.id';

  /// Ed25519 private key seed (base64), generated on-device and never exported.
  static const String devicePrivateKey = 'armx.device.ed25519.private';

  /// Ed25519 public key (base64) — safe to display as a fingerprint/QR.
  static const String devicePublicKey = 'armx.device.ed25519.public';

  /// Key used to sign short-lived owner-verified assertions.
  static const String ownerAssertionKey = 'armx.owner.assertion.ed25519.private';

  /// Per-install nonce salt that prevents token replay across reinstalls.
  static const String installSalt = 'armx.device.install_salt';

  /// Argon2id-hashed app-level PIN — the lock-screen fallback when the device
  /// offers no biometrics and no screen PIN.
  static const String appPin = 'armx.security.app_pin';

  /// All keys, used by the data-deletion flow.
  static const List<String> all = <String>[
    accessToken,
    refreshToken,
    accessTokenExpiry,
    deviceKey,
    deviceId,
    devicePrivateKey,
    devicePublicKey,
    ownerAssertionKey,
    installSalt,
    appPin,
  ];

  /// Keys that hold biometric-adjacent material and must be erased by
  /// "delete all biometric data".
  static const List<String> biometricRelated = <String>[
    ownerAssertionKey,
  ];
}

/// Minimal key/value contract over platform secure storage.
///
/// Abstracted so that tests (and desktop builds without a keyring) can substitute
/// [InMemorySecureStore] without touching production call sites.
abstract interface class SecureStore {
  /// Reads [key], returning `null` when absent.
  Future<String?> read(String key);

  /// Writes [value] under [key].
  Future<void> write(String key, String value);

  /// Removes [key] if present.
  Future<void> delete(String key);

  /// Removes every A.R.M.X key (see [SecureKeys.all]).
  Future<void> clear();

  /// Removes only the keys listed in [keys].
  Future<void> deleteKeys(Iterable<String> keys);
}

/// [SecureStore] backed by `flutter_secure_storage`
/// (Android Keystore / iOS Keychain / DPAPI / libsecret).
class PlatformSecureStore implements SecureStore {
  /// Creates a store over an optional pre-built [FlutterSecureStorage] instance.
  PlatformSecureStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
              wOptions: WindowsOptions(useBackwardCompatibility: false),
              lOptions: LinuxOptions(),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } on Object catch (error, stackTrace) {
      throw StorageException(
        'Secure storage read failed for "$key" '
        '(${LogRedactor.fingerprint(key)})',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } on Object catch (error, stackTrace) {
      throw StorageException('Secure storage write failed for "$key"', cause: error, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } on Object catch (error, stackTrace) {
      throw StorageException('Secure storage delete failed for "$key"', cause: error, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> deleteKeys(Iterable<String> keys) async {
    for (final key in keys) {
      await delete(key);
    }
  }

  @override
  Future<void> clear() => deleteKeys(SecureKeys.all);
}

/// Non-persistent [SecureStore] for tests and for mock mode on machines without a keyring.
///
/// Values are dropped when the process exits, which is the point: it can never leak a
/// stale token into a later session.
class InMemorySecureStore implements SecureStore {
  /// Creates an in-memory store, optionally pre-seeded with [seed].
  InMemorySecureStore([Map<String, String>? seed])
      : _values = <String, String>{...?seed};

  final Map<String, String> _values;

  /// Snapshot of the stored entries (tests only; never log this in production).
  Map<String, String> get snapshot => Map<String, String>.unmodifiable(_values);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<void> deleteKeys(Iterable<String> keys) async {
    for (final key in keys) {
      _values.remove(key);
    }
  }

  @override
  Future<void> clear() => deleteKeys(SecureKeys.all);
}
