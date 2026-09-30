// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/errors/app_exception.dart';
import 'package:armx_ai/core/security/risk_tier.dart';
import 'package:armx_ai/data/api/mock/mock_api.dart';
import 'package:armx_ai/data/api/ws_events.dart';
import 'package:armx_ai/data/models/admin.dart';
import 'package:armx_ai/data/models/audit_entry.dart';
import 'package:armx_ai/data/models/auth.dart';
import 'package:armx_ai/data/models/device.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

/// The mock backend is the only backend that exists, so it carries the same weight as a
/// real service: these tests pin its contract (determinism, error codes, kill-switch
/// semantics) that every screen is built against.
void main() {
  late MockArmxApi api;

  setUp(() {
    api = Fixtures.mockApi();
  });

  tearDown(() async {
    await api.dispose();
  });

  group('determinism', () {
    test('two instances with the same seed agree on devices, audit and rules', () async {
      final other = Fixtures.mockApi();
      addTearDown(other.dispose);

      final devices = await api.devices();
      final otherDevices = await other.devices();
      final audit = await api.audit(const AuditQuery(limit: 50));
      final otherAudit = await other.audit(const AuditQuery(limit: 50));

      expect(
        devices.map((device) => device.id).toList(),
        otherDevices.map((device) => device.id).toList(),
      );
      expect(audit.map((entry) => entry.id).toList(), otherAudit.map((entry) => entry.id).toList());
      // Same seed ⇒ same sequence, so demo data never shuffles between runs.
      expect(
        MockArmxApi.deterministicRandom().nextInt(1 << 31),
        MockArmxApi.deterministicRandom().nextInt(1 << 31),
      );
    });

    test('the seed data matches the documented demo estate', () async {
      final devices = await api.devices();
      final targets = await api.unlockTargets();
      final tools = await api.adminState();

      expect(devices, hasLength(4));
      expect(devices.every((device) => device.site == 'home'), isTrue);
      expect(targets, hasLength(3));
      expect(tools.tools.length, greaterThanOrEqualTo(5));
      expect(api.conversationId, 'conv-0001');
    });
  });

  group('auth and pairing', () {
    test('valid credentials return a session with a refresh token', () async {
      final session = await api.login(
        serverUrl: Uri.parse('https://api.armx.test'),
        username: 'mohiur',
        password: 'correct horse battery staple',
        deviceKey: 'mockkey_0123456789abcdef0123456789abcdef',
      );

      expect(session.accessToken, startsWith('mock.access.'));
      expect(session.refreshToken, startsWith('mock.refresh.'));
      expect(session.user.displayName, contains('Moshiur'));
      expect(session.expiresAt.isAfter(Fixtures.anchor), isTrue);
    });

    test('wrong credentials fail with a typed reason', () async {
      await expectLater(
        api.login(
          serverUrl: Uri.parse('https://api.armx.test'),
          username: 'wrong',
          password: 'x',
          deviceKey: 'mockkey_0123456789abcdef0123456789abcdef',
        ),
        throwsA(
          isA<AuthException>().having(
            (error) => error.reason,
            'reason',
            AuthFailureReason.invalidCredentials,
          ),
        ),
      );
    });

    test('a short device key is rejected as a pairing failure', () async {
      await expectLater(
        api.login(
          serverUrl: Uri.parse('https://api.armx.test'),
          username: 'mohiur',
          password: 'pw',
          deviceKey: 'short',
        ),
        throwsA(
          isA<AuthException>().having(
            (error) => error.reason,
            'reason',
            AuthFailureReason.pairingRejected,
          ),
        ),
      );
    });

    test('a locked account fails with its own typed reason', () async {
      await expectLater(
        api.login(
          serverUrl: Uri.parse('https://api.armx.test'),
          username: 'locked',
          password: 'whatever',
          deviceKey: 'mockkey_0123456789abcdef0123456789abcdef',
        ),
        throwsA(
          isA<AuthException>().having(
            (error) => error.reason,
            'reason',
            AuthFailureReason.accountLocked,
          ),
        ),
      );
    });

    test('health reports reachability, version and TLS fingerprint', () async {
      final probe = await api.health(Uri.parse('https://api.armx.test'));

      expect(probe.reachable, isTrue);
      expect(probe.serverVersion, 'mock-1.0.0');
      expect(probe.tlsFingerprintMatched, isTrue);

      api.control.offline = true;
      await expectLater(
        api.health(Uri.parse('https://api.armx.test')),
        throwsA(isA<NetworkException>()),
      );
    });

    test('refresh mints a new pair only for tokens the mock issued', () async {
      final tokens = await api.refresh(
        serverUrl: Uri.parse('https://api.armx.test'),
        refreshToken: 'mock.refresh.abc123',
      );

      expect(tokens.accessToken, startsWith('mock.access.'));
      expect(tokens.refreshToken, startsWith('mock.refresh.'));
      expect(tokens.expiresAt.isAfter(Fixtures.anchor), isTrue);

      await expectLater(
        api.refresh(
          serverUrl: Uri.parse('https://api.armx.test'),
          refreshToken: 'bogus.token',
        ),
        throwsA(
          isA<AuthException>().having(
            (error) => error.reason,
            'reason',
            AuthFailureReason.refreshRejected,
          ),
        ),
      );
    });

    test('pair approves by default and keeps the documented key format', () async {
      final status = await api.pair(
        serverUrl: Uri.parse('https://api.armx.test'),
        publicKey: List<String>.filled(44, 'A').join(),
        deviceName: 'Mohiur Pixel',
        platform: 'android',
      );

      expect(status.state, PairingState.approved);
      expect(status.isPaired, isTrue);
      expect(status.result, isNotNull);
      expect(status.result!.deviceKey, startsWith('mockkey_'));
      expect(status.result!.deviceKey.length, greaterThanOrEqualTo(40));
      expect(status.result!.site, 'home');
    });

    test('pair can stay pending with a stable device id until approved', () async {
      api.control.pairingOutcome = MockPairingOutcome.pending;
      final publicKey = List<String>.filled(44, 'B').join();

      final first = await api.pair(
        serverUrl: Uri.parse('https://api.armx.test'),
        publicKey: publicKey,
        deviceName: 'Mohiur Pixel',
        platform: 'android',
      );
      final second = await api.pair(
        serverUrl: Uri.parse('https://api.armx.test'),
        publicKey: publicKey,
        deviceName: 'Mohiur Pixel',
        platform: 'android',
      );

      expect(first.state, PairingState.pending);
      expect(first.isPending, isTrue);
      expect(second.deviceId, first.deviceId);

      api.control.pairingOutcome = MockPairingOutcome.approved;
      final approved = await api.pair(
        serverUrl: Uri.parse('https://api.armx.test'),
        publicKey: publicKey,
        deviceName: 'Mohiur Pixel',
        platform: 'android',
      );

      expect(approved.state, PairingState.approved);
      expect(approved.deviceId, first.deviceId);
    });

    test('pair reports a rejection with the pairing-rejected reason', () async {
      api.control.pairingOutcome = MockPairingOutcome.rejected;

      await expectLater(
        api.pair(
          serverUrl: Uri.parse('https://api.armx.test'),
          publicKey: List<String>.filled(44, 'C').join(),
          deviceName: 'Mohiur Pixel',
          platform: 'android',
        ),
        throwsA(
          isA<AuthException>().having(
            (error) => error.reason,
            'reason',
            AuthFailureReason.pairingRejected,
          ),
        ),
      );
    });

    test('unpair is idempotent and does not disturb other endpoints', () async {
      await api.unpair(
        serverUrl: Uri.parse('https://api.armx.test'),
        deviceId: 'device-unknown',
      );

      final session = await api.login(
        serverUrl: Uri.parse('https://api.armx.test'),
        username: 'mohiur',
        password: 'correct horse battery staple',
        deviceKey: 'mockkey_0123456789abcdef0123456789abcdef',
      );
      await api.unpair(serverUrl: Uri.parse('https://api.armx.test'), deviceId: session.deviceId);
    });
  });

  group('devices', () {
    test('an unknown device id is a 404', () async {
      await expectLater(
        api.sendCommand(deviceId: 'nope', command: 'relay-main:ON'),
        throwsA(isA<ApiException>().having((error) => error.statusCode, 'status', 404)),
      );
    });

    test('toggling a relay mutates the mock state and emits an event', () async {
      final events = <WsEvent>[];
      final subscription = api.events().listen(events.add);
      addTearDown(subscription.cancel);

      final result = await api.sendCommand(deviceId: 'dev-living-light', command: 'relay-main:ON');
      final devices = await api.devices();
      final relay = devices
          .firstWhere((device) => device.id == 'dev-living-light')
          .relays
          .firstWhere((relay) => relay.id == 'relay-main');

      expect(result.accepted, isTrue);
      expect(result.deviceId, 'dev-living-light');
      expect(relay.state, RelayState.on);
      await Future<void>.delayed(Duration.zero);
      expect(events.whereType<DeviceStateEvent>(), isNotEmpty);
    });

    test('simulated offline mode surfaces as a retryable network error', () async {
      api.control.offline = true;

      await expectLater(
        api.devices(),
        throwsA(isA<NetworkException>().having((error) => error.isRetryable, 'retryable', isTrue)),
      );
    });
  });

  group('kill-switch', () {
    test('engaging clears tool calls, reports closed sockets and blocks commands', () async {
      final state = await api.setKillSwitch(engaged: true, reason: 'test');

      expect(state.engaged, isTrue);
      expect(state.socketsClosed, 1);
      await expectLater(
        api.sendCommand(deviceId: 'dev-living-light', command: 'relay-main:ON'),
        throwsA(isA<KillSwitchActiveException>()),
      );
      await expectLater(
        api.sendChatMessage('hello', conversationId: api.conversationId),
        throwsA(isA<KillSwitchActiveException>()),
      );
    });

    test('the kill event reaches subscribers before the socket closes', () async {
      final events = <WsEvent>[];
      api.events().listen(events.add);
      await Future<void>.delayed(Duration.zero);

      await api.setKillSwitch(engaged: true);

      final killed = events.whereType<SystemKilledEvent>().toList();
      expect(killed, hasLength(1));
      expect(killed.single.engaged, isTrue);
      expect(killed.single.actor, 'owner');
    });

    test('releasing the switch restores commands and is audited', () async {
      await api.setKillSwitch(engaged: true);
      final released = await api.setKillSwitch(engaged: false);
      final audit = await api.audit(const AuditQuery(search: 'kill'));

      expect(released.engaged, isFalse);
      expect(released.socketsClosed, 0);
      expect((await api.adminState()).killSwitchEngaged, isFalse);
      expect(audit, isNotEmpty);
      expect(audit.first.action, 'admin.kill');
      expect(audit.first.riskTier, RiskTier.high);
    });

    test('tool switches can be toggled individually', () async {
      final tools = await api.setToolEnabled(tool: ToolId.github, enabled: false);
      final github = tools.where((tool) => tool.id == ToolId.github).single;

      expect(github.enabled, isFalse);
      expect((await api.adminState()).tools.where((t) => t.id == ToolId.github).single.enabled,
          isFalse);
    });

    test('revoking a device removes it from the estate', () async {
      final before = await api.devices();
      await api.revokeDevice(before.first.id);
      final after = await api.devices();

      expect(after.length, before.length - 1);
      expect(after.any((device) => device.id == before.first.id), isFalse);
    });
  });
}
