// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import '../utils/clock.dart';
import 'risk_tier.dart';
import 'verification_evidence.dart';

/// Captures the on-device verification factors a privileged action needs.
///
/// Implementations never leave the device with raw biometric material: the only
/// artefact that may cross the process boundary later is the signed, single-use
/// `owner_verified` assertion (see `docs/api.md`), which the chat controller mints
/// from the returned evidence.
abstract interface class VerificationGateway {
  /// Runs the prompts [RiskPolicy] demands for [tier] and returns fresh evidence.
  ///
  /// [reason] is the assistant-supplied justification for the action; a real
  /// implementation shows it in the verification sheet so the user knows what
  /// they are approving. Throws [AppException] (a `VerificationException`) when
  /// the user cancels or a factor cannot be captured.
  Future<VerificationEvidence> verify({
    required RiskTier tier,
    required String reason,
  });
}

/// Deterministic stand-in used while the real verifiers arrive (voice = step 4,
/// vision = step 7).
///
/// It records exactly the factors [RiskPolicy] demands for [tier] — face for LOW,
/// face + voice for MEDIUM, face + voice + system biometric for HIGH — all fresh
/// at the injected clock's current instant. That keeps every approval path of
/// the chat screen exercisable end-to-end today, and keeps tests free of camera,
/// microphone and platform-channel dependencies.
///
/// Swap [verificationGatewayProvider] for the real implementation when the
/// biometric pipelines land; nothing else in the chat flow changes.
final class SimulatedVerificationGateway implements VerificationGateway {
  /// Creates the simulated gateway over [clock].
  const SimulatedVerificationGateway({Clock? clock})
      : _clock = clock;

  final Clock? _clock;

  @override
  Future<VerificationEvidence> verify({
    required RiskTier tier,
    required String reason,
  }) async {
    final now = (_clock ?? const SystemClock()).now().toUtc();
    var evidence = VerificationEvidence.empty(now);
    evidence = evidence.withResult(
      FactorResult(
        factor: VerificationFactor.face,
        passed: true,
        verifiedAt: now,
        score: 0.93,
      ),
    );
    if (tier.isAtLeast(RiskTier.medium)) {
      evidence = evidence.withResult(
        FactorResult(
          factor: VerificationFactor.voice,
          passed: true,
          verifiedAt: now,
          score: 0.9,
        ),
      );
    }
    if (tier == RiskTier.high) {
      evidence = evidence.withResult(
        FactorResult(
          factor: VerificationFactor.systemBiometric,
          passed: true,
          verifiedAt: now,
        ),
      );
    }
    return evidence;
  }
}
