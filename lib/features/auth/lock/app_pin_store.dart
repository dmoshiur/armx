// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';
import '../../../core/security/secure_store.dart';

part 'app_pin_store.g.dart';

/// App-level PIN used as the lock-screen fallback when the device has neither
/// biometrics nor a screen PIN enrolled.
///
/// The PIN never travels over the network and is never stored verbatim: only an
/// Argon2id hash plus a per-store random salt lives in platform secure storage.
abstract interface class AppPinStore {
  /// Whether a PIN has been configured on this install.
  Future<bool> get isConfigured;

  /// Hashes [pin] (4–8 digits) with Argon2id and persists the record.
  ///
  /// Throws an [AuthException] when [pin] is malformed.
  Future<void> configure(String pin);

  /// Verifies [pin] against the stored hash in constant time.
  ///
  /// A malformed or missing record fails closed by throwing; a well-formed
  /// mismatch returns `false`.
  Future<bool> verify(String pin);

  /// Erases the stored PIN record.
  Future<void> clear();
}

/// [AppPinStore] backed by Argon2id (OWASP 2024 first choice) over
/// [SecureStore].
///
/// Record format (single line, all components lowercase hex):
/// `argon2id$<memory_kb>$<iterations>$<parallelism>$<saltHex>$<hashHex>`
class Argon2AppPinStore implements AppPinStore {
  /// Creates the store over [store]; [random] is injectable for tests.
  Argon2AppPinStore({required SecureStore store, Random? random})
      : _store = store,
        _random = random ?? Random.secure();

  /// OWASP-recommended Argon2id parameters: 19 MiB, t=2, p=1, 256-bit output.
  static final Argon2id _algorithm = Argon2id(
    parallelism: 1,
    memory: 19456,
    iterations: 2,
    hashLength: 32,
  );

  static const int _saltBytes = 16;
  static final RegExp _pinPattern = RegExp(r'^[0-9]{4,8}$');

  final SecureStore _store;
  final Random _random;

  @override
  Future<bool> get isConfigured async {
    final raw = await _store.read(SecureKeys.appPin);
    return raw != null && raw.isNotEmpty;
  }

  @override
  Future<void> configure(String pin) async {
    if (!_pinPattern.hasMatch(pin)) {
      throw const AuthException(
        AuthFailureReason.appLockFailed,
        message: 'App PIN must be 4-8 digits',
      );
    }
    final salt = List<int>.generate(_saltBytes, (_) => _random.nextInt(256));
    final hash = await _derive(pin, salt);
    await _store.write(SecureKeys.appPin, _encode(salt, hash));
  }

  @override
  Future<bool> verify(String pin) async {
    final raw = await _store.read(SecureKeys.appPin);
    if (raw == null || raw.isEmpty) {
      // Fail closed: a lock that silently accepts anything is not a lock.
      throw const AuthException(
        AuthFailureReason.appLockFailed,
        message: 'No app PIN configured',
      );
    }
    if (!_pinPattern.hasMatch(pin)) {
      return false;
    }
    final record = _decode(raw);
    final hash = await _derive(pin, record.$1);
    return _constantTimeEquals(hash, record.$2);
  }

  @override
  Future<void> clear() => _store.delete(SecureKeys.appPin);

  Future<List<int>> _derive(String pin, List<int> salt) async {
    final key = await _algorithm.deriveKeyFromPassword(password: pin, nonce: salt);
    return key.extractBytes();
  }

  String _encode(List<int> salt, List<int> hash) =>
      'argon2id\$${_algorithm.memory}\$${_algorithm.iterations}\$${_algorithm.parallelism}'
      '\$${_toHex(salt)}\$${_toHex(hash)}';

  (List<int>, List<int>) _decode(String raw) {
    final parts = raw.split(r'$');
    if (parts.length != 6 || parts.first != 'argon2id') {
      throw const AuthException(
        AuthFailureReason.appLockFailed,
        message: 'Malformed app PIN record',
      );
    }
    try {
      final salt = _fromHex(parts[4]);
      final hash = _fromHex(parts[5]);
      if (salt.isEmpty || hash.isEmpty) {
        throw const AuthException(
          AuthFailureReason.appLockFailed,
          message: 'Malformed app PIN record',
        );
      }
      return (salt, hash);
    } on AuthException {
      rethrow;
    } on Object {
      throw const AuthException(
        AuthFailureReason.appLockFailed,
        message: 'Malformed app PIN record',
      );
    }
  }

  /// Length-independent-enough constant-time compare (equal lengths only here).
  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  String _toHex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  List<int> _fromHex(String hex) {
    if (hex.length.isOdd) {
      throw const AuthException(
        AuthFailureReason.appLockFailed,
        message: 'Malformed hex in app PIN record',
      );
    }
    final out = List<int>.filled(hex.length ~/ 2, 0);
    for (var i = 0; i < out.length; i++) {
      final byte = int.tryParse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      if (byte == null) {
        throw const AuthException(
          AuthFailureReason.appLockFailed,
          message: 'Malformed hex in app PIN record',
        );
      }
      out[i] = byte;
    }
    return out;
  }
}

/// PIN storage for the app-lock gate; overridable in tests.
@Riverpod(keepAlive: true)
AppPinStore appPinStore(Ref ref) => Argon2AppPinStore(
      store: ref.watch(secureStoreProvider),
    );
