// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:armx_ai/core/errors/app_exception.dart';
import 'package:armx_ai/core/providers.dart';
import 'package:armx_ai/core/security/risk_tier.dart';
import 'package:armx_ai/data/api/armx_api.dart';
import 'package:armx_ai/data/api/mock/mock_api.dart';
import 'package:armx_ai/data/api/ws_events.dart';
import 'package:armx_ai/data/db/armx_database.dart';
import 'package:armx_ai/data/models/chat.dart';
import 'package:armx_ai/data/models/unlock.dart';
import 'package:armx_ai/features/chat/chat_controller.dart';
import 'package:armx_ai/features/chat/chat_state.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';
import '../../../support/test_harness.dart';

/// Minimal [ArmxApi] stand-in for the failure paths the deterministic mock
/// cannot produce (a refused send, an immediately closed socket).
///
/// Every member the chat controller does not use throws through
/// [noSuchMethod], so a test fails loudly instead of silently passing.
class _StubApi implements ArmxApi {
  _StubApi({
    this.onSend,
    this.onDecide,
    Stream<WsEvent> events = const Stream<WsEvent>.empty(),
  }) : _events = events;

  final Future<void> Function(String text, {required String conversationId})? onSend;
  final Future<void> Function({
    required String toolCallId,
    required bool approve,
    OwnerVerifiedToken? assertion,
  })? onDecide;
  final Stream<WsEvent> _events;

  @override
  Stream<WsEvent> events() => _events;

  @override
  Future<void> sendChatMessage(String text, {required String conversationId}) =>
      onSend?.call(text, conversationId: conversationId) ?? Future<void>.value();

  @override
  Future<void> decideToolCall({
    required String toolCallId,
    required bool approve,
    OwnerVerifiedToken? assertion,
  }) =>
      onDecide?.call(toolCallId: toolCallId, approve: approve, assertion: assertion) ??
      Future<void>.value();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late MockArmxApi api;

  setUp(() {
    api = Fixtures.mockApi(
      control: MockBackendControl(
        latency: Duration.zero,
        tokenInterval: Duration.zero,
        toolCallDelay: Duration.zero,
      ),
    );
  });

  tearDown(() async {
    await api.dispose();
  });

  ProviderContainer containerWith({ArmxApi? override, ArmxDatabase? database}) {
    final container = ProviderContainer(
      overrides: <Override>[
        ...testOverrides(database: database),
        if (override != null) armxApiProvider.overrideWithValue(override),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Lets the mock's zero-latency streaming and result timers drain.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

  group('transcript', () {
    test('a prompt streams tokens and finalises with the server text', () async {
      final container = containerWith(override: api);
      await container.read(chatControllerProvider.notifier).send('what is in the audit log?');
      await settle();

      final messages = container.read(chatControllerProvider).messages;
      expect(messages.where((m) => m.role == ChatRole.user), hasLength(1));
      final reply = messages.where((m) => m.role == ChatRole.assistant).single;
      expect(reply.text, contains('Last 24 hours'));
      expect(reply.status, ChatMessageStatus.sent);
      expect(container.read(chatControllerProvider).isStreaming, isFalse);
    });

    test('an empty draft is never sent', () async {
      final container = containerWith(override: api);
      await container.read(chatControllerProvider.notifier).send('   ');
      await settle();

      expect(container.read(chatControllerProvider).messages, isEmpty);
    });
  });

  group('tool approvals', () {
    test('a MEDIUM call raises a card and approval runs it end to end', () async {
      final container = containerWith(override: api);
      final controller = container.read(chatControllerProvider.notifier);
      await controller.send('turn on the living room light');
      await settle();

      final pending = container.read(chatControllerProvider).toolCalls['call-light-1'];
      expect(pending, isNotNull);
      expect(pending!.riskTier, RiskTier.medium);
      expect(pending.status, ToolCallStatus.pending);
      expect(pending.needsDecision, isTrue);
      expect(pending.requiresVerification, isTrue);
      expect(
        container.read(chatControllerProvider).messages.any((m) => m.toolCallId == 'call-light-1'),
        isTrue,
      );

      await controller.approve('call-light-1');
      await settle();

      final done = container.read(chatControllerProvider).toolCalls['call-light-1']!;
      expect(done.status, ToolCallStatus.succeeded);
      expect(done.resultSummary, contains('mqtt.publish'));
    });

    test('a HIGH call needs the minted owner_verified assertion', () async {
      final container = containerWith(override: api);
      final controller = container.read(chatControllerProvider.notifier);
      await controller.send('unlock my studio pc');
      await settle();

      final pending = container.read(chatControllerProvider).toolCalls['call-unlock-1']!;
      expect(pending.riskTier, RiskTier.high);

      await controller.approve('call-unlock-1');
      await settle();

      // The mock rejects a HIGH approval without the assertion, so a
      // succeeded card proves the controller minted and sent one.
      expect(
        container.read(chatControllerProvider).toolCalls['call-unlock-1']!.status,
        ToolCallStatus.succeeded,
      );
    });

    test('denying a call closes the card as denied', () async {
      final container = containerWith(override: api);
      final controller = container.read(chatControllerProvider.notifier);
      await controller.send('turn on the living room light');
      await settle();

      await controller.deny('call-light-1');
      await settle();

      final call = container.read(chatControllerProvider).toolCalls['call-light-1']!;
      expect(call.status, ToolCallStatus.denied);
      expect(call.resultSummary, contains('Denied'));
    });

    test('a LOW call runs immediately without a card', () async {
      final container = containerWith(override: api);
      final controller = container.read(chatControllerProvider.notifier);
      await controller.send('give me a status snapshot');
      await settle();

      final state = container.read(chatControllerProvider);
      expect(state.toolCalls, isEmpty);
      final toolLines = state.messages.where((m) => m.role == ChatRole.tool).toList();
      expect(toolLines, hasLength(1));
      expect(toolLines.single.text, contains('devices.list'));
    });

    test('approving a second MEDIUM call reuses the fresh verification', () async {
      final container = containerWith(override: api);
      final controller = container.read(chatControllerProvider.notifier);
      await controller.send('turn on the living room light');
      await settle();
      await controller.approve('call-light-1');
      await settle();

      await controller.send('switch on the lamp please');
      await settle();
      await controller.approve('call-light-1');
      await settle();

      expect(
        container.read(chatControllerProvider).toolCalls['call-light-1']!.status,
        ToolCallStatus.succeeded,
      );
    });
  });

  group('kill-switch', () {
    test('engaging it blocks sending and expires pending cards', () async {
      final container = containerWith(override: api);
      final controller = container.read(chatControllerProvider.notifier);
      await controller.send('turn on the living room light');
      await settle();
      expect(
        container.read(chatControllerProvider).toolCalls['call-light-1']!.status,
        ToolCallStatus.pending,
      );

      await api.setKillSwitch(engaged: true);
      await settle();

      final state = container.read(chatControllerProvider);
      expect(state.killed, isTrue);
      expect(state.toolCalls['call-light-1']!.status, ToolCallStatus.expired);

      await controller.send('hello');
      await settle();
      // The draft is dropped locally, so no second user bubble appears.
      expect(state.messages.where((m) => m.role == ChatRole.user), hasLength(1));
    });

    test('releasing it restores the composer after the reconnect', () async {
      final container = containerWith(override: api);
      container.read(chatControllerProvider.notifier);

      await api.setKillSwitch(engaged: true);
      await settle();
      expect(container.read(chatControllerProvider).killed, isTrue);

      // The mock closed the socket; the controller reconnects with backoff.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await api.setKillSwitch(engaged: false);
      await settle();

      expect(container.read(chatControllerProvider).killed, isFalse);
      expect(container.read(chatControllerProvider).connection, ChatConnection.live);
    });
  });

  group('failures', () {
    test('a refused send is marked failed and retried in place', () async {
      var attempts = 0;
      final stub = _StubApi(
        onSend: (text, {required conversationId}) async {
          attempts += 1;
          throw const NetworkException('Simulated offline mode');
        },
      );
      final container = containerWith(override: stub);
      final controller = container.read(chatControllerProvider.notifier);
      await controller.send('hello');
      await settle();

      final state = container.read(chatControllerProvider);
      expect(state.messages.single.status, ChatMessageStatus.failed);
      expect(state.error, isA<NetworkException>());

      await controller.retry(state.messages.single.id);
      await settle();

      expect(attempts, 2);
      expect(container.read(chatControllerProvider).messages.single.status, ChatMessageStatus.failed);
    });

    test('a refused decision puts the card back to pending', () async {
      final channel = StreamController<WsEvent>.broadcast();
      addTearDown(channel.close);
      final stub = _StubApi(
        events: channel.stream,
        onSend: (text, {required conversationId}) async {},
        onDecide: ({
          required toolCallId,
          required approve,
          assertion,
        }) async =>
            throw const PolicyException(
          requiredTier: 'HIGH',
          satisfiedTier: 'NONE',
          reason: 'stale verification',
        ),
      );
      final container = containerWith(override: stub);
      final controller = container.read(chatControllerProvider.notifier);
      // Raise a pending card straight from the "server" side.
      channel.add(
        ToolRequestEvent(
          receivedAt: testAnchor,
          toolCallId: 'call-stub-1',
          toolName: 'mqtt.publish',
          parameters: const <Object?, Object?>{},
          riskTier: RiskTier.medium,
          reason: 'stubbed request',
        ),
      );
      await settle();
      expect(
        container.read(chatControllerProvider).toolCalls['call-stub-1']!.status,
        ToolCallStatus.pending,
      );

      await controller.deny('call-stub-1');
      await settle();

      final call = container.read(chatControllerProvider).toolCalls['call-stub-1']!;
      expect(call.status, ToolCallStatus.pending);
      expect(container.read(chatControllerProvider).error, isA<PolicyException>());
    });
  });

  group('persistence', () {
    test('the transcript is restored from the local cache', () async {
      final database = ArmxDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final first = containerWith(override: api, database: database);
      await first.read(chatControllerProvider.notifier).send('what is in the audit log?');
      await settle();
      expect(first.read(chatControllerProvider).messages.length, greaterThanOrEqualTo(2));

      final second = containerWith(override: api, database: database);
      second.read(chatControllerProvider.notifier);
      await settle();

      final restored = second.read(chatControllerProvider).messages;
      expect(restored.length, greaterThanOrEqualTo(2));
      expect(restored.where((m) => m.role == ChatRole.user).single.text, 'what is in the audit log?');
      expect(restored.where((m) => m.role == ChatRole.assistant).single.text, contains('Last 24 hours'));
    });

    test('clearing the chat empties the transcript and the cache', () async {
      final database = ArmxDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final container = containerWith(override: api, database: database);
      final controller = container.read(chatControllerProvider.notifier);
      await controller.send('what is in the audit log?');
      await settle();

      await controller.clear();

      expect(container.read(chatControllerProvider).messages, isEmpty);
      final repository = container.read(chatRepositoryProvider);
      expect(await repository.mostRecentConversationId(), isNull);
    });
  });
}
