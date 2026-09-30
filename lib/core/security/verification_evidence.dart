// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:freezed_annotation/freezed_annotation.dart';

import '../utils/clock.dart';
import 'risk_tier.dart';
import 'security_constants.dart';

part 'verification_evidence.freezed.dart';

/// The three verification factors A.R.M.X can ask for.
///
/// Trust levels differ per product policy: a 2D face match is medium trust, a voice sample
/// is never sufficient on its own, and only the platform biometric/PIN is strong enough to
/// unlock the highest tier.
enum VerificationFactor {
  /// On-device face match against the enrolled template.
  face,

  /// Voice sample matched against the enrolled voice print.
  voice,

  /// System biometric prompt, device PIN/pattern or password.
  systemBiometric,
}

/// The outcome of a single verification prompt.
@freezed
abstract class FactorResult with _$FactorResult {
  /// Creates a factor result.
  const factory FactorResult({
    required VerificationFactor factor,
    required bool passed,
    required DateTime verifiedAt,
    @Default(0) double score,
    String? detail,
  }) = _FactorResult;

  const FactorResult._();

  /// Whether this factor is still inside the trust window at [now].
  ///
  /// The window matches [SecurityConstants.verificationTrustWindow] (60 s).
  bool isFreshAt(DateTime now) {
    if (!passed) {
      return false;
    }
    final age = now.difference(verifiedAt);
    return !age.isNegative && age < SecurityConstants.verificationTrustWindow;
  }

  /// Age of this result at [now]; negative values mean a clock skew.
  Duration ageAt(DateTime now) => now.difference(verifiedAt);
}

/// Everything the app knows about the current user-verification session.
///
/// Short-lived by design: rebuilt for each privileged action and wiped on app lock,
/// long backgrounding, or when the user taps "lock app".
@freezed
abstract class VerificationEvidence with _$VerificationEvidence {
  /// Creates an evidence set.
  const factory VerificationEvidence({
    required DateTime capturedAt,
    @Default(<FactorResult>[]) List<FactorResult> factors,
  }) = _VerificationEvidence;

  const VerificationEvidence._();

  /// Evidence containing no satisfied factors.
  factory VerificationEvidence.empty(DateTime now) => VerificationEvidence(capturedAt: now);

  /// Evidence captured at [clock]'s current instant.
  factory VerificationEvidence.at(Clock clock) => VerificationEvidence.empty(clock.now());

  /// Most recent result for [factor], or `null` when that factor never ran.
  FactorResult? latest(VerificationFactor factor) {
    FactorResult? found;
    for (final result in factors) {
      if (result.factor == factor &&
          (found == null || result.verifiedAt.isAfter(found.verifiedAt))) {
        found = result;
      }
    }
    return found;
  }

  /// Whether [factor] passed and is still fresh at [now].
  bool hasFresh(VerificationFactor factor, DateTime now) =>
      latest(factor)?.isFreshAt(now) ?? false;

  /// Whether [factor] passed after [instant] (used for escalation re-verification).
  bool hasFreshAfter(VerificationFactor factor, DateTime instant, DateTime now) {
    final result = latest(factor);
    if (result == null || !result.isFreshAt(now)) {
      return false;
    }
    return !result.verifiedAt.isBefore(instant);
  }

  /// Adds a factor result and keeps the history bounded (newest last).
  VerificationEvidence withResult(FactorResult result) {
    final kept = factors
        .where(
          (existing) =>
              existing.factor != result.factor || existing.verifiedAt != result.verifiedAt,
        )
        .toList(growable: true)
      ..add(result);
    final bounded = kept.length > 12 ? kept.sublist(kept.length - 12) : kept;
    return copyWith(factors: bounded);
  }

  /// The highest tier this evidence satisfies at [now], if any.
  ///
  /// * no face ⇒ nothing (voice alone is never trusted);
  /// * face only ⇒ [RiskTier.low];
  /// * face + voice ⇒ [RiskTier.medium];
  /// * face + voice + system biometric/PIN ⇒ [RiskTier.high].
  RiskTier? satisfiedTier(DateTime now) {
    final face = hasFresh(VerificationFactor.face, now);
    final voice = hasFresh(VerificationFactor.voice, now);
    final system = hasFresh(VerificationFactor.systemBiometric, now);
    if (!face) {
      return null;
    }
    if (system && voice) {
      return RiskTier.high;
    }
    if (voice) {
      return RiskTier.medium;
    }
    return RiskTier.low;
  }

  /// Seconds left before [factor]'s result goes stale at [now]; zero when already stale.
  int secondsRemaining(VerificationFactor factor, DateTime now) {
    final result = latest(factor);
    if (result == null || !result.isFreshAt(now)) {
      return 0;
    }
    final remaining = SecurityConstants.verificationTrustWindow - result.ageAt(now);
    return remaining.inSeconds < 0 ? 0 : remaining.inSeconds;
  }

  /// Drops every factor result (used by "lock app" and by a device revocation event).
  VerificationEvidence cleared(DateTime now) => VerificationEvidence.empty(now);
}
