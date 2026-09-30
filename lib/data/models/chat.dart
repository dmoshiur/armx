// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/security/risk_tier.dart';
import 'converters.dart';

part 'chat.freezed.dart';
part 'chat.g.dart';

/// Who produced a chat message.
enum ChatRole {
  /// The human user.
  @JsonValue('USER')
  user,

  /// The A.R.M.X assistant (streamed token by token).
  @JsonValue('ASSISTANT')
  assistant,

  /// System notice rendered inline (kill-switch, reconnect, policy refusal).
  @JsonValue('SYSTEM')
  system,

  /// Result of a tool execution.
  @JsonValue('TOOL')
  tool,
}

/// Delivery state of a message bubble.
enum ChatMessageStatus {
  /// Queued locally, not yet acknowledged by the server.
  @JsonValue('SENDING')
  sending,

  /// Assistant tokens are still arriving.
  @JsonValue('STREAMING')
  streaming,

  /// Delivered and complete.
  @JsonValue('SENT')
  sent,

  /// Delivery failed; the bubble offers a retry.
  @JsonValue('FAILED')
  failed,

  /// Blocked by the kill-switch or by policy.
  @JsonValue('BLOCKED')
  blocked,
}

/// A chat message (user, assistant, system or tool result).
@freezed
abstract class ChatMessage with _$ChatMessage {
  /// Creates a message.
  const factory ChatMessage({
    required String id,
    required ChatRole role,
    @Default('') String text,
    required DateTime at,
    @Default(ChatMessageStatus.sent) ChatMessageStatus status,
    @JsonKey(fromJson: riskTierFromJson, toJson: riskTierToJson) RiskTier? riskTier,
    String? toolCallId,
    @Default('') String conversationId,
  }) = _ChatMessage;

  /// Creates a message from wire JSON.
  factory ChatMessage.fromJson(Map<String, dynamic> json) => _$ChatMessageFromJson(json);

  const ChatMessage._();

  /// True while the assistant is still streaming into this bubble.
  bool get isStreaming => status == ChatMessageStatus.streaming;

  /// True for messages the user can retry.
  bool get isFailed => status == ChatMessageStatus.failed;
}

/// Lifecycle of a tool call requested by the assistant.
enum ToolCallStatus {
  /// Waiting for the user's Approve/Deny decision.
  @JsonValue('PENDING')
  pending,

  /// Approved by the user (LOW-tier calls may auto-approve).
  @JsonValue('APPROVED')
  approved,

  /// Denied by the user.
  @JsonValue('DENIED')
  denied,

  /// Executing on the backend.
  @JsonValue('RUNNING')
  running,

  /// Finished successfully.
  @JsonValue('SUCCEEDED')
  succeeded,

  /// Finished with an error.
  @JsonValue('FAILED')
  failed,

  /// Nobody approved in time.
  @JsonValue('EXPIRED')
  expired,
}

/// A tool the assistant wants to run, with its parameters and risk tier.
@freezed
abstract class ToolCall with _$ToolCall {
  /// Creates a tool call.
  const factory ToolCall({
    required String id,
    required String toolName,
    @JsonKey(fromJson: objectMapFromJson)
    @Default(<String, Object?>{})
    Map<String, Object?> parameters,
    @JsonKey(fromJson: riskTierFromJson, toJson: riskTierToJson)
    @Default(RiskTier.high)
    RiskTier riskTier,
    @Default(ToolCallStatus.pending) ToolCallStatus status,
    required DateTime requestedAt,
    DateTime? decidedAt,
    @Default('') String reason,
    @Default('') String resultSummary,
    @Default(<String, String>{}) Map<String, String> requiredFactors,
  }) = _ToolCall;

  /// Creates a tool call from wire JSON.
  factory ToolCall.fromJson(Map<String, dynamic> json) => _$ToolCallFromJson(json);

  const ToolCall._();

  /// True when the card must show Approve/Deny buttons.
  bool get needsDecision => status == ToolCallStatus.pending;

  /// True when the user has to be re-verified before approving.
  bool get requiresVerification => riskTier.isAtLeast(RiskTier.medium);
}

/// A tool the backend can expose, listed in the admin panel and settings.
@freezed
abstract class ToolDescriptor with _$ToolDescriptor {
  /// Creates a tool descriptor.
  const factory ToolDescriptor({
    required String id,
    required String label,
    required String description,
    @JsonKey(fromJson: riskTierFromJson, toJson: riskTierToJson)
    @Default(RiskTier.medium)
    RiskTier maxRiskTier,
    @Default(true) bool requiresApproval,
    @Default(true) bool enabled,
    @Default(false) bool connected,
  }) = _ToolDescriptor;

  /// Creates a descriptor from wire JSON.
  factory ToolDescriptor.fromJson(Map<String, dynamic> json) =>
      _$ToolDescriptorFromJson(json);
}
