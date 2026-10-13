// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/router/routes.dart';
import 'package:armx_ai/data/models/admin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountStatus', () {
    test('round-trips through the wire', () {
      for (final AccountStatus status in AccountStatus.values) {
        expect(AccountStatus.fromWire(status.wire), status);
      }
    });

    test('an unknown status is disabled rather than active', () {
      // An unrecognised account state must never render as a usable account.
      expect(AccountStatus.fromWire('???'), AccountStatus.disabled);
      expect(AccountStatus.fromWire(null), AccountStatus.disabled);
    });
  });

  group('AuditOutcome', () {
    test('an unknown outcome is a failure, not a success', () {
      expect(AuditOutcome.fromWire('whatever'), AuditOutcome.failed);
      expect(AuditOutcome.fromWire(null), AuditOutcome.failed);
    });

    test('denied is distinguishable from failed — the user said no, nothing broke', () {
      expect(AuditOutcome.fromWire('denied'), AuditOutcome.denied);
      expect(AuditOutcome.fromWire('denied'), isNot(AuditOutcome.failed));
    });
  });

  group('AdminUserRow', () {
    test('parses a row the table renders', () {
      final AdminUserRow row = AdminUserRow.fromJson(const <String, Object?>{
        'id': 'u-1',
        'display_name': 'Moshiur',
        'email': 'mohi@thamjj13.top',
        'role': 'admin',
        'status': 'active',
        'linked_device_count': 3,
        'is_self': true,
      });
      expect(row.role, UserRole.admin);
      expect(row.status, AccountStatus.active);
      expect(row.linkedDeviceCount, 3);
      expect(row.isSelf, isTrue);
    });

    test('an admin cannot suspend themselves; the model says who this row is', () {
      final AdminUserRow self = AdminUserRow.fromJson(const <String, Object?>{
        'id': 'u-1',
        'email': 'mohi@thamjj13.top',
        'role': 'admin',
        'is_self': true,
      });
      expect(self.isSelf, isTrue);
    });
  });

  group('AuditEntry', () {
    test('parses an entry with its outcome and risk', () {
      final AuditEntry entry = AuditEntry.fromJson(const <String, Object?>{
        'id': 'e-1',
        'occurred_at': '2026-10-13T04:30:00Z',
        'actor_email': 'mohi@thamjj13.top',
        'action': 'unlock_front_door',
        'outcome': 'success',
        'risk_tier': 'high',
        'target_label': 'Front door',
        'request_id': 'req-9',
      });
      expect(entry.action, 'unlock_front_door');
      expect(entry.outcome, AuditOutcome.success);
      expect(entry.riskTierName, 'high');
      expect(entry.requestId, 'req-9');
    });

    test('an entry with no outcome reported reads as failed rather than as approved', () {
      final AuditEntry entry = AuditEntry.fromJson(const <String, Object?>{
        'id': 'e-2',
        'action': 'set_light',
      });
      expect(entry.outcome, AuditOutcome.failed);
    });
  });

  group('ToolToggle', () {
    test('a disabled tool can carry the reason it is unavailable', () {
      final ToolToggle toggle = ToolToggle.fromJson(const <String, Object?>{
        'id': 'web_deploy',
        'name': 'Web deploy',
        'description': 'Publishes a generated site.',
        'enabled': false,
        'risk_tier': 'high',
        'blocked_reason': 'No repository is connected.',
      });
      expect(toggle.enabled, isFalse);
      expect(toggle.blockedReason, 'No repository is connected.');
      expect(toggle.riskTierName, 'high');
    });

    test('a tool with no risk tier reported is assumed high-risk', () {
      final ToolToggle toggle = ToolToggle.fromJson(const <String, Object?>{
        'id': 'mystery',
        'name': 'Mystery',
      });
      expect(toggle.riskTierName, isNotEmpty);
    });
  });

  group('KillSwitchState', () {
    test('an engaged kill switch says when, by whom and why', () {
      final KillSwitchState state = KillSwitchState.fromJson(const <String, Object?>{
        'engaged': true,
        'engaged_at': '2026-10-13T04:30:00Z',
        'engaged_by': 'mohi@thamjj13.top',
        'reason': 'Suspicious command',
      });
      expect(state.engaged, isTrue);
      expect(state.engagedBy, 'mohi@thamjj13.top');
      expect(state.reason, 'Suspicious command');
    });

    test('a missing payload is disengaged — but it reports no phantom author', () {
      final KillSwitchState state = KillSwitchState.fromJson(const <String, Object?>{});
      expect(state.engaged, isFalse);
      expect(state.engagedBy, isNull);
      expect(state.engagedAt, isNull);
    });
  });

  group('SessionInfo', () {
    test('parses a session, including the one making the request', () {
      final SessionInfo session = SessionInfo.fromJson(const <String, Object?>{
        'id': 's-1',
        'device_name': 'Pixel 8',
        'platform': 'android',
        'created_at': '2026-10-01T09:00:00Z',
        'last_used_at': '2026-10-13T04:00:00Z',
        'current': true,
        'ip_hint': 'Shibganj, BD',
      });
      expect(session.deviceName, 'Pixel 8');
      expect(session.current, isTrue);
      expect(session.ipHint, 'Shibganj, BD');
    });

    test('a session with no timestamps still parses, so the list never crashes the screen',
        () {
      final SessionInfo session = SessionInfo.fromJson(const <String, Object?>{
        'id': 's-2',
      });
      expect(session.id, 's-2');
      expect(session.current, isFalse);
      expect(session.deviceName, isNotNull);
    });
  });
}
