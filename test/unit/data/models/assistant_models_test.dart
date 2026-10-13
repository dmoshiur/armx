// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/security/risk_tier.dart';
import 'package:armx_ai/data/models/assistant.dart';
import 'package:armx_ai/features/assistant/application/assistant_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Model parsing is where a hostile or merely sloppy backend meets the UI. Every fallback here
/// is a decision, and the tests state it.
void main() {
  group('AppUser', () {
    test('parses the fields the session needs', () {
      final AppUser user = AppUser.fromJson(const <String, Object?>{
        'id': 'u-1',
        'email': 'mohi@thamjj13.top',
        'display_name': 'Moshiur',
        'role': 'admin',
        'email_verified': true,
      });
      expect(user.id, 'u-1');
      expect(user.email, 'mohi@thamjj13.top');
      expect(user.displayName, 'Moshiur');
      expect(user.role, UserRole.admin);
      expect(user.emailVerified, isTrue);
      expect(user.initials, 'M');
    });

    test('a missing name falls back to the email rather than an empty label', () {
      final AppUser user = AppUser.fromJson(const <String, Object?>{
        'email': 'rafi@example.com',
      });
      expect(user.displayName, 'rafi@example.com');
      expect(user.initials, 'R');
    });

    test('an unknown role is the least-privileged one', () {
      final AppUser user = AppUser.fromJson(const <String, Object?>{
        'email': 'someone@example.com',
        'role': 'wizard',
      });
      expect(user.role, UserRole.user);
    });
  });

  group('ToolCall', () {
    test('parses a high-risk call and defaults to awaiting a decision', () {
      final ToolCall call = ToolCall.fromJson(const <String, Object?>{
        'id': 'c-1',
        'tool': 'unlock_front_door',
        'summary': 'Unlock the front door',
        'risk_tier': 'high',
        'parameters': <String, Object?>{'device_id': 'lock-1'},
      });
      expect(call.tool, 'unlock_front_door');
      expect(call.riskTier, RiskTier.high);
      expect(call.status, ToolCallStatus.awaitingDecision);
      expect(call.parameters['device_id'], 'lock-1');
    });

    test('an unrecognised status becomes failed, not succeeded', () {
      // The one fallback that must never flatter the app: an unknown state is not success.
      final ToolCall call = ToolCall.fromJson(const <String, Object?>{
        'id': 'c-2',
        'tool': 'set_light',
        'status': 'teleported',
      });
      expect(call.status, ToolCallStatus.failed);
    });

    test('a missing risk tier is treated as high risk', () {
      final ToolCall call = ToolCall.fromJson(const <String, Object?>{
        'id': 'c-3',
        'tool': 'mystery',
      });
      expect(call.riskTier, RiskTier.high);
    });
  });

  group('ChatMessage', () {
    test('parses author and text, and links no tool call when there is none', () {
      final ChatMessage message = ChatMessage.fromJson(const <String, Object?>{
        'id': 'm-1',
        'author': 'assistant',
        'text': 'Done.',
      });
      expect(message.author, ChatAuthor.assistant);
      expect(message.text, 'Done.');
      expect(message.toolCallId, isNull);
      expect(message.pending, isFalse);
      expect(message.failed, isFalse);
    });

    test('a tool-call message carries the id that links it to the card', () {
      final ChatMessage message = ChatMessage.fromJson(const <String, Object?>{
        'id': 'm-2',
        'author': 'system',
        'text': 'Unlocking…',
        'tool_call_id': 'c-9',
      });
      expect(message.toolCallId, 'c-9');
      expect(message.author, ChatAuthor.system);
    });

    test('a dictated message remembers its language, for the right spoken voice', () {
      final ChatMessage message = ChatMessage.fromJson(const <String, Object?>{
        'id': 'm-4',
        'text': 'ঘর অন্ধকার',
        'language_code': 'bn',
      });
      expect(message.languageCode, 'bn');
    });

    test('an unknown author is the assistant, never the user', () {
      // Attributing the assistant's words to the user would put them in the transcript as
      // something the human said.
      final ChatMessage message = ChatMessage.fromJson(const <String, Object?>{
        'id': 'm-3',
        'author': 'ghost',
        'text': 'hi',
      });
      expect(message.author, ChatAuthor.assistant);
    });
  });

  group('AssistantState', () {
    test('a fresh state is idle: not listening, not sending, not streaming', () {
      const AssistantState idle = AssistantState();
      expect(idle.listening, isFalse);
      expect(idle.sending, isFalse);
      expect(idle.wakeWordArmed, isFalse);
      expect(idle.messages, isEmpty);
      expect(idle.toolCalls, isEmpty);
      expect(idle.error, isNull);
    });
  });
}
