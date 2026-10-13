// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:meta/meta.dart';

/// What a controllable thing is.
enum DeviceKind {
  /// A dimmable or switchable light.
  light,

  /// A fan or other variable-speed motor.
  fan,

  /// A plug with on/off control.
  plug,

  /// A read-only environmental sensor.
  sensor,

  /// A camera. Never controllable from this screen; the guest greeter owns it.
  camera,

  /// A lock with lock/unlock control.
  lock,

  /// Something the client does not model yet. Rendered generically rather than hidden.
  other;

  /// Parses a wire value.
  static DeviceKind fromWire(String? value) => switch (value?.toLowerCase()) {
        'light' => DeviceKind.light,
        'fan' => DeviceKind.fan,
        'plug' || 'socket' => DeviceKind.plug,
        'sensor' => DeviceKind.sensor,
        'camera' => DeviceKind.camera,
        'lock' => DeviceKind.lock,
        _ => DeviceKind.other,
      };

  /// True when the device exposes on/off and/or level control.
  bool get isControllable =>
      this == DeviceKind.light ||
      this == DeviceKind.fan ||
      this == DeviceKind.plug ||
      this == DeviceKind.lock;

  /// True when the device only reports readings.
  bool get isReadOnly => this == DeviceKind.sensor;
}

/// A sensor reading with its unit, so the UI never renders a bare number.
@immutable
class SensorReading {
  /// Creates a reading.
  const SensorReading({
    required this.metric,
    required this.value,
    required this.unit,
    this.recordedAt,
  });

  /// What is measured: `temperature`, `humidity`, `motion`, `illuminance`, `co2`.
  final String metric;

  /// The number.
  final double value;

  /// Unit symbol. Unitless metrics use an empty string.
  final String unit;

  /// When the backend took the reading.
  final DateTime? recordedAt;

  /// Parses from the wire.
  factory SensorReading.fromJson(Map<String, Object?> json) => SensorReading(
        metric: (json['metric'] ?? 'value') as String,
        value: (json['value'] as num?)?.toDouble() ?? 0,
        unit: (json['unit'] ?? '') as String,
        recordedAt: json['recorded_at'] is String
            ? DateTime.tryParse(json['recorded_at']! as String)
            : null,
      );

  /// Serialises.
  Map<String, Object?> toJson() => <String, Object?>{
        'metric': metric,
        'value': value,
        'unit': unit,
        'recorded_at': recordedAt?.toIso8601String(),
      };

  /// The value with its unit, e.g. `24.5 °C`.
  String get display => unit.isEmpty
      ? value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)
      : '${value.toStringAsFixed(1)} $unit';
}

/// A controllable or readable device.
@immutable
class ArmxDevice {
  /// Creates a device.
  const ArmxDevice({
    required this.id,
    required this.name,
    required this.kind,
    required this.roomId,
    required this.online,
    this.level,
    this.brightness,
    this.reading,
    this.firmwareVersion,
    this.lastSeenAt,
    this.controllableByCurrentUser = true,
  });

  /// Stable identifier.
  final String id;

  /// Display name, owner-supplied.
  final String name;

  /// What it is.
  final DeviceKind kind;

  /// Owning room.
  final String roomId;

  /// Whether the backend can currently reach it. A device that is offline is **not**
  /// rendered as "off" — that distinction is the whole point of this flag.
  final bool online;

  /// On/off for switch-like devices.
  final bool? level;

  /// 0–100 brightness for dimmable lights, or speed for fans.
  final int? brightness;

  /// Latest reading for sensors.
  final SensorReading? reading;

  /// Reported firmware version, shown on the detail page.
  final String? firmwareVersion;

  /// Last successful contact.
  final DateTime? lastSeenAt;

  /// False when the current role may see but not command this device (a VIP-only lock,
  /// for example). The control is rendered disabled **with a reason**, never hidden.
  final bool controllableByCurrentUser;

  /// Parses from the wire.
  factory ArmxDevice.fromJson(Map<String, Object?> json) => ArmxDevice(
        id: json['id']! as String,
        name: (json['name'] ?? 'Device') as String,
        kind: DeviceKind.fromWire(json['kind'] as String?),
        roomId: (json['room_id'] ?? json['roomId'] ?? 'unassigned') as String,
        online: json['online'] == true,
        level: json['level'] as bool?,
        brightness: (json['brightness'] as num?)?.toInt(),
        reading: json['reading'] is Map<String, Object?>
            ? SensorReading.fromJson(json['reading']! as Map<String, Object?>)
            : null,
        firmwareVersion: json['firmware_version'] as String?,
        lastSeenAt: json['last_seen_at'] is String
            ? DateTime.tryParse(json['last_seen_at']! as String)
            : null,
        controllableByCurrentUser: json['controllable'] != false,
      );

  /// Serialises.
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'kind': kind.name,
        'room_id': roomId,
        'online': online,
        'level': level,
        'brightness': brightness,
        'reading': reading?.toJson(),
        'firmware_version': firmwareVersion,
        'last_seen_at': lastSeenAt?.toIso8601String(),
        'controllable': controllableByCurrentUser,
      };

  /// Copy with changes.
  ArmxDevice copyWith({
    String? id,
    String? name,
    DeviceKind? kind,
    String? roomId,
    bool? online,
    bool? level,
    int? brightness,
    SensorReading? reading,
    String? firmwareVersion,
    DateTime? lastSeenAt,
    bool? controllableByCurrentUser,
  }) =>
      ArmxDevice(
        id: id ?? this.id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        roomId: roomId ?? this.roomId,
        online: online ?? this.online,
        level: level ?? this.level,
        brightness: brightness ?? this.brightness,
        reading: reading ?? this.reading,
        firmwareVersion: firmwareVersion ?? this.firmwareVersion,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        controllableByCurrentUser:
            controllableByCurrentUser ?? this.controllableByCurrentUser,
      );

  /// True when the device is on (lights, fans, plugs) or unlocked (locks).
  bool get isActive => level ?? false;

  @override
  bool operator ==(Object other) =>
      other is ArmxDevice &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.roomId == roomId &&
      other.online == online &&
      other.level == level &&
      other.brightness == brightness &&
      other.reading?.value == reading?.value &&
      other.controllableByCurrentUser == controllableByCurrentUser;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        kind,
        roomId,
        online,
        level,
        brightness,
        reading?.value,
        controllableByCurrentUser,
      );
}

/// A room groups devices and gives the smart-home grid its sections.
@immutable
class ArmxRoom {
  /// Creates a room.
  const ArmxRoom({
    required this.id,
    required this.name,
    this.floor,
    this.icon,
  });

  /// Stable identifier.
  final String id;

  /// Display name.
  final String name;

  /// Optional floor label used to group rooms on wide layouts.
  final String? floor;

  /// Optional icon name the client maps to a glyph.
  final String? icon;

  /// Parses from the wire.
  factory ArmxRoom.fromJson(Map<String, Object?> json) => ArmxRoom(
        id: json['id']! as String,
        name: (json['name'] ?? 'Room') as String,
        floor: json['floor'] as String?,
        icon: json['icon'] as String?,
      );

  /// Serialises.
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'floor': floor,
        'icon': icon,
      };

  @override
  bool operator ==(Object other) =>
      other is ArmxRoom && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// The outcome of a device command, reported by the backend.
///
/// There is no optimistic success here: the UI shows [accepted] as *pending* until the
/// device state event confirms it, and shows [message] verbatim on refusal.
@immutable
class DeviceCommandResult {
  /// Creates a result.
  const DeviceCommandResult({
    required this.deviceId,
    required this.command,
    required this.accepted,
    this.pending = false,
    this.message,
    this.state,
  });

  /// Target device.
  final String deviceId;

  /// Command that was sent.
  final String command;

  /// Whether the backend accepted it.
  final bool accepted;

  /// True when the backend accepted it but the device has not confirmed yet. The UI must
  /// render this as "pending", never as success.
  final bool pending;

  /// Human-readable detail, shown as-is when present.
  final String? message;

  /// Resulting device state, when the backend already knows it.
  final ArmxDevice? state;

  /// Parses from the wire.
  factory DeviceCommandResult.fromJson(Map<String, Object?> json) =>
      DeviceCommandResult(
        deviceId: json['device_id']! as String,
        command: (json['command'] ?? '') as String,
        accepted: json['accepted'] == true,
        pending: json['pending'] == true,
        message: json['message'] as String?,
        state: json['state'] is Map<String, Object?>
            ? ArmxDevice.fromJson(json['state']! as Map<String, Object?>)
            : null,
      );
}
