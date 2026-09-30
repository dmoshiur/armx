// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/foundation.dart';

import 'risk_tier.dart';
import 'security_constants.dart';
import 'verification_evidence.dart';

/// Why a privileged action was refused.
enum PolicyDenialReason {
  /// The user has not verified anything yet.
  nothingVerified,

  /// Only a voice sample was presented. Voice alone is never trusted.
  voiceOnlyNotTrusted,

  /// A face match is required and missing (or stale).
  faceRequired,

  /// A voice sample is required and missing (or stale).
  voiceRequired,

  /// A system biometric/PIN prompt is required and missing (or stale).
  systemBiometricRequired,

  /// Evidence exists but is older than the 60 s trust window.
  evidenceExpired,

  /// The action escalates the tier and the existing evidence predates the request.
  reVerificationRequired,
}

/// The outcome of [RiskPolicy.evaluate].
@immutable
class PolicyDecision {
  const PolicyDecision._({
    required this.allowed,
    required this.required,
    this.satisfied,
    this.reason,
    this.missingFactors = const <VerificationFactor>{},
    this.expiresIn,
  });

  /// Allows the action with [satisfied] evidence.
  factory PolicyDecision.allow({
    required RiskTier required,
    required RiskTier satisfied,
    Duration? expiresIn,
  }) =>
      PolicyDecision._(
        allowed: true,
        required: required,
        satisfied: satisfied,
        expiresIn: expiresIn,
      );

  /// Refuses the action, explaining exactly what is missing.
  factory PolicyDecision.deny({
    required RiskTier required,
    required PolicyDenialReason reason,
    RiskTier? satisfied,
    Set<VerificationFactor> missingFactors = const <VerificationFactor>{},
  }) =>
      PolicyDecision._(
        allowed: false,
        required: required,
        satisfied: satisfied,
        reason: reason,
        missingFactors: missingFactors,
      );

  /// Whether the action may proceed.
  final bool allowed;

  /// Tier demanded by the action.
  final RiskTier required;

  /// Highest tier actually satisfied by the presented evidence, if any.
  final RiskTier? satisfied;

  /// Why the action was refused (`null` when [allowed]).
  final PolicyDenialReason? reason;

  /// Factors the user still needs to provide, in the order they should be requested.
  final Set<VerificationFactor> missingFactors;

  /// How long the granted trust lasts (only set when [allowed]).
  final Duration? expiresIn;

  /// Whether the user must be prompted for at least one more factor.
  bool get needsReVerification => !allowed && missingFactors.isNotEmpty;

  @override
  String toString() => allowed
      ? 'PolicyDecision.allow(${required.wireName} via ${satisfied?.wireName})'
      : 'PolicyDecision.deny(${required.wireName}: ${reason?.name})';
}

/// The single place where A.R.M.X decides how much verification an action needs.
///
/// Product rules (see README "Risk rules"):
/// | Tier   | Required verification                                          |
/// |--------|----------------------------------------------------------------|
/// | LOW    | face **or** voice                                              |
/// | MEDIUM | face **and** voice                                             |
/// | HIGH   | face **and** voice **and** system biometric or device PIN       |
///
/// Two extra rules are enforced here rather than in the UI:
/// 1. **Voice alone is never trusted.** A voice-only sample therefore grants *no* tier,
///    including LOW. This is the fail-closed reading of the spec, which says both
///    "LOW = face OR voice" and "voice alone is never trusted"; where those two statements
///    conflict this implementation refuses the action and asks for a face check. Set
///    [allowVoiceOnlyForLowTier] to `true` only if a deployment explicitly wants the
///    literal "OR" behaviour for LOW.
/// 2. **Escalation forces re-verification.** Passing [reVerifyAfter] makes every factor
///    that was captured before that instant invalid for the new tier.
abstract final class RiskPolicy {
  /// Deployment switch documenting the ambiguity resolved above. Defaults to fail-closed.
  static const bool allowVoiceOnlyForLowTier = false;

  /// Verification trust window (mirrors [SecurityConstants.verificationTrustWindow]).
  static Duration get trustWindow => SecurityConstants.verificationTrustWindow;

  /// Factors the given [tier] requires.
  ///
  /// LOW returns both acceptable factors; [evaluate] accepts *any one* of them.
  static Set<VerificationFactor> requiredFactors(RiskTier tier) => switch (tier) {
        RiskTier.low => const <VerificationFactor>{
            VerificationFactor.face,
            VerificationFactor.voice,
          },
        RiskTier.medium || RiskTier.high => const <VerificationFactor>{
            VerificationFactor.face,
            VerificationFactor.voice,
          },
      };

  /// Whether [tier] additionally demands a system biometric/PIN prompt.
  static bool requiresSystemBiometric(RiskTier tier) => tier == RiskTier.high;

  /// Evaluates whether [evidence] permits an action of [required] tier at [now].
  ///
  /// [reVerifyAfter] is the instant at which the tier escalated (for example when the user
  /// tapped a HIGH-tier tool card); factors older than it are ignored, which forces a fresh
  /// prompt instead of silently reusing a previous low-risk verification.
  static PolicyDecision evaluate({
    required RiskTier required,
    required VerificationEvidence evidence,
    required DateTime now,
    DateTime? reVerifyAfter,
  }) {
    final face = _factorState(evidence, VerificationFactor.face, now, reVerifyAfter);
    final voice = _factorState(evidence, VerificationFactor.voice, now, reVerifyAfter);
    final system = _factorState(evidence, VerificationFactor.systemBiometric, now, reVerifyAfter);

    final anythingFresh = face.fresh || voice.fresh || system.fresh;
    final anythingEverVerified = evidence.factors.any((result) => result.passed);

    // Voice-only: the only fresh factor is voice.
    if (voice.fresh && !face.fresh && !system.fresh && !allowVoiceOnlyForLowTier) {
      return PolicyDecision.deny(
        required: required,
        reason: PolicyDenialReason.voiceOnlyNotTrusted,
        missingFactors: const <VerificationFactor>{VerificationFactor.face},
      );
    }

    switch (required) {
      case RiskTier.low:
        final satisfiedLow = face.fresh || (allowVoiceOnlyForLowTier && voice.fresh);
        if (satisfiedLow) {
          // LOW can be satisfied by either factor; report the longer remaining window.
          final faceTtl = _timeLeft(evidence, VerificationFactor.face, now);
          final voiceTtl = _timeLeft(evidence, VerificationFactor.voice, now);
          return PolicyDecision.allow(
            required: required,
            satisfied: RiskTier.low,
            expiresIn: face.fresh ? faceTtl : voiceTtl,
          );
        }
        return PolicyDecision.deny(
          required: required,
          reason: _reason(anythingEverVerified, anythingFresh, face.fresh, voice.fresh, system.fresh,
              reVerifyAfter: reVerifyAfter),
          missingFactors: face.fresh ? const <VerificationFactor>{} : const <VerificationFactor>{VerificationFactor.face},
        );

      case RiskTier.medium:
        if (face.fresh && voice.fresh) {
          return PolicyDecision.allow(
            required: required,
            satisfied: RiskTier.medium,
            expiresIn: _minTtl(
              _timeLeft(evidence, VerificationFactor.face, now),
              _timeLeft(evidence, VerificationFactor.voice, now),
            ),
          );
        }
        return PolicyDecision.deny(
          required: required,
          reason: _reason(anythingEverVerified, anythingFresh, face.fresh, voice.fresh, system.fresh,
              reVerifyAfter: reVerifyAfter),
          missingFactors: <VerificationFactor>{
            if (!face.fresh) VerificationFactor.face,
            if (!voice.fresh) VerificationFactor.voice,
          },
        );

      case RiskTier.high:
        if (face.fresh && voice.fresh && system.fresh) {
          return PolicyDecision.allow(
            required: required,
            satisfied: RiskTier.high,
            expiresIn: _minTtl(
              _minTtl(
                _timeLeft(evidence, VerificationFactor.face, now),
                _timeLeft(evidence, VerificationFactor.voice, now),
              ),
              _timeLeft(evidence, VerificationFactor.systemBiometric, now),
            ),
          );
        }
        return PolicyDecision.deny(
          required: required,
          reason: _reason(anythingEverVerified, anythingFresh, face.fresh, voice.fresh, system.fresh,
              reVerifyAfter: reVerifyAfter),
          missingFactors: <VerificationFactor>{
            if (!face.fresh) VerificationFactor.face,
            if (!voice.fresh) VerificationFactor.voice,
            if (!system.fresh) VerificationFactor.systemBiometric,
          },
        );
    }
  }

  /// Picks the denial reason that best describes what the user must fix.
  static PolicyDenialReason _reason(
    bool anythingEverVerified,
    bool anythingFresh,
    bool face,
    bool voice,
    bool system, {
    DateTime? reVerifyAfter,
  }) {
    if (!anythingEverVerified) {
      return PolicyDenialReason.nothingVerified;
    }
    if (!anythingFresh) {
      return reVerifyAfter != null
          ? PolicyDenialReason.reVerificationRequired
          : PolicyDenialReason.evidenceExpired;
    }
    if (reVerifyAfter != null && !face && !voice) {
      return PolicyDenialReason.reVerificationRequired;
    }
    if (!face) {
      return PolicyDenialReason.faceRequired;
    }
    if (!voice) {
      return PolicyDenialReason.voiceRequired;
    }
    if (!system) {
      return PolicyDenialReason.systemBiometricRequired;
    }
    return PolicyDenialReason.nothingVerified;
  }

  static _FactorState _factorState(
    VerificationEvidence evidence,
    VerificationFactor factor,
    DateTime now,
    DateTime? reVerifyAfter,
  ) {
    final fresh = reVerifyAfter == null
        ? evidence.hasFresh(factor, now)
        : evidence.hasFreshAfter(factor, reVerifyAfter, now);
    return _FactorState(fresh: fresh);
  }

  static Duration _timeLeft(
    VerificationEvidence evidence,
    VerificationFactor factor,
    DateTime now,
  ) =>
      Duration(seconds: evidence.secondsRemaining(factor, now));

  static Duration _minTtl(Duration a, Duration b) => a < b ? a : b;
}

/// Internal carrier for a factor's freshness decision.
@immutable
class _FactorState {
  const _FactorState({required this.fresh});

  final bool fresh;
}
