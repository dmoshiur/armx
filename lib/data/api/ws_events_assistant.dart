// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

part of 'ws_events.dart';

/// One token of a streaming assistant reply.
final class AssistantTokenEvent extends WsEvent {
  /// Creates a token event.
  const AssistantTokenEvent({
    required super.receivedAt,
    required this.messageId,
    required this.conversationId,
    required this.token,
    required this.index,
  });

  /// Server-side message id being built.
  final String messageId;

  /// Conversation the message belongs to.
  final String conversationId;

  /// The token text (rendered as plain text, never as markup).
  final String token;

  /// Zero-based token index, used to detect gaps.
  final int index;

  @override
  String get type => WsEventType.assistantToken;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'type': type,
        'message_id': messageId,
        'conversation_id': conversationId,
        'token': token,
        'index': index,
      };
}

/// End of a streaming reply.
final class AssistantDoneEvent extends WsEvent {
  /// Creates a completion event.
  const AssistantDoneEvent({
    required super.receivedAt,
    required this.messageId,
    required this.text,
    required this.finishReason,
    required this.blocked,
  });

  /// Message id that finished.
  final String messageId;

  /// Full final text (authoritative, in case tokens were dropped).
  final String text;

  /// `stop`, `length`, `blocked`, …
  final String finishReason;

  /// True when the kill-switch or policy suppressed the reply.
  final bool blocked;

  @override
  String get type => WsEventType.assistantDone;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'type': type,
        'message_id': messageId,
        'text': text,
        'finish_reason': finishReason,
        'blocked': blocked,
      };
}

/// The assistant requests a tool run; MEDIUM/HIGH tiers need explicit approval.
final class ToolRequestEvent extends WsEvent {
  /// Creates a tool request event.
  const ToolRequestEvent({
    required super.receivedAt,
    required this.toolCallId,
    required this.toolName,
    required this.parameters,
    required this.riskTier,
    required this.reason,
  });

  /// Tool-call id used by `decideToolCall`.
  final String toolCallId;

  /// Tool name (`mqtt.publish`, `mail.send`, …).
  final String toolName;

  /// Parameters, rendered in the tool card as read-only text.
  final Map<Object?, Object?> parameters;

  /// Risk tier driving the verification requirement.
  final RiskTier riskTier;

  /// Why the assistant wants to run it (shown on the card).
  final String reason;

  @override
  String get type => WsEventType.toolRequest;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'type': type,
        'call': <String, Object?>{
          'id': toolCallId,
          'tool': toolName,
          'parameters': parameters,
          'risk_tier': riskTier.wireName,
          'reason': reason,
        },
      };
}

/// Result of a tool run.
final class ToolResultEvent extends WsEvent {
  /// Creates a tool result event.
  const ToolResultEvent({
    required super.receivedAt,
    required this.toolCallId,
    required this.success,
    required this.summary,
  });

  /// Tool-call id.
  final String toolCallId;

  /// Whether execution succeeded.
  final bool success;

  /// Short human-readable outcome.
  final String summary;

  @override
  String get type => WsEventType.toolResult;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'type': type,
        'tool_call_id': toolCallId,
        'success': success,
        'summary': summary,
      };
}
