// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// The connectivity/health vocabulary for [ArmxStatusDot].
///
/// The dot is decoration; the [label] is the message. A status is always written out beside
/// the dot, so colour is never the only signal — including for the states (`pending`,
/// `unknown`) that a user must not mistake for "fine".
enum ArmxStatus {
  /// Reachable and healthy, or a completed success.
  online,

  /// Reachable but degraded, or a request that has not settled.
  warning,

  /// Unreachable.
  offline,

  /// Failed outright.
  failed,

  /// Accepted, not yet done. **Never** rendered as success.
  pending,

  /// Switched off on purpose by the user or the kill-switch.
  stopped,

  /// The client genuinely does not know: no data yet, or no answer to compare against.
  unknown,
}

/// A small dot with a text label.
class ArmxStatusDot extends StatelessWidget {
  /// Creates a dot.
  const ArmxStatusDot({
    required this.status,
    required this.label,
    this.compact = false,
    this.pulse = false,
    super.key,
  });

  /// The state shown.
  final ArmxStatus status;

  /// The words shown next to the dot.
  final String label;

  /// When true the dot is smaller and the label uses `bodySmall`.
  final bool compact;

  /// When true the dot breathes, for something that is actively happening.
  final bool pulse;

  /// The colour this status paints.
  static Color colorFor(ArmxStatus status, ArmxColors colors) => switch (status) {
        ArmxStatus.online => colors.successText,
        ArmxStatus.warning => colors.warningText,
        ArmxStatus.offline => colors.textMuted,
        ArmxStatus.failed => colors.dangerText,
        ArmxStatus.pending => colors.accentText,
        ArmxStatus.stopped => colors.dangerText,
        ArmxStatus.unknown => colors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final Color tint = colorFor(status, colors);
    final double size = compact ? 8 : 10;

    return Semantics(
      label: label,
      // The label already carries the meaning, so the dot is not announced separately.
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (pulse)
            _PulsingDot(color: tint, size: size)
          else
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: tint),
            ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: compact
                  ? Theme.of(context).textTheme.bodySmall
                  : Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_controller),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
        ),
      ),
    );
  }
}
