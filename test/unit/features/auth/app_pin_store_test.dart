// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:math';

import 'package:armx_ai/core/errors/app_exception.dart';
import 'package:armx_ai/core/security/secure_store.dart';
import 'package:armx_ai/features/auth/lock/app_pin_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app-PIN fallback: Argon2id records in secure storage, verified in
/// constant time and failing closed when anything looks wrong.
void main() {
  late InMemorySecureStore store;
  late Argon2AppPinStore pins;

  setUp(() {
    store = InMemorySecureStore();
    pins = Argon2AppPinStore(store: store, random: Random(7));
  });

  test('configure writes an argon2id$m$t$p$salt$hash record, never the PIN', () async {
    await pins.configure('1234');

    expect(await pins.isConfigured, isTrue);
    final raw = await store.read(SecureKeys.appPin);
    expect(raw, isNotNull);
    expect(
      RegExp(r'^argon2id\$19456\$2\$1\$[0-9a-f]{32}\$[0-9a-f]{64}$').hasMatch(raw!),
      isTrue,
      reason: 'OWASP Argon2id parameters and hex salt/hash, got: $raw',
    );
    expect(raw.contains('1234'), isFalse, reason: 'the PIN itself is never stored');
    expect(
      store.snapshot.values.any((value) => value.contains('1234')),
      isFalse,
      reason: 'no stored value may embed the PIN',
    );
  });

  test('verify accepts the configured PIN and rejects others', () async {
    await pins.configure('1234');

    expect(await pins.verify('1234'), isTrue);
    expect(await pins.verify('1235'), isFalse);
    expect(await pins.verify('0000'), isFalse);
    expect(await pins.verify('12'), isFalse, reason: 'malformed input is a plain miss');
    expect(await pins.verify('abcd'), isFalse);
  });

  test('verify fails closed when no PIN record exists', () async {
    expect(
      pins.verify('1234'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.reason,
          'reason',
          AuthFailureReason.appLockFailed,
        ),
      ),
    );
  });

  test('a corrupted record fails closed instead of opening the gate', () async {
    await store.write(SecureKeys.appPin, 'not-a-record');
    expect(
      pins.verify('1234'),
      throwsA(isA<AuthException>()),
    );
    await store.write(SecureKeys.appPin, r'argon2id$19456$2$1$zzzz$zzzz');
    expect(
      pins.verify('1234'),
      throwsA(isA<AuthException>()),
    );
  });

  test('configure refuses malformed PINs', () async {
    expect(pins.configure('12'), throwsA(isA<AuthException>()));
    expect(pins.configure('abcdef'), throwsA(isA<AuthException>()));
    expect(pins.configure('123456789'), throwsA(isA<AuthException>()));
    expect(await pins.isConfigured, isFalse);
  });

  test('re-configuring salts afresh so records never collide', () async {
    await pins.configure('1234');
    final first = await store.read(SecureKeys.appPin);
    await pins.configure('1234');
    final second = await store.read(SecureKeys.appPin);

    expect(first, isNot(second), reason: 'fresh random salt per configure');
    expect(await pins.verify('1234'), isTrue);
  });

  test('clear removes the record', () async {
    await pins.configure('4321');
    await pins.clear();
    expect(await pins.isConfigured, isFalse);
  });
}
