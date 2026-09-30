// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../theme/armx_colors.dart';
import '../theme/armx_effects.dart';
import 'armx_button.dart';

/// Glowing primary CTA used for the single most important action on a screen.
class ArmxGlowButton extends StatelessWidget {
  /// Creates a glow button.
  const ArmxGlowButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    super.key,
  });

  /// Button label.
  final String label;

  /// Tap handler.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// Loading state.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: ArmxEffects.cyanGlow(colors.cyan, strength: 0.7, radius: 18),
      ),
      child: ArmxButton(
        label: label,
        onPressed: onPressed,
        icon: icon,
        loading: loading,
        expanded: true,
      ),
    );
  }
}
