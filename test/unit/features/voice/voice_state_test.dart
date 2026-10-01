// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/features/voice/voice_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VoiceState', () {
    test('maps every phase onto the orb contract', () {
      const expectations = <VoicePhase, String>{
        VoicePhase.idle: 'idle',
        VoicePhase.arming: 'listening',
        VoicePhase.listening: 'listening',
        VoicePhase.transcribing: 'listening',
        VoicePhase.thinking: 'thinking',
        VoicePhase.speaking: 'speaking',
        VoicePhase.error: 'locked',
        VoicePhase.unsupported: 'locked',
      };
      for (final entry in expectations.entries) {
        expect(
          VoiceState(phase: entry.key).orbPhaseName,
          entry.value,
          reason: 'phase ${entry.key.name}',
        );
      }
    });

    test('exposes capturing/responding flags for the composer', () {
      expect(const VoiceState().isCapturing, isFalse);
      expect(const VoiceState(phase: VoicePhase.listening).isCapturing, isTrue);
      expect(const VoiceState(phase: VoicePhase.speaking).isResponding, isTrue);
      expect(const VoiceState(phase: VoicePhase.speaking).isCapturing, isFalse);
    });

    test('displayTranscript prefers the partial transcript while listening', () {
      const state = VoiceState(transcript: 'old', partialTranscript: 'new words');
      expect(state.displayTranscript, 'new words');
      expect(state.copyWith(partialTranscript: '').displayTranscript, 'old');
    });

    test('copyWith can clear the nullable fields explicitly', () {
      final state = VoiceState(
        errorCode: 'stt_unavailable',
        captureStartedAt: DateTime.utc(2026, 10, 1),
      );
      expect(state.copyWith(clearError: true).errorCode, isNull);
      expect(state.copyWith(clearCaptureStart: true).captureStartedAt, isNull);
      expect(state.copyWith().errorCode, 'stt_unavailable');
    });

    test('engine report flags a stub detector as not available', () {
      const report = VoiceEngineReport();
      expect(report.wakeWordIsStub, isTrue);
      expect(report.wakeWordAvailable, isFalse);
      expect(report.copyWith(wakeWordIsStub: false).wakeWordAvailable, isTrue);
      expect(
        const VoiceEngineReport().copyWith(sttAvailable: true),
        isNot(const VoiceEngineReport()),
      );
    });
  });
}
