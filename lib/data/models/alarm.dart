// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:meta/meta.dart';

/// Which class of device an alarm rings on.
enum AlarmTargetKind {
  /// The signed-in phone/tablet.
  phone,

  /// A linked desktop or laptop.
  computer,

  /// A linked watch or band.
  watch,

  /// Every linked device that is capable of ringing.
  allLinked;

  /// Parses a wire value.
  static AlarmTargetKind fromWire(String? value) => switch (value?.toLowerCase()) {
        'phone' || 'mobile' => AlarmTargetKind.phone,
        'computer' || 'pc' || 'desktop' => AlarmTargetKind.computer,
        'watch' => AlarmTargetKind.watch,
        'all' || 'all_linked' => AlarmTargetKind.allLinked,
        _ => AlarmTargetKind.phone,
      };

  /// The wire value.
  String get wire => switch (this) {
        AlarmTargetKind.phone => 'phone',
        AlarmTargetKind.computer => 'computer',
        AlarmTargetKind.watch => 'watch',
        AlarmTargetKind.allLinked => 'all_linked',
      };
}

/// One device an alarm rings on, and whether it actually did.
@immutable
class AlarmTarget {
  /// Creates a target.
  const AlarmTarget({
    required this.deviceId,
    required this.kind,
    required this.label,
    this.ringing = false,
    this.acknowledged = false,
    this.reachable = true,
  });

  /// Device identifier, or `self` for the device in hand.
  final String deviceId;

  /// Device class.
  final AlarmTargetKind kind;

  /// Display label.
  final String label;

  /// True while this device is ringing.
  final bool ringing;

  /// True once the user dismissed it on this device. Cross-device dismissal is the point
  /// of [ringing] being per target.
  final bool acknowledged;

  /// False when the backend could not reach the device, which is why it did not ring.
  /// The UI states this explicitly instead of showing a silent failure.
  final bool reachable;

  /// Parses from the wire.
  factory AlarmTarget.fromJson(Map<String, Object?> json) => AlarmTarget(
        deviceId: json['device_id']! as String,
        kind: AlarmTargetKind.fromWire(json['kind'] as String?),
        label: (json['label'] ?? '') as String,
        ringing: json['ringing'] == true,
        acknowledged: json['acknowledged'] == true,
        reachable: json['reachable'] != false,
      );

  /// Serialises.
  Map<String, Object?> toJson() => <String, Object?>{
        'device_id': deviceId,
        'kind': kind.wire,
        'label': label,
        'ringing': ringing,
        'acknowledged': acknowledged,
        'reachable': reachable,
      };

  /// Copy with changes.
  AlarmTarget copyWith({
    String? deviceId,
    AlarmTargetKind? kind,
    String? label,
    bool? ringing,
    bool? acknowledged,
    bool? reachable,
  }) =>
      AlarmTarget(
        deviceId: deviceId ?? this.deviceId,
        kind: kind ?? this.kind,
        label: label ?? this.label,
        ringing: ringing ?? this.ringing,
        acknowledged: acknowledged ?? this.acknowledged,
        reachable: reachable ?? this.reachable,
      );

  @override
  bool operator ==(Object other) =>
      other is AlarmTarget &&
      other.deviceId == deviceId &&
      other.ringing == ringing &&
      other.acknowledged == acknowledged &&
      other.reachable == reachable;

  @override
  int get hashCode => Object.hash(deviceId, ringing, acknowledged, reachable);
}

/// Repeat pattern for an alarm.
enum AlarmRepeat {
  /// Rings once, then disables itself.
  once,

  /// Every day.
  daily,

  /// Monday to Friday.
  weekdays,

  /// Saturday and Sunday.
  weekends;

  /// Parses a wire value.
  static AlarmRepeat fromWire(String? value) => switch (value?.toLowerCase()) {
        'daily' || 'everyday' => AlarmRepeat.daily,
        'weekdays' || 'mon-fri' => AlarmRepeat.weekdays,
        'weekends' || 'sat-sun' => AlarmRepeat.weekends,
        _ => AlarmRepeat.once,
      };
}

/// A scheduled alarm across one or more devices.
@immutable
class ArmxAlarm {
  /// Creates an alarm.
  const ArmxAlarm({
    required this.id,
    required this.label,
    required this.hour,
    required this.minute,
    required this.enabled,
    required this.repeat,
    required this.targets,
    this.snoozeMinutes = 5,
    this.lastRangAt,
  });

  /// Stable identifier. `new` before the first save.
  final String id;

  /// Display label.
  final String label;

  /// Hour, 0–23, in the device's local zone.
  final int hour;

  /// Minute, 0–59.
  final int minute;

  /// Whether the alarm is armed.
  final bool enabled;

  /// Repeat pattern.
  final AlarmRepeat repeat;

  /// Devices that ring.
  final List<AlarmTarget> targets;

  /// Snooze length offered when it rings.
  final int snoozeMinutes;

  /// When it last rang, for the "last rang" line.
  final DateTime? lastRangAt;

  /// `HH:MM` in 24-hour form.
  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// True when any target is ringing right now.
  bool get isRinging => targets.any((AlarmTarget t) => t.ringing);

  /// Targets that were unreachable the last time this alarm fired.
  List<AlarmTarget> get unreachableTargets =>
      targets.where((AlarmTarget t) => !t.reachable).toList(growable: false);

  /// Parses from the wire.
  factory ArmxAlarm.fromJson(Map<String, Object?> json) {
    final Object? targets = json['targets'];
    return ArmxAlarm(
      id: json['id']! as String,
      label: (json['label'] ?? '') as String,
      hour: (json['hour'] as num?)?.toInt() ?? 7,
      minute: (json['minute'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] == true,
      repeat: AlarmRepeat.fromWire(json['repeat'] as String?),
      targets: targets is List<Object?>
          ? targets
              .whereType<Map<String, Object?>>()
              .map(AlarmTarget.fromJson)
              .toList(growable: false)
          : const <AlarmTarget>[],
      snoozeMinutes: (json['snooze_minutes'] as num?)?.toInt() ?? 5,
      lastRangAt: json['last_rang_at'] is String
          ? DateTime.tryParse(json['last_rang_at']! as String)
          : null,
    );
  }

  /// Serialises.
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        'hour': hour,
        'minute': minute,
        'enabled': enabled,
        'repeat': repeat.name,
        'targets': targets.map((AlarmTarget t) => t.toJson()).toList(),
        'snooze_minutes': snoozeMinutes,
        'last_rang_at': lastRangAt?.toIso8601String(),
      };

  /// Copy with changes.
  ArmxAlarm copyWith({
    String? id,
    String? label,
    int? hour,
    int? minute,
    bool? enabled,
    AlarmRepeat? repeat,
    List<AlarmTarget>? targets,
    int? snoozeMinutes,
    DateTime? lastRangAt,
  }) =>
      ArmxAlarm(
        id: id ?? this.id,
        label: label ?? this.label,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        enabled: enabled ?? this.enabled,
        repeat: repeat ?? this.repeat,
        targets: targets ?? this.targets,
        snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
        lastRangAt: lastRangAt ?? this.lastRangAt,
      );

  @override
  bool operator ==(Object other) =>
      other is ArmxAlarm &&
      other.id == id &&
      other.label == label &&
      other.hour == hour &&
      other.minute == minute &&
      other.enabled == enabled &&
      other.repeat == repeat &&
      other.targets.length == targets.length;

  @override
  int get hashCode =>
      Object.hash(id, label, hour, minute, enabled, repeat, targets.length);
}
