// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:typed_data';

import 'package:armx_ai/core/security/secure_store.dart';
import 'package:armx_ai/core/utils/clock.dart';
import 'package:armx_ai/data/api/mock/mock_api.dart';
import 'package:armx_ai/data/api/rest/auth_interceptor.dart';
import 'package:armx_ai/data/db/armx_database.dart';
import 'package:armx_ai/data/repositories/preferences_repository.dart';
import 'package:armx_ai/features/auth/session/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

/// Behaviour of the dio auth layer, driven against a scripted
/// [HttpClientAdapter] so no sockets are involved:
///
/// * proactive refresh when the stored access token is inside the leeway;
/// * exactly one replay of a `401` with a fresh token;
/// * a rejected refresh ends the session (router lands on login);
/// * a transport failure during refresh does **not** end the session.
void main() {
  final anchor = Fixtures.anchor;

  late InMemorySecureStore store;
  late PreferencesRepository preferences;
  late AuthRepository repository;
  late MockBackendControl control;

  setUp(() async {
    store = InMemorySecureStore();
    preferences = PreferencesRepository(ArmxDatabase(NativeDatabase.memory()));
    await preferences.setLastServerUrl('https://api.armx.test');
    control = MockBackendControl(latency: Duration.zero, tokenInterval: Duration.zero);
    repository = AuthRepository(
      api: Fixtures.mockApi(clock: FixedClock(anchor), control: control),
      store: store,
      preferences: preferences,
      clock: FixedClock(anchor),
      logger: Fixtures.silentLogger(),
    );
  });

  ({Dio dio, _ScriptedAdapter adapter, int Function() expired}) buildDio(_ScriptedAdapter adapter) {
    var expired = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.armx.test'));
    final interceptor = AuthInterceptor(
      repository: repository,
      onSessionExpired: () => expired += 1,
    );
    dio.interceptors.add(interceptor);
    interceptor.dio = dio;
    return (dio: dio, adapter: adapter, expired: () => expired);
  }

  test('a token inside the refresh leeway is replaced before the request flies',
      () async {
    await store.write(SecureKeys.accessToken, 'mock.access.seed');
    await store.write(SecureKeys.refreshToken, 'mock.refresh.seed');
    await store.write(
      SecureKeys.accessTokenExpiry,
      anchor.add(const Duration(seconds: 30)).toUtc().toIso8601String(),
    );
    final adapter = _ScriptedAdapter((options, call) async => _jsonOk());
    final harness = buildDio(adapter);

    final response = await harness.dio.get<void>('/probe');

    expect(response.statusCode, 200);
    expect(adapter.fetches, 1, reason: 'refresh happens before, not as a retry');
    expect(adapter.authHeaders.first, startsWith('Bearer mock.access.'));
    expect(adapter.authHeaders.first, isNot('Bearer mock.access.seed'));
    expect(await store.read(SecureKeys.accessToken), isNot('mock.access.seed'));
    expect(harness.expired(), 0);
  });

  test('a 401 is replayed exactly once with the refreshed token', () async {
    await store.write(SecureKeys.accessToken, 'mock.access.seed');
    await store.write(SecureKeys.refreshToken, 'mock.refresh.seed');
    await store.write(
      SecureKeys.accessTokenExpiry,
      anchor.add(const Duration(minutes: 30)).toUtc().toIso8601String(),
    );
    final adapter = _ScriptedAdapter(
      (options, call) async => call == 1 ? _jsonStatus(401) : _jsonOk(),
    );
    final harness = buildDio(adapter);

    final response = await harness.dio.get<void>('/probe');

    expect(response.statusCode, 200);
    expect(adapter.fetches, 2, reason: 'one original call, one replay');
    expect(adapter.authHeaders.first, 'Bearer mock.access.seed');
    expect(adapter.authHeaders.last, isNot('Bearer mock.access.seed'));
    expect(harness.expired(), 0);
  });

  test('a second 401 after the replay is not retried again', () async {
    await store.write(SecureKeys.accessToken, 'mock.access.seed');
    await store.write(SecureKeys.refreshToken, 'mock.refresh.seed');
    await store.write(
      SecureKeys.accessTokenExpiry,
      anchor.add(const Duration(minutes: 30)).toUtc().toIso8601String(),
    );
    final adapter = _ScriptedAdapter((options, call) async => _jsonStatus(401));
    final harness = buildDio(adapter);

    await expectLater(
      harness.dio.get<void>('/probe'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.fetches, 2, reason: 'the single auth retry budget is spent');
    expect(harness.expired(), 0, reason: 'the refresh itself succeeded');
  });

  test('a rejected refresh fires onSessionExpired and skips the replay', () async {
    await store.write(SecureKeys.accessToken, 'mock.access.seed');
    await store.write(SecureKeys.refreshToken, 'not-a-mock-token');
    await store.write(
      SecureKeys.accessTokenExpiry,
      anchor.add(const Duration(minutes: 30)).toUtc().toIso8601String(),
    );
    final adapter = _ScriptedAdapter((options, call) async => _jsonStatus(401));
    final harness = buildDio(adapter);

    await expectLater(
      harness.dio.get<void>('/probe'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.fetches, 1, reason: 'no point replaying a dead session');
    expect(harness.expired(), 1);
  });

  test('a transport failure while refreshing keeps the session alive', () async {
    await store.write(SecureKeys.accessToken, 'mock.access.seed');
    await store.write(SecureKeys.refreshToken, 'mock.refresh.seed');
    await store.write(
      SecureKeys.accessTokenExpiry,
      anchor.add(const Duration(minutes: 30)).toUtc().toIso8601String(),
    );
    control.offline = true;
    final adapter = _ScriptedAdapter((options, call) async => _jsonStatus(401));
    final harness = buildDio(adapter);

    await expectLater(
      harness.dio.get<void>('/probe'),
      throwsA(isA<DioException>()),
    );
    expect(harness.expired(), 0, reason: 'offline is retryable, expiry is not');
  });
}

ResponseBody _jsonOk() => ResponseBody.fromString(
      '{"ok":true}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );

ResponseBody _jsonStatus(int status) => ResponseBody.fromString(
      '{}',
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );

/// Scripted [HttpClientAdapter]: records the Authorization header of every
/// fetch and answers through the per-test closure.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._respond);

  final Future<ResponseBody> Function(RequestOptions options, int call) _respond;

  /// Number of transport-level fetches performed.
  int fetches = 0;

  /// `Authorization` header seen by each fetch, in order.
  final List<Object?> authHeaders = <Object?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetches += 1;
    Object? auth;
    for (final entry in options.headers.entries) {
      if (entry.key.toLowerCase() == 'authorization') {
        auth = entry.value;
      }
    }
    authHeaders.add(auth);
    return _respond(options, fetches);
  }

  @override
  void close({bool force = false}) {}
}
