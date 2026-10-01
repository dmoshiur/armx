// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/armx_colors.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/armx_tile.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/status_pill.dart';

/// The wake-word card: the switch, the phrase, the honesty notice and the demo trigger.
///
/// The demo trigger is rendered **only** when the attached detector is the no-audio stub,
/// because the stub is the only engine that accepts a simulated detection. A real detector
/// can never be triggered from the UI.
class WakeWordCard extends StatelessWidget {
  /// Creates the card.
  const WakeWordCard({
    required this.enabled,
    required this.supported,
    required this.isStub,
    required this.phrase,
    required this.serviceState,
    required this.busy,
    required this.onChanged,
    required this.onSimulate,
    super.key,
  });

  /// Whether the mode is currently armed.
  final bool enabled;

  /// Whether the platform can run background listening at all.
  final bool supported;

  /// Whether the native detector is the no-audio stub.
  final bool isStub;

  /// The configured phrase (default `Armex`).
  final String phrase;

  /// Phase reported by the platform's visible listener (`running`, `paused`, `stopped`, …).
  final String serviceState;

  /// Whether a start/stop request is in flight.
  final bool busy;

  /// Enables/disables the mode.
  final ValueChanged<bool> onChanged;

  /// Fires a simulated detection (stub only).
  final VoidCallback onSimulate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);
    final canEnable = supported && !busy;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ArmxTile(
            title: l10n.voiceWakeWordTitle,
            subtitle: supported
                ? l10n.voiceWakeWordSubtitle(phrase)
                : l10n.voiceWakeWordUnsupported,
            leading: Icon(
              enabled ? Icons.hearing_rounded : Icons.hearing_disabled_rounded,
              color: enabled ? colors.cyan : colors.muted,
            ),
            trailing: Switch(
              value: enabled,
              onChanged: canEnable ? onChanged : null,
            ),
          ),
          const SizedBox(height: 6),
          if (enabled) ...<Widget>[
            StatusPill(
              label: l10n.voiceBackgroundServiceState(serviceState),
              tone: serviceState == 'running'
                  ? SeverityTone.success
                  : SeverityTone.neutral,
              compact: true,
              showDot: true,
            ),
            const SizedBox(height: 10),
          ],
          // Rule 7 (visible background): the mode always runs behind the platform's
          // persistent notification, and the stub notice says plainly that no audio is
          // captured in this build.
          Text(
            isStub ? l10n.voiceWakeWordStubNotice : l10n.voiceWakeWordRealNotice,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.muted),
          ),
          if (enabled && isStub) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: ArmxButton(
                    label: l10n.voiceSimulateWakeWord,
                    icon: Icons.play_arrow_rounded,
                    variant: ArmxButtonVariant.outlined,
                    onPressed: onSimulate,
                    expanded: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.voiceSimulateWakeWordNote,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small info panel that states the fail-closed verification rule on the voice screen.
class VoiceVerificationNotice extends StatelessWidget {
  /// Creates the notice.
  const VoiceVerificationNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);
    return GlassPanel(
      accent: colors.amber,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.gpp_maybe_outlined, size: 18, color: colors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.voiceVerifyHint,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
