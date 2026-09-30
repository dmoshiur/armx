// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/security/risk_policy.dart';
import 'package:armx_ai/core/security/risk_tier.dart';
import 'package:armx_ai/core/security/security_constants.dart';
import 'package:armx_ai/core/security/verification_evidence.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

/// `RiskPolicy` is the single authority on how much verification an action needs.
/// These tests are the specification; if they change, the product rules changed.
void main() {
  final now = Fixtures.anchor;

  group('tier requirements', () {
    test('LOW accepts a face match on its own', () {
      final decision = RiskPolicy.evaluate(
        required: RiskTier.low,
        evidence: Fixtures.evidence(now, face: true),
        now: now,
      );

      expect(decision.allowed, isTrue);
      expect(decision.satisfied, RiskTier.low);
      expect(decision.expiresIn, isNotNull);
      expect(decision.needsReVerification, isFalse);
    });

    test('voice alone is never trusted, not even for LOW', () {
      final decision = RiskPolicy.evaluate(
        required: RiskTier.low,
        evidence: Fixtures.evidence(now, voice: true),
        now: now,
      );

      expect(RiskPolicy.allowVoiceOnlyForLowTier, isFalse,
          reason: 'the fail-closed reading is the shipped default');
      expect(decision.allowed, isFalse);
      expect(decision.reason, PolicyDenialReason.voiceOnlyNotTrusted);
      expect(decision.missingFactors, contains(VerificationFactor.face));
    });

    test('MEDIUM requires face AND voice', () {
      final faceOnly = RiskPolicy.evaluate(
        required: RiskTier.medium,
        evidence: Fixtures.evidence(now, face: true),
        now: now,
      );
      final both = RiskPolicy.evaluate(
        required: RiskTier.medium,
        evidence: Fixtures.evidence(now, face: true, voice: true),
        now: now,
      );

      expect(faceOnly.allowed, isFalse);
      expect(faceOnly.reason, PolicyDenialReason.voiceRequired);
      expect(faceOnly.missingFactors, <VerificationFactor>{VerificationFactor.voice});
      expect(both.allowed, isTrue);
      expect(both.satisfied, RiskTier.medium);
    });

    test('HIGH requires face AND voice AND system biometric/PIN', () {
      final withoutBiometric = RiskPolicy.evaluate(
        required: RiskTier.high,
        evidence: Fixtures.evidence(now, face: true, voice: true),
        now: now,
      );
      final complete = RiskPolicy.evaluate(
        required: RiskTier.high,
        evidence: Fixtures.evidence(now, face: true, voice: true, systemBiometric: true),
        now: now,
      );

      expect(withoutBiometric.allowed, isFalse);
      expect(withoutBiometric.reason, PolicyDenialReason.systemBiometricRequired);
      expect(complete.allowed, isTrue);
      expect(complete.satisfied, RiskTier.high);
      expect(RiskPolicy.requiresSystemBiometric(RiskTier.high), isTrue);
    });

    test('nothing verified yet is reported as such', () {
      final decision = RiskPolicy.evaluate(
        required: RiskTier.high,
        evidence: VerificationEvidence.empty(now),
        now: now,
      );

      expect(decision.allowed, isFalse);
      expect(decision.reason, PolicyDenialReason.nothingVerified);
      expect(decision.missingFactors.length, 3);
    });

    test('a failed factor never counts', () {
      final decision = RiskPolicy.evaluate(
        required: RiskTier.low,
        evidence: Fixtures.evidence(now, face: true, facePassed: false),
        now: now,
      );

      expect(decision.allowed, isFalse);
      expect(decision.satisfied, isNull);
    });
  });

  group('expiry', () {
    test('the trust window is exactly 60 seconds', () {
      expect(RiskPolicy.trustWindow, const Duration(seconds: 60));
      expect(SecurityConstants.verificationTrustWindow, RiskPolicy.trustWindow);
    });

    test('evidence older than the window is rejected', () {
      final decision = RiskPolicy.evaluate(
        required: RiskTier.low,
        evidence: Fixtures.evidence(
          now,
          face: true,
          age: const Duration(seconds: 61),
        ),
        now: now,
      );

      expect(decision.allowed, isFalse);
      expect(decision.reason, PolicyDenialReason.evidenceExpired);
    });

    test('evidence inside the window reports the remaining seconds', () {
      final decision = RiskPolicy.evaluate(
        required: RiskTier.medium,
        evidence: Fixtures.evidence(
          now,
          face: true,
          voice: true,
          age: const Duration(seconds: 20),
        ),
        now: now,
      );

      expect(decision.allowed, isTrue);
      expect(decision.expiresIn!.inSeconds, 40);
    });
  });

  group('tier escalation', () {
    test('escalating forces re-verification instead of reusing old evidence', () {
      final stale = Fixtures.evidence(now, face: true, voice: true);
      final decision = RiskPolicy.evaluate(
        required: RiskTier.high,
        evidence: stale,
        now: now,
        reVerifyAfter: now.add(const Duration(seconds: 1)),
      );

      expect(decision.allowed, isFalse);
      expect(decision.reason, PolicyDenialReason.reVerificationRequired);
      expect(decision.missingFactors, contains(VerificationFactor.face));
    });

    test('fresh evidence captured after the escalation is accepted', () {
      final fresh = Fixtures.evidence(
        now,
        face: true,
        voice: true,
        systemBiometric: true,
        age: const Duration(seconds: 3),
      );
      final decision = RiskPolicy.evaluate(
        required: RiskTier.high,
        evidence: fresh,
        now: now,
        reVerifyAfter: now.subtract(const Duration(seconds: 10)),
      );

      expect(decision.allowed, isTrue);
      expect(decision.satisfied, RiskTier.high);
    });
  });

  group('tier ordering', () {
    test('isAtLeast compares severity', () {
      expect(RiskTier.high.isAtLeast(RiskTier.medium), isTrue);
      expect(RiskTier.low.isAtLeast(RiskTier.medium), isFalse);
    });

    test('unknown wire values fail closed to HIGH', () {
      expect(RiskTier.fromWire('MEDIUM'), RiskTier.medium);
      expect(RiskTier.fromWire('low'), RiskTier.low);
      expect(RiskTier.fromWire(null), RiskTier.high);
      expect(RiskTier.fromWire('whatever'), RiskTier.high);
      expect(RiskTier.fromWire(7), RiskTier.high);
    });
  });
}
