// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../../../../core/breakpoints.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/armx_badge.dart';
import '../../../../core/widgets/armx_button.dart';
import '../../../../core/widgets/armx_card.dart';
import '../../../../core/widgets/armx_status_dot.dart';
import '../../../../core/widgets/armx_text_field.dart';
import '../../../../data/models/alarm.dart';

/// One alarm, with its per-device ring status.
///
/// The card never reduces "did it reach me" to a boolean. Each target reports one of three
/// outcomes — ringing, dismissed, or unreachable — listed by device name, because "it rang
/// on the phone but never reached the watch" is exactly the failure a person discovers too
/// late to forgive.
class AlarmCard extends StatelessWidget {
  /// Creates a card.
  const AlarmCard({
    required this.alarm,
    required this.onEdit,
    required this.onToggle,
    required this.onTest,
    required this.onDismissRing,
    required this.onDelete,
    super.key,
  });

  /// The alarm.
  final ArmxAlarm alarm;

  /// Opens the editor.
  final VoidCallback onEdit;

  /// Arms or disarms it.
  final ValueChanged<bool> onToggle;

  /// Rings the targets once so the owner can check them.
  final VoidCallback onTest;

  /// Dismisses a ring everywhere.
  final VoidCallback onDismissRing;

  /// Deletes it (the caller confirms first).
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final bool ringing = alarm.isRinging;

    return ArmxCard(
      semanticLabel: '${alarm.timeLabel}. ${alarm.label}. '
          '${alarm.enabled ? context.l10n.alarmsEnabled : context.l10n.alarmsDisabled}. '
          '${ringing ? context.l10n.alarmsRinging : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      // Tabular figures so a column of alarms aligns; 24-hour so the value
                      // can never be misread as a different half of the day.
                      alarm.timeLabel,
                      style: ArmxTypography.inter(
                        size: 32,
                        weight: FontWeight.w700,
                        color: alarm.enabled ? colors.text : colors.textMuted,
                        tabular: true,
                      ),
                    ),
                    Text(
                      alarm.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: Insets.sm),
                    AdaptiveWrapRow(
                      children: <Widget>[
                        ArmxBadge(
                          label: _repeatLabel(context),
                          tone: ArmxBadgeTone.neutral,
                          icon: Icons.repeat_rounded,
                        ),
                        ArmxBadge(
                          label: alarm.enabled
                              ? context.l10n.alarmsEnabled
                              : context.l10n.alarmsDisabled,
                          tone: alarm.enabled
                              ? ArmxBadgeTone.success
                              : ArmxBadgeTone.neutral,
                        ),
                        if (ringing)
                          ArmxBadge(
                            label: context.l10n.alarmsRinging,
                            tone: ArmxBadgeTone.warning,
                            icon: Icons.notifications_active_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              ArmxIconToggle(
                icon: alarm.enabled
                    ? Icons.toggle_on_rounded
                    : Icons.toggle_off_outlined,
                selected: alarm.enabled,
                semanticLabel: alarm.enabled
                    ? context.l10n.alarmsDisabled
                    : context.l10n.alarmsEnabled,
                onPressed: () => onToggle(!alarm.enabled),
              ),
            ],
          ),
          if (alarm.targets.isNotEmpty) ...<Widget>[
            const SizedBox(height: Insets.md),
            Text(
              context.l10n.alarmsRingStatus,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: Insets.xs),
            for (final AlarmTarget target in alarm.targets)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.xs),
                child: ArmxStatusDot(
                  status: !target.reachable
                      ? ArmxStatus.offline
                      : target.ringing
                          ? ArmxStatus.pending
                          : ArmxStatus.online,
                  label: '${target.label} — ${_targetState(context, target)}',
                  compact: true,
                ),
              ),
          ],
          const SizedBox(height: Insets.md),
          AdaptiveWrapRow(
            children: <Widget>[
              ArmxButton(
                label: context.l10n.alarmsEdit,
                variant: ArmxButtonVariant.secondary,
                size: ArmxButtonSize.small,
                icon: Icons.edit_outlined,
                onPressed: onEdit,
              ),
              ArmxButton(
                label: context.l10n.alarmsTestRing,
                variant: ArmxButtonVariant.ghost,
                size: ArmxButtonSize.small,
                icon: Icons.play_arrow_rounded,
                onPressed: onTest,
              ),
              if (ringing)
                ArmxButton(
                  label: context.l10n.alarmsDismiss,
                  variant: ArmxButtonVariant.primary,
                  size: ArmxButtonSize.small,
                  icon: Icons.alarm_off_rounded,
                  onPressed: onDismissRing,
                ),
              ArmxButton(
                label: context.l10n.commonDelete,
                variant: ArmxButtonVariant.destructive,
                size: ArmxButtonSize.small,
                icon: Icons.delete_outline_rounded,
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _targetState(BuildContext context, AlarmTarget target) {
    if (!target.reachable) {
      return context.l10n.alarmsUnreachable;
    }
    if (target.ringing) {
      return context.l10n.alarmsRinging;
    }
    return target.acknowledged
        ? context.l10n.alarmsAcknowledged
        : context.l10n.statusOnline;
  }

  String _repeatLabel(BuildContext context) => switch (alarm.repeat) {
        AlarmRepeat.once => context.l10n.alarmsRepeatOnce,
        AlarmRepeat.daily => context.l10n.alarmsRepeatDaily,
        AlarmRepeat.weekdays => context.l10n.alarmsRepeatWeekdays,
        AlarmRepeat.weekends => context.l10n.alarmsRepeatWeekends,
      };
}

/// A wrapping row. Named here because both the alarm card and the tile grids want the same
/// behaviour: never overflow, wrap instead.
class AdaptiveWrapRow extends StatelessWidget {
  /// Creates the row.
  const AdaptiveWrapRow({required this.children, super.key});

  /// Items.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}
