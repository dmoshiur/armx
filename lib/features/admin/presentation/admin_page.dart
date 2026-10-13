// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/breakpoints.dart';
import '../../../core/confirm/confirm_policy.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/armx_badge.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/armx_card.dart';
import '../../../core/widgets/armx_confirm_dialog.dart';
import '../../../core/widgets/armx_empty_state.dart';
import '../../../core/widgets/armx_error_state.dart';
import '../../../core/widgets/armx_loading_skeleton.dart';
import '../../../core/widgets/armx_status_dot.dart';
import '../../../data/models/admin.dart';
import '../../auth/application/auth_controller.dart';
import '../application/admin_controller.dart';
import 'widgets/admin_users_table.dart';

/// The admin dashboard.
///
/// ## Layout
///
/// Compact stacks the kill-switch above the account list; expanded puts the kill-switch in a
/// narrower left column so it stays visible while scrolling accounts. The kill-switch is
/// first on the page in every layout, because it is the control that exists for the moment
/// something is going wrong, and hunting for it is not acceptable then.
///
/// ## Rules
///
/// * The page is reachable only by admins — the router refuses the path for other roles and
///   the backend refuses the calls. Hiding a link is not a guard, so this screen does not
///   pretend to be one.
/// * Every value shown comes from the backend. Nothing is written optimistically: a status
///   that looks changed but is not would hide a real problem.
/// * An admin cannot demote or suspend themselves here, and the disabled buttons say why.
class AdminPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const AdminPage({super.key});

  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage> {
  bool _killBusy = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AdminUserRow>> users = ref.watch(adminUsersProvider);
    final String? currentEmail =
        ref.watch(authControllerProvider).user?.email;

    return Scaffold(
      backgroundColor: ArmxColors.of(context).background,
      appBar: AppBar(
        title: Text(context.l10n.adminTitle),
        actions: <Widget>[
          ArmxIconButton(
            icon: Icons.receipt_long_outlined,
            semanticLabel: context.l10n.adminAuditTitle,
            onPressed: () => context.go(Routes.adminAudit),
          ),
          ArmxIconButton(
            icon: Icons.toggle_on_outlined,
            semanticLabel: context.l10n.adminToolsTitle,
            onPressed: () => context.go(Routes.adminTools),
          ),
          ArmxIconButton(
            icon: Icons.refresh_rounded,
            semanticLabel: context.l10n.commonRefresh,
            onPressed: () {
              ref.read(adminUsersProvider.notifier).refresh();
              ref.read(killSwitchProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: PageBody(
        children: <Widget>[
          Text(
            context.l10n.adminSubtitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: Insets.lg),
          if (context.isExpanded)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(width: 360, child: _killSwitchCard()),
                const SizedBox(width: Insets.lg),
                Expanded(child: _usersCard(users, currentEmail)),
              ],
            )
          else ...<Widget>[
            _killSwitchCard(),
            const SizedBox(height: Insets.lg),
            _usersCard(users, currentEmail),
          ],
          const SizedBox(height: Insets.xxl),
        ],
      ),
    );
  }

  Widget _usersCard(AsyncValue<List<AdminUserRow>> users, String? currentEmail) {
    return ArmxCard(
      title: context.l10n.adminUsers,
      leading: const Icon(Icons.people_outline_rounded),
      action: TextButton(
        onPressed: () => context.go(Routes.adminAudit),
        child: Text(context.l10n.adminAuditTitle),
      ),
      child: switch (users) {
        AsyncLoading<List<AdminUserRow>>() => const ArmxSkeletonTable(rows: 6),
        AsyncError<List<AdminUserRow>>(:final Object error) => ArmxErrorState(
            error: error,
            compact: true,
            onRetry: () => ref.invalidate(adminUsersProvider),
          ),
        AsyncData<List<AdminUserRow>>(:final List<AdminUserRow> value) =>
          value.isEmpty
              ? ArmxEmptyState(
                  icon: Icons.people_outline_rounded,
                  title: context.l10n.adminUsersEmpty,
                  compact: true,
                )
              : AdminUsersTable(
                  users: value,
                  onChangeRole: (AdminUserRow user) =>
                      _changeRole(user, currentEmail),
                  onToggleStatus: (AdminUserRow user) => _toggleStatus(user),
                ),
      },
    );
  }

  Widget _killSwitchCard() {
    final AsyncValue<KillSwitchState> state = ref.watch(killSwitchProvider);

    return switch (state) {
      AsyncLoading<KillSwitchState>() => const ArmxSkeletonCard(lines: 4),
      AsyncError<KillSwitchState>(:final Object error) => ArmxErrorState(
          error: error,
          compact: true,
          onRetry: () => ref.invalidate(killSwitchProvider),
        ),
      AsyncData<KillSwitchState>(:final KillSwitchState value) => ArmxCard(
          tone: value.engaged ? ArmxCardTone.tinted : ArmxCardTone.surface,
          tint: value.engaged ? ArmxColors.of(context).danger : null,
          title: context.l10n.adminKillSwitch,
          leading: Icon(
            value.engaged
                ? Icons.pause_circle_filled_rounded
                : Icons.power_settings_new_rounded,
            color: value.engaged
                ? ArmxColors.of(context).dangerText
                : ArmxColors.of(context).textMuted,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ArmxStatusPill(
                status: value.engaged ? ArmxStatus.stopped : ArmxStatus.online,
                label: value.engaged
                    ? context.l10n.shellKillSwitchEngaged
                    : context.l10n.shellKillSwitchIdle,
                pulse: value.engaged,
              ),
              const SizedBox(height: Insets.md),
              Text(
                context.l10n.adminKillSwitchBody,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (value.engaged) ...<Widget>[
                const SizedBox(height: Insets.md),
                if (value.engagedBy != null)
                  ArmxDetailRow(
                    label: context.l10n.adminAuditActor,
                    value: value.engagedBy!,
                    monospace: true,
                    icon: Icons.person_outline_rounded,
                  ),
                if (value.engagedAt != null)
                  ArmxDetailRow(
                    label: context.l10n.alarmsTime,
                    value: value.engagedAt!.toLocal().toString(),
                    icon: Icons.schedule_rounded,
                  ),
                if (value.reason != null && value.reason!.isNotEmpty)
                  ArmxDetailRow(
                    label: context.l10n.adminAuditAction,
                    value: value.reason!,
                    icon: Icons.notes_rounded,
                  ),
              ],
              const SizedBox(height: Insets.lg),
              ArmxButton(
                // Engaging is confirmed here, unlike the shell's hold-to-engage button:
                // holding is itself the confirmation, a click is not.
                label: value.engaged
                    ? context.l10n.adminKillSwitchRelease
                    : context.l10n.adminKillSwitch,
                variant: value.engaged
                    ? ArmxButtonVariant.secondary
                    : ArmxButtonVariant.destructive,
                icon: value.engaged
                    ? Icons.play_arrow_rounded
                    : Icons.pause_circle_filled_rounded,
                loading: _killBusy,
                onPressed:
                    _killBusy ? null : () => _setKillSwitch(engaged: !value.engaged),
              ),
            ],
          ),
        ),
    };
  }

  Future<void> _setKillSwitch({required bool engaged}) async {
    final bool confirmed = await ConfirmPolicy.confirm(
      context,
      ConfirmPolicy.forAction(
        context,
        title: engaged
            ? context.l10n.adminKillSwitch
            : context.l10n.adminKillSwitchRelease,
        action: 'kill_switch',
        target: context.l10n.commonAll,
        parameters: <ConfirmParameter>[
          ConfirmParameter(
            label: 'engaged',
            value: '$engaged',
            monospace: true,
          ),
          const ConfirmParameter(label: 'scope', value: 'all_devices'),
        ],
        consequence: context.l10n.adminKillSwitchBody,
        confirmLabel: engaged
            ? context.l10n.adminKillSwitch
            : context.l10n.adminKillSwitchRelease,
      ),
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _killBusy = true);
    try {
      await ref
          .read(killSwitchProvider.notifier)
          .set(engaged: engaged, reason: 'Set from the admin dashboard');
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _killBusy = false);
      }
    }
  }

  Future<void> _changeRole(AdminUserRow user, String? currentEmail) async {
    final UserRole? next = await showModalBottomSheet<UserRole>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Text(
                context.l10n.adminPromoteRoleTitle(user.displayName),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final UserRole role in UserRole.values)
              ListTile(
                title: Text(roleLabel(context, role)),
                enabled: role != user.role,
                selected: role == user.role,
                leading: Icon(
                  role == user.role
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                ),
                onTap: role == user.role
                    ? null
                    : () => Navigator.of(sheetContext).pop(role),
              ),
            ListTile(
              title: Text(context.l10n.commonCancel),
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    );
    if (next == null || !mounted) {
      return;
    }

    final bool confirmed = await ConfirmPolicy.confirm(
      context,
      ConfirmPolicy.forAction(
        context,
        title: context.l10n.adminPromoteTitle(user.displayName),
        action: 'update_admin_user',
        target: user.email,
        parameters: <ConfirmParameter>[
          ConfirmParameter(label: 'user_id', value: user.id, monospace: true),
          ConfirmParameter(
            label: 'role',
            value: '${user.role.wire} -> ${next.wire}',
            monospace: true,
          ),
        ],
        consequence: context.l10n.adminPromoteBody,
        confirmLabel: context.l10n.adminPromote,
      ),
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await ref.read(adminUsersProvider.notifier).update(
            userId: user.id,
            role: next,
          );
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }

  Future<void> _toggleStatus(AdminUserRow user) async {
    final bool suspending = user.status != AccountStatus.suspended;

    // Suspending signs somebody out of every device: confirmed. Restoring access is not
    // destructive and is not.
    if (suspending) {
      final bool confirmed = await ConfirmPolicy.confirm(
        context,
        ConfirmPolicy.forAction(
          context,
          title: context.l10n.adminSuspendTitle(user.displayName),
          action: 'update_admin_user',
          target: user.email,
          parameters: <ConfirmParameter>[
            ConfirmParameter(label: 'user_id', value: user.id, monospace: true),
            ConfirmParameter(
              label: 'status',
              value: '${user.status.wire} -> ${AccountStatus.suspended.wire}',
              monospace: true,
            ),
          ],
          consequence: context.l10n.adminSuspendBody,
          confirmLabel: context.l10n.adminSuspend,
        ),
      );
      if (!confirmed || !mounted) {
        return;
      }
    }

    try {
      await ref.read(adminUsersProvider.notifier).update(
            userId: user.id,
            status: suspending ? AccountStatus.suspended : AccountStatus.active,
          );
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }
}
