// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:math';

import '../../../core/security/risk_tier.dart';
import '../../models/chat.dart';
import 'mock_data.dart';

/// A scripted assistant turn produced by the mock backend.
class MockAssistantScript {
  /// Creates a script.
  const MockAssistantScript({
    required this.replyText,
    required this.messageId,
    this.toolCall,
  });

  /// Full reply text that will be streamed token by token.
  final String replyText;

  /// Server-side message id.
  final String messageId;

  /// Tool the assistant "wants" to run, if any (drives the approval card).
  final ToolCall? toolCall;
}

/// Deterministic, offline stand-in for the real assistant.
///
/// The backend does not exist yet, so the mock must still exercise every UI path: streamed
/// tokens, LOW/MEDIUM/HIGH tool cards, denials and Bengali replies.
abstract final class MockAssistant {
  /// Number of characters per streamed token (word-aware).
  static const int _chunkSize = 6;

  /// Builds the scripted reply for [prompt].
  ///
  /// [bengali] switches the canned text to Bengali so the bilingual UI can be tested
  /// without a network round trip.
  static MockAssistantScript scriptFor({
    required String prompt,
    required String messageId,
    required DateTime now,
    bool bengali = false,
  }) {
    final text = prompt.toLowerCase();

    if (text.contains('kill') || text.contains('switch off everything')) {
      return MockAssistantScript(replyText: replies['kill']!, messageId: messageId);
    }
    if (text.contains('unlock')) {
      return MockAssistantScript(
        replyText: replies['unlock']!,
        messageId: messageId,
        toolCall: ToolCall(
          id: 'call-unlock-1',
          toolName: 'system.unlock',
          parameters: <String, Object?>{
            'target_id': 'pc-studio',
            'action': 'unlock',
            'ttl_seconds': 30,
          },
          riskTier: RiskTier.high,
          requestedAt: now,
          reason: 'Owner asked to unlock the paired machine.',
        ),
      );
    }
    if (text.contains('gate')) {
      return MockAssistantScript(
        replyText: 'The gate is a HIGH risk device: face, voice and your device '
            'biometric are required before I pulse the motor.',
        messageId: messageId,
        toolCall: ToolCall(
          id: 'call-gate-1',
          toolName: 'mqtt.publish',
          parameters: <String, Object?>{
            'topic': 'armx/home/dev-gate/cmd',
            'payload': <String, Object?>{'relay': 'relay-gate', 'pulse_ms': 800},
          },
          riskTier: RiskTier.high,
          requestedAt: now,
          reason: 'Open the main gate for the owner.',
        ),
      );
    }
    if (text.contains('light') || text.contains('lamp')) {
      return MockAssistantScript(
        replyText: replies['light']!,
        messageId: messageId,
        toolCall: ToolCall(
          id: 'call-light-1',
          toolName: 'mqtt.publish',
          parameters: <String, Object?>{
            'topic': 'armx/home/dev-living-light/cmd',
            'payload': <String, Object?>{'relay': 'relay-main', 'state': 'ON'},
            'device_id': 'dev-living-light',
          },
          riskTier: RiskTier.medium,
          requestedAt: now,
          reason: 'Turn on the living room lights.',
        ),
      );
    }
    if (text.contains('audit') || text.contains('log')) {
      return MockAssistantScript(replyText: replies['audit']!, messageId: messageId);
    }
    if (bengali) {
      return MockAssistantScript(replyText: replies['bn']!, messageId: messageId);
    }
    return MockAssistantScript(replyText: replies['default']!, messageId: messageId);
  }

  /// Splits [text] into deterministic, word-aware chunks for streaming.
  ///
  /// Uses a seeded random so the same reply always streams in the same shape: golden and
  /// widget tests can assert on intermediate frames.
  static List<String> tokenize(String text, {int seed = 7}) {
    final random = Random(seed);
    final chunks = <String>[];
    var index = 0;
    while (index < text.length) {
      var size = _chunkSize + random.nextInt(4);
      if (index + size >= text.length) {
        size = text.length - index;
      } else {
        // Prefer breaking on whitespace so the transcript looks natural.
        final window = text.substring(index, index + size);
        final lastSpace = window.lastIndexOf(' ');
        if (lastSpace > 2) {
          size = lastSpace + 1;
        }
      }
      chunks.add(text.substring(index, index + size));
      index += size;
    }
    return chunks;
  }

  /// Identifier for a new assistant message, derived deterministically from [seed].
  static String messageIdFor(int seed) => 'msg-a-${seed.toString().padLeft(6, '0')}';

  /// Identifier for a new user message, derived deterministically from [seed].
  static String userIdFor(int seed) => 'msg-u-${seed.toString().padLeft(6, '0')}';

  /// Identifier for a conversation, derived deterministically from [seed].
  static String conversationIdFor(int seed) => 'conv-${seed.toString().padLeft(4, '0')}';

  /// Canned assistant replies keyed by intent.
  static const Map<String, String> assistantReplies = <String, String>{
    'light': 'Switching the living room lights now — Main relay goes ON. '
        'This is a MEDIUM risk action, so I recorded your face + voice approval in the audit log.',
    'audit': 'Last 24 hours: 1 denied command (gate, expired verification), '
        '1 unlock to Studio PC with owner verification, and one device offline notice '
        'from the greenhouse node.',
    'unlock': 'Launching the secure unlock flow for your paired machine. '
        'Face, voice and your device biometric are required, and the token is valid for '
        'at most 30 seconds and can be used once.',
    'kill': 'The KILL-SWITCH is always available from the app bar: hold it for one second '
        'and the assistant stops immediately, without any biometric prompt.',
    'bn': 'আমি প্রস্তুত। আপনি যা বলবেন তা করতে পারি — তবে MEDIUM বা HIGH ঝুঁকির কাজের আগে '
        'আমি আপনার মুখ ও কণ্ঠ যাচাই চাইব।',
    'default': 'Understood. I am running locally with the mock backend, so nothing leaves '
        'this device yet. Ask me to switch a light, show the audit trail, or prepare an unlock.',
  };
}
