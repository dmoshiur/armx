// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// The configuration is the app's one security boundary: it decides what the client talks to,
/// and it must be impossible to represent a secret in it.
AppConfig configWith({
  required String api,
  required String socket,
  bool mock = true,
  String environment = 'test',
  bool allowCleartext = false,
}) =>
    AppConfig(
      apiBaseUrl: Uri.parse(api),
      webSocketUrl: Uri.parse(socket),
      useMockBackend: mock,
      environment: environment,
      allowCleartextInDebug: allowCleartext,
    );

void main() {
  group('AppConfig.fromEnvironment', () {
    test('defaults to a TLS base URL, a derived socket URL and the mock backend', () {
      final AppConfig config = AppConfig.fromEnvironment();
      expect(config.apiBaseUrl.scheme, 'https');
      expect(config.webSocketUrl.scheme, anyOf('wss', 'ws'));
      expect(config.useMockBackend, isTrue);
      expect(config.environment, isNotEmpty);
      expect(config.apiBaseUrl.host, isNotEmpty);
    });

    test('a cleartext debug/mock build is the only one allowed to be insecure', () {
      final AppConfig config = AppConfig.fromEnvironment();
      // In a Dart VM test run `kDebugMode` is true and the mock default is true, so a
      // cleartext URL would be tolerated — but the default itself is still https.
      expect(config.isSecure, isTrue);
    });
  });

  group('cleartext refusal', () {
    test('a cleartext base URL is rejected unless the build explicitly allows it', () {
      final AppConfig config = configWith(
        api: 'http://armx.example:8080',
        socket: 'ws://armx.example:8080/ws',
        mock: false,
        environment: 'production',
      );
      expect(config.isSecure, isFalse);
      expect(() => config.httpsBaseUrl, throwsArgumentError);
    });

    test('the debug-mock escape hatch is the only way through, and it is visible', () {
      final AppConfig config = configWith(
        api: 'http://10.0.2.2:8443',
        socket: 'ws://10.0.2.2:8443/ws',
        allowCleartext: true,
      );
      expect(config.httpsBaseUrl.scheme, 'http');
      expect(config.isSecure, isFalse);
      // The build says so, in the configuration summary the Diagnostics screen renders.
      expect(config.describe()['secure'], isFalse);
    });

    test('an https URL never throws', () {
      final AppConfig config = configWith(
        api: 'https://armx.example:8443',
        socket: 'wss://armx.example:8443/ws',
        mock: false,
        environment: 'production',
      );
      expect(config.httpsBaseUrl.toString(), 'https://armx.example:8443');
      expect(config.isSecure, isTrue);
    });
  });

  group('describe', () {
    test('reports the configuration without a token, a key or a password', () {
      final AppConfig config = configWith(
        api: 'https://armx.example:8443',
        socket: 'wss://armx.example:8443/ws',
        mock: false,
        environment: 'staging',
      );
      final Map<String, Object?> described = config.describe();
      expect(described['environment'], 'staging');
      expect(described['mock'], isFalse);
      expect(described['baseUrl'], 'https://armx.example:8443');

      final String flattened = described.toString().toLowerCase();
      for (final String forbidden in <String>[
        'token',
        'secret',
        'apikey',
        'api_key',
        'password',
      ]) {
        expect(flattened.contains(forbidden), isFalse);
      }
    });

    test('the summary is exactly these five keys', () {
      final AppConfig config = configWith(
        api: 'https://armx.example:8443',
        socket: 'wss://armx.example:8443/ws',
      );
      // Adding a key here is how a secret would get onto the Diagnostics screen; this test
      // makes that a deliberate change rather than an accident.
      expect(config.describe().keys.toSet(), <String>{
        'baseUrl',
        'socket',
        'mock',
        'environment',
        'secure',
      });
    });
  });

  group('transport defaults', () {
    test('timeouts are bounded and long enough for a slow mobile network', () {
      final AppConfig config = configWith(
        api: 'https://armx.example:8443',
        socket: 'wss://armx.example:8443/ws',
      );
      expect(config.requestTimeout.inSeconds, greaterThanOrEqualTo(10));
      expect(config.requestTimeout.inSeconds, lessThanOrEqualTo(60));
      expect(config.connectTimeout, lessThan(config.requestTimeout));
    });
  });
}
