// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/armx_colors.dart';
import '../theme/armx_effects.dart';
import '../theme/motion.dart';

/// Assistant states rendered by [ArmxOrb].
enum ArmxOrbState {
  /// Waiting for input.
  idle,

  /// Capturing speech (push-to-talk or wake word).
  listening,

  /// Streaming/thinking about a reply.
  thinking,

  /// Speaking a reply through TTS.
  speaking,

  /// Kill-switch engaged or app locked: no assistant activity allowed.
  locked,
}

/// The glowing assistant orb — the signature widget of A.R.M.X AI.
///
/// * colour and pulse encode the assistant state;
/// * the animation is skipped entirely when the platform asks for reduced motion (the state
///   colour and icon still convey the information);
/// * the semantic label is localized and includes the state name.
class ArmxOrb extends StatefulWidget {
  /// Creates an orb.
  const ArmxOrb({
    required this.state,
    this.size = 168,
    this.onTap,
    this.showLabel = true,
    super.key,
  });

  /// Current assistant state.
  final ArmxOrbState state;

  /// Diameter of the orb core in logical pixels.
  final double size;

  /// Optional tap handler (for example: tap to talk).
  final VoidCallback? onTap;

  /// Whether the state label is rendered under the orb.
  final bool showLabel;

  @override
  State<ArmxOrb> createState() => _ArmxOrbState();
}

class _ArmxOrbState extends State<ArmxOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ArmxMotion.breath,
  );

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant ArmxOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _syncAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncAnimation() {
    _controller
      ..stop()
      ..duration = switch (widget.state) {
        ArmxOrbState.listening => ArmxMotion.pulse,
        ArmxOrbState.thinking => const Duration(milliseconds: 1200),
        ArmxOrbState.speaking => const Duration(milliseconds: 700),
        ArmxOrbState.idle => ArmxMotion.breath,
        ArmxOrbState.locked => ArmxMotion.breath,
      };
    _controller.repeat(reverse: true);
  }

  Color _tone(ArmxColors colors) => switch (widget.state) {
        ArmxOrbState.idle => colors.cyan,
        ArmxOrbState.listening => colors.cyan,
        ArmxOrbState.thinking => colors.violet,
        ArmxOrbState.speaking => colors.green,
        ArmxOrbState.locked => colors.red,
      };

  IconData _icon() => switch (widget.state) {
        ArmxOrbState.idle => Icons.auto_awesome_outlined,
        ArmxOrbState.listening => Icons.mic_none_rounded,
        ArmxOrbState.thinking => Icons.blur_on_rounded,
        ArmxOrbState.speaking => Icons.graphic_eq_rounded,
        ArmxOrbState.locked => Icons.lock_outline_rounded,
      };

  String _label(BuildContext context) => switch (widget.state) {
        ArmxOrbState.idle => context.l10n.orbStateIdle,
        ArmxOrbState.listening => context.l10n.orbStateListening,
        ArmxOrbState.thinking => context.l10n.orbStateThinking,
        ArmxOrbState.speaking => context.l10n.orbStateSpeaking,
        ArmxOrbState.locked => context.l10n.orbStateLocked,
      };

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    final tone = _tone(colors);
    final reduceMotion = ArmxMotion.reduceMotion(context);
    final label = _label(context);

    final orb = RepaintBoundary(
      child: SizedBox(
        width: widget.size * 1.4,
        height: widget.size * 1.4,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = reduceMotion ? 0.5 : _controller.value;
            final scale = widget.state == ArmxOrbState.listening
                ? 1 + 0.06 * math.sin(t * math.pi)
                : 1 + 0.03 * math.sin(t * math.pi);
            final glowStrength = 0.6 + 0.4 * t;
            return Transform.scale(
              scale: scale,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: ArmxEffects.orbCore(tone),
                  boxShadow: ArmxEffects.cyanGlow(
                    tone,
                    strength: glowStrength,
                    radius: widget.size * 0.16,
                  ),
                ),
                child: child,
              ),
            );
          },
          child: Center(
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.panel.withValues(alpha: 0.72),
                border: Border.all(color: tone.withValues(alpha: 0.7), width: 1.5),
              ),
              child: Center(
                child: Icon(_icon(), size: widget.size * 0.3, color: tone),
              ),
            ),
          ),
        ),
      ),
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.onTap != null)
          Semantics(
            button: true,
            label: context.l10n.orbSemantics(label),
            child: InkWell(
              onTap: widget.onTap,
              customBorder: const CircleBorder(),
              child: orb,
            ),
          )
        else
          Semantics(label: context.l10n.orbSemantics(label), child: orb),
        if (widget.showLabel)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: tone),
            ),
          ),
      ],
    );

    return content;
  }
}
