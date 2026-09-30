// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import 'armx_colors.dart';

/// Glows, gradients and shadow recipes used by the signature widgets.
///
/// Kept out of [ArmxColors] because these are *effects*, not tokens: they compose colours
/// with blur radii and opacities and are therefore platform-agnostic helpers.
abstract final class ArmxEffects {
  /// Cyan glow used by the assistant orb and primary CTAs.
  static List<BoxShadow> cyanGlow(Color cyan, {double strength = 1, double radius = 24}) =>
      <BoxShadow>[
        BoxShadow(
          color: cyan.withValues(alpha: 0.35 * strength),
          blurRadius: radius,
          spreadRadius: radius * 0.08,
        ),
        BoxShadow(
          color: cyan.withValues(alpha: 0.16 * strength),
          blurRadius: radius * 2.2,
          spreadRadius: radius * 0.2,
        ),
      ];

  /// Colour-matched glow for risk tiers and status pills.
  static List<BoxShadow> tintGlow(Color color, {double strength = 0.8, double radius = 16}) =>
      <BoxShadow>[
        BoxShadow(
          color: color.withValues(alpha: 0.28 * strength),
          blurRadius: radius,
          spreadRadius: radius * 0.05,
        ),
      ];

  /// Soft elevation shadow that reads well on both dark and light backgrounds.
  static List<BoxShadow> panelShadow(BuildContext context) {
    final colors = ArmxColors.of(context);
    return <BoxShadow>[
      BoxShadow(
        color: (colors.isDark ? Colors.black : colors.border).withValues(
          alpha: colors.isDark ? 0.45 : 0.18,
        ),
        blurRadius: colors.isDark ? 28 : 18,
        offset: const Offset(0, 10),
      ),
    ];
  }

  /// Signature cyan→violet gradient used by the splash, orb ring and progress bars.
  static LinearGradient brandGradient(Color cyan, Color violet) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[cyan, violet],
      );

  /// Radial gradient used as the orb's inner light.
  static RadialGradient orbCore(Color color) => RadialGradient(
        colors: <Color>[
          color.withValues(alpha: 0.95),
          color.withValues(alpha: 0.45),
          color.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.0, 0.55, 1.0],
      );

  /// The faint grid/vignette painted behind the dashboard.
  static BoxDecoration ambientBackground(ArmxColors colors) => BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.6),
          radius: 1.1,
          colors: <Color>[
            colors.violet.withValues(alpha: colors.isDark ? 0.16 : 0.08),
            colors.background,
          ],
        ),
      );
}
