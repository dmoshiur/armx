// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/security/risk_tier.dart';
import 'package:flutter_test/flutter_test.dart';

/// The risk tier decides whether a confirmation dialog appears at all, so its parsing rules
/// are part of the safety story rather than a formatting detail.
void main() {
  group('RiskTier.fromWire', () {
    test('reads the three tiers, case-insensitively', () {
      expect(RiskTier.fromWire('low'), RiskTier.low);
      expect(RiskTier.fromWire('MEDIUM'), RiskTier.medium);
      expect(RiskTier.fromWire(' high '), RiskTier.high);
    });

    test('accepts the server spellings it may use', () {
      expect(RiskTier.fromWire('medium_risk'), RiskTier.high);
      expect(RiskTier.fromWire('unlock'), RiskTier.high);
    });

    test('an unknown tier is treated as HIGH, never as low', () {
      // Fail closed: a tier the client cannot classify must demand confirmation, not skip it.
      expect(RiskTier.fromWire('whatever'), RiskTier.high);
      expect(RiskTier.fromWire(null), RiskTier.high);
    });
  });

  group('properties', () {
    test('low needs no confirmation; medium and high do', () {
      expect(RiskTier.low.requiresConfirmation, isFalse);
      expect(RiskTier.medium.requiresConfirmation, isTrue);
      expect(RiskTier.high.requiresConfirmation, isTrue);
    });

    test('only high is destructive', () {
      expect(RiskTier.high.isDestructive, isTrue);
      expect(RiskTier.medium.isDestructive, isFalse);
      expect(RiskTier.low.isDestructive, isFalse);
    });

    test('the wire value round-trips', () {
      for (final RiskTier tier in RiskTier.values) {
        expect(RiskTier.fromWire(tier.wire), tier);
      }
    });
  });
}
