// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../data/models/admin.dart';

/// The account list.
class AdminUsersController extends AsyncNotifier<List<AdminUserRow>> {
  @override
  Future<List<AdminUserRow>> build() => ref.watch(armxApiProvider).adminUsers();

  /// Re-reads the list.
  Future<void> refresh() async {
    state = const AsyncValue<List<AdminUserRow>>.loading();
    state = await AsyncValue.guard(build);
  }

  /// Changes a role or a status.
  ///
  /// The backend's copy of the row replaces the local one; nothing is written optimistically,
  /// because a "suspended" that did not happen is worse than an error message.
  Future<void> update({
    required String userId,
    UserRole? role,
    AccountStatus? status,
  }) async {
    final AdminUserRow updated = await ref
        .read(armxApiProvider)
        .updateAdminUser(userId: userId, role: role, status: status);
    final List<AdminUserRow> current = state.value ?? const <AdminUserRow>[];
    state = AsyncValue<List<AdminUserRow>>.data(
      current
          .map((AdminUserRow row) => row.id == updated.id ? updated : row)
          .toList(growable: false),
    );
  }
}

/// The accounts.
final AsyncNotifierProvider<AdminUsersController, List<AdminUserRow>>
    adminUsersProvider =
    AsyncNotifierProvider<AdminUsersController, List<AdminUserRow>>(
  AdminUsersController.new,
);

/// Audit-log filters, held in one place so the page and the log agree.
class AuditFilter {
  /// Creates a filter.
  const AuditFilter({this.actorEmail, this.action, this.outcome});

  /// Actor email, or `null` for all.
  final String? actorEmail;

  /// Machine action name, or `null` for all.
  final String? action;

  /// Outcome, or `null` for all.
  final AuditOutcome? outcome;

  /// True when nothing is filtered.
  bool get isEmpty => actorEmail == null && action == null && outcome == null;

  /// Copy with changes.
  AuditFilter copyWith({
    String? actorEmail,
    String? action,
    AuditOutcome? outcome,
    bool clearActor = false,
    bool clearAction = false,
    bool clearOutcome = false,
  }) =>
      AuditFilter(
        actorEmail: clearActor ? null : (actorEmail ?? this.actorEmail),
        action: clearAction ? null : (action ?? this.action),
        outcome: clearOutcome ? null : (outcome ?? this.outcome),
      );
}

/// The active audit filter.
class AuditFilterController extends Notifier<AuditFilter> {
  @override
  AuditFilter build() => const AuditFilter();

  /// Sets the actor; an empty value clears it.
  void setActor(String value) => state = value.trim().isEmpty
      ? state.copyWith(clearActor: true)
      : state.copyWith(actorEmail: value.trim());

  /// Sets the action; an empty value clears it.
  void setAction(String value) => state = value.trim().isEmpty
      ? state.copyWith(clearAction: true)
      : state.copyWith(action: value.trim());

  /// Toggles an outcome filter.
  void setOutcome(AuditOutcome? outcome) => state = outcome == null
      ? state.copyWith(clearOutcome: true)
      : state.copyWith(outcome: outcome);

  /// Clears everything.
  void clear() => state = const AuditFilter();
}

/// The audit filter.
final NotifierProvider<AuditFilterController, AuditFilter> auditFilterProvider =
    NotifierProvider<AuditFilterController, AuditFilter>(
  AuditFilterController.new,
);

/// The audit log.
///
/// Actor and action are filtered by the server, which is where the data is. Outcome is
/// filtered here, and the page says so, because the endpoint does not take that parameter —
/// presenting it as a server-side filter would be a small lie with real consequences when
/// the log is long.
final FutureProvider<List<AuditEntry>> auditLogProvider =
    FutureProvider<List<AuditEntry>>((Ref ref) async {
  final AuditFilter filter = ref.watch(auditFilterProvider);
  final List<AuditEntry> entries = await ref.watch(armxApiProvider).auditLog(
        actorEmail: filter.actorEmail,
        action: filter.action,
      );
  final AuditOutcome? outcome = filter.outcome;
  if (outcome == null) {
    return entries;
  }
  return entries
      .where((AuditEntry entry) => entry.outcome == outcome)
      .toList(growable: false);
});

/// The assistant's tool toggles.
class ToolTogglesController extends AsyncNotifier<List<ToolToggle>> {
  @override
  Future<List<ToolToggle>> build() => ref.watch(armxApiProvider).toolToggles();

  /// Re-reads them.
  Future<void> refresh() async {
    state = const AsyncValue<List<ToolToggle>>.loading();
    state = await AsyncValue.guard(build);
  }

  /// Switches one tool on or off.
  Future<void> setEnabled({
    required String toolId,
    required bool enabled,
  }) async {
    final ToolToggle updated = await ref
        .read(armxApiProvider)
        .setToolEnabled(toolId: toolId, enabled: enabled);
    final List<ToolToggle> current = state.value ?? const <ToolToggle>[];
    state = AsyncValue<List<ToolToggle>>.data(
      current
          .map((ToolToggle tool) => tool.id == updated.id ? updated : tool)
          .toList(growable: false),
    );
  }
}

/// The tool toggles.
final AsyncNotifierProvider<ToolTogglesController, List<ToolToggle>>
    toolTogglesProvider =
    AsyncNotifierProvider<ToolTogglesController, List<ToolToggle>>(
  ToolTogglesController.new,
);

/// The global kill-switch.
///
/// Read from the backend, never assumed. The behaviour worth stating: a failed change leaves
/// the previous state in place, so the UI can say the switch did *not* move.
class KillSwitchController extends AsyncNotifier<KillSwitchState> {
  @override
  Future<KillSwitchState> build() => ref.watch(armxApiProvider).killSwitchState();

  /// Re-reads it.
  Future<void> refresh() async {
    state = const AsyncValue<KillSwitchState>.loading();
    state = await AsyncValue.guard(build);
  }

  /// Engages or releases it, adopting whatever the backend returns.
  Future<KillSwitchState> set({required bool engaged, String reason = ''}) async {
    final KillSwitchState next = await ref
        .read(armxApiProvider)
        .setKillSwitch(engaged: engaged, reason: reason);
    state = AsyncValue<KillSwitchState>.data(next);
    return next;
  }
}

/// The kill-switch state.
final AsyncNotifierProvider<KillSwitchController, KillSwitchState>
    killSwitchProvider =
    AsyncNotifierProvider<KillSwitchController, KillSwitchState>(
  KillSwitchController.new,
);
