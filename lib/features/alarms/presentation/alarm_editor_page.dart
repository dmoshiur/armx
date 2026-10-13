// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/breakpoints.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/armx_badge.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/armx_card.dart';
import '../../../core/widgets/armx_error_state.dart';
import '../../../core/widgets/armx_text_field.dart';
import '../../../data/models/alarm.dart';
import '../application/alarms_controller.dart';
import 'widgets/alarm_card.dart';

/// Create or edit one alarm.
///
/// ## Why a form and not a dialog
///
/// A form *is* the confirmation: the user names it, sets the time, picks the repeat rule and
/// presses Save. Wrapping that in [ArmxConfirmDialog] as well would train people to dismiss
/// dialogs, so the dialog is reserved for the actions that really are destructive — deleting
/// an alarm, unlinking a device, publishing a site.
///
/// ## Targets
///
/// The target list is built from the devices the account can actually ring: this device,
/// plus anything in the linked-device list. An alarm with no target rings here, which the
/// form states rather than leaving to be discovered at 6 a.m.
class AlarmEditorPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const AlarmEditorPage({required this.alarmId, super.key});

  /// Alarm id, or `new`.
  final String alarmId;

  @override
  ConsumerState<AlarmEditorPage> createState() => _AlarmEditorPageState();
}

class _AlarmEditorPageState extends ConsumerState<AlarmEditorPage> {
  final TextEditingController _label = TextEditingController();
  bool _saving = false;
  bool _seeded = false;

  bool get _isNew => widget.alarmId == 'new';

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AlarmDraft draft = ref.watch(alarmDraftProvider(widget.alarmId));
    if (!_seeded) {
      _label.text = draft.label;
      _seeded = true;
    }

    return Scaffold(
      backgroundColor: ArmxColors.of(context).background,
      appBar: AppBar(
        title: Text(
          _isNew ? context.l10n.alarmsCreateTitle : context.l10n.alarmsEditTitle,
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(context.pagePadding),
        children: <Widget>[
          if (draft.error != null) ...<Widget>[
            ArmxErrorState(error: draft.error, compact: true),
            const SizedBox(height: Insets.lg),
          ],
          ArmxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ArmxTextField(
                  label: context.l10n.alarmsLabel,
                  hint: context.l10n.alarmsLabelHint,
                  helper: context.l10n.alarmsLabelOptional,
                  controller: _label,
                  maxLength: 60,
                  onChanged: (String value) => _update(
                    (AlarmDraft d) => d.copyWith(label: value),
                  ),
                ),
                const SizedBox(height: Insets.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        context.l10n.alarmsTime,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    ArmxButton(
                      label: draft.timeLabel,
                      variant: ArmxButtonVariant.secondary,
                      size: ArmxButtonSize.large,
                      icon: Icons.schedule_rounded,
                      semanticLabel: context.l10n.alarmsTime,
                      onPressed: _saving ? null : () => _pickTime(draft),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.lg),
                Text(
                  context.l10n.alarmsRepeat,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: Insets.sm),
                AdaptiveWrapRow(
                  children: <Widget>[
                    for (final AlarmRepeat repeat in AlarmRepeat.values)
                      ArmxChip(
                        label: _repeatLabel(context, repeat),
                        selected: draft.repeat == repeat,
                        onSelected: _saving
                            ? null
                            : (_) => _update(
                                  (AlarmDraft d) => d.copyWith(repeat: repeat),
                                ),
                      ),
                  ],
                ),
                const SizedBox(height: Insets.lg),
                Text(
                  context.l10n.alarmsSnooze(draft.snoozeMinutes),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: Insets.sm),
                AdaptiveWrapRow(
                  children: <Widget>[
                    for (final int minutes in const <int>[0, 5, 10, 15, 30])
                      ArmxChip(
                        label: minutes == 0
                            ? context.l10n.commonNone
                            : context.l10n.commonMinutes(minutes),
                        selected: draft.snoozeMinutes == minutes,
                        onSelected: _saving
                            ? null
                            : (_) => _update(
                                  (AlarmDraft d) => d.copyWith(snoozeMinutes: minutes),
                                ),
                      ),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                ArmxSwitchRow(
                  title: context.l10n.alarmsEnabled,
                  subtitle: context.l10n.alarmsSubtitle,
                  value: draft.enabled,
                  enabled: !_saving,
                  onChanged: (bool enabled) =>
                      _update((AlarmDraft d) => d.copyWith(enabled: enabled)),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),
          ArmxCard(
            title: context.l10n.alarmsTargets,
            leading: const Icon(Icons.devices_other_rounded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.alarmsTargetsBody,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: Insets.md),
                for (final ArmxTargetOption option in ArmxTargetOption.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.xs),
                    child: ArmxSwitchRow(
                      title: option.label(context),
                      value: _hasTarget(draft, option),
                      enabled: !_saving,
                      onChanged: (bool on) => _toggleTarget(draft, option, on),
                    ),
                  ),
                const SizedBox(height: Insets.sm),
                Text(
                  draft.targets.isEmpty
                      ? context.l10n.alarmsTargetFallback
                      : context.l10n.alarmsTargetsSelected(
                          draft.targets.map((AlarmTarget t) => t.label).join(', '),
                        ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),
          AdaptiveWrapRow(
            children: <Widget>[
              ArmxButton(
                label: _isNew
                    ? context.l10n.commonCreate
                    : context.l10n.commonSaveChanges,
                icon: Icons.check_rounded,
                loading: _saving,
                onPressed: _saving ? null : () => _save(draft),
              ),
              ArmxButton(
                label: context.l10n.commonCancel,
                variant: ArmxButtonVariant.ghost,
                onPressed: _saving ? null : () => context.go(Routes.alarms),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _update(AlarmDraft Function(AlarmDraft draft) transform) =>
      ref.read(alarmDraftProvider(widget.alarmId).notifier).update(transform);

  bool _hasTarget(AlarmDraft draft, ArmxTargetOption option) =>
      draft.targets.any((AlarmTarget target) => target.kind == option.kind);

  void _toggleTarget(AlarmDraft draft, ArmxTargetOption option, bool on) {
    _update((AlarmDraft d) {
      final List<AlarmTarget> next = <AlarmTarget>[
        for (final AlarmTarget target in d.targets)
          if (target.kind != option.kind) target,
      ];
      if (on) {
        next.add(
          AlarmTarget(
            deviceId: option.wireDeviceId,
            kind: option.kind,
            label: option.label(context),
            // The editor is not a ring report: these flags describe the *last* fire, which
            // is only known after the alarm has actually run, so a fresh target starts
            // un-rung and reachable by default.
            ringing: false,
            acknowledged: false,
            reachable: true,
          ),
        );
      }
      return d.copyWith(targets: next);
    });
  }

  String _repeatLabel(BuildContext context, AlarmRepeat repeat) => switch (repeat) {
        AlarmRepeat.once => context.l10n.alarmsRepeatOnce,
        AlarmRepeat.daily => context.l10n.alarmsRepeatDaily,
        AlarmRepeat.weekdays => context.l10n.alarmsRepeatWeekdays,
        AlarmRepeat.weekends => context.l10n.alarmsRepeatWeekends,
      };

  Future<void> _pickTime(AlarmDraft draft) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: draft.hour, minute: draft.minute),
      // Forced to 24-hour input so the value the user picked and the value shown in the list
      // can never disagree about which half of the day it is.
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) {
      _update((AlarmDraft d) => d.copyWith(hour: picked.hour, minute: picked.minute));
    }
  }

  /// Saves and returns to the list. A failure keeps the draft on screen.
  Future<void> _save(AlarmDraft draft) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(alarmsProvider.notifier)
          .save(draft.toAlarm(id: _isNew ? 'new' : widget.alarmId));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.alarmsSaved)),
      );
      context.go(Routes.alarms);
    } on AppException catch (error) {
      ref.read(alarmDraftProvider(widget.alarmId).notifier).fail(error);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

/// The kinds of device an alarm can ring on.
///
/// A short, fixed list rather than the raw linked-device list: the backend rings *classes* of
/// device (`phone`, `computer`, `watch`), and mixing session ids into the target list would
/// create alarms that look precise and are not.
enum ArmxTargetOption {
  /// This phone or tablet.
  thisDevice(AlarmTargetKind.phone, 'this-device'),

  /// A linked computer.
  computer(AlarmTargetKind.computer, 'linked-computer'),

  /// A linked watch or band.
  watch(AlarmTargetKind.watch, 'linked-watch'),

  /// Every linked device that can ring.
  allLinked(AlarmTargetKind.allLinked, 'all-linked');

  const ArmxTargetOption(this.kind, this.wireDeviceId);

  /// The wire kind.
  final AlarmTargetKind kind;

  /// Stable pseudo-id used before the backend assigns one.
  final String wireDeviceId;

  /// The localized label.
  String label(BuildContext context) => switch (this) {
        ArmxTargetOption.thisDevice => context.l10n.alarmsTargetPhone,
        ArmxTargetOption.computer => context.l10n.alarmsTargetComputer,
        ArmxTargetOption.watch => context.l10n.alarmsTargetWatch,
        ArmxTargetOption.allLinked => context.l10n.alarmsTargetAll,
      };
}
