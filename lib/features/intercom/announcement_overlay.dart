// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/armx_colors.dart';
import '../../core/widgets/armx_controls.dart';
import '../../core/widgets/armx_orb.dart';
import '../../core/widgets/glass_panel.dart';
import '../../core/widgets/status_pill.dart';
import 'intercom_controller.dart';
import 'intercom_state.dart';

/// The incoming-announcement overlay (rule 2: always audible *and* visible).
///
/// Shown for every announcement a consented device receives: chime first, then the
/// speaker's name, a live waveform, and two one-tap actions — mute this announcement, or
/// turn announcements off entirely. The overlay appears even when the OS is silencing
/// alerts; only the sound is skipped, never the notice.
class AnnouncementOverlay extends ConsumerStatefulWidget {
  /// Creates the overlay. [speaker] is who is talking.
  const AnnouncementOverlay({required this.speaker, super.key});

  /// Who is speaking.
  final String speaker;

  @override
  ConsumerState<AnnouncementOverlay> createState() => _AnnouncementOverlayState();
}

class _AnnouncementOverlayState extends ConsumerState<AnnouncementOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);
    final state = ref.watch(intercomControllerProvider);
    final controller = ref.read(intercomControllerProvider.notifier);
    final speaking = state.overlay == OverlayPhase.speaking;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Positioned.fill(
      child: GestureDetector(
        onTap: () {}, // Absorb taps so the overlay cannot be dismissed by a stray click.
        child: ColoredBox(
          color: colors.background.withValues(alpha: 0.92),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const ArmxOrb(state: ArmxOrbState.listening, size: 132, showLabel: false),
                  const SizedBox(height: 20),
                  Text(
                    l10n.intercomSpeakingFrom(widget.speaker),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.intercomOverlayBody,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.muted),
                  ),
                  const SizedBox(height: 20),
                  _Waveform(
                    level: state.level,
                    animate: speaking && !reduceMotion,
                    shimmer: _shimmer,
                  ),
                  const SizedBox(height: 24),
                  StatusPill(
                    label: speaking ? l10n.orbStateListening : l10n.intercomOverlayRinging,
                    tone: speaking ? SeverityTone.success : SeverityTone.info,
                    icon: Icons.graphic_eq_rounded,
                  ),
                  const SizedBox(height: 24),
                  GlassPanel(
                    accent: colors.cyan,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: <Widget>[
                        ArmxButton(
                          label: l10n.intercomMuteOnce,
                          icon: Icons.volume_off_rounded,
                          variant: ArmxButtonVariant.outlined,
                          expanded: true,
                          onPressed: controller.muteOnce,
                        ),
                        const SizedBox(height: 8),
                        ArmxButton(
                          label: l10n.intercomTurnOff,
                          icon: Icons.notifications_off_rounded,
                          variant: ArmxButtonVariant.danger,
                          expanded: true,
                          onPressed: controller.turnOffFromOverlay,
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: controller.dismissOverlay,
                          child: Text(l10n.commonClose),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Live waveform driven by the recorder's amplitude (or a shimmer when idle).
class _Waveform extends StatelessWidget {
  const _Waveform({required this.level, required this.animate, required this.shimmer});

  /// Current level 0.0–1.0.
  final double level;

  /// Whether the bars should animate.
  final bool animate;

  /// Shared animation used for the idle shimmer.
  final Animation<double> shimmer;

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    return SizedBox(
      height: 56,
      child: AnimatedBuilder(
        animation: shimmer,
        builder: (BuildContext context, Widget? child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              for (var index = 0; index < 21; index++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _Bar(
                    height: _barHeight(index, animate ? level : shimmer.value * 0.25),
                    color: colors.cyan,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static double _barHeight(int index, double level) {
    final shape = math.sin(index / 21 * math.pi);
    final jitter = 0.55 + 0.45 * math.sin(index * 1.7);
    return (6 + 46 * shape * jitter * (0.25 + level)).clamp(4.0, 50.0);
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Convenience wrapper used by the app shell to host the overlay.
class AnnouncementOverlayHost extends ConsumerWidget {
  /// Creates the host.
  const AnnouncementOverlayHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(intercomControllerProvider);
    if (!state.enabled || !state.consent.enabled) {
      return const SizedBox.shrink();
    }
    if (state.overlay == OverlayPhase.hidden || state.overlay == OverlayPhase.done) {
      return const SizedBox.shrink();
    }
    return AnnouncementOverlay(speaker: 'Admin');
  }
}
