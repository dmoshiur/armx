// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/errors/app_exception.dart';
import 'package:armx_ai/core/security/secure_store.dart';
import 'package:armx_ai/core/utils/clock.dart';
import 'package:armx_ai/data/db/armx_database.dart';
import 'package:armx_ai/data/repositories/preferences_repository.dart';
import 'package:armx_ai/features/auth/session/auth_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

/// Session storage rules: tokens live **only** in secure storage, refreshes are
/// single-flight and classified, and teardown erases exactly what it promises.
void main() {
  final anchor = Fixtures.anchor;

  Future<(AuthRepository, InMemorySecureStore, PreferencesRepository)> buildRepo({
    bool paired = true,
    Map<String, String> seed = const <String, String>{},
  }) async {
    final store = InMemorySecureStore(<String, String>{
      if (paired) SecureKeys.deviceKey: 'device-key-seed',
      ...seed,
    });
    final preferences = PreferencesRepository(ArmxDatabase(NativeDatabase.memory()));
    await preferences.setLastServerUrl('https://api.armx.test');
    final repository = AuthRepository(
      api: Fixtures.mockApi(clock: FixedClock(anchor)),
      store: store,
      preferences: preferences,
      clock: FixedClock(anchor),
      logger: Fixtures.silentLogger(),
    );
    return (repository, store, preferences);
  }

  group('signIn', () {
    test('persists tokens only in secure storage and the profile in prefs', () async {
      final (repository, store, preferences) = await buildRepo();

      final session = await repository.signIn(
        username: 'mohiur',
        password: 'correct horse',
        rememberDevice: true,
      );

      expect(session.accessToken, startsWith('mock.access.'));
      expect(await store.read(SecureKeys.accessToken), session.accessToken);
      expect(await store.read(SecureKeys.refreshToken), session.refreshToken);
      expect(await store.read(SecureKeys.accessTokenExpiry), isNotNull);

      final prefs = await preferences.load();
      expect(prefs.rememberDevice, isTrue);
      expect(prefs.sessionUserJson, contains(session.user.email));
      // No secret ever lands in the drift preferences table.
      expect(prefs.sessionUserJson.contains('mock.access.'), isFalse);
      expect(prefs.sessionUserJson.contains('mock.refresh.'), isFalse);
    });

    test('maps wrong credentials to invalidCredentials', () async {
      final (repository, _, _) = await buildRepo();
      expect(
        repository.signIn(username: 'wrong', password: 'x', rememberDevice: true),
        throwsA(
          isA<AuthException>().having(
            (e) => e.reason,
            'reason',
            AuthFailureReason.invalidCredentials,
          ),
        ),
      );
    });

    test('maps the reserved locked account to accountLocked', () async {
      final (repository, _, _) = await buildRepo();
      expect(
        repository.signIn(username: 'locked', password: 'x', rememberDevice: true),
        throwsA(
          isA<AuthException>().having(
            (e) => e.reason,
            'reason',
            AuthFailureReason.accountLocked,
          ),
        ),
      );
    });

    test('refuses to sign in on an unpaired device', () async {
      final (repository, _, _) = await buildRepo(paired: false);
      expect(
        repository.signIn(username: 'mohiur', password: 'x', rememberDevice: true),
        throwsA(
          isA<AuthException>().having(
            (e) => e.reason,
            'reason',
            AuthFailureReason.pairingRejected,
          ),
        ),
      );
    });
  });

  group('refresh', () {
    test('exchanges a valid refresh token and persists the new pair', () async {
      final (repository, store, _) = await buildRepo(
        seed: <String, String>{
          SecureKeys.refreshToken: 'mock.refresh.seed',
          SecureKeys.accessToken: 'mock.access.seed',
          SecureKeys.accessTokenExpiry: anchor.toUtc().toIso8601String(),
        },
      );

      final tokens = await repository.refreshSession();

      expect(tokens.accessToken, startsWith('mock.access.'));
      expect(tokens.refreshToken, startsWith('mock.refresh.'));
      expect(tokens.accessToken, isNot('mock.access.seed'));
      expect(await store.read(SecureKeys.accessToken), tokens.accessToken);
      expect(await store.read(SecureKeys.refreshToken), tokens.refreshToken);
      expect(
        await store.read(SecureKeys.accessTokenExpiry),
        tokens.expiresAt.toUtc().toIso8601String(),
      );
    });

    test('concurrent callers share one single-flight exchange', () async {
      final (repository, _, _) = await buildRepo(
        seed: <String, String>{SecureKeys.refreshToken: 'mock.refresh.seed'},
      );

      final first = repository.refreshSession();
      final second = repository.refreshSession();
      final a = await first;
      final b = await second;

      expect(identical(a, b), isTrue, reason: 'one in-flight exchange, one answer');
    });

    test('a refresh token the server does not know is rejected', () async {
      final (repository, _, _) = await buildRepo(
        seed: <String, String>{SecureKeys.refreshToken: 'stolen.token'},
      );
      expect(
        repository.refreshSession(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.reason,
            'reason',
            AuthFailureReason.refreshRejected,
          ),
        ),
      );
    });

    test('no stored refresh token means the session is over', () async {
      final (repository, _, _) = await buildRepo();
      expect(
        repository.refreshSession(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.reason,
            'reason',
            AuthFailureReason.sessionExpired,
          ),
        ),
      );
    });
  });

  group('restoreSession', () {
    test('rebuilds the session written by signIn', () async {
      final (repository, _, _) = await buildRepo();
      final signedIn = await repository.signIn(
        username: 'mohiur',
        password: 'x',
        rememberDevice: true,
      );

      final restored = await repository.restoreSession();
      expect(restored, isNotNull);
      expect(restored!.accessToken, signedIn.accessToken);
      expect(restored.user.id, signedIn.user.id);
    });

    test('rememberDevice=false drops the tokens on restore', () async {
      final (repository, store, _) = await buildRepo();
      await repository.signIn(
        username: 'mohiur',
        password: 'x',
        rememberDevice: false,
      );

      expect(await repository.restoreSession(), isNull);
      expect(await store.read(SecureKeys.accessToken), isNull);
      expect(await store.read(SecureKeys.refreshToken), isNull);
      // Pairing material survives a forgotten session.
      expect(await store.read(SecureKeys.deviceKey), 'device-key-seed');
    });

    test('nothing stored restores to null', () async {
      final (repository, _, _) = await buildRepo();
      expect(await repository.restoreSession(), isNull);
    });
  });

  group('teardown', () {
    test('signOut wipes tokens and keeps the pairing', () async {
      final (repository, store, preferences) = await buildRepo();
      await repository.signIn(username: 'mohiur', password: 'x', rememberDevice: true);

      await repository.signOut();

      expect(await store.read(SecureKeys.accessToken), isNull);
      expect(await store.read(SecureKeys.refreshToken), isNull);
      expect(await store.read(SecureKeys.deviceKey), 'device-key-seed');
      expect((await preferences.load()).sessionUserJson, isEmpty);
    });

    test('unpair erases keypair and tokens, and resets the pairing marker', () async {
      final (repository, store, preferences) = await buildRepo();
      await repository.signIn(username: 'mohiur', password: 'x', rememberDevice: true);
      // Give the device an id so the server-side unpair path runs too.
      await store.write(SecureKeys.deviceId, 'device-1234');
      await store.write(SecureKeys.devicePrivateKey, 'priv');
      await store.write(SecureKeys.devicePublicKey, 'pub');

      await repository.unpair();

      expect(await store.read(SecureKeys.deviceKey), isNull);
      expect(await store.read(SecureKeys.deviceId), isNull);
      expect(await store.read(SecureKeys.devicePrivateKey), isNull);
      expect(await store.read(SecureKeys.devicePublicKey), isNull);
      expect(await store.read(SecureKeys.accessToken), isNull);
      final prefs = await preferences.load();
      expect(prefs.pairingStatus, 'unpaired');
      expect(prefs.rememberDevice, isTrue, reason: 'sign-in preference is not pairing');
    });
  });
}
