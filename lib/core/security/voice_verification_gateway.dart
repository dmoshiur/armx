// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../features/voice/voice_engines.dart';
import '../errors/app_exception.dart';
import '../utils/clock.dart';
import 'security_constants.dart';
import 'risk_tier.dart';
import 'verification_evidence.dart';
import 'verification_gateway.dart';

/// The spoken phrase a voice verification asks the owner to repeat.
///
/// The words are deliberately not user-facing copy (the *instruction* is localized in the
/// UI); they exist so a voice sample cannot be satisfied by silence, by a random noise
/// burst, or by replaying unrelated audio.
@immutable
class VoiceChallenge {
  /// Creates a challenge.
  const VoiceChallenge({required this.localeCode, required this.phrase, required this.issuedAt});

  /// `en` or `bn`.
  final String localeCode;

  /// The words the owner must say.
  final String phrase;

  /// When the challenge was issued.
  final DateTime issuedAt;

  /// Challenge phrases per locale. Bengali phrases are written in Bengali script so a
  /// Bengali speech recognizer can match them.
  static const Map<String, List<String>> phrases = <String, List<String>>{
    'en': <String>[
      'armx verify blue comet',
      'armx confirm river stone',
      'armx approve maple north',
      'armx verify silver dawn',
    ],
    'bn': <String>[
      'আরমেক্স যাচাই নীল ধূমকেতু',
      'আরমেক্স নিশ্চিত নদী পাথর',
      'আরমেক্স অনুমোদন ম্যাপল উত্তর',
      'আরমেক্স যাচাই রূপালী ভোর',
    ],
  };

  /// Picks a random challenge for [localeCode].
  static VoiceChallenge random({
    required String localeCode,
    required Random random,
    required DateTime now,
  }) {
    final list = phrases[localeCode] ?? phrases['en']!;
    return VoiceChallenge(
      localeCode: localeCode,
      phrase: list[random.nextInt(list.length)],
      issuedAt: now,
    );
  }

  /// Ratio of challenge words present in [transcript] (0.0–1.0).
  ///
  /// Word-set matching rather than exact string equality: recognizers differ on spacing,
  /// punctuation and on how they transliterate. The threshold applied by
  /// [VoiceSampleProbe] is 0.5, and a failed match is never treated as a pass.
  double matchRatio(String transcript) {
    final expected = phrase.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (expected.isEmpty) {
      return 0;
    }
    final heard = transcript.toLowerCase().split(RegExp(r'\s+')).toSet();
    final hits = expected.where((word) => heard.contains(word)).length;
    return hits / expected.length;
  }
}

/// Outcome of one on-device voice capture.
@immutable
class VoiceSampleResult {
  /// Creates a result.
  const VoiceSampleResult({
    required this.passed,
    required this.transcript,
    required this.duration,
    required this.matchRatio,
    this.failureReason,
  });

  /// Whether the sample satisfies the voice factor.
  final bool passed;

  /// What the recognizer heard (never stored, never sent anywhere).
  final String transcript;

  /// How long the owner spoke.
  final Duration duration;

  /// Word-overlap ratio against the challenge.
  final double matchRatio;

  /// Why the sample failed, when it did.
  final VerificationFailureReason? failureReason;
}

/// Captures one voice sample and decides whether the voice factor passed.
///
/// The threshold logic lives here (and not in the UI) so every caller — chat approvals,
/// unlock, walkie-talkie consent — applies the same rule:
/// * the sample must be at least [SecurityConstants.minVoiceSampleDuration] long;
/// * the recognizer must have heard something;
/// * at least half of the challenge words must appear in the transcript.
///
/// This is a **liveness-lite** check: it defeats silence and unrelated audio, not a
/// high-quality recording of the owner. That is exactly why the product never lets voice
/// alone satisfy a tier (see `RiskPolicy` and README rule 1).
class VoiceSampleProbe {
  /// Creates the probe.
  VoiceSampleProbe({
    required SpeechToTextEngine engine,
    required Clock clock,
    Random? random,
  })  : _engine = engine,
        _clock = clock,
        _random = random ?? Random.secure();

  final SpeechToTextEngine _engine;
  final Clock _clock;
  final Random _random;

  /// Whether a real capture can be attempted at all.
  bool get isSimulated => _engine.isSimulated;

  /// Runs one capture for [challenge], giving the owner [timeout] to speak.
  ///
  /// [onLevel] feeds the level meter; no audio is retained or forwarded.
  Future<VoiceSampleResult> capture({
    required VoiceChallenge challenge,
    required Duration timeout,
    void Function(double level)? onLevel,
  }) async {
    final started = _clock.now().toUtc();
    var transcript = '';
    final done = Completer<void>();

    await _engine.startListening(
      localeCode: challenge.localeCode,
      onResult: (words, isFinal) {
        transcript = words;
        if (isFinal && !done.isCompleted) {
          done.complete();
        }
      },
      onLevel: onLevel,
    );

    // Wait for the recognizer to finish, or stop it when the window closes.
    try {
      await done.future.timeout(timeout);
    } on TimeoutException {
      transcript = await _engine.stopListening();
    }
    final spokenFor = _clock.now().toUtc().difference(started);
    return evaluate(
      transcript: transcript,
      duration: spokenFor,
      challenge: challenge,
    );
  }

  /// Applies the pass/fail rule without touching any hardware (used by tests).
  VoiceSampleResult evaluate({
    required String transcript,
    required Duration duration,
    required VoiceChallenge challenge,
  }) {
    final ratio = challenge.matchRatio(transcript);
    if (duration < SecurityConstants.minVoiceSampleDuration) {
      return VoiceSampleResult(
        passed: false,
        transcript: transcript,
        duration: duration,
        matchRatio: ratio,
        failureReason: VerificationFailureReason.voiceTooShort,
      );
    }
    if (transcript.trim().isEmpty || ratio < 0.5) {
      return VoiceSampleResult(
        passed: false,
        transcript: transcript,
        duration: duration,
        matchRatio: ratio,
        failureReason: VerificationFailureReason.voiceNotHeard,
      );
    }
    return VoiceSampleResult(
      passed: true,
      transcript: transcript,
      duration: duration,
      matchRatio: ratio,
    );
  }

  /// A fresh random challenge for [localeCode].
  VoiceChallenge newChallenge(String localeCode) => VoiceChallenge.random(
        localeCode: localeCode,
        random: _random,
        now: _clock.now().toUtc(),
      );
}

/// [VerificationGateway] that captures **only the voice factor**.
///
/// Used where the voice half of a MEDIUM/HIGH challenge is collected as one step of a
/// composite gateway (see [CompositeVerificationGateway]) — most importantly for the
/// unlock flow, which needs face **and** voice **and** the system biometric.
///
/// On its own it can never satisfy any tier:
/// * LOW — `RiskPolicy` refuses a voice-only sample (`voiceOnlyNotTrusted`);
/// * MEDIUM / HIGH — the face and system factors are missing.
///
/// That is intentional and covered by tests: no feature may use this class to bypass rule 1.
class VoiceVerificationGateway implements VerificationGateway {
  /// Creates the gateway.
  VoiceVerificationGateway({
    required VoiceSampleProbe probe,
    required Clock clock,
    this.localeCode = 'en',
    this.timeout = const Duration(seconds: 8),
  })  : _probe = probe,
        _clock = clock;

  final VoiceSampleProbe _probe;
  final Clock _clock;

  /// Language the challenge is spoken in.
  final String localeCode;

  /// How long the owner has to speak.
  final Duration timeout;

  /// The challenge currently being asked (so the UI can display it), if any.
  VoiceChallenge? get currentChallenge => _current;

  VoiceChallenge? _current;

  /// Level stream hook for the verification sheet's meter.
  void Function(double level)? onLevel;

  @override
  Future<VerificationEvidence> verify({
    required RiskTier tier,
    required String reason,
  }) async {
    final challenge = _probe.newChallenge(localeCode);
    _current = challenge;
    final VoiceSampleResult result;
    try {
      result = await _probe.capture(
        challenge: challenge,
        timeout: timeout,
        onLevel: onLevel,
      );
    } on AppException {
      rethrow;
    } on Object catch (error) {
      throw VerificationException(
        VerificationFailureReason.hardwareUnavailable,
        message: 'Voice capture failed: ${error.runtimeType}',
      );
    } finally {
      _current = null;
    }

    if (!result.passed) {
      throw VerificationException(
        result.failureReason ?? VerificationFailureReason.voiceNotHeard,
        message: 'Voice verification failed',
      );
    }

    final now = _clock.now().toUtc();
    return VerificationEvidence.empty(now).withResult(
      FactorResult(
        factor: VerificationFactor.voice,
        passed: true,
        verifiedAt: now,
        score: result.matchRatio.clamp(0.0, 1.0),
      ),
    );
  }
}
