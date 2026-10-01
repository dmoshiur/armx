// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/security/risk_policy.dart';
import '../../core/security/security_constants.dart';
import '../../core/security/verification_evidence.dart';
import '../../core/security/verification_gateway.dart';
import '../../data/api/armx_api.dart';
import '../../data/api/ws_events.dart';
import '../../data/models/chat.dart';
import '../../data/models/unlock.dart';
import 'chat_state.dart';

part 'chat_controller.g.dart';

/// Owns the assistant conversation: transcript, streaming, tool approvals and
/// the realtime channel.
///
/// Event flow (see `docs/api.md` § WebSocket): the controller subscribes once
/// in [build] and folds every frame into [ChatState]:
/// * `assistant.token` appends to the streaming bubble;
/// * `assistant.done` finalises it (the server text wins over the tokens);
/// * `tool.request` raises an approval card — LOW runs without one, MEDIUM/HIGH
///   are gated by [RiskPolicy] through the [VerificationGateway];
/// * `tool.result` closes the card;
/// * `system.killed` blocks the composer, expires pending cards and clears
///   verification evidence (fail closed).
///
/// A dropped socket reconnects with exponential backoff; the mock backend
/// closes the channel exactly like the real server when the kill-switch
/// engages, so the same path is exercised offline.
@Riverpod(keepAlive: true)
class ChatController extends _$ChatController {
  /// First reconnect delay; doubles up to [_maxBackoff].
  static const Duration _initialBackoff = Duration(milliseconds: 250);

  /// Backoff ceiling, matching the "exponential backoff" contract.
  static const Duration _maxBackoff = Duration(seconds: 5);

  final Uuid _uuid = const Uuid();
  StreamSubscription<WsEvent>? _subscription;
  Timer? _reconnectTimer;
  Duration _backoff = _initialBackoff;
  bool _disposed = false;
  late VerificationEvidence _evidence;
  String _conversationId = '';

  @override
  ChatState build() {
    _disposed = false;
    _evidence = VerificationEvidence.empty(ref.read(clockProvider).now().toUtc());
    _conversationId = _newConversationId();
    _subscribe();
    unawaited(_restoreHistory());
    ref.onDispose(_teardown);
    return const ChatState();
  }

  /// Sends [raw] as a user message and streams the reply through [events].
  Future<void> send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || state.killed) {
      return;
    }
    final message = ChatMessage(
      id: _newId('msg-u'),
      role: ChatRole.user,
      text: text,
      at: ref.read(clockProvider).now().toUtc(),
      status: ChatMessageStatus.sending,
      conversationId: _conversationId,
    );
    _append(message);
    await _transmit(message);
  }

  /// Re-sends a failed user message in place (same bubble, new attempt).
  Future<void> retry(String messageId) async {
    ChatMessage? failed;
    for (final message in state.messages) {
      if (message.id == messageId && message.role == ChatRole.user) {
        failed = message;
        break;
      }
    }
    if (failed == null || !failed.isFailed) {
      return;
    }
    final pending = failed.copyWith(status: ChatMessageStatus.sending);
    _replace(pending);
    await _transmit(pending);
  }

  /// Approves a tool call, running the verification the risk tier demands.
  ///
  /// LOW calls are approved outright. MEDIUM/HIGH need fresh evidence: existing
  /// evidence inside the 60 s trust window is reused, otherwise the
  /// [VerificationGateway] captures it first. A HIGH call additionally mints
  /// the single-use `owner_verified` assertion the server requires.
  Future<void> approve(String toolCallId) async {
    final call = state.toolCalls[toolCallId];
    if (call == null || !call.needsDecision) {
      return;
    }
    if (call.riskTier == RiskTier.low) {
      await _decide(call, approve: true);
      return;
    }

    final now = ref.read(clockProvider).now().toUtc();
    var decision = RiskPolicy.evaluate(required: call.riskTier, evidence: _evidence, now: now);
    if (!decision.allowed) {
      state = state.copyWith(verifyingToolCallId: toolCallId, error: null);
      try {
        _evidence = await ref
            .read(verificationGatewayProvider)
            .verify(tier: call.riskTier, reason: call.reason);
      } on AppException catch (error) {
        state = state.copyWith(verifyingToolCallId: null, error: error);
        return;
      }
      decision = RiskPolicy.evaluate(required: call.riskTier, evidence: _evidence, now: now);
      if (!decision.allowed) {
        state = state.copyWith(
          verifyingToolCallId: null,
          error: const PolicyException(
            requiredTier: 'HIGH',
            satisfiedTier: 'NONE',
            reason: 'Verification did not satisfy the risk tier.',
          ),
        );
        return;
      }
    }

    state = state.copyWith(verifyingToolCallId: null);
    final assertion = call.riskTier == RiskTier.high ? _mintAssertion(now) : null;
    await _decide(call, approve: true, assertion: assertion);
  }

  /// Denies a tool call; the server reports the outcome as a `tool.result`.
  Future<void> deny(String toolCallId) async {
    final call = state.toolCalls[toolCallId];
    if (call == null || !call.needsDecision) {
      return;
    }
    await _decide(call, approve: false);
  }

  /// Clears the transcript (local cache included).
  Future<void> clear() async {
    state = state.copyWith(
      messages: const <ChatMessage>[],
      toolCalls: const <String, ToolCall>{},
      streamingMessageId: null,
      error: null,
    );
    await ref.read(chatRepositoryProvider).clear(_conversationId);
  }

  /// Dismisses the error banner without touching the transcript.
  void dismissError() {
    state = state.copyWith(error: null);
  }

  // ---- Decisions -----------------------------------------------------------

  Future<void> _transmit(ChatMessage message) async {
    try {
      await ref.read(armxApiProvider).sendChatMessage(
            message.text,
            conversationId: _conversationId,
          );
      _replace(message.copyWith(status: ChatMessageStatus.sent));
    } on KillSwitchActiveException catch (error) {
      _replace(message.copyWith(status: ChatMessageStatus.failed));
      state = state.copyWith(killed: true, error: error);
    } on AppException catch (error) {
      _replace(message.copyWith(status: ChatMessageStatus.failed));
      state = state.copyWith(error: error);
    }
  }

  Future<void> _decide(
    ToolCall call, {
    required bool approve,
    OwnerVerifiedToken? assertion,
  }) async {
    _updateCall(call.copyWith(
      status: approve ? ToolCallStatus.running : ToolCallStatus.denied,
    ));
    try {
      await ref.read(armxApiProvider).decideToolCall(
            toolCallId: call.id,
            approve: approve,
            assertion: assertion,
          );
    } on AppException catch (error) {
      // The server refused the decision (policy, stale verification, kill
      // switch): put the card back so the owner can try again.
      _updateCall(call.copyWith(status: ToolCallStatus.pending));
      state = state.copyWith(error: error);
    }
  }

  OwnerVerifiedToken _mintAssertion(DateTime now) => OwnerVerifiedToken(
        token: 'owner-verified-${_newId('assertion')}',
        issuedAt: now,
        expiresAt: now.add(SecurityConstants.ownerVerifiedTtl),
        riskTier: RiskTier.high,
        satisfiedFactors: const <String>['face', 'voice', 'systemBiometric'],
      );

  // ---- Realtime channel ----------------------------------------------------

  void _subscribe() {
    _subscription?.cancel();
    _subscription = ref.read(armxApiProvider).events().listen(
          _onEvent,
          onError: _onStreamError,
          onDone: _onStreamDone,
        );
  }

  void _onEvent(WsEvent event) {
    if (_disposed) {
      return;
    }
    _backoff = _initialBackoff;
    if (state.connection != ChatConnection.live) {
      state = state.copyWith(connection: ChatConnection.live);
    }
    switch (event) {
      case AssistantTokenEvent event:
        _onToken(event);
      case AssistantDoneEvent event:
        _onDone(event);
      case ToolRequestEvent event:
        _onToolRequest(event);
      case ToolResultEvent event:
        _onToolResult(event);
      case SystemKilledEvent event:
        _onKilled(event);
      case DeviceStateEvent():
      case HeartbeatEvent():
      case UnknownEvent():
        // Owned by the dashboard/admin screens (step 5/6); ignored here.
        break;
    }
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    if (_disposed) {
      return;
    }
    ref.read(appLoggerProvider).w('chat: socket error (${error.runtimeType})');
    state = state.copyWith(
      connection: ChatConnection.reconnecting,
      error: error is AppException
          ? error
          : const NetworkException('The realtime channel failed.'),
    );
    _scheduleReconnect();
  }

  void _onStreamDone() {
    if (_disposed) {
      return;
    }
    state = state.copyWith(connection: ChatConnection.reconnecting);
    _finalizeStreaming(ChatMessageStatus.failed);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_backoff, () {
      if (!_disposed) {
        _subscribe();
      }
    });
    final doubled = _backoff * 2;
    _backoff = doubled > _maxBackoff ? _maxBackoff : doubled;
  }

  // ---- Event folding -------------------------------------------------------

  void _onToken(AssistantTokenEvent event) {
    final streamingId = state.streamingMessageId;
    if (streamingId == event.messageId) {
      final index = state.messages.indexWhere((message) => message.id == event.messageId);
      if (index < 0) {
        return;
      }
      final current = state.messages[index];
      _replace(current.copyWith(text: '${current.text}${event.token}'));
      return;
    }
    if (streamingId != null) {
      // A new reply started before the previous one finished: close the old
      // bubble so the transcript never shows two streaming messages.
      _finalizeStreaming(ChatMessageStatus.sent);
    }
    final message = ChatMessage(
      id: event.messageId,
      role: ChatRole.assistant,
      text: event.token,
      at: ref.read(clockProvider).now().toUtc(),
      status: ChatMessageStatus.streaming,
      conversationId: _conversationId,
    );
    _append(message);
    state = state.copyWith(streamingMessageId: message.id);
  }

  void _onDone(AssistantDoneEvent event) {
    final index = state.messages.indexWhere((message) => message.id == event.messageId);
    if (index >= 0) {
      final current = state.messages[index];
      _replace(current.copyWith(
        // The server text is authoritative when tokens were dropped.
        text: event.text.isEmpty ? current.text : event.text,
        status: event.blocked ? ChatMessageStatus.blocked : ChatMessageStatus.sent,
      ));
    }
    if (state.streamingMessageId == event.messageId) {
      state = state.copyWith(streamingMessageId: null);
    }
  }

  void _onToolRequest(ToolRequestEvent event) {
    final now = ref.read(clockProvider).now().toUtc();
    final call = ToolCall(
      id: event.toolCallId,
      toolName: event.toolName,
      parameters: <String, Object?>{
        for (final entry in event.parameters.entries) entry.key.toString(): entry.value,
      },
      riskTier: event.riskTier,
      requestedAt: now,
      reason: event.reason,
    );
    _append(ChatMessage(
      id: _newId('msg-t'),
      role: ChatRole.tool,
      at: now,
      status: ChatMessageStatus.sent,
      riskTier: call.riskTier,
      toolCallId: call.id,
      conversationId: _conversationId,
    ));
    _updateCall(call);
  }

  void _onToolResult(ToolResultEvent event) {
    final call = state.toolCalls[event.toolCallId];
    if (call == null) {
      // LOW-tier calls run without a card: surface the outcome as a tool line.
      _append(ChatMessage(
        id: _newId('msg-t'),
        role: ChatRole.tool,
        text: event.summary,
        at: ref.read(clockProvider).now().toUtc(),
        status: event.success ? ChatMessageStatus.sent : ChatMessageStatus.failed,
        toolCallId: event.toolCallId,
        conversationId: _conversationId,
      ));
      return;
    }
    _updateCall(call.copyWith(
      status: call.status == ToolCallStatus.denied
          ? ToolCallStatus.denied
          : event.success
              ? ToolCallStatus.succeeded
              : ToolCallStatus.failed,
      resultSummary: event.summary,
      decidedAt: call.decidedAt ?? ref.read(clockProvider).now().toUtc(),
    ));
  }

  void _onKilled(SystemKilledEvent event) {
    if (event.engaged) {
      state = state.copyWith(
        killed: true,
        toolCalls: <String, ToolCall>{
          for (final entry in state.toolCalls.entries)
            entry.key: entry.value.needsDecision
                ? entry.value.copyWith(status: ToolCallStatus.expired)
                : entry.value,
        },
        verifyingToolCallId: null,
        // The real server closes the socket; the mock mirrors that behaviour.
        connection: ChatConnection.reconnecting,
      );
      _finalizeStreaming(ChatMessageStatus.blocked);
      _evidence = VerificationEvidence.empty(ref.read(clockProvider).now().toUtc());
      return;
    }
    state = state.copyWith(killed: false, connection: ChatConnection.live);
  }

  // ---- State helpers -------------------------------------------------------

  void _append(ChatMessage message) {
    state = state.copyWith(messages: <ChatMessage>[...state.messages, message]);
    unawaited(_persist(message));
  }

  void _replace(ChatMessage message) {
    final index = state.messages.indexWhere((existing) => existing.id == message.id);
    if (index < 0) {
      return;
    }
    final messages = List<ChatMessage>.of(state.messages)..[index] = message;
    state = state.copyWith(messages: messages);
    unawaited(_persist(message));
  }

  void _updateCall(ToolCall call) {
    state = state.copyWith(
      toolCalls: <String, ToolCall>{...state.toolCalls, call.id: call},
    );
  }

  void _finalizeStreaming(ChatMessageStatus status) {
    final streamingId = state.streamingMessageId;
    if (streamingId == null) {
      return;
    }
    final index = state.messages.indexWhere((message) => message.id == streamingId);
    if (index >= 0) {
      _replace(state.messages[index].copyWith(status: status));
    }
    state = state.copyWith(streamingMessageId: null);
  }

  // ---- Persistence ---------------------------------------------------------

  Future<void> _persist(ChatMessage message) async {
    try {
      await ref.read(chatRepositoryProvider).save(message);
    } on Object catch (error) {
      ref.read(appLoggerProvider).w('chat: persist failed (${error.runtimeType})');
    }
  }

  Future<void> _restoreHistory() async {
    final repository = ref.read(chatRepositoryProvider);
    String? storedConversationId;
    List<ChatMessage> history = const <ChatMessage>[];
    try {
      storedConversationId = await repository.mostRecentConversationId();
      if (storedConversationId != null) {
        history = await repository.recent(storedConversationId);
      }
    } on Object catch (error) {
      ref.read(appLoggerProvider).w('chat: history restore failed (${error.runtimeType})');
      state = state.copyWith(
        restored: true,
        error: error is AppException
            ? error
            : const NetworkException('The local transcript could not be read.'),
      );
      return;
    }
    if (_disposed) {
      return;
    }
    if (storedConversationId != null) {
      _conversationId = storedConversationId;
    }
    if (history.isEmpty) {
      state = state.copyWith(restored: true);
      return;
    }
    // History is oldest-first and always predates anything sent this session;
    // concatenate (never re-sort) so identical timestamps keep their order.
    final knownIds = history.map((message) => message.id).toSet();
    state = state.copyWith(
      messages: <ChatMessage>[
        ...history,
        ...state.messages.where((message) => !knownIds.contains(message.id)),
      ],
      restored: true,
    );
  }

  // ---- Lifecycle -----------------------------------------------------------

  void _teardown() {
    _disposed = true;
    _subscription?.cancel();
    _subscription = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  String _newId(String prefix) => '$prefix-${_uuid.v4()}';

  String _newConversationId() => 'conv-${_uuid.v4().substring(0, 8)}';
}
