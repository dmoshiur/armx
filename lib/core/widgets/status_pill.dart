// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../theme/armx_colors.dart';
import '../theme/armx_theme.dart';

/// Small rounded status indicator ("Connected", "Offline", "KILL-SWITCH", …).
///
/// Always renders an icon or a leading dot in addition to colour, so the information is
/// available to colour-blind users and to screen readers.
class StatusPill extends StatelessWidget {
  /// Creates a status pill.
  const StatusPill({
    required this.label,
    this.tone = SeverityTone.neutral,
    this.icon,
    this.showDot = true,
    this.compact = false,
    this.semanticLabel,
    super.key,
  });

  /// Visible text.
  final String label;

  /// Semantic tone driving the colour.
  final SeverityTone tone;

  /// Optional leading icon (takes precedence over [showDot]).
  final IconData? icon;

  /// Whether to draw a leading dot when no [icon] is given.
  final bool showDot;

  /// Compact variant used inside dense list rows.
  final bool compact;

  /// Overrides the announced text (for example to include a value).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    final color = colors.severity(tone);
    final textStyle = (compact
            ? Theme.of(context).textTheme.labelSmall
            : Theme.of(context).textTheme.labelMedium)
        ?.copyWith(color: color, fontWeight: FontWeight.w600);

    return Semantics(
      label: semanticLabel ?? label,
      container: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: colors.isDark ? 0.14 : 0.12),
          borderRadius: BorderRadius.circular(ArmxTheme.pillRadius),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: compact ? 12 : 14, color: color),
              const SizedBox(width: 5),
            ] else if (showDot) ...<Widget>[
              Container(
                width: compact ? 6 : 7,
                height: compact ? 6 : 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(label, style: textStyle),
          ],
        ),
      ),
    );
  }
}
