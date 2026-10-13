// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/armx_confirm_dialog.dart';
import '../../../../data/models/admin.dart';

/// The global stop.
///
/// ## Deliberate properties
///
/// * **No biometric.** This is the emergency brake; requiring a fingerprint to stop the
///   assistant would be the wrong trade. Press-and-hold is the only friction.
/// * **One-second long press.** A tap does nothing, so it cannot be triggered by a pocket
///   press. A progress ring fills while the press is held.
/// * **Engaging needs no confirmation** — stopping things fast is the point. **Releasing**
///   does: re-arming the assistant is the action that needs a deliberate decision, and it
///   goes through [ArmxConfirmDialog] with the exact state change and target.
/// * **The UI follows the backend.** The local flag is only ever optimistic while the call
///   is in flight; if the server refuses, the button returns to its previous state and the
///   failure is shown.
class KillSwitchButton extends ConsumerStatefulWidget {
  /// Creates the button.
  const KillSwitchButton({this.compact = false, this.onChanged, super.key});

  /// Renders the compact variant for the sidebar footer.
  final bool compact;

  /// Called after the backend has confirmed the new state, so a host screen can re-read
  /// whatever the switch affects (device availability, the assistant's tool list). Never
  /// called for an attempt that failed.
  final VoidCallback? onChanged;

  /// How long the press must be held.
  static const Duration holdDuration = Duration(seconds: 1);

  @override
  ConsumerState<KillSwitchButton> createState() => _KillSwitchButtonState();
}

class _KillSwitchButtonState extends ConsumerState<KillSwitchButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _holdController = AnimationController(
    vsync: this,
    duration: KillSwitchButton.holdDuration,
  );
  Timer? _holdTimer;
  bool _busy = false;

  /// Optimistic display while a call is in flight; cleared once the server answers.
  bool? _optimistic;

  @override
  void dispose() {
    _holdTimer?.cancel();
    _holdController.dispose();
    super.dispose();
  }

  void _startHold() {
    _holdController.forward(from: 0);
    _holdTimer?.cancel();
    _holdTimer = Timer(KillSwitchButton.holdDuration, _engage);
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdController.reverse();
  }

  Future<void> _engage() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _optimistic = true;
    });
    try {
      final KillSwitchState next = await ref
          .read(armxApiProvider)
          .setKillSwitch(engaged: true, reason: 'Pressed from the shell');
      // Close the socket: with the assistant stopped there is nothing to stream, and an
      // open socket would keep the device reachable.
      await ref.read(webSocketProvider).suspend(reason: 'Kill-switch engaged.');
      widget.onChanged?.call();
      _showSnack(context, context.l10n.shellKillSwitchEngaged, next);
    } on Object {
      _showSnack(context, context.l10n.errorGenericBody, null);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _optimistic = null;
        });
      }
    }
  }

  Future<void> _release() async {
    // Releasing is the risky direction, so it is confirmed with the exact change.
    final bool confirmed = await ArmxConfirmDialog.show(
      context,
      ConfirmRequest(
        title: context.l10n.shellKillSwitch,
        action: 'set_kill_switch',
        target: context.l10n.commonAll,
        riskTier: ArmxRiskTier.high,
        consequence: context.l10n.shellKillSwitchReleased,
        confirmLabel: context.l10n.shellKillSwitchReleased,
        parameters: const <ConfirmParameter>[
          ConfirmParameter(label: 'engaged', value: 'false'),
        ],
      ),
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _optimistic = false;
    });
    try {
      await ref
          .read(armxApiProvider)
          .setKillSwitch(engaged: false, reason: 'Released from the shell');
      unawaited(ref.read(webSocketProvider).connect());
      widget.onChanged?.call();
      _showSnack(context, context.l10n.shellKillSwitchReleased, null);
    } on Object {
      _showSnack(context, context.l10n.errorGenericBody, null);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _optimistic = null;
        });
      }
    }
  }

  void _showSnack(BuildContext context, String message, KillSwitchState? state) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    // The backend is the truth; anything else is a request in flight.
    final bool engaged = _optimistic ?? false;

    final Widget body = Stack(
      alignment: Alignment.center,
      children: <Widget>[
        AnimatedBuilder(
          animation: _holdController,
          builder: (BuildContext context, Widget? child) => SizedBox(
            height: 4,
            child: LinearProgressIndicator(
              value: _holdController.value,
              minHeight: 4,
              backgroundColor: Colors.transparent,
              color: colors.onDangerFill,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                engaged ? Icons.lock_rounded : Icons.power_settings_new_rounded,
                size: 16,
                color: colors.onDangerFill,
              ),
              const SizedBox(width: Insets.sm),
              Flexible(
                child: Text(
                  engaged
                      ? context.l10n.shellKillSwitchEngaged
                      : context.l10n.shellKillSwitch,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.onDangerFill,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Tooltip(
      message: engaged
          ? context.l10n.shellKillSwitchReleased
          : context.l10n.shellKillSwitchHold,
      child: Semantics(
        button: true,
        enabled: !_busy,
        label: engaged
            ? context.l10n.shellKillSwitchEngaged
            : context.l10n.shellKillSwitch,
        hint: context.l10n.shellKillSwitchHold,
        excludeSemantics: true,
        child: GestureDetector(
          // Long-press to engage: a tap can never fire it, so it cannot be triggered by
          // an accidental touch.
          onTapDown: (_) => engaged ? null : _startHold(),
          onTapUp: (_) => _cancelHold(),
          onTapCancel: _cancelHold,
          onLongPress: engaged ? _release : _engage,
          child: Container(
            constraints: const BoxConstraints(minHeight: Insets.minTouchTarget),
            decoration: BoxDecoration(
              color: engaged ? colors.danger : colors.dangerFill,
              borderRadius: BorderRadius.circular(Insets.controlRadius),
              border: Border.all(
                color: colors.danger.withValues(alpha: engaged ? 1 : 0.6),
                width: engaged ? 2 : 1,
              ),
            ),
            child: _busy
                ? Padding(
                    padding: const EdgeInsets.all(Insets.md),
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onDangerFill,
                        ),
                      ),
                    ),
                  )
                : body,
          ),
        ),
      ),
    );
  }
}
