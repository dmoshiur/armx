// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/breakpoints.dart';
import '../../../core/confirm/confirm_policy.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/armx_confirm_dialog.dart';
import '../../../core/widgets/armx_empty_state.dart';
import '../../../core/widgets/armx_error_state.dart';
import '../../../core/widgets/armx_loading_skeleton.dart';
import '../../../data/models/alarm.dart';
import '../application/alarms_controller.dart';
import 'widgets/alarm_card.dart';

/// The alarm list.
///
/// The order is the schedule, not the insertion order: ringing first, then armed alarms by
/// time, then the disarmed ones. Sorting is a pure function ([sortedAlarms]) so the rule can
/// be tested rather than eyeballed.
class AlarmsPage extends ConsumerWidget {
  /// Creates the page.
  const AlarmsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ArmxAlarm>> alarms = ref.watch(alarmsProvider);
    final ArmxColors colors = ArmxColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(context.l10n.alarmsTitle),
        actions: <Widget>[
          ArmxIconButton(
            icon: Icons.refresh_rounded,
            semanticLabel: context.l10n.commonRefresh,
            onPressed: () => ref.read(alarmsProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(Routes.alarmFor('new')),
        icon: const Icon(Icons.add_alarm_rounded),
        label: Text(context.l10n.alarmsNew),
      ),
      body: switch (alarms) {
        AsyncLoading<List<ArmxAlarm>>() => const Padding(
            padding: EdgeInsets.all(Insets.lg),
            child: Column(
              children: <Widget>[
                ArmxSkeletonCard(lines: 2),
                SizedBox(height: Insets.md),
                ArmxSkeletonCard(lines: 2),
              ],
            ),
          ),
        AsyncError<List<ArmxAlarm>>(:final Object error) => ArmxErrorState(
            error: error,
            onRetry: () => ref.invalidate(alarmsProvider),
          ),
        AsyncData<List<ArmxAlarm>>(:final List<ArmxAlarm> value) =>
          _List(alarms: sortedAlarms(value)),
      },
    );
  }
}

/// Rings first, then armed alarms by time, then disarmed ones by time.
List<ArmxAlarm> sortedAlarms(List<ArmxAlarm> alarms) {
  int rank(ArmxAlarm alarm) => alarm.isRinging
      ? 0
      : alarm.enabled
          ? 1
          : 2;

  return <ArmxAlarm>[...alarms]..sort((ArmxAlarm a, ArmxAlarm b) {
      final int byRank = rank(a).compareTo(rank(b));
      return byRank != 0
          ? byRank
          : (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute);
    });
}

class _List extends ConsumerWidget {
  const _List({required this.alarms});

  final List<ArmxAlarm> alarms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (alarms.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: ArmxEmptyState(
            icon: Icons.alarm_add_rounded,
            title: context.l10n.alarmsEmptyTitle,
            message: context.l10n.alarmsEmptyBody,
            actionLabel: context.l10n.alarmsNew,
            onAction: () => context.go(Routes.alarmFor('new')),
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        Insets.lg,
        context.pagePadding,
        Insets.xxl * 2,
      ),
      children: <Widget>[
        Text(
          context.l10n.alarmsSubtitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: Insets.lg),
        for (final ArmxAlarm alarm in alarms) ...<Widget>[
          AlarmCard(
            alarm: alarm,
            onEdit: () => context.go(Routes.alarmFor(alarm.id)),
            onToggle: (bool enabled) => _act(
              context,
              () => ref.read(alarmsProvider.notifier).save(
                    ArmxAlarm(
                      id: alarm.id,
                      label: alarm.label,
                      hour: alarm.hour,
                      minute: alarm.minute,
                      enabled: enabled,
                      repeat: alarm.repeat,
                      targets: alarm.targets,
                      snoozeMinutes: alarm.snoozeMinutes,
                      lastRangAt: alarm.lastRangAt,
                    ),
                  ),
            ),
            onTest: () => _act(
              context,
              () => ref.read(alarmsProvider.notifier).testRing(alarm.id),
            ),
            onDismissRing: () => _act(
              context,
              () => ref.read(alarmsProvider.notifier).acknowledge(alarm.id),
            ),
            onDelete: () => _delete(context, ref, alarm),
          ),
          const SizedBox(height: Insets.md),
        ],
      ],
    );
  }

  /// Runs an alarm action and reports its outcome without pretending it worked.
  Future<void> _act(BuildContext context, Future<Object?> Function() action) async {
    try {
      await action();
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('${context.l10n.alarmsSaveFailed} ${error.message}')),
        );
      }
    }
  }

  /// Deleting an alarm cannot be undone from the app, so it is confirmed and names the
  /// alarm and the devices it would have rung.
  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ArmxAlarm alarm,
  ) async {
    final bool confirmed = await ConfirmPolicy.confirm(
      context,
      ConfirmPolicy.forAction(
        context,
        title: context.l10n.alarmsDeleteTitle,
        action: 'delete_alarm',
        target: '${alarm.timeLabel} · ${alarm.label}',
        parameters: <ConfirmParameter>[
          ConfirmParameter(label: 'alarm_id', value: alarm.id, monospace: true),
          ConfirmParameter(label: 'repeat', value: alarm.repeat.name),
          ConfirmParameter(
            label: 'targets',
            value: alarm.targets.isEmpty
                ? 'this-device'
                : alarm.targets.map((AlarmTarget t) => t.label).join(', '),
          ),
        ],
        consequence: context.l10n.alarmsDeleteBody,
        irreversible: true,
        confirmLabel: context.l10n.commonDelete,
      ),
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    await _act(context, () => ref.read(alarmsProvider.notifier).delete(alarm.id));
  }
}
