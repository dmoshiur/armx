// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/foundation.dart';

import '../../core/errors/app_exception.dart';
import '../../data/models/chat.dart';

/// Realtime channel state, shown as the status pill in the chat app bar.
enum ChatConnection {
  /// The socket is delivering frames.
  live,

  /// The socket dropped; a reconnect with backoff is scheduled.
  reconnecting,

  /// The backend is unreachable (offline mode or a dead socket).
  offline,
}

/// Immutable snapshot of the chat screen.
@immutable
class ChatState {
  /// Creates a chat state.
  const ChatState({
    this.messages = const <ChatMessage>[],
    this.toolCalls = const <String, ToolCall>{},
    this.connection = ChatConnection.live,
    this.streamingMessageId,
    this.verifyingToolCallId,
    this.killed = false,
    this.restored = false,
    this.error,
  });

  /// Transcript in chronological order (oldest first).
  final List<ChatMessage> messages;

  /// Live tool calls by id; approval cards read their state from here.
  final Map<String, ToolCall> toolCalls;

  /// Realtime channel state.
  final ChatConnection connection;

  /// Message id the assistant is currently streaming into, if any.
  final String? streamingMessageId;

  /// Tool call waiting for the verification gateway, if any.
  final String? verifyingToolCallId;

  /// True while the global kill-switch is engaged.
  final bool killed;

  /// True once the cached transcript has been loaded.
  final bool restored;

  /// Last failure, rendered by the dismissible banner.
  final AppException? error;

  /// True while an assistant reply is streaming.
  bool get isStreaming => streamingMessageId != null;

  static const Object _clear = Object();

  /// Copies selected fields; nullable fields clear on explicit `null`.
  ChatState copyWith({
    List<ChatMessage>? messages,
    Map<String, ToolCall>? toolCalls,
    ChatConnection? connection,
    Object? streamingMessageId = _clear,
    Object? verifyingToolCallId = _clear,
    bool? killed,
    bool? restored,
    Object? error = _clear,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        toolCalls: toolCalls ?? this.toolCalls,
        connection: connection ?? this.connection,
        streamingMessageId:
            streamingMessageId == _clear ? this.streamingMessageId : streamingMessageId as String?,
        verifyingToolCallId:
            verifyingToolCallId == _clear ? this.verifyingToolCallId : verifyingToolCallId as String?,
        killed: killed ?? this.killed,
        restored: restored ?? this.restored,
        error: error == _clear ? this.error : error as AppException?,
      );
}
