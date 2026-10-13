// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';
import '../../../data/api/armx_api.dart';
import '../../../data/models/assistant.dart';

/// One conversation's state.
class AssistantState {
  /// Creates a state.
  const AssistantState({
    this.messages = const <ChatMessage>[],
    this.toolCalls = const <ToolCall>[],
    this.streamingMessageId,
    this.streamingText = '',
    this.sending = false,
    this.loading = true,
    this.error,
    this.listening = false,
    this.wakeWordArmed = false,
    this.lastSpokenLanguage,
  });

  /// The transcript, oldest first.
  final List<ChatMessage> messages;

  /// Every proposal the assistant has made this session, newest first.
  final List<ToolCall> toolCalls;

  /// Id of the message currently streaming, if any.
  final String? streamingMessageId;

  /// Partial text received so far for [streamingMessageId].
  final String streamingText;

  /// True while the user's message is being sent.
  final bool sending;

  /// True until the first load completes.
  final bool loading;

  /// Load failure, if any.
  final AppException? error;

  /// True while voice capture is active.
  final bool listening;

  /// True when the wake word is armed.
  final bool wakeWordArmed;

  /// Language of the last utterance, so the reply can be spoken back in it.
  final String? lastSpokenLanguage;

  /// Proposals still waiting for a decision.
  List<ToolCall> get openCalls =>
      toolCalls.where((ToolCall c) => c.status.isOpen).toList(growable: false);

  /// The partial assistant reply, or an empty string.
  String get partial => streamingMessageId == null ? '' : streamingText;

  /// Copy with changes.
  AssistantState copyWith({
    List<ChatMessage>? messages,
    List<ToolCall>? toolCalls,
    String? streamingMessageId,
    String? streamingText,
    bool? sending,
    bool? loading,
    AppException? error,
    bool clearError = false,
    bool? listening,
    bool? wakeWordArmed,
    String? lastSpokenLanguage,
  }) =>
      AssistantState(
        messages: messages ?? this.messages,
        toolCalls: toolCalls ?? this.toolCalls,
        streamingMessageId: streamingMessageId ?? this.streamingMessageId,
        streamingText: streamingText ?? this.streamingText,
        sending: sending ?? this.sending,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        listening: listening ?? this.listening,
        wakeWordArmed: wakeWordArmed ?? this.wakeWordArmed,
        lastSpokenLanguage: lastSpokenLanguage ?? this.lastSpokenLanguage,
      );
}

/// Drives the assistant conversation.
///
/// ## The rules this controller exists to hold
///
/// * A user message is **pending** until the server accepts it, and **failed** if it does
///   not. It is never silently shown as delivered.
/// * A tool proposal is added with the status the server gave it. The controller never
///   decides that a call succeeded — only an [AssistantToolStatusEvent] does.
/// * [decideToolCall] is the **only** path that answers a proposal, and the UI calls it
///   only after the confirmation dialog has resolved true for MEDIUM/HIGH. Nothing here
///   auto-approves.
/// * The stream is subscribed once; every event type folds into state.
final NotifierProvider<AssistantController, AssistantState>
    assistantControllerProvider =
    NotifierProvider<AssistantController, AssistantState>(AssistantController.new);

/// Conversation state machine.
class AssistantController extends Notifier<AssistantState> {
  StreamSubscription<AssistantEvent>? _subscription;

  /// A stable conversation id for this device's session.
  static const String conversationId = 'primary';

  @override
  AssistantState build() {
    ref.onDispose(() => unawaited(_subscription?.cancel()));
    return const AssistantState();
  }

  /// Loads the transcript and subscribes to the event stream.
  Future<void> start() async {
    final ArmxApi api = ref.read(armxApiProvider);
    try {
      final List<ChatMessage> history =
          await api.transcript(conversationId: conversationId);
      state = state.copyWith(messages: history, loading: false, clearError: true);
    } on AppException catch (error) {
      state = state.copyWith(loading: false, error: error);
      // Keep going: the socket may still work, and a missing transcript should not stop
      // the user from talking.
    }
    _subscription ??= api.events().listen(
      _onEvent,
      onError: (Object error) {
        if (error is AppException) {
          state = state.copyWith(error: error);
        }
      },
    );
  }

  void _onEvent(AssistantEvent event) {
    switch (event) {
      case AssistantTokenEvent():
        if (event.done) {
          // The final message is appended as real content and the buffer is cleared, so a
          // lost "done" frame cannot leave partial text on screen forever.
          final String text =
              '${state.streamingText}${event.text}';
          state = state.copyWith(
            messages: <ChatMessage>[
              ...state.messages,
              ChatMessage(
                id: event.messageId,
                author: ChatAuthor.assistant,
                text: text.isEmpty ? state.streamingText : text,
                createdAt: DateTime.now().toUtc(),
              ),
            ],
            streamingMessageId: null,
            streamingText: '',
          );
        } else {
          state = state.copyWith(
            streamingMessageId: event.messageId,
            streamingText: '${state.streamingText}${event.text}',
          );
        }
      case AssistantToolCallEvent():
        state = state.copyWith(
          toolCalls: <ToolCall>[
            event.call,
            ...state.toolCalls.where((ToolCall c) => c.id != event.call.id),
          ],
        );
      case AssistantToolStatusEvent():
        state = state.copyWith(
          toolCalls: state.toolCalls
              .map(
                (ToolCall c) => c.id == event.toolCallId
                    ? c.copyWith(status: event.status, resultMessage: event.message)
                    : c,
              )
              .toList(growable: false),
        );
      case AssistantKillSwitchEvent():
        if (event.state.engaged) {
          state = state.copyWith(wakeWordArmed: false, listening: false);
        }
      case AssistantVoiceEvent():
        state = state.copyWith(
          listening: event.listening,
          lastSpokenLanguage: event.languageCode,
        );
      case AssistantConnectionEvent():
      case AssistantDeviceEvent():
        // The connection indicator and the device screens own these.
        break;
    }
  }

  /// Sends a message. The optimistic entry is marked pending, then resolved.
  Future<void> send(String text, {String? languageCode}) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) {
      return;
    }
    final ChatMessage pending = ChatMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      author: ChatAuthor.user,
      text: trimmed,
      createdAt: DateTime.now().toUtc(),
      pending: true,
      languageCode: languageCode,
    );
    state = state.copyWith(
      messages: <ChatMessage>[...state.messages, pending],
      sending: true,
      clearError: true,
      lastSpokenLanguage: languageCode ?? state.lastSpokenLanguage,
    );

    try {
      await ref.read(armxApiProvider).sendMessage(
            conversationId: conversationId,
            text: trimmed,
            languageCode: languageCode,
          );
      state = state.copyWith(
        sending: false,
        messages: state.messages
            .map(
              (ChatMessage m) =>
                  m.id == pending.id ? m.copyWith(pending: false) : m,
            )
            .toList(growable: false),
      );
    } on AppException catch (error) {
      // A failed send stays visible and marked, with retry available. It is never
      // quietly dropped, and never shown as delivered.
      state = state.copyWith(
        sending: false,
        error: error,
        messages: state.messages
            .map(
              (ChatMessage m) => m.id == pending.id
                  ? m.copyWith(pending: false, failed: true)
                  : m,
            )
            .toList(growable: false),
      );
    }
  }

  /// Retries a failed message by re-sending its text.
  Future<void> retry(ChatMessage message) async {
    state = state.copyWith(
      messages: state.messages
          .where((ChatMessage m) => m.id != message.id)
          .toList(growable: false),
    );
    await send(message.text, languageCode: message.languageCode);
  }

  /// Answers a proposal.
  ///
  /// The caller must have obtained an explicit confirmation for MEDIUM/HIGH before
  /// invoking this with [ToolDecision.approve]. The presentation layer enforces that, and
  /// `test/unit/features/assistant/assistant_controller_test.dart` pins the rule.
  Future<void> decideToolCall(
    ToolCall call, {
    required ToolDecision decision,
    String? denyReason,
  }) async {
    try {
      await ref.read(armxApiProvider).decideToolCall(
            toolCallId: call.id,
            decision: decision,
            denyReason: denyReason,
          );
      // Marked as in flight; the backend's status event is what settles it.
      state = state.copyWith(
        toolCalls: state.toolCalls
            .map(
              (ToolCall c) => c.id == call.id
                  ? c.copyWith(
                      status: decision == ToolDecision.deny
                          ? ToolCallStatus.denied
                          : ToolCallStatus.running,
                    )
                  : c,
            )
            .toList(growable: false),
        clearError: true,
      );
    } on AppException catch (error) {
      state = state.copyWith(error: error);
    }
  }

  /// Arms or disarms the wake word.
  void setWakeWordArmed({required bool armed}) =>
      state = state.copyWith(wakeWordArmed: armed);

  /// Marks local voice capture as started or stopped.
  void setListening({required bool listening, String? languageCode}) =>
      state = state.copyWith(
        listening: listening,
        lastSpokenLanguage: languageCode ?? state.lastSpokenLanguage,
      );

  /// Replaces the transcript, used after a sign-out or an account switch.
  void reset() => state = const AssistantState(loading: false);
}
