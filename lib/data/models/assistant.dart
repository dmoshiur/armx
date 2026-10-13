// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:meta/meta.dart';

import '../../core/security/risk_tier.dart';

/// Who said it.
enum ChatAuthor {
  /// The user.
  user,

  /// The assistant.
  assistant,

  /// The system (approval outcomes, connection notices). Rendered as an inline notice
  /// rather than a bubble, so a system message is never mistaken for the assistant
  /// speaking.
  system;

  /// Parses a wire value, defaulting to [assistant] only for the assistant's own text —
  /// anything unknown is rendered as [system] so it cannot masquerade as a reply.
  static ChatAuthor fromWire(String? value) => switch (value?.toLowerCase()) {
        'user' || 'human' => ChatAuthor.user,
        'assistant' || 'ai' => ChatAuthor.assistant,
        _ => ChatAuthor.system,
      };
}

/// One message in the transcript.
@immutable
class ChatMessage {
  /// Creates a message.
  const ChatMessage({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAt,
    this.pending = false,
    this.failed = false,
    this.toolCallId,
    this.languageCode,
  });

  /// Stable identifier (client-generated for optimistic entries).
  final String id;

  /// Who spoke.
  final ChatAuthor author;

  /// Message body. Rendered as sanitized text — never as HTML, never with live links.
  final String text;

  /// When it was created (client clock for optimistic entries).
  final DateTime createdAt;

  /// True while the message is still being sent. Rendered with a pending indicator and
  /// **never** as if it had been delivered.
  final bool pending;

  /// True when sending failed. The user gets an explicit retry affordance.
  final bool failed;

  /// Links a system message to the tool call it reports on.
  final String? toolCallId;

  /// Language the message was dictated in, used to pick the TTS voice.
  final String? languageCode;

  /// Parses from the wire.
  factory ChatMessage.fromJson(Map<String, Object?> json) => ChatMessage(
        id: json['id']! as String,
        author: ChatAuthor.fromWire(json['author'] as String?),
        text: (json['text'] ?? '') as String,
        createdAt: json['created_at'] is String
            ? DateTime.parse(json['created_at']! as String)
            : DateTime.now().toUtc(),
        toolCallId: json['tool_call_id'] as String?,
        languageCode: json['language'] as String?,
      );

  /// Serialises.
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'author': author.name,
        'text': text,
        'created_at': createdAt.toUtc().toIso8601String(),
        'tool_call_id': toolCallId,
        'language': languageCode,
      };

  /// Copy with changes.
  ChatMessage copyWith({
    String? id,
    ChatAuthor? author,
    String? text,
    DateTime? createdAt,
    bool? pending,
    bool? failed,
    String? toolCallId,
    String? languageCode,
  }) =>
      ChatMessage(
        id: id ?? this.id,
        author: author ?? this.author,
        text: text ?? this.text,
        createdAt: createdAt ?? this.createdAt,
        pending: pending ?? this.pending,
        failed: failed ?? this.failed,
        toolCallId: toolCallId ?? this.toolCallId,
        languageCode: languageCode ?? this.languageCode,
      );

  @override
  bool operator ==(Object other) =>
      other is ChatMessage &&
      other.id == id &&
      other.text == text &&
      other.pending == pending &&
      other.failed == failed;

  @override
  int get hashCode => Object.hash(id, text, pending, failed);
}

/// Where a proposed action has got to.
enum ToolCallStatus {
  /// Waiting for the user's decision. Rendered as a card with Approve/Deny.
  awaitingDecision,

  /// The user approved it and the backend is running it.
  running,

  /// The backend confirmed success.
  succeeded,

  /// The user refused it. No backend call was made.
  denied,

  /// The backend ran it and it failed.
  failed,

  /// The user did not answer in time and the proposal expired. Distinct from [denied]:
  /// nothing was refused, it simply went stale.
  expired;

  /// Parses a wire value. Unknown values become [awaitingDecision] so an unrecognised
  /// status presents as "needs a decision" rather than as a done deal.
  static ToolCallStatus fromWire(String? value) => switch (value?.toLowerCase()) {
        'running' || 'executing' => ToolCallStatus.running,
        'succeeded' || 'ok' || 'done' => ToolCallStatus.succeeded,
        'denied' || 'rejected' => ToolCallStatus.denied,
        'failed' || 'error' => ToolCallStatus.failed,
        'expired' => ToolCallStatus.expired,
        _ => ToolCallStatus.awaitingDecision,
      };

  /// True while the card still needs a decision from the user.
  bool get isOpen => this == ToolCallStatus.awaitingDecision;

  /// True when the action completed successfully and may be shown as done.
  bool get isSuccess => this == ToolCallStatus.succeeded;
}

/// An action the assistant proposes to take.
///
/// The UI renders one card per call. A [RiskTier.medium] or [RiskTier.high] call blocks on
/// [ArmxConfirmDialog] and the client performs **no** decision call until the user
/// confirms.
@immutable
class ToolCall {
  /// Creates a tool call.
  const ToolCall({
    required this.id,
    required this.tool,
    required this.summary,
    required this.riskTier,
    required this.status,
    this.parameters = const <String, Object?>{},
    this.targetLabel,
    this.requestedAt,
    this.resultMessage,
  });

  /// Identifier used when approving or denying.
  final String id;

  /// Backend tool name, e.g. `set_light`, `web_deploy`, `unlink_device`.
  final String tool;

  /// One-line human summary of what will happen.
  final String summary;

  /// How dangerous it is. Server-supplied; the client may only escalate.
  final RiskTier riskTier;

  /// Current status.
  final ToolCallStatus status;

  /// Exact parameters that will be sent. Rendered verbatim in the confirmation dialog.
  final Map<String, Object?> parameters;

  /// Human label for the target, e.g. "Kitchen lamp" or
  /// "github.com/owner/site".
  final String? targetLabel;

  /// When the proposal arrived.
  final DateTime? requestedAt;

  /// Detail shown after the call resolves (success note or failure reason).
  final String? resultMessage;

  /// Parses from the wire.
  factory ToolCall.fromJson(Map<String, Object?> json) => ToolCall(
        id: json['id']! as String,
        tool: (json['tool'] ?? 'unknown') as String,
        summary: (json['summary'] ?? '') as String,
        riskTier: RiskTier.fromWire(json['risk_tier'] as String?),
        status: ToolCallStatus.fromWire(json['status'] as String?),
        parameters: json['parameters'] is Map<String, Object?>
            ? json['parameters']! as Map<String, Object?>
            : const <String, Object?>{},
        targetLabel: json['target_label'] as String?,
        requestedAt: json['requested_at'] is String
            ? DateTime.tryParse(json['requested_at']! as String)
            : null,
        resultMessage: json['result'] as String?,
      );

  /// Serialises.
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'tool': tool,
        'summary': summary,
        'risk_tier': riskTier.wire,
        'status': status.name,
        'parameters': parameters,
        'target_label': targetLabel,
        'requested_at': requestedAt?.toIso8601String(),
        'result': resultMessage,
      };

  /// Copy with changes.
  ToolCall copyWith({
    String? id,
    String? tool,
    String? summary,
    RiskTier? riskTier,
    ToolCallStatus? status,
    Map<String, Object?>? parameters,
    String? targetLabel,
    DateTime? requestedAt,
    String? resultMessage,
  }) =>
      ToolCall(
        id: id ?? this.id,
        tool: tool ?? this.tool,
        summary: summary ?? this.summary,
        riskTier: riskTier ?? this.riskTier,
        status: status ?? this.status,
        parameters: parameters ?? this.parameters,
        targetLabel: targetLabel ?? this.targetLabel,
        requestedAt: requestedAt ?? this.requestedAt,
        resultMessage: resultMessage ?? this.resultMessage,
      );

  @override
  bool operator ==(Object other) =>
      other is ToolCall &&
      other.id == id &&
      other.status == status &&
      other.summary == summary &&
      other.resultMessage == resultMessage;

  @override
  int get hashCode => Object.hash(id, status, summary, resultMessage);
}

/// The user's answer to a tool proposal.
enum ToolDecision {
  /// Run it.
  approve,

  /// Do not run it.
  deny,
}
