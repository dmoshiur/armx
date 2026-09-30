// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/security/risk_tier.dart';
import 'converters.dart';

part 'device.freezed.dart';
part 'device.g.dart';

/// What kind of node an [ArmxDevice] is.
enum DeviceKind {
  /// Mains relay / smart plug.
  @JsonValue('LIGHT')
  light,

  /// Gate, shutter or barrier relay.
  @JsonValue('GATE')
  gate,

  /// Door lock actuator.
  @JsonValue('LOCK')
  lock,

  /// Sensor-only node (no actuator).
  @JsonValue('SENSOR')
  sensor,

  /// Camera node.
  @JsonValue('CAMERA')
  camera,

  /// Anything the server adds later.
  @JsonValue('OTHER')
  other,
}

/// State of a relay channel.
enum RelayState {
  /// Energised.
  @JsonValue('ON')
  on,

  /// De-energised.
  @JsonValue('OFF')
  off,

  /// Unknown or unreadable (offline device).
  @JsonValue('UNKNOWN')
  unknown,
}

/// Physical quantity reported by a sensor.
enum SensorKind {
  /// Degrees Celsius.
  @JsonValue('TEMPERATURE')
  temperature,

  /// Relative humidity percentage.
  @JsonValue('HUMIDITY')
  humidity,

  /// Motion detected flag.
  @JsonValue('MOTION')
  motion,

  /// Door/window contact flag.
  @JsonValue('CONTACT')
  contact,

  /// Battery percentage.
  @JsonValue('BATTERY')
  battery,

  /// Instantaneous power in watts.
  @JsonValue('POWER')
  power,

  /// Anything else.
  @JsonValue('OTHER')
  other,
}

/// One relay channel of a device.
@freezed
abstract class Relay with _$Relay {
  /// Creates a relay channel.
  const factory Relay({
    required String id,
    required String label,
    @Default(RelayState.unknown) RelayState state,
    required DateTime lastChangedAt,
    @JsonKey(fromJson: riskTierFromJson, toJson: riskTierToJson)
    @Default(RiskTier.medium)
    RiskTier riskTier,
    @Default(false) bool isMomentary,
  }) = _Relay;

  /// Creates a relay from wire JSON.
  factory Relay.fromJson(Map<String, dynamic> json) => _$RelayFromJson(json);
}

/// One sensor readout of a device.
@freezed
abstract class SensorReading with _$SensorReading {
  /// Creates a sensor reading.
  const factory SensorReading({
    required String id,
    required String label,
    required SensorKind kind,
    required double value,
    required String unit,
    required DateTime updatedAt,
    @Default(false) bool isStale,
  }) = _SensorReading;

  /// Creates a reading from wire JSON.
  factory SensorReading.fromJson(Map<String, dynamic> json) => _$SensorReadingFromJson(json);
}

/// An ESP32 node managed by A.R.M.X.
@freezed
abstract class ArmxDevice with _$ArmxDevice {
  /// Creates a device.
  const factory ArmxDevice({
    required String id,
    required String name,
    required String site,
    @JsonKey(unknownEnumValue: DeviceKind.other) @Default(DeviceKind.other) DeviceKind kind,
    @Default(false) bool online,
    @JsonKey(fromJson: riskTierFromJson, toJson: riskTierToJson)
    @Default(RiskTier.medium)
    RiskTier riskTier,
    @Default('unknown') String firmware,
    required DateTime lastSeenAt,
    @Default(<Relay>[]) List<Relay> relays,
    @Default(<SensorReading>[]) List<SensorReading> sensors,
    @Default(<String, String>{}) Map<String, String> tags,
  }) = _ArmxDevice;

  const ArmxDevice._();

  /// Creates a device from wire JSON.
  factory ArmxDevice.fromJson(Map<String, dynamic> json) => _$ArmxDeviceFromJson(json);

  /// True when the node reported in the last 90 seconds.
  bool get isLikelyOnline =>
      online && DateTime.now().difference(lastSeenAt).inSeconds.abs() < 90;

  /// Relay currently energised, if any (used by the dashboard quick actions).
  Relay? get primaryRelay => relays.isEmpty ? null : relays.first;
}

/// Result of sending a command to a device.
@freezed
abstract class DeviceCommandResult with _$DeviceCommandResult {
  /// Creates a command result.
  const factory DeviceCommandResult({
    required String deviceId,
    required bool accepted,
    required DateTime at,
    @Default('') String message,
    String? commandId,
  }) = _DeviceCommandResult;

  /// Creates a result from wire JSON.
  factory DeviceCommandResult.fromJson(Map<String, dynamic> json) =>
      _$DeviceCommandResultFromJson(json);
}
