// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import '../utils/clock.dart';
import 'risk_tier.dart';
import 'verification_evidence.dart';
import 'verification_gateway.dart';

/// Runs several [VerificationGateway]s in order and merges their evidence.
///
/// The product's verification flows are composed, never invented:
/// * chat approval for MEDIUM/HIGH — face + voice (+ system biometric for HIGH);
/// * unlock (HIGH) — the same three factors;
/// * walkie-talkie consent changes — LOW (face) only.
///
/// Each step contributes exactly the factor(s) it captured, and the merged evidence is what
/// [RiskPolicy] evaluates. Because the merge can only *add* factors, a composite can never
/// satisfy a tier that its parts could not; and because each part fails closed by throwing,
/// a cancelled step aborts the whole verification instead of downgrading it.
class CompositeVerificationGateway implements VerificationGateway {
  /// Creates the composite over [steps], executed in order.
  CompositeVerificationGateway({
    required List<VerificationGateway> steps,
    required Clock clock,
  })  : _steps = List<VerificationGateway>.unmodifiable(steps),
        _clock = clock;

  final List<VerificationGateway> _steps;
  final Clock _clock;

  /// How many prompts the next verification will show (used by the UI to explain the
  /// sequence before it starts).
  int get stepCount => _steps.length;

  @override
  Future<VerificationEvidence> verify({
    required RiskTier tier,
    required String reason,
  }) async {
    var evidence = VerificationEvidence.empty(_clock.now().toUtc());
    for (final step in _steps) {
      final captured = await step.verify(tier: tier, reason: reason);
      for (final result in captured.factors) {
        evidence = evidence.withResult(result);
      }
    }
    return evidence;
  }
}
