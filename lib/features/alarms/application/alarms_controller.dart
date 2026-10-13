// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';
import '../../../data/models/alarm.dart';

/// The alarm list and the mutations the UI performs on it.
///
/// Every method adopts the server's copy of the alarm rather than a locally patched one, so
/// the list shows the ring state of targets on *other* devices — which the client cannot
/// know by itself and must never invent.
class AlarmsController extends AsyncNotifier<List<ArmxAlarm>> {
  @override
  Future<List<ArmxAlarm>> build() => ref.watch(armxApiProvider).alarms();

  /// Re-reads the list.
  Future<void> refresh() async {
    state = const AsyncValue<List<ArmxAlarm>>.loading();
    state = await AsyncValue.guard(build);
  }

  /// Creates or updates [alarm].
  Future<ArmxAlarm> save(ArmxAlarm alarm) async {
    final ArmxAlarm stored = await ref.read(armxApiProvider).saveAlarm(alarm);
    _replace(stored);
    return stored;
  }

  /// Deletes an alarm. The caller confirms first — this is irreversible.
  Future<void> delete(String alarmId) async {
    await ref.read(armxApiProvider).deleteAlarm(alarmId);
    final List<ArmxAlarm> current = state.value ?? const <ArmxAlarm>[];
    state = AsyncValue<List<ArmxAlarm>>.data(
      current.where((ArmxAlarm a) => a.id != alarmId).toList(growable: false),
    );
  }

  /// Rings the targets once.
  Future<ArmxAlarm> testRing(String alarmId) async {
    final ArmxAlarm alarm = await ref.read(armxApiProvider).testAlarmRing(alarmId);
    _replace(alarm);
    return alarm;
  }

  /// Dismisses a ringing alarm on every target.
  Future<ArmxAlarm> acknowledge(String alarmId) async {
    final ArmxAlarm alarm =
        await ref.read(armxApiProvider).acknowledgeAlarm(alarmId);
    _replace(alarm);
    return alarm;
  }

  void _replace(ArmxAlarm alarm) {
    final List<ArmxAlarm> current = state.value ?? const <ArmxAlarm>[];
    final bool known = current.any((ArmxAlarm a) => a.id == alarm.id);
    state = AsyncValue<List<ArmxAlarm>>.data(
      <ArmxAlarm>[
        if (known)
          for (final ArmxAlarm a in current) a.id == alarm.id ? alarm : a
        else
          ...current,
        if (!known) alarm,
      ],
    );
  }
}

/// The alarm list.
final AsyncNotifierProvider<AlarmsController, List<ArmxAlarm>> alarmsProvider =
    AsyncNotifierProvider<AlarmsController, List<ArmxAlarm>>(
  AlarmsController.new,
);

/// One alarm by id, for the editor.
final ProviderFamily<ArmxAlarm?, String> alarmByIdProvider =
    Provider.family<ArmxAlarm?, String>(
  (Ref ref, String id) =>
      ref.watch(alarmsProvider).value?.where((ArmxAlarm a) => a.id == id).firstOrNull,
);

/// Draft state for the alarm editor, keyed by alarm id.
///
/// Keyed so opening the editor for a second alarm cannot inherit the first one's unsaved
/// fields — a bug class that surfaces as "my 6 a.m. alarm became 7 a.m." and is miserable to
/// trace back.
class AlarmDraft {
  /// Creates a draft.
  const AlarmDraft({
    required this.label,
    required this.hour,
    required this.minute,
    required this.repeat,
    required this.enabled,
    required this.snoozeMinutes,
    required this.targets,
    this.error,
  });

  /// An empty draft.
  factory AlarmDraft.empty() => const AlarmDraft(
        label: '',
        hour: 7,
        minute: 0,
        repeat: AlarmRepeat.daily,
        enabled: true,
        snoozeMinutes: 5,
        targets: <AlarmTarget>[],
      );

  /// A draft pre-filled from a stored alarm.
  factory AlarmDraft.from(ArmxAlarm alarm) => AlarmDraft(
        label: alarm.label,
        hour: alarm.hour,
        minute: alarm.minute,
        repeat: alarm.repeat,
        enabled: alarm.enabled,
        snoozeMinutes: alarm.snoozeMinutes,
        targets: alarm.targets,
      );

  /// Alarm name.
  final String label;

  /// Hour, 0–23.
  final int hour;

  /// Minute, 0–59.
  final int minute;

  /// Repeat rule.
  final AlarmRepeat repeat;

  /// Whether it is armed.
  final bool enabled;

  /// Snooze length.
  final int snoozeMinutes;

  /// Devices it rings on.
  final List<AlarmTarget> targets;

  /// Last save failure.
  final AppException? error;

  /// `HH:MM`.
  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Copy with changes.
  AlarmDraft copyWith({
    String? label,
    int? hour,
    int? minute,
    AlarmRepeat? repeat,
    bool? enabled,
    int? snoozeMinutes,
    List<AlarmTarget>? targets,
    AppException? error,
    bool clearError = false,
  }) =>
      AlarmDraft(
        label: label ?? this.label,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        repeat: repeat ?? this.repeat,
        enabled: enabled ?? this.enabled,
        snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
        targets: targets ?? this.targets,
        error: clearError ? null : (error ?? this.error),
      );

  /// Builds the wire alarm. [id] is `new` when creating.
  ///
  /// An empty label falls back to the time, and an empty target list is legal — the backend
  /// rings this device — and both are stated in the editor rather than silently applied.
  ArmxAlarm toAlarm({required String id}) => ArmxAlarm(
        id: id,
        label: label.trim().isEmpty ? timeLabel : label.trim(),
        hour: hour,
        minute: minute,
        enabled: enabled,
        repeat: repeat,
        snoozeMinutes: snoozeMinutes,
        targets: targets,
      );
}

/// The editor draft for one alarm (`new` for creation).
final NotifierProviderFamily<AlarmDraftController, AlarmDraft, String>
    alarmDraftProvider =
    NotifierProvider.family<AlarmDraftController, AlarmDraft, String>(
  AlarmDraftController.new,
);

/// Holds one editor's draft.
class AlarmDraftController extends FamilyNotifier<AlarmDraft, String> {
  @override
  AlarmDraft build(String alarmId) {
    if (alarmId == 'new') {
      return AlarmDraft.empty();
    }
    final ArmxAlarm? existing = ref.watch(alarmByIdProvider(alarmId));
    return existing == null ? AlarmDraft.empty() : AlarmDraft.from(existing);
  }

  /// Applies a change.
  void update(AlarmDraft Function(AlarmDraft draft) transform) =>
      state = transform(state);

  /// Records a failure so the form can show it in place instead of closing.
  void fail(AppException error) => state = state.copyWith(error: error);
}
