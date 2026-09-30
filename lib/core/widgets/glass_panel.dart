// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../theme/armx_colors.dart';
import '../theme/armx_effects.dart';
import '../theme/armx_theme.dart';

/// The signature frosted panel used by every card in A.R.M.X.
///
/// Renders a translucent fill, a hairline border and (optionally) a colour-matched glow so
/// that risk and status information is legible at a glance on the dark background.
class GlassPanel extends StatelessWidget {
  /// Creates a glass panel around [child].
  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.accent,
    this.onTap,
    this.elevated = false,
    this.semanticLabel,
    super.key,
  });

  /// Panel content.
  final Widget child;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// Outer margin.
  final EdgeInsetsGeometry? margin;

  /// Optional accent colour that tints the border and adds a glow.
  final Color? accent;

  /// Makes the whole panel tappable (adds an ink ripple and a semantics button role).
  final VoidCallback? onTap;

  /// Draws a stronger shadow; use for the "hero" panel on a screen.
  final bool elevated;

  /// Accessibility label announced when [onTap] is set.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    final borderColor = accent?.withValues(alpha: 0.55) ?? colors.glassBorder;
    final shadows = <BoxShadow>[
      if (elevated) ...ArmxEffects.panelShadow(context),
      if (accent != null) ...ArmxEffects.tintGlow(accent!, strength: 0.5, radius: 20),
    ];

    final content = AnimatedContainer(
      duration: ArmxMotionDurations.quick,
      curve: Curves.easeOut,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.panel.withValues(alpha: colors.isDark ? 0.82 : 0.92),
        borderRadius: BorderRadius.circular(ArmxTheme.panelRadius),
        border: Border.all(color: borderColor),
        boxShadow: shadows.isEmpty ? null : shadows,
      ),
      child: child,
    );

    if (onTap == null) {
      return content;
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ArmxTheme.panelRadius),
          splashColor: (accent ?? colors.cyan).withValues(alpha: 0.12),
          highlightColor: (accent ?? colors.cyan).withValues(alpha: 0.06),
          child: content,
        ),
      ),
    );
  }
}

/// Motion durations re-exported so widgets do not import the motion module twice.
abstract final class ArmxMotionDurations {
  /// 120 ms — colour/opacity tweaks.
  static const Duration quick = Duration(milliseconds: 120);
}
