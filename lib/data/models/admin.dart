// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/security/risk_tier.dart';
import 'converters.dart';

part 'admin.freezed.dart';
part 'admin.g.dart';

/// Tools the assistant may use. Mirrors the admin panel toggles.
enum ToolId {
  /// Repository automation (issues, PRs, actions).
  @JsonValue('GITHUB')
  github,

  /// Mail drafting/sending.
  @JsonValue('MAIL')
  mail,

  /// MQTT publishing to devices and sites.
  @JsonValue('MQTT')
  mqtt,

  /// Database queries (read-only unless explicitly allowed).
  @JsonValue('DB')
  database,

  /// Shell / privileged system operations.
  @JsonValue('SYSTEM')
  system,

  /// Vision verifications (face/voice results, never raw templates).
  @JsonValue('VISION')
  vision,
}

/// A single tool switch in the admin panel.
@freezed
abstract class ToolToggle with _$ToolToggle {
  /// Creates a toggle.
  const factory ToolToggle({
    required ToolId id,
    required String label,
    @Default('') String description,
    @Default(false) bool enabled,
    @Default(false) bool connected,
    @JsonKey(fromJson: riskTierFromJson, toJson: riskTierToJson)
    @Default(RiskTier.medium)
    RiskTier maxRiskTier,
    @Default(true) bool requiresApproval,
  }) = _ToolToggle;

  /// Creates a toggle from wire JSON.
  factory ToolToggle.fromJson(Map<String, dynamic> json) => _$ToolToggleFromJson(json);
}

/// Global assistant + kill-switch state (`GET /admin/state`).
@freezed
abstract class AdminState with _$AdminState {
  /// Creates an admin state snapshot.
  const factory AdminState({
    @Default(true) bool assistantEnabled,
    @Default(false) bool killSwitchEngaged,
    @Default(<ToolToggle>[]) List<ToolToggle> tools,
    required DateTime updatedAt,
    @Default('') String engagedBy,
    @Default('') String engagedReason,
    @Default(0) int revokedDevices,
  }) = _AdminState;

  /// Creates a state from wire JSON.
  factory AdminState.fromJson(Map<String, dynamic> json) => _$AdminStateFromJson(json);

  const AdminState._();

  /// True when the assistant may run at all.
  bool get isOperational => assistantEnabled && !killSwitchEngaged;

  /// Enabled tools only.
  List<ToolToggle> get enabledTools =>
      tools.where((tool) => tool.enabled).toList(growable: false);
}

/// Outcome of `POST /admin/kill`.
@freezed
abstract class KillSwitchState with _$KillSwitchState {
  /// Creates a kill-switch state.
  const factory KillSwitchState({
    required bool engaged,
    required DateTime at,
    @Default('') String reason,
    @Default('') String actor,
    @Default(0) int socketsClosed,
  }) = _KillSwitchState;

  /// Creates a state from wire JSON.
  factory KillSwitchState.fromJson(Map<String, dynamic> json) =>
      _$KillSwitchStateFromJson(json);
}

/// A device/key that an administrator revoked.
@freezed
abstract class RevokedCredential with _$RevokedCredential {
  /// Creates a revoked credential record.
  const factory RevokedCredential({
    required String id,
    required String deviceId,
    required String label,
    required DateTime revokedAt,
    @Default('') String revokedBy,
  }) = _RevokedCredential;

  /// Creates a record from wire JSON.
  factory RevokedCredential.fromJson(Map<String, dynamic> json) =>
      _$RevokedCredentialFromJson(json);
}
