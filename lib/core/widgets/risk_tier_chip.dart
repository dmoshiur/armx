// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../security/risk_tier.dart';
import '../theme/armx_colors.dart';
import '../theme/armx_theme.dart';

/// The mandatory risk badge: LOW = green, MEDIUM = amber, HIGH = red.
///
/// Product rule: the chip never relies on colour alone — it always prints the tier name
/// and, for MEDIUM/HIGH, the verification the user will be asked for.
class RiskTierChip extends StatelessWidget {
  /// Creates a risk chip.
  const RiskTierChip({
    required this.tier,
    this.showRequirements = false,
    this.compact = false,
    super.key,
  });

  /// Tier to display.
  final RiskTier tier;

  /// Also prints the required verification factors (used on tool cards).
  final bool showRequirements;

  /// Compact variant for list rows.
  final bool compact;

  /// Maps a tier onto the palette and its localized label.
  static (SeverityTone, String) describe(BuildContext context, RiskTier tier) {
    final l10n = context.l10n;
    return switch (tier) {
      RiskTier.low => (SeverityTone.success, l10n.riskLow),
      RiskTier.medium => (SeverityTone.warning, l10n.riskMedium),
      RiskTier.high => (SeverityTone.danger, l10n.riskHigh),
    };
  }

  /// Short text describing which factors the tier requires.
  static String requirementsFor(BuildContext context, RiskTier tier) => switch (tier) {
        RiskTier.low => '${context.l10n.verificationFace} / ${context.l10n.verificationVoice}',
        RiskTier.medium =>
          '${context.l10n.verificationFace} + ${context.l10n.verificationVoice}',
        RiskTier.high =>
          '${context.l10n.verificationFace} + ${context.l10n.verificationVoice} + ${context.l10n.verificationBiometric}',
      };

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    final (tone, label) = describe(context, tier);
    final color = colors.severity(tone);
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = (compact ? textTheme.labelSmall : textTheme.labelMedium)
        ?.copyWith(color: color, fontWeight: FontWeight.w700, letterSpacing: 0.6);

    return Semantics(
      label: context.l10n.riskTierSemantics(label),
      container: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: colors.isDark ? 0.16 : 0.12),
          borderRadius: BorderRadius.circular(ArmxTheme.pillRadius),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              switch (tier) {
                RiskTier.low => Icons.shield_outlined,
                RiskTier.medium => Icons.shield_moon_outlined,
                RiskTier.high => Icons.gpp_maybe_outlined,
              },
              size: compact ? 12 : 14,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(label, style: labelStyle),
            if (showRequirements) ...<Widget>[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  requirementsFor(context, tier),
                  style: textTheme.labelSmall?.copyWith(color: colors.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
