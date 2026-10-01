// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/armx_colors.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/status_pill.dart';
import '../voice_state.dart';

/// Press-and-hold microphone button.
///
/// Uses raw pointer events (not `onLongPress`) so the capture starts the instant the finger
/// lands and stops the instant it lifts — a long-press delay would clip the first word.
class PushToTalkButton extends StatelessWidget {
  /// Creates the button.
  const PushToTalkButton({
    required this.phase,
    required this.enabled,
    required this.onStart,
    required this.onStop,
    required this.label,
    required this.hint,
    super.key,
  });

  /// Current voice phase (drives the icon and colour).
  final VoicePhase phase;

  /// Whether the microphone gate allows a capture right now.
  final bool enabled;

  /// Called on pointer down.
  final VoidCallback onStart;

  /// Called on pointer up/cancel.
  final VoidCallback onStop;

  /// Localized button label.
  final String label;

  /// Localized hint shown under the button.
  final String hint;

  /// Whether a capture is in flight.
  bool get _listening =>
      phase == VoicePhase.listening || phase == VoicePhase.arming;

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    final tone = !enabled
        ? colors.muted
        : _listening
            ? colors.green
            : colors.cyan;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      hint: hint,
      child: Column(
        children: <Widget>[
          Listener(
            onPointerDown: enabled ? (_) => onStart() : null,
            onPointerUp: enabled ? (_) => onStop() : null,
            onPointerCancel: enabled ? (_) => onStop() : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.panel2,
                border: Border.all(color: tone, width: _listening ? 3 : 2),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: tone.withValues(alpha: _listening ? 0.42 : 0.18),
                    blurRadius: _listening ? 34 : 18,
                    spreadRadius: _listening ? 4 : 0,
                  ),
                ],
              ),
              child: Icon(
                enabled ? (_listening ? Icons.mic_rounded : Icons.mic_none_rounded) : Icons.mic_off_outlined,
                size: 44,
                color: tone,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: tone),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.muted),
          ),
        ],
      ),
    );
  }
}

/// Bar meter driven by the live input level. No audio is retained: this widget only ever
/// receives a 0–1 number.
class VoiceLevelMeter extends StatelessWidget {
  /// Creates the meter.
  const VoiceLevelMeter({required this.level, required this.active, super.key});

  /// Current level 0.0–1.0.
  final double level;

  /// Whether a capture is running (inactive meters show an empty track).
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    return Semantics(
      label: context.l10n.voiceLevelSemantics,
      value: active ? '${(level * 100).round()}%' : '0%',
      child: SizedBox(
        height: 26,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (var i = 0; i < 12; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  width: 5,
                  height: active && level * 12 > i ? 8 + (i * 1.4) : 6,
                  decoration: BoxDecoration(
                    color: active && level * 12 > i ? colors.cyan : colors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The "Heard" card: transcript plus send/discard actions.
class TranscriptCard extends StatelessWidget {
  /// Creates the card.
  const TranscriptCard({
    required this.text,
    required this.capturing,
    required this.onSend,
    required this.onDiscard,
    super.key,
  });

  /// Transcript to display (partial or final).
  final String text;

  /// Whether the transcript is still growing.
  final bool capturing;

  /// Sends the transcript to the assistant.
  final VoidCallback? onSend;

  /// Discards the transcript.
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(l10n.voiceTranscriptTitle, style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              if (capturing)
                StatusPill(
                  label: l10n.voiceListening,
                  tone: SeverityTone.success,
                  compact: true,
                  showDot: true,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text.isEmpty ? l10n.voiceTranscriptEmpty : text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: text.isEmpty ? colors.muted : colors.text,
                  fontStyle: text.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
          ),
          if (text.isNotEmpty && !capturing) ...<Widget>[
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: ArmxButton(
                    label: l10n.voiceSendToAssistant,
                    icon: Icons.send_rounded,
                    onPressed: onSend,
                    expanded: true,
                  ),
                ),
                const SizedBox(width: 10),
                ArmxButton(
                  label: l10n.voiceDiscard,
                  icon: Icons.delete_outline_rounded,
                  variant: ArmxButtonVariant.text,
                  onPressed: onDiscard,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One engine row: label + honest status pill.
class VoiceEngineRow extends StatelessWidget {
  /// Creates the row.
  const VoiceEngineRow({
    required this.label,
    required this.engineId,
    required this.available,
    required this.simulated,
    required this.note,
    super.key,
  });

  /// Localized label of the engine slot.
  final String label;

  /// Engine identifier reported by the adapter.
  final String engineId;

  /// Whether the engine can do real work.
  final bool available;

  /// Whether the engine is a simulator (no audio captured/played).
  final bool simulated;

  /// Localized description of what the status means.
  final String note;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);
    final tone = !available
        ? SeverityTone.warning
        : simulated
            ? SeverityTone.info
            : SeverityTone.success;
    final status = !available
        ? l10n.voiceEngineUnavailable
        : simulated
            ? l10n.voiceEngineSimulated
            : l10n.voiceEngineReal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  '$engineId · $note',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusPill(label: status, tone: tone, compact: true),
        ],
      ),
    );
  }
}
