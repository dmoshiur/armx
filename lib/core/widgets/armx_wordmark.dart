// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../theme/armx_colors.dart';
import '../theme/armx_typography.dart';

/// The `A.R.M.X AI` wordmark: dark wordmark with the cyan "AI", per brand guidelines.
class ArmxWordmark extends StatelessWidget {
  /// Creates a wordmark.
  const ArmxWordmark({
    this.fontSize = 34,
    this.showAi = true,
    this.color,
    this.semanticsLabel = 'A.R.M.X AI',
    super.key,
  });

  /// Wordmark font size in logical pixels.
  final double fontSize;

  /// Whether the trailing "AI" is rendered (set to false for tight app bars).
  final bool showAi;

  /// Overrides the base colour; defaults to the theme's primary text colour.
  final Color? color;

  /// Accessibility label; the wordmark is decorative next to the app title.
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    final base = ArmxTypography.wordmark(size: fontSize, color: color ?? colors.text);
    return Semantics(
      label: semanticsLabel,
      header: true,
      child: RichText(
        text: TextSpan(
          style: base,
          children: <InlineSpan>[
            const TextSpan(text: 'A.R.M.X'),
            if (showAi)
              TextSpan(
                text: ' AI',
                style: base.copyWith(color: colors.cyan),
              ),
          ],
        ),
      ),
    );
  }
}
