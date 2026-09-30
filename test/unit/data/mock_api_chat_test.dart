// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/errors/app_exception.dart';
import 'package:armx_ai/core/security/risk_tier.dart';
import 'package:armx_ai/core/security/security_constants.dart';
import 'package:armx_ai/data/api/mock/mock_api.dart';
import 'package:armx_ai/data/api/ws_events.dart';
import 'package:armx_ai/data/models/audit_entry.dart';
import 'package:armx_ai/data/models/unlock.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

/// Unlock-token, rule, chat-streaming and audit-query behaviour of the mock backend.
void main() {
  late MockArmxApi api;

  setUp(() {
    api = Fixtures.mockApi();
  });

  tearDown(() async {
    await api.dispose();
  });

  group('unlock tokens', () {
    SignedUnlockToken token(DateTime expiresAt, {String signature = 'sig', String key = 'pub'}) =>
        SignedUnlockToken(
          payload: UnlockTokenPayload(
            deviceId: 'pc-studio',
            nonce: 'nonce-1',
            issuedAt: Fixtures.anchor,
            expiresAt: expiresAt,
            action: 'unlock',
          ),
          signature: signature,
          publicKey: key,
        );

    test('an unsigned token is rejected with 400', () async {
      await expectLater(
        api.requestUnlock(
          token(Fixtures.anchor.add(const Duration(seconds: 10)), signature: ''),
        ),
        throwsA(isA<ApiException>().having((error) => error.statusCode, 'status', 400)),
      );
    });

    test('a token valid for longer than 30 s is rejected', () async {
      await expectLater(
        api.requestUnlock(token(Fixtures.anchor.add(const Duration(seconds: 31)))),
        throwsA(
          isA<ApiException>().having((error) => error.serverCode, 'code', 'token_ttl_too_long'),
        ),
      );
    });

    test('an expired token is reported as expired, not as an error', () async {
      final outcome = await api.requestUnlock(token(Fixtures.anchor.subtract(const Duration(seconds: 1))));

      expect(outcome.status, UnlockStatus.expired);
      expect(outcome.targetId, 'pc-studio');
    });

    test('a fresh token unlocks and mentions the owner assertion', () async {
      final outcome = await api.requestUnlock(
        token(Fixtures.anchor.add(const Duration(seconds: 10))),
        assertion: OwnerVerifiedToken(
          token: 'owner-assertion-1',
          issuedAt: Fixtures.anchor,
          expiresAt: Fixtures.anchor.add(SecurityConstants.ownerVerifiedTtl),
        ),
      );

      expect(outcome.status, UnlockStatus.unlocked);
      expect(outcome.message, contains('owner assertion'));
    });

    test('revoking a target only clears the pairing flag', () async {
      final targets = await api.revokeUnlockTarget('pc-studio');

      expect(targets.where((target) => target.id == 'pc-studio').single.paired, isFalse);
    });
  });

  group('rules', () {
    test('dry run explains the risk tier without executing', () async {
      final rules = await api.rules();
      final result = await api.dryRunRule(rules.first);

      expect(result.ruleId, rules.first.id);
      expect(result.steps.join(' '), contains(rules.first.riskTier.wireName));
      expect(result.wouldFire, rules.first.enabled);
    });

    test('upsert then delete round-trips', () async {
      final rules = await api.rules();
      final updated = rules.first.copyWith(enabled: false);

      expect((await api.upsertRule(updated)).enabled, isFalse);
      await api.deleteRule(updated.id);
      expect((await api.rules()).any((rule) => rule.id == updated.id), isFalse);
    });

    test('seed rules cover both trigger types', () async {
      final rules = await api.rules();

      expect(rules, hasLength(greaterThanOrEqualTo(2)));
      expect(rules.map((rule) => rule.triggerType).toSet().length, greaterThanOrEqualTo(2));
    });
  });

  group('chat streaming', () {
    test('a prompt streams tokens and then a done event', () async {
      final events = <WsEvent>[];
      final subscription = api.events().listen(events.add);
      addTearDown(subscription.cancel);

      await api.sendChatMessage('what is in the audit log?', conversationId: api.conversationId);
      await pumpEventQueue(times: 40);

      final tokens = events.whereType<AssistantTokenEvent>().toList();
      final done = events.whereType<AssistantDoneEvent>().toList();
      expect(tokens.length, greaterThan(3));
      expect(tokens.every((token) => token.messageId == 'msg-a-000001'), isTrue);
      expect(tokens.first.index, 0);
      expect(done, hasLength(1));
      expect(done.single.text, contains('Last 24 hours'));
    });

    test('a MEDIUM risk prompt raises a tool card after the reply', () async {
      final events = <WsEvent>[];
      api.events().listen(events.add);

      await api.sendChatMessage('turn on the living room light', conversationId: api.conversationId);
      await Future<void>.delayed(const Duration(milliseconds: 250));

      final request = events.whereType<ToolRequestEvent>().single;
      expect(request.toolName, 'mqtt.publish');
      expect(request.riskTier, RiskTier.medium);
      expect(request.parameters['topic'], 'armx/home/dev-living-light/cmd');
    });

    test('a HIGH risk tool needs the owner assertion to be approved', () async {
      final events = <WsEvent>[];
      api.events().listen(events.add);
      await api.sendChatMessage('unlock my studio pc', conversationId: api.conversationId);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final call = events.whereType<ToolRequestEvent>().single;

      expect(call.riskTier, RiskTier.high);
      await expectLater(
        api.decideToolCall(toolCallId: call.toolCallId, approve: true),
        throwsA(isA<PolicyException>()),
      );
      await expectLater(
        api.decideToolCall(toolCallId: call.toolCallId, approve: false),
        completes,
      );
    });

    test('Bengali locale streams a Bengali reply', () async {
      final bengali = Fixtures.mockApi(locale: 'bn');
      addTearDown(bengali.dispose);
      final events = <WsEvent>[];
      bengali.events().listen(events.add);

      await bengali.sendChatMessage('কেমন আছো?', conversationId: bengali.conversationId);
      await pumpEventQueue(times: 40);

      final done = events.whereType<AssistantDoneEvent>().single;
      expect(done.text, contains('প্রস্তুত'));
    });
  });

  group('audit queries', () {
    test('search and outcome filters narrow the result set', () async {
      final all = await api.audit(const AuditQuery(limit: 50));
      final denied = await api.audit(const AuditQuery(outcome: AuditOutcome.denied, limit: 50));
      final searched = await api.audit(const AuditQuery(search: 'gate', limit: 50));

      expect(all.length, greaterThanOrEqualTo(12));
      expect(denied.every((entry) => entry.outcome == AuditOutcome.denied), isTrue);
      expect(searched, isNotEmpty);
      expect(searched.every((entry) => entry.target.contains('gate') || entry.detail.contains('gate')),
          isTrue);
    });

    test('newest entries come first and paging is honoured', () async {
      final page1 = await api.audit(const AuditQuery(limit: 5));
      final page2 = await api.audit(const AuditQuery(limit: 5, offset: 5));

      expect(page1.first.at.isAfter(page1.last.at), isTrue);
      expect(page1.map((entry) => entry.id).toSet().intersection(
            page2.map((entry) => entry.id).toSet(),
          ), isEmpty);
    });
  });
}
