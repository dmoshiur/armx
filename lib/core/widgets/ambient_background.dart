// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../theme/armx_colors.dart';
import '../theme/armx_effects.dart';

/// Paints the A.R.M.X ambient background (violet-to-background radial gradient) behind a page.
///
/// Cheap by design: one [DecoratedBox], no shaders, no animation, so it is safe to wrap
/// every route on low-end Android devices.
class ArmxBackground extends StatelessWidget {
  /// Creates the background wrapper.
  const ArmxBackground({required this.child, this.showGrid = false, super.key});

  /// Page content.
  final Widget child;

  /// Draws a faint technical grid on top of the gradient.
  final bool showGrid;

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    return DecoratedBox(
      decoration: ArmxEffects.ambientBackground(colors),
      child: showGrid
          ? CustomPaint(
              painter: _GridPainter(color: colors.border.withValues(alpha: 0.25)),
              child: child,
            )
          : child,
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.color, this.spacing = 48});

  final Color color;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.6;
    for (var x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.spacing != spacing;
}
