// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:meta/meta.dart';

import '../../core/router/routes.dart';

/// A row in the admin user table.
@immutable
class AdminUserRow {
  /// Creates a row.
  const AdminUserRow({
    required this.id,
    required this.displayName,
    required this.email,
    required this.role,
    required this.status,
    this.lastActiveAt,
    this.linkedDeviceCount = 0,
    this.isSelf = false,
  });

  /// Identifier.
  final String id;

  /// Display name.
  final String displayName;

  /// Email.
  final String email;

  /// Role.
  final UserRole role;

  /// Account status.
  final AccountStatus status;

  /// Last activity, for the "last active" column.
  final DateTime? lastActiveAt;

  /// How many devices are linked.
  final int linkedDeviceCount;

  /// True for the signed-in admin. Self-demotion and self-suspension are blocked, so the
  /// row marks itself.
  final bool isSelf;

  /// Parses from the wire.
  factory AdminUserRow.fromJson(Map<String, Object?> json) => AdminUserRow(
        id: json['id']! as String,
        displayName: (json['display_name'] ?? '') as String,
        email: (json['email'] ?? '') as String,
        role: UserRole.fromWire(json['role'] as String?),
        status: AccountStatus.fromWire(json['status'] as String?),
        lastActiveAt: json['last_active_at'] is String
            ? DateTime.tryParse(json['last_active_at']! as String)
            : null,
        linkedDeviceCount: (json['linked_devices'] as num?)?.toInt() ?? 0,
        isSelf: json['self'] == true,
      );
}

/// Account lifecycle.
enum AccountStatus {
  /// Normal.
  active,

  /// Vitable but not yet confirmed.
  invited,

  /// Blocked from signing in. Existing sessions are revoked.
  suspended,

  /// Deactivated by the owner.
  disabled;

  /// Parses a wire value. Unknown values become [suspended] — the state that grants least.
  static AccountStatus fromWire(String? value) => switch (value?.toLowerCase()) {
        'active' || 'enabled' => AccountStatus.active,
        'invited' || 'pending' => AccountStatus.invited,
        'disabled' || 'deactivated' => AccountStatus.disabled,
        _ => AccountStatus.suspended,
      };

  /// The wire value.
  String get wire => switch (this) {
        AccountStatus.active => 'active',
        AccountStatus.invited => 'invited',
        AccountStatus.suspended => 'suspended',
        AccountStatus.disabled => 'disabled',
      };
}

/// A row in the audit log.
@immutable
class AuditEntry {
  /// Creates an entry.
  const AuditEntry({
    required this.id,
    required this.occurredAt,
    required this.actorEmail,
    required this.action,
    required this.outcome,
    this.targetLabel,
    this.riskTierName,
    this.detail,
    this.requestId,
  });

  /// Identifier.
  final String id;

  /// When it happened.
  final DateTime occurredAt;

  /// Who did it (`system` for backend-initiated rows).
  final String actorEmail;

  /// Machine action name, e.g. `set_light`, `unlink_device`, `kill_switch`.
  final String action;

  /// Result.
  final AuditOutcome outcome;

  /// What it acted on.
  final String? targetLabel;

  /// Risk tier the action carried, when it had one.
  final String? riskTierName;

  /// Extra detail. Rendered as monospace text; never as markup.
  final String? detail;

  /// Correlation id, so an audit row can be matched to a support ticket.
  final String? requestId;

  /// Parses from the wire.
  factory AuditEntry.fromJson(Map<String, Object?> json) => AuditEntry(
        id: json['id']! as String,
        occurredAt: json['at'] is String
            ? DateTime.parse(json['at']! as String)
            : DateTime.now().toUtc(),
        actorEmail: (json['actor'] ?? 'system') as String,
        action: (json['action'] ?? '') as String,
        outcome: AuditOutcome.fromWire(json['outcome'] as String?),
        targetLabel: json['target'] as String?,
        riskTierName: json['risk_tier'] as String?,
        detail: json['detail'] as String?,
        requestId: json['request_id'] as String?,
      );
}

/// What the audit row says happened.
enum AuditOutcome {
  /// Completed successfully.
  success,

  /// Refused by policy or by the user.
  denied,

  /// Attempted and failed.
  failed,

  /// Accepted, still running.
  pending;

  /// Parses a wire value. Unknown values become [pending] so the log never overstates
  /// what happened.
  static AuditOutcome fromWire(String? value) => switch (value?.toLowerCase()) {
        'success' || 'ok' => AuditOutcome.success,
        'denied' || 'rejected' => AuditOutcome.denied,
        'failed' || 'error' => AuditOutcome.failed,
        _ => AuditOutcome.pending,
      };
}

/// One capability the admin can switch on or off.
@immutable
class ToolToggle {
  /// Creates a toggle.
  const ToolToggle({
    required this.id,
    required this.name,
    required this.description,
    required this.enabled,
    required this.riskTierName,
    this.blockedReason,
  });

  /// Tool id, matching the backend's tool name.
  final String id;

  /// Display name.
  final String name;

  /// What the tool does, in one line.
  final String description;

  /// Whether the tool may run.
  final bool enabled;

  /// The tier the tool carries, so the admin sees the risk before enabling it.
  final String riskTierName;

  /// Why the toggle cannot be flipped right now (for example, the kill-switch is engaged).
  final String? blockedReason;

  /// Parses from the wire.
  factory ToolToggle.fromJson(Map<String, Object?> json) => ToolToggle(
        id: json['id']! as String,
        name: (json['name'] ?? '') as String,
        description: (json['description'] ?? '') as String,
        enabled: json['enabled'] == true,
        riskTierName: (json['risk_tier'] ?? 'low') as String,
        blockedReason: json['blocked_reason'] as String?,
      );

  /// Copy with changes.
  ToolToggle copyWith({
    String? id,
    String? name,
    String? description,
    bool? enabled,
    String? riskTierName,
    String? blockedReason,
  }) =>
      ToolToggle(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        enabled: enabled ?? this.enabled,
        riskTierName: riskTierName ?? this.riskTierName,
        blockedReason: blockedReason ?? this.blockedReason,
      );
}

/// The global kill-switch.
@immutable
class KillSwitchState {
  /// Creates a state.
  const KillSwitchState({
    required this.engaged,
    this.engagedAt,
    this.engagedBy,
    this.reason,
  });

  /// True when everything is stopped.
  final bool engaged;

  /// When it was engaged.
  final DateTime? engagedAt;

  /// Who engaged it.
  final String? engagedBy;

  /// Optional reason.
  final String? reason;

  /// Parses from the wire.
  factory KillSwitchState.fromJson(Map<String, Object?> json) => KillSwitchState(
        engaged: json['engaged'] == true,
        engagedAt: json['engaged_at'] is String
            ? DateTime.tryParse(json['engaged_at']! as String)
            : null,
        engagedBy: json['engaged_by'] as String?,
        reason: json['reason'] as String?,
      );

  /// Copy with changes.
  KillSwitchState copyWith({
    bool? engaged,
    DateTime? engagedAt,
    String? engagedBy,
    String? reason,
  }) =>
      KillSwitchState(
        engaged: engaged ?? this.engaged,
        engagedAt: engagedAt ?? this.engagedAt,
        engagedBy: engagedBy ?? this.engagedBy,
        reason: reason ?? this.reason,
      );
}

/// A signed-in session, shown on Settings → Account.
@immutable
class SessionInfo {
  /// Creates a session.
  const SessionInfo({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.createdAt,
    this.lastUsedAt,
    this.current = false,
    this.ipHint,
  });

  /// Identifier used to revoke it.
  final String id;

  /// Device name.
  final String deviceName;

  /// Platform string.
  final String platform;

  /// When the session started.
  final DateTime createdAt;

  /// Last use.
  final DateTime? lastUsedAt;

  /// True for the session making the request; it cannot revoke itself from this list.
  final bool current;

  /// A coarse location hint (`Shibganj, BD`). Never a precise address, and never an IP.
  final String? ipHint;

  /// Parses from the wire.
  factory SessionInfo.fromJson(Map<String, Object?> json) => SessionInfo(
        id: json['id']! as String,
        deviceName: (json['device_name'] ?? '') as String,
        platform: (json['platform'] ?? 'unknown') as String,
        createdAt: json['created_at'] is String
            ? DateTime.parse(json['created_at']! as String)
            : DateTime.now().toUtc(),
        lastUsedAt: json['last_used_at'] is String
            ? DateTime.tryParse(json['last_used_at']! as String)
            : null,
        current: json['current'] == true,
        ipHint: json['location_hint'] as String?,
      );
}
