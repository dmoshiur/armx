// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/security/risk_tier.dart';
import '../../core/utils/json_utils.dart';
import '../models/device.dart';

// Concrete events live in two part files: assistant traffic and system traffic. Parts
// (rather than separate libraries) are used so the codec below can construct every
// subclass without a circular import.
part 'ws_events_assistant.dart';
part 'ws_events_system.dart';

/// Wire names of the WebSocket events (mirrors `docs/api.md`).
abstract final class WsEventType {
  /// One streamed assistant token.
  static const String assistantToken = 'assistant.token';

  /// End of an assistant reply.
  static const String assistantDone = 'assistant.done';

  /// The assistant wants to run a tool; the user may have to approve it.
  static const String toolRequest = 'tool.request';

  /// Outcome of a tool execution.
  static const String toolResult = 'tool.result';

  /// A device changed state.
  static const String deviceState = 'device.state';

  /// The global kill-switch changed state.
  static const String systemKilled = 'system.killed';

  /// Keep-alive.
  static const String heartbeat = 'system.heartbeat';

  /// Anything this client version does not know yet.
  static const String unknown = 'unknown';
}

/// Base type for every server-push event.
///
/// Hand-written (rather than generated) for two reasons: parsing must be *total* — a
/// hostile or future server can send anything and the UI must not crash — and the codec is
/// a single place to fuzz in tests.
@immutable
sealed class WsEvent {
  /// Const constructor for subclasses.
  const WsEvent({required this.receivedAt});

  /// When the client decoded the event (UTC).
  final DateTime receivedAt;

  /// Wire name of the event.
  String get type;

  /// JSON body, used by the mock backend and by tests for round-trips.
  Map<String, Object?> toJson();

  /// Decodes one raw WebSocket frame. Never throws.
  static WsEvent decode(String raw, {DateTime? receivedAt}) {
    final now = receivedAt ?? DateTime.now().toUtc();
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return UnknownEvent(receivedAt: now, rawType: 'invalid_json', payload: <String, Object?>{'raw_length': raw.length});
    }
    final json = JsonUtils.asMap(decoded);
    if (json == null) {
      return UnknownEvent(receivedAt: now, rawType: 'invalid_payload', payload: const <String, Object?>{});
    }
    return WsEvent.fromJson(json, receivedAt: now);
  }

  /// Builds a typed event from a decoded JSON map.
  static WsEvent fromJson(Map<Object?, Object?> json, {required DateTime receivedAt}) {
    final type = JsonUtils.string(json, 'type') ?? WsEventType.unknown;
    switch (type) {
      case WsEventType.assistantToken:
        return AssistantTokenEvent(
          receivedAt: receivedAt,
          messageId: JsonUtils.string(json, 'message_id') ?? '',
          conversationId: JsonUtils.string(json, 'conversation_id') ?? '',
          token: JsonUtils.string(json, 'token') ?? '',
          index: JsonUtils.integer(json, 'index') ?? 0,
        );
      case WsEventType.assistantDone:
        return AssistantDoneEvent(
          receivedAt: receivedAt,
          messageId: JsonUtils.string(json, 'message_id') ?? '',
          text: JsonUtils.string(json, 'text') ?? '',
          finishReason: JsonUtils.string(json, 'finish_reason') ?? 'stop',
          blocked: JsonUtils.boolean(json, 'blocked') ?? false,
        );
      case WsEventType.toolRequest:
        final call = JsonUtils.asMap(json['call']) ?? json;
        return ToolRequestEvent(
          receivedAt: receivedAt,
          toolCallId: JsonUtils.string(call, 'id') ?? '',
          toolName: JsonUtils.string(call, 'tool') ?? JsonUtils.string(call, 'tool_name') ?? '',
          parameters: JsonUtils.asMap(call['parameters']) ?? const <Object?, Object?>{},
          riskTier: RiskTier.fromWire(JsonUtils.string(call, 'risk_tier')),
          reason: JsonUtils.string(call, 'reason') ?? '',
        );
      case WsEventType.toolResult:
        return ToolResultEvent(
          receivedAt: receivedAt,
          toolCallId: JsonUtils.string(json, 'tool_call_id') ?? '',
          success: JsonUtils.boolean(json, 'success') ?? false,
          summary: JsonUtils.string(json, 'summary') ?? '',
        );
      case WsEventType.deviceState:
        final device = JsonUtils.asMap(json['device']) ?? json;
        return DeviceStateEvent(
          receivedAt: receivedAt,
          deviceId: JsonUtils.string(device, 'id') ?? '',
          online: JsonUtils.boolean(device, 'online') ?? false,
          relayStates: <String, String>{
            for (final relay in JsonUtils.asMapList(device['relays']))
              JsonUtils.string(relay, 'id') ?? '?': JsonUtils.string(relay, 'state') ?? 'UNKNOWN',
          },
          payload: <String, Object?>{for (final e in device.entries) e.key.toString(): e.value},
        );
      case WsEventType.systemKilled:
        return SystemKilledEvent(
          receivedAt: receivedAt,
          engaged: JsonUtils.boolean(json, 'engaged') ?? true,
          reason: JsonUtils.string(json, 'reason') ?? '',
          actor: JsonUtils.string(json, 'actor') ?? 'unknown',
        );
      case WsEventType.heartbeat:
        return HeartbeatEvent(receivedAt: receivedAt);
      default:
        return UnknownEvent(
          receivedAt: receivedAt,
          rawType: type,
          payload: <String, Object?>{for (final e in json.entries) e.key.toString(): e.value},
        );
    }
  }
}
