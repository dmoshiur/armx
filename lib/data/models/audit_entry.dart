// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/security/risk_tier.dart';
import 'converters.dart';

part 'audit_entry.freezed.dart';
part 'audit_entry.g.dart';

/// How an audited action ended.
enum AuditOutcome {
  /// Completed successfully.
  @JsonValue('SUCCESS')
  success,

  /// Attempted but failed.
  @JsonValue('FAILURE')
  failure,

  /// Refused by the risk policy or by an approver.
  @JsonValue('DENIED')
  denied,

  /// Still running / awaiting approval.
  @JsonValue('PENDING')
  pending,
}

/// A single immutable audit record rendered in the admin log viewer.
@freezed
abstract class AuditEntry with _$AuditEntry {
  /// Creates an audit entry.
  const factory AuditEntry({
    required String id,
    required DateTime at,
    required String actor,
    required String action,
    @Default('') String target,
    @JsonKey(fromJson: riskTierFromJson, toJson: riskTierToJson)
    @Default(RiskTier.low)
    RiskTier riskTier,
    @Default(AuditOutcome.success) AuditOutcome outcome,
    @Default('') String detail,
    String? deviceId,
    @Default(<String, String>{}) Map<String, String> metadata,
  }) = _AuditEntry;

  /// Creates an entry from wire JSON.
  factory AuditEntry.fromJson(Map<String, dynamic> json) => _$AuditEntryFromJson(json);

  const AuditEntry._();

  /// One-line summary used by the dashboard "recent activity" list.
  String get summary => target.isEmpty ? action : '$action · $target';
}

/// Filter/sort/paging options for `GET /audit`.
@freezed
abstract class AuditQuery with _$AuditQuery {
  /// Creates an audit query. All filters are optional and combine with AND.
  const factory AuditQuery({
    DateTime? from,
    DateTime? to,
    @JsonKey(fromJson: riskTierFromJson, toJson: riskTierToJson) RiskTier? riskTier,
    AuditOutcome? outcome,
    @Default('') String actor,
    @Default('') String search,
    @Default(50) int limit,
    @Default(0) int offset,
  }) = _AuditQuery;

  /// Creates a query from wire JSON.
  factory AuditQuery.fromJson(Map<String, dynamic> json) => _$AuditQueryFromJson(json);

  const AuditQuery._();

  /// Query-string parameters for the REST call.
  Map<String, dynamic> toQueryParameters() => <String, dynamic>{
        if (from != null) 'from': from!.toUtc().toIso8601String(),
        if (to != null) 'to': to!.toUtc().toIso8601String(),
        if (riskTier != null) 'risk_tier': riskTier!.wireName,
        if (outcome != null) 'outcome': outcome!.name.toUpperCase(),
        if (actor.isNotEmpty) 'actor': actor,
        if (search.isNotEmpty) 'search': search,
        'limit': limit,
        'offset': offset,
      };
}
