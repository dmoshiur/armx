// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:math';

import 'package:armx_ai/core/errors/app_exception.dart';
import 'package:armx_ai/core/security/risk_policy.dart';
import 'package:armx_ai/core/security/risk_tier.dart';
import 'package:armx_ai/core/security/verification_evidence.dart';
import 'package:armx_ai/core/security/voice_verification_gateway.dart';
import 'package:armx_ai/core/utils/clock.dart';
import 'package:armx_ai/features/voice/voice_engines.dart';
import 'package:flutter_test/flutter_test.dart';

/// Speech-to-text engine that speaks a fixed transcript and advances the clock, so the
/// probe's minimum-sample-duration rule is exercised without real time passing.
class _ScriptedStt implements SpeechToTextEngine {
  _ScriptedStt({
    required this.clock,
    required this.transcript,
    this.speakFor = const Duration(seconds: 2),
    this.simulated = false,
  });

  final FixedClock clock;
  final String transcript;
  final Duration speakFor;
  final bool simulated;

  @override
  String get engineId => 'scripted';

  @override
  bool get isAvailable => true;

  @override
  bool get isSimulated => simulated;

  @override
  Future<bool> initialize({
    required String localeCode,
    void Function(String code)? onError,
  }) async =>
      true;

  @override
  Future<void> startListening({
    required String localeCode,
    required void Function(String words, bool isFinal) onResult,
    void Function(double level)? onLevel,
  }) async {
    onLevel?.call(0.5);
    onResult(transcript, true);
    clock.advance(speakFor);
  }

  @override
  Future<String> stopListening() async => transcript;

  @override
  Future<void> cancelListening() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  final now = DateTime.utc(2026, 10, 1, 12);
  late FixedClock clock;

  setUp(() => clock = FixedClock(now));

  VoiceChallenge challenge() => VoiceChallenge.random(
        localeCode: 'en',
        random: Random(7),
        now: now,
      );

  group('VoiceChallenge', () {
    test('offers phrases for both supported languages', () {
      expect(VoiceChallenge.phrases['en'], isNotEmpty);
      expect(VoiceChallenge.phrases['bn'], isNotEmpty);
    });

    test('matchRatio counts word overlap, not exact order', () {
      final value = VoiceChallenge(localeCode: 'en', phrase: 'armx verify blue', issuedAt: now);
      expect(value.matchRatio('armx verify blue'), 1);
      expect(value.matchRatio('blue armx verify'), 1);
      expect(value.matchRatio('armx verify'), closeTo(2 / 3, 0.001));
      expect(value.matchRatio('something else entirely'), 0);
    });
  });

  group('VoiceSampleProbe', () {
    test('rejects a sample shorter than the minimum duration', () {
      final probe = VoiceSampleProbe(engine: _ScriptedStt(
        clock: clock,
        transcript: challenge().phrase,
        speakFor: const Duration(milliseconds: 400),
      ), clock: clock);
      final result = probe.evaluate(
        transcript: challenge().phrase,
        duration: const Duration(milliseconds: 400),
        challenge: challenge(),
      );
      expect(result.passed, isFalse);
      expect(result.failureReason, VerificationFailureReason.voiceTooShort);
      expect(probe.isSimulated, isFalse);
    });

    test('rejects an empty transcript with voiceNotHeard', () {
      final probe = VoiceSampleProbe(
        engine: _ScriptedStt(clock: clock, transcript: ''),
        clock: clock,
      );
      final result = probe.evaluate(
        transcript: '   ',
        duration: const Duration(seconds: 3),
        challenge: challenge(),
      );
      expect(result.passed, isFalse);
      expect(result.failureReason, VerificationFailureReason.voiceNotHeard);
    });

    test('accepts a long enough sample that repeats the challenge', () async {
      final expected = challenge();
      final engine = _ScriptedStt(clock: clock, transcript: expected.phrase);
      final probe = VoiceSampleProbe(engine: engine, clock: clock, random: Random(1));

      final result = await probe.capture(
        challenge: expected,
        timeout: const Duration(seconds: 5),
      );

      expect(result.passed, isTrue);
      expect(result.matchRatio, 1);
      expect(result.duration.inMilliseconds, greaterThan(1000));
    });
  });

  group('VoiceVerificationGateway', () {
    test('returns a voice-only evidence set on success', () async {
      final expected = challenge();
      final probe = VoiceSampleProbe(
        engine: _ScriptedStt(clock: clock, transcript: expected.phrase),
        clock: clock,
        random: Random(3),
      );
      final gateway = VoiceVerificationGateway(probe: probe, clock: clock);

      final evidence = await gateway.verify(tier: RiskTier.low, reason: 'demo');

      expect(evidence.factors, hasLength(1));
      expect(evidence.factors.single.factor, VerificationFactor.voice);
      expect(evidence.factors.single.passed, isTrue);
      expect(evidence.hasFresh(VerificationFactor.voice, clock.now()), isTrue);
      expect(evidence.hasFresh(VerificationFactor.face, clock.now()), isFalse);
    });

    test('throws a VerificationException when the phrase is not heard', () async {
      final probe = VoiceSampleProbe(
        engine: _ScriptedStt(clock: clock, transcript: 'unrelated audio'),
        clock: clock,
      );
      final gateway = VoiceVerificationGateway(probe: probe, clock: clock);

      expect(
        () => gateway.verify(tier: RiskTier.medium, reason: 'demo'),
        throwsA(
          isA<VerificationException>().having(
            (error) => error.reason,
            'reason',
            VerificationFailureReason.voiceNotHeard,
          ),
        ),
      );
    });

    test('RULE 1: voice alone never satisfies any tier, not even LOW', () async {
      // The gateway always adds exactly one factor; RiskPolicy must refuse it. This is the
      // regression test for "voice alone is NEVER sufficient".
      final expected = challenge();
      final probe = VoiceSampleProbe(
        engine: _ScriptedStt(clock: clock, transcript: expected.phrase),
        clock: clock,
        random: Random(5),
      );
      final evidence = await VoiceVerificationGateway(probe: probe, clock: clock)
          .verify(tier: RiskTier.low, reason: 'demo');

      for (final tier in RiskTier.values) {
        final decision = RiskPolicy.evaluate(
          required: tier,
          evidence: evidence,
          now: clock.now(),
        );
        expect(decision.allowed, isFalse, reason: 'tier ${tier.name} must not pass on voice alone');
      }
      expect(
        RiskPolicy.evaluate(required: RiskTier.low, evidence: evidence, now: clock.now()).reason,
        PolicyDenialReason.voiceOnlyNotTrusted,
      );
    });
  });
}
