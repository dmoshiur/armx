// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

/// The `A.R.M.X` wordmark.
///
/// The `AI` suffix is drawn in the accent colour while the letters stay in the theme's
/// text colour, so the mark works on both the dark and light surfaces without a second
/// asset. It is exposed to assistive technology as a single label rather than as three
/// letters.
class ArmxWordmark extends StatelessWidget {
  /// Creates the wordmark.
  const ArmxWordmark({this.size = 32, this.showSuffix = true, super.key});

  /// Cap height of the mark in logical pixels.
  final double size;

  /// Whether to draw the `AI` suffix.
  final bool showSuffix;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    return Semantics(
      label: 'A.R.M.X AI',
      header: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Text(
            'A.R.M.X',
            style: ArmxTypography.wordmark(size: size, color: colors.text),
          ),
          if (showSuffix) ...<Widget>[
            const SizedBox(width: 6),
            Text(
              'AI',
              style: ArmxTypography.wordmark(size: size, color: colors.accentText),
            ),
          ],
        ],
      ),
    );
  }
}

/// The assistant orb: a soft radial mark used by the splash, the voice overlay and the
/// listening indicator.
///
/// [active] drives a slow pulse which is suppressed when the platform requests reduced
/// motion, and the whole widget is decorative — callers must supply the state as text
/// (see `ArmxStatusDot`), so the orb is never the only indicator.
class ArmxOrb extends StatefulWidget {
  /// Creates an orb.
  const ArmxOrb({
    this.size = 96,
    this.active = false,
    this.icon = Icons.graphic_eq_rounded,
    super.key,
  });

  /// Diameter in logical pixels.
  final double size;

  /// Whether to animate and brighten.
  final bool active;

  /// Glyph in the centre.
  final IconData icon;

  @override
  State<ArmxOrb> createState() => _ArmxOrbState();
}

class _ArmxOrbState extends State<ArmxOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant ArmxOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.active && !MediaQuery.disableAnimationsOf(context)) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final Color core = widget.active ? colors.accent : colors.textMuted;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double t = _controller.value;
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  core.withValues(alpha: 0.30 + (t * 0.22)),
                  core.withValues(alpha: 0.10),
                  colors.surface,
                ],
                stops: const <double>[0, 0.62, 1],
              ),
              border: Border.all(color: core.withValues(alpha: 0.42)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: core.withValues(alpha: 0.18 + (t * 0.16)),
                  blurRadius: 24 + (t * 18),
                  spreadRadius: 2 + (t * 4),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                widget.icon,
                size: widget.size * 0.36,
                color: core,
              ),
            ),
          );
        },
      ),
    );
  }
}
