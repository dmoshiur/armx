// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../../../../core/breakpoints.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/armx_badge.dart';
import '../../../../core/widgets/armx_button.dart';
import '../../../../core/widgets/armx_card.dart';
import '../../../../data/models/admin.dart';

/// The account list, as a table where there is room and as cards where there is not.
///
/// A seven-column table at 360 dp is unreadable, and the usual fix — a horizontal scroll with
/// no affordance — hides the actions on the right. So compact gets one card per account with
/// the same fields and the same buttons; nobody loses a control by being on a phone. From
/// medium up the real table appears, inside a scroll view for the columns that overflow.
///
/// An admin cannot act on their own row: the server refuses it, the buttons are disabled, and
/// the reason is written underneath. Hiding the buttons would make people wonder whether the
/// permission is missing.
class AdminUsersTable extends StatelessWidget {
  /// Creates the table.
  const AdminUsersTable({
    required this.users,
    required this.onChangeRole,
    required this.onToggleStatus,
    super.key,
  });

  /// The accounts.
  final List<AdminUserRow> users;

  /// Called when a role change is requested.
  final ValueChanged<AdminUserRow> onChangeRole;

  /// Called when suspend/activate is requested.
  final ValueChanged<AdminUserRow> onToggleStatus;

  @override
  Widget build(BuildContext context) {
    if (context.isCompact) {
      return Column(
        children: <Widget>[
          for (final AdminUserRow user in users) ...<Widget>[
            _UserCard(
              user: user,
              onChangeRole: () => onChangeRole(user),
              onToggleStatus: () => onToggleStatus(user),
            ),
            const SizedBox(height: Insets.md),
          ],
        ],
      );
    }

    final ArmxColors colors = ArmxColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 720),
        child: DataTable(
          headingTextStyle: text.labelLarge,
          dataTextStyle: text.bodyMedium,
          columnSpacing: Insets.xl,
          dividerThickness: 0.5,
          border: TableBorder(
            horizontalInside: BorderSide(color: colors.hairline),
          ),
          columns: <DataColumn>[
            DataColumn(label: Text(context.l10n.authNameLabel)),
            DataColumn(label: Text(context.l10n.authEmailLabel)),
            DataColumn(label: Text(context.l10n.adminRole)),
            DataColumn(label: Text(context.l10n.adminStatus)),
            DataColumn(label: Text(context.l10n.adminLinkedCount)),
            DataColumn(
              label: Text(context.l10n.adminLastActive),
              numeric: false,
            ),
            DataColumn(label: Text(context.l10n.commonEdit)),
          ],
          rows: <DataRow>[
            for (final AdminUserRow user in users)
              DataRow(
                cells: <DataCell>[
                  DataCell(
                    Row(
                      children: <Widget>[
                        Flexible(child: Text(user.displayName)),
                        if (user.isSelf) ...<Widget>[
                          const SizedBox(width: Insets.xs),
                          const Icon(Icons.person_pin_circle_outlined, size: 16),
                        ],
                      ],
                    ),
                  ),
                  DataCell(
                    SelectableText(user.email, style: text.bodySmall),
                  ),
                  DataCell(
                    ArmxBadge(
                      label: roleLabel(context, user.role),
                      tone: ArmxBadge.toneForRole(user.role.name),
                    ),
                  ),
                  DataCell(
                    ArmxBadge(
                      label: statusLabel(context, user.status),
                      tone: statusTone(user.status),
                    ),
                  ),
                  DataCell(Text('${user.linkedDeviceCount}')),
                  DataCell(
                    Text(
                      user.lastActiveAt?.toLocal().toString() ??
                          context.l10n.statusNever,
                      style: text.bodySmall,
                    ),
                  ),
                  DataCell(
                    Row(
                      children: <Widget>[
                        ArmxButton(
                          label: context.l10n.adminPromote,
                          variant: ArmxButtonVariant.secondary,
                          size: ArmxButtonSize.small,
                          onPressed: user.isSelf ? null : () => onChangeRole(user),
                        ),
                        const SizedBox(width: Insets.xs),
                        ArmxButton(
                          label: user.status == AccountStatus.suspended
                              ? context.l10n.adminActivate
                              : context.l10n.adminSuspend,
                          variant: user.status == AccountStatus.suspended
                              ? ArmxButtonVariant.primary
                              : ArmxButtonVariant.destructive,
                          size: ArmxButtonSize.small,
                          onPressed:
                              user.isSelf ? null : () => onToggleStatus(user),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onChangeRole,
    required this.onToggleStatus,
  });

  final AdminUserRow user;
  final VoidCallback onChangeRole;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    return ArmxCard(
      title: user.displayName,
      semanticLabel: '${user.displayName}. ${user.email}. '
          '${roleLabel(context, user.role)}. ${statusLabel(context, user.status)}',
      leading: const Icon(Icons.person_outline_rounded),
      trailing: ArmxBadge(
        label: roleLabel(context, user.role),
        tone: ArmxBadge.toneForRole(user.role.name),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SelectableText(user.email, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: Insets.sm),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: <Widget>[
              ArmxBadge(
                label: statusLabel(context, user.status),
                tone: statusTone(user.status),
              ),
              ArmxBadge(
                label: '${context.l10n.adminLinkedCount}: '
                    '${user.linkedDeviceCount}',
                tone: ArmxBadgeTone.neutral,
                icon: Icons.devices_rounded,
              ),
              ArmxBadge(
                label: user.lastActiveAt?.toLocal().toString() ??
                    context.l10n.statusNever,
                tone: ArmxBadgeTone.neutral,
                icon: Icons.schedule_rounded,
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: <Widget>[
              ArmxButton(
                label: context.l10n.adminPromote,
                variant: ArmxButtonVariant.secondary,
                size: ArmxButtonSize.small,
                onPressed: user.isSelf ? null : onChangeRole,
              ),
              ArmxButton(
                label: user.status == AccountStatus.suspended
                    ? context.l10n.adminActivate
                    : context.l10n.adminSuspend,
                variant: user.status == AccountStatus.suspended
                    ? ArmxButtonVariant.primary
                    : ArmxButtonVariant.destructive,
                size: ArmxButtonSize.small,
                onPressed: user.isSelf ? null : onToggleStatus,
              ),
            ],
          ),
          if (user.isSelf) ...<Widget>[
            const SizedBox(height: Insets.sm),
            Text(
              context.l10n.adminSelfNote,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// A role as a localized word.
String roleLabel(BuildContext context, UserRole role) => switch (role) {
      UserRole.admin => context.l10n.roleAdmin,
      UserRole.vip => context.l10n.roleVip,
      UserRole.user => context.l10n.roleUser,
    };

/// An account status as a localized word.
String statusLabel(BuildContext context, AccountStatus status) => switch (status) {
      AccountStatus.active => context.l10n.statusActive,
      AccountStatus.suspended => context.l10n.statusSuspended,
      AccountStatus.invited => context.l10n.statusInvited,
      AccountStatus.disabled => context.l10n.statusDisabled,
    };

/// The badge tone for an account status.
ArmxBadgeTone statusTone(AccountStatus status) => switch (status) {
      AccountStatus.active => ArmxBadgeTone.success,
      AccountStatus.suspended => ArmxBadgeTone.danger,
      AccountStatus.invited => ArmxBadgeTone.warning,
      AccountStatus.disabled => ArmxBadgeTone.neutral,
    };
