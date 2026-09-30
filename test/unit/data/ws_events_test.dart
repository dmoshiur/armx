// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:convert';

import 'package:armx_ai/core/security/risk_tier.dart';
import 'package:armx_ai/data/api/ws_events.dart';
import 'package:flutter_test/flutter_test.dart';

/// The WebSocket codec is the app's exposure to a hostile or future server, so the
/// decoding tests deliberately include malformed and unexpected payloads.
void main() {
  final receivedAt = DateTime.utc(2026, 9, 30, 12);

  test('decodes assistant.token', () {
    final event = WsEvent.decode(
      jsonEncode(<String, Object?>{
        'type': 'assistant.token',
        'message_id': 'm1',
        'conversation_id': 'c1',
        'token': 'Hel',
        'index': 0,
      }),
      receivedAt: receivedAt,
    );

    expect(event, isA<AssistantTokenEvent>());
    final token = event as AssistantTokenEvent;
    expect(token.token, 'Hel');
    expect(token.messageId, 'm1');
    expect(token.type, WsEventType.assistantToken);
  });

  test('decodes assistant.done including the blocked flag', () {
    final event = WsEvent.fromJson(
      <String, Object?>{
        'type': 'assistant.done',
        'message_id': 'm1',
        'text': 'done',
        'finish_reason': 'blocked',
        'blocked': true,
      },
      receivedAt: receivedAt,
    );

    expect(event, isA<AssistantDoneEvent>());
    final done = event as AssistantDoneEvent;
    expect(done.blocked, isTrue);
    expect(done.finishReason, 'blocked');
  });

  test('decodes tool.request and fails closed on an unknown risk tier', () {
    final event = WsEvent.fromJson(
      <String, Object?>{
        'type': 'tool.request',
        'call': <String, Object?>{
          'id': 'call-1',
          'tool': 'mqtt.publish',
          'parameters': <String, Object?>{'topic': 'armx/home/dev-gate/cmd'},
          'risk_tier': 'SOMETHING_NEW',
        },
      },
      receivedAt: receivedAt,
    );

    expect(event, isA<ToolRequestEvent>());
    final request = event as ToolRequestEvent;
    expect(request.toolName, 'mqtt.publish');
    expect(request.riskTier, RiskTier.high,
        reason: 'unknown tiers must be treated as HIGH');
  });

  test('decodes device.state relay map', () {
    final event = WsEvent.fromJson(
      <String, Object?>{
        'type': 'device.state',
        'device': <String, Object?>{
          'id': 'dev-gate',
          'online': true,
          'relays': <Object?>[
            <String, Object?>{'id': 'relay-gate', 'state': 'ON'},
          ],
        },
      },
      receivedAt: receivedAt,
    );

    expect(event, isA<DeviceStateEvent>());
    final state = event as DeviceStateEvent;
    expect(state.online, isTrue);
    expect(state.relayStates['relay-gate'], 'ON');
  });

  test('decodes system.killed', () {
    final event = WsEvent.fromJson(
      <String, Object?>{
        'type': 'system.killed',
        'engaged': true,
        'reason': 'owner',
        'actor': 'mohiur',
      },
      receivedAt: receivedAt,
    );

    expect(event, isA<SystemKilledEvent>());
    expect((event as SystemKilledEvent).engaged, isTrue);
  });

  test('unknown event types are preserved but inert', () {
    final event = WsEvent.decode(
      jsonEncode(<String, Object?>{'type': 'future.thing', 'value': 42}),
      receivedAt: receivedAt,
    );

    expect(event, isA<UnknownEvent>());
    expect((event as UnknownEvent).rawType, 'future.thing');
    expect(event.payload['value'], 42);
  });

  test('malformed frames never throw', () {
    expect(WsEvent.decode('not json at all'), isA<UnknownEvent>());
    expect(WsEvent.decode('[1,2,3]'), isA<UnknownEvent>());
    expect(WsEvent.decode('{}'), isA<UnknownEvent>());
    expect(WsEvent.decode(''), isA<UnknownEvent>());
  });

  test('events round-trip through JSON', () {
    final original = ToolRequestEvent(
      receivedAt: receivedAt,
      toolCallId: 'call-9',
      toolName: 'mail.send',
      parameters: <Object?, Object?>{'to': 'owner@thamjj13.top'},
      riskTier: RiskTier.high,
      reason: 'Send the daily summary',
    );

    final decoded = WsEvent.decode(jsonEncode(original.toJson()), receivedAt: receivedAt);

    expect(decoded, isA<ToolRequestEvent>());
    final roundTripped = decoded as ToolRequestEvent;
    expect(roundTripped.toolCallId, 'call-9');
    expect(roundTripped.riskTier, RiskTier.high);
    expect(roundTripped.parameters['to'], 'owner@thamjj13.top');
  });
}
