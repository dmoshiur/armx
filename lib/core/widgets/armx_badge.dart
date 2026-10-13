// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'armx_status_dot.dart';

/// Small tag styles.
enum ArmxBadgeTone {
  /// Neutral grey. Unclassified metadata.
  neutral,

  /// `accent`. Brand-positive metadata.
  accent,

  /// `accent2`. Secondary highlight — never placed next to [accent] on one element.
  secondary,

  /// `success`. Approved / connected / allowed.
  success,

  /// `warning`. MEDIUM risk, needs attention.
  warning,

  /// `danger`. HIGH risk, denied, destructive.
  danger,
}

/// Role tags (`Admin` / `VIP` / `User`) and risk tiers (`LOW` / `MEDIUM` / `HIGH`).
///
/// Always text-bearing: a badge is never a bare coloured square. The MEDIUM and HIGH tones
/// additionally include a small glyph so the distinction survives greyscale printing and
/// colour-vision deficiency.
class ArmxBadge extends StatelessWidget {
  /// Creates a badge.
  const ArmxBadge({
    required this.label,
    this.tone = ArmxBadgeTone.neutral,
    this.icon,
    this.tooltip,
    super.key,
  });

  /// Badge text.
  final String label;

  /// Colour intent.
  final ArmxBadgeTone tone;

  /// Optional leading glyph. Defaults to a warning triangle for [ArmxBadgeTone.warning]
  /// and a shield for [ArmxBadgeTone.danger], so those two never rely on hue alone.
  final IconData? icon;

  /// Explanation shown on hover/long-press.
  final String? tooltip;

  /// Resolves the foreground colour for a tone.
  static Color foregroundFor(ArmxBadgeTone tone, ArmxColors colors) => switch (tone) {
        ArmxBadgeTone.neutral => colors.textMuted,
        ArmxBadgeTone.accent => colors.accentText,
        ArmxBadgeTone.secondary => colors.accent2Text,
        ArmxBadgeTone.success => colors.successText,
        ArmxBadgeTone.warning => colors.warningText,
        ArmxBadgeTone.danger => colors.dangerText,
      };

  /// Maps a role id onto a tone. Admin is the only elevated role that gets `danger`-adjacent
  /// emphasis, because it carries kill-switch authority.
  static ArmxBadgeTone toneForRole(String role) => switch (role.toLowerCase()) {
        'admin' => ArmxBadgeTone.secondary,
        'vip' => ArmxBadgeTone.accent,
        _ => ArmxBadgeTone.neutral,
      };

  /// Maps a risk tier onto a tone.
  static ArmxBadgeTone toneForRisk(String tier) => switch (tier.toLowerCase()) {
        'high' => ArmxBadgeTone.danger,
        'medium' => ArmxBadgeTone.warning,
        'low' => ArmxBadgeTone.success,
        _ => ArmxBadgeTone.neutral,
      };

  IconData? get _effectiveIcon =>
      icon ??
      switch (tone) {
        ArmxBadgeTone.warning => Icons.warning_amber_rounded,
        ArmxBadgeTone.danger => Icons.gpp_maybe_outlined,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final Color foreground = foregroundFor(tone, colors);
    final IconData? glyph = _effectiveIcon;

    final Widget badge = Semantics(
      label: label,
      readOnly: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.sm,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: foreground.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(Insets.chipRadius),
          border: Border.all(color: foreground.withValues(alpha: 0.42)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (glyph != null) ...<Widget>[
              Icon(glyph, size: 12, color: foreground),
              const SizedBox(width: Insets.xs),
            ],
            Text(
              label,
              style: ArmxTypography.inter(
                size: 11,
                weight: 700,
                height: 1.3,
                letterSpacing: 0.4,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );

    if (tooltip == null) {
      return badge;
    }
    return Tooltip(message: tooltip!, child: badge);
  }
}

/// A selectable chip for filter strips and multi-select groups.
///
/// Selection is communicated three ways — border weight, fill and a check glyph — plus a
/// semantic `selected` flag, so it is legible without colour.
class ArmxChip extends StatelessWidget {
  /// Creates a chip.
  const ArmxChip({
    required this.label,
    this.selected = false,
    this.onSelected,
    this.icon,
    this.count,
    this.semanticLabel,
    super.key,
  });

  /// Chip text.
  final String label;

  /// Whether the chip is currently active.
  final bool selected;

  /// Toggle callback. `null` renders a static, non-interactive chip.
  final ValueChanged<bool>? onSelected;

  /// Optional leading glyph.
  final IconData? icon;

  /// Optional count rendered after the label (e.g. `Alarms 4`).
  final int? count;

  /// Accessible name; defaults to [label].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final bool interactive = onSelected != null;
    final Color foreground = selected ? colors.accentText : colors.textMuted;

    final Widget body = Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm,
      ),
      decoration: BoxDecoration(
        color: selected
            ? colors.accent.withValues(alpha: colors.isDark ? 0.20 : 0.14)
            : colors.surfaceAlt,
        borderRadius: BorderRadius.circular(Insets.chipRadius),
        border: Border.all(
          color: selected ? colors.accent : colors.hairline,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (selected) ...<Widget>[
            Icon(Icons.check_rounded, size: 14, color: foreground),
            const SizedBox(width: Insets.xs),
          ] else if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: Insets.xs),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: foreground),
          ),
          if (count != null) ...<Widget>[
            const SizedBox(width: Insets.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: colors.border.withValues(alpha: colors.isDark ? 0.14 : 1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: ArmxTypography.inter(
                  size: 11,
                  weight: 700,
                  color: colors.textMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (!interactive) {
      return body;
    }

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Insets.chipRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onSelected!(!selected),
          borderRadius: BorderRadius.circular(Insets.chipRadius),
          hoverColor: colors.accent.withValues(alpha: 0.08),
          focusColor: colors.accent.withValues(alpha: 0.16),
          child: body,
        ),
      ),
    );
  }
}

/// A status dot plus label rendered as a compact pill, for table cells and card headers.
class ArmxStatusPill extends StatelessWidget {
  /// Creates a pill.
  const ArmxStatusPill({
    required this.status,
    required this.label,
    this.compact = true,
    this.pulse = false,
    super.key,
  });

  /// The state.
  final ArmxStatus status;

  /// Localized state text.
  final String label;

  /// Dense rendering for table cells.
  final bool compact;

  /// Breathes the dot for something happening right now (a live camera, a running deploy).
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final Color color = ArmxStatusDot.colorFor(status, colors);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? Insets.sm : Insets.md,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: ArmxStatusDot(
        status: status,
        label: label,
        compact: compact,
        pulse: pulse,
      ),
    );
  }
}
