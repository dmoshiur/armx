// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/errors/app_exception.dart';
import 'package:armx_ai/core/security/risk_tier.dart';
import 'package:armx_ai/data/api/mock/mock_api.dart';
import 'package:armx_ai/data/api/ws_events.dart';
import 'package:armx_ai/data/models/admin.dart';
import 'package:armx_ai/data/models/audit_entry.dart';
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

    test('pair returns an installable device key in the documented format', () async {
      final result = await api.pair(
        serverUrl: Uri.parse('https://api.armx.test'),
        publicKey: List<String>.filled(44, 'A').join(),
        deviceName: 'Mohiur Pixel',
        platform: 'android',
      );

      expect(result.deviceKey, startsWith('mockkey_'));
      expect(result.deviceKey.length, greaterThanOrEqualTo(40));
      expect(result.site, 'home');
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
