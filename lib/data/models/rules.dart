// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/security/risk_tier.dart';
import 'converters.dart';

part 'rules.freezed.dart';
part 'rules.g.dart';

/// Activity classes the OS reports (and that rule triggers can match).
enum ActivityKind {
  /// Stationary.
  @JsonValue('STILL')
  still,

  /// Walking.
  @JsonValue('WALKING')
  walking,

  /// Running.
  @JsonValue('RUNNING')
  running,

  /// Cycling.
  @JsonValue('ON_BICYCLE')
  cycling,

  /// In a vehicle.
  @JsonValue('IN_VEHICLE')
  driving,

  /// Unknown or permission missing.
  @JsonValue('UNKNOWN')
  unknown,
}

/// What starts a rule.
enum RuleTriggerType {
  /// Current activity equals a value.
  @JsonValue('ACTIVITY_IS')
  activityIs,

  /// Entered a geofence.
  @JsonValue('GEOFENCE_ENTER')
  geofenceEnter,

  /// Left a geofence.
  @JsonValue('GEOFENCE_EXIT')
  geofenceExit,

  /// Local time window.
  @JsonValue('TIME_WINDOW')
  timeWindow,

  /// A device reached a state.
  @JsonValue('DEVICE_STATE')
  deviceState,
}

/// What a rule does when it fires.
enum RuleActionType {
  /// Send a command to a device.
  @JsonValue('DEVICE_COMMAND')
  deviceCommand,

  /// Activate a scene.
  @JsonValue('SCENE')
  scene,

  /// Raise a local notification.
  @JsonValue('NOTIFY')
  notify,

  /// Prepare an unlock (still requires HIGH verification in the unlock module).
  @JsonValue('UNLOCK_PREPARE')
  unlockPrepare,

  /// Ask the assistant to speak a prompt. Only possible when AI is enabled.
  @JsonValue('ASSISTANT_PROMPT')
  assistantPrompt,
}

/// Kind of place a geofence represents.
enum GeofenceKind {
  /// Home.
  @JsonValue('HOME')
  home,

  /// Work.
  @JsonValue('WORK')
  work,

  /// Anything else.
  @JsonValue('CUSTOM')
  custom,
}

/// A circular geofence around a point.
@freezed
abstract class Geofence with _$Geofence {
  /// Creates a geofence.
  const factory Geofence({
    required String id,
    required String label,
    required double latitude,
    required double longitude,
    @Default(150) double radiusMeters,
    @Default(GeofenceKind.custom) GeofenceKind kind,
    @Default(true) bool enabled,
  }) = _Geofence;

  /// Creates a geofence from wire JSON.
  factory Geofence.fromJson(Map<String, dynamic> json) => _$GeofenceFromJson(json);

  const Geofence._();

  /// Rough containment test (planar approximation, good enough at fence radii).
  ///
  /// A precise implementation would use `geolocator`'s `distanceBetween`, which is what
  /// the activity repository uses for real fixes.
  bool containsApprox(double lat, double lon) {
    const metersPerDegreeLat = 111320.0;
    final dLat = (lat - latitude) * metersPerDegreeLat;
    final dLon = (lon - longitude) *
        metersPerDegreeLat *
        (0.017453292519943295 * latitude).abs().clamp(0.01, 1.0);
    return (dLat * dLat + dLon * dLon).abs() <= radiusMeters * radiusMeters;
  }
}

/// A single WHEN/THEN rule.
@freezed
abstract class AutomationRule with _$AutomationRule {
  /// Creates a rule.
  const factory AutomationRule({
    required String id,
    required String name,
    required RuleTriggerType triggerType,
    required RuleActionType actionType,
    @Default(true) bool enabled,
    @Default(false) bool dryRun,
    @JsonKey(fromJson: riskTierFromJson, toJson: riskTierToJson)
    @Default(RiskTier.medium)
    RiskTier riskTier,
    @JsonKey(fromJson: objectMapFromJson) @Default(<String, Object?>{}) Map<String, Object?> triggerParams,
    @JsonKey(fromJson: objectMapFromJson) @Default(<String, Object?>{}) Map<String, Object?> actionParams,
    String? geofenceId,
    String? deviceId,
    DateTime? lastRunAt,
    @Default(0) int runCount,
  }) = _AutomationRule;

  /// Creates a rule from wire JSON.
  factory AutomationRule.fromJson(Map<String, dynamic> json) => _$AutomationRuleFromJson(json);

  const AutomationRule._();

  /// Human readable "WHEN …" fragment for the rule list.
  String get whenLabel => switch (triggerType) {
        RuleTriggerType.activityIs => 'activity is ${triggerParams['activity'] ?? '?'}',
        RuleTriggerType.geofenceEnter => 'entering ${triggerParams['geofence'] ?? 'geofence'}',
        RuleTriggerType.geofenceExit => 'leaving ${triggerParams['geofence'] ?? 'geofence'}',
        RuleTriggerType.timeWindow => 'between ${triggerParams['from'] ?? '?'} and ${triggerParams['to'] ?? '?'}',
        RuleTriggerType.deviceState =>
          '${triggerParams['device'] ?? 'device'} is ${triggerParams['state'] ?? '?'}',
      };

  /// Human readable "THEN …" fragment for the rule list.
  String get thenLabel => switch (actionType) {
        RuleActionType.deviceCommand =>
          '${actionParams['command'] ?? 'command'} on ${actionParams['device'] ?? 'device'}',
        RuleActionType.scene => 'activate scene ${actionParams['scene'] ?? '?'}',
        RuleActionType.notify => 'notify "${actionParams['title'] ?? 'me'}"',
        RuleActionType.unlockPrepare => 'prepare unlock for ${actionParams['target'] ?? 'target'}',
        RuleActionType.assistantPrompt => 'ask the assistant to say "${actionParams['text'] ?? '…'}"',
      };
}

/// Latest activity snapshot shown on the activity screen.
@freezed
abstract class ActivitySnapshot with _$ActivitySnapshot {
  /// Creates a snapshot.
  const factory ActivitySnapshot({
    required ActivityKind kind,
    @Default(0) double confidence,
    required DateTime at,
    @Default(false) bool permissionGranted,
    @Default('') String source,
  }) = _ActivitySnapshot;

  /// Creates a snapshot from wire JSON.
  factory ActivitySnapshot.fromJson(Map<String, dynamic> json) =>
      _$ActivitySnapshotFromJson(json);
}

/// Dry-run evaluation result for a rule (the "dry-run switch" in the builder).
@freezed
abstract class RuleDryRunResult with _$RuleDryRunResult {
  /// Creates a dry-run result.
  const factory RuleDryRunResult({
    required String ruleId,
    required bool wouldFire,
    required DateTime at,
    @Default(<String>[]) List<String> steps,
    @Default('') String blockedReason,
  }) = _RuleDryRunResult;

  /// Creates a result from wire JSON.
  factory RuleDryRunResult.fromJson(Map<String, dynamic> json) =>
      _$RuleDryRunResultFromJson(json);
}
