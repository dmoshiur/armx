// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

part of 'mock_api.dart';

/// MockChatDomain — one slice of [MockArmxApi].
///
/// Declared as a mixin in a part file so the mock backend stays split across small
/// files while every slice keeps access to the shared in-memory state.
mixin MockChatDomain on MockArmxApi {
  // ---- Chat & realtime -----------------------------------------------------

  @override
  Stream<WsEvent> events() => _ensureChannel().stream;

  @override
  Future<void> sendChatMessage(String text, {required String conversationId}) async {
    _guardKillSwitch();
    final now = _clock.now().toUtc();
    final messageId = MockAssistant.messageIdFor(++_messageCounter);
    final script = MockAssistant.scriptFor(
      prompt: text,
      messageId: messageId,
      now: now,
      bengali: localeCode == 'bn',
    );

    for (final toolCall in <ToolCall>[
      if (script.toolCall != null) script.toolCall!,
    ]) {
      _toolCalls[toolCall.id] = toolCall;
    }

    final generation = ++_streamGeneration;
    final chunks = MockAssistant.tokenize(script.replyText);
    unawaited(_stream(script, chunks, generation, conversationId, now, text));
  }

  Future<void> _stream(
    MockAssistantScript script,
    List<String> chunks,
    int generation,
    String conversationId,
    DateTime startedAt,
    String prompt,
  ) async {
    for (var index = 0; index < chunks.length; index++) {
      if (_disposed || generation != _streamGeneration || _killSwitchEngaged) {
        return;
      }
      await Future<void>.delayed(control.tokenInterval);
      _emit(AssistantTokenEvent(
        receivedAt: _clock.now().toUtc(),
        messageId: script.messageId,
        conversationId: conversationId,
        token: chunks[index],
        index: index,
      ));
    }
    if (_disposed || generation != _streamGeneration || _killSwitchEngaged) {
      return;
    }
    _emit(AssistantDoneEvent(
      receivedAt: _clock.now().toUtc(),
      messageId: script.messageId,
      text: script.replyText,
      finishReason: 'stop',
      blocked: false,
    ));
    final call = script.toolCall;
    if (call == null) {
      _logger.d('mock: streamed reply for "$prompt" in ${chunks.length} tokens since $startedAt');
      return;
    }
    if (call.riskTier == RiskTier.low) {
      // LOW risk runs immediately: no approval card, the result arrives directly.
      await Future<void>.delayed(control.toolCallDelay);
      if (_disposed || generation != _streamGeneration || _killSwitchEngaged) {
        return;
      }
      _applyToolEffect(call);
      _emit(ToolResultEvent(
        receivedAt: _clock.now().toUtc(),
        toolCallId: call.id,
        success: true,
        summary: '${call.toolName} executed (mock, LOW tier — no approval needed).',
      ));
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _emit(ToolRequestEvent(
      receivedAt: _clock.now().toUtc(),
      toolCallId: call.id,
      toolName: call.toolName,
      parameters: call.parameters,
      riskTier: call.riskTier,
      reason: call.reason,
    ));
    _logger.d('mock: streamed reply for "$prompt" in ${chunks.length} tokens since $startedAt');
  }

  @override
  Future<void> decideToolCall({
    required String toolCallId,
    required bool approve,
    OwnerVerifiedToken? assertion,
  }) async {
    await _delay();
    _guardKillSwitch();
    final call = _toolCalls[toolCallId];
    if (call == null) {
      throw ApiException('Unknown tool call', statusCode: 404, serverCode: 'tool_call_not_found');
    }
    if (call.riskTier == RiskTier.high && approve && assertion == null) {
      throw const PolicyException(
        requiredTier: 'HIGH',
        satisfiedTier: 'NONE',
        reason: 'HIGH risk tool calls require the owner_verified assertion.',
      );
    }
    final decided = call.copyWith(
      status: approve ? ToolCallStatus.approved : ToolCallStatus.denied,
      decidedAt: _clock.now().toUtc(),
    );
    _toolCalls[toolCallId] = decided;

    if (!approve) {
      _emit(ToolResultEvent(
        receivedAt: _clock.now().toUtc(),
        toolCallId: toolCallId,
        success: false,
        summary: 'Denied by the owner.',
      ));
      return;
    }

    await Future<void>.delayed(control.toolCallDelay);
    _applyToolEffect(decided);
    _emit(ToolResultEvent(
      receivedAt: _clock.now().toUtc(),
      toolCallId: toolCallId,
      success: true,
      summary: '${call.toolName} executed (mock).',
    ));
  }
}
