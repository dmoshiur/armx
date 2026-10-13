// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../auth/data/auth_models.dart';
import '../application/sessions_controller.dart';

/// The account, and every device signed in to it.
///
/// Sessions are the security surface of this page: the list is what tells an owner that
/// somebody else is signed in. So it is read from the server, the current session is marked,
/// and revoking is per row — or all others at once, with the count that really went reported
/// back. Signing out of this device is the one action here that ends the current session, and
/// it is confirmed.
class SettingsAccountPage extends ConsumerWidget {
  /// Creates the page.
  const SettingsAccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState auth = ref.watch(authControllerProvider);
    final AuthUser? user = auth.user;
    final AsyncValue<List<SessionInfo>> sessions = ref.watch(sessionsProvider);

    return Scaffold(
      backgroundColor: ArmxColors.of(context).background,
      appBar: AppBar(
        title: Text(context.l10n.settingsAccountTitle),
        actions: <Widget>[
          ArmxIconButton(
            icon: Icons.refresh_rounded,
            semanticLabel: context.l10n.commonRefresh,
            onPressed: () => ref.read(sessionsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: PageBody(
        children: <Widget>[
          Text(
            context.l10n.settingsAccountBody,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: Insets.lg),
          ArmxCard(
            title: user?.displayName ?? context.l10n.settingsAccountTitle,
            leading: const Icon(Icons.person_outline_rounded),
            trailing: user == null
                ? null
                : ArmxBadge(
                    label: switch (user.role) {
                      UserRole.admin => context.l10n.roleAdmin,
                      UserRole.vip => context.l10n.roleVip,
                      UserRole.user => context.l10n.roleUser,
                    },
                    tone: ArmxBadge.toneForRole(user.role.name),
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (user != null) ...<Widget>[
                  SelectableText(
                    user.email,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Insets.sm),
                  // Verification is a state, not a hint: an unverified account cannot sign
                  // in, so the badge says which it is.
                  ArmxStatusPill(
                    status: user.emailVerified
                        ? ArmxStatus.online
                        : ArmxStatus.warning,
                    label: user.emailVerified
                        ? context.l10n.authEmailVerified
                        : context.l10n.authEmailNotVerified,
                  ),
                  const SizedBox(height: Insets.lg),
                ],
                ArmxButton(
                  label: context.l10n.shellLogout,
                  variant: ArmxButtonVariant.destructive,
                  icon: Icons.logout_rounded,
                  loading: auth.busy,
                  onPressed: auth.busy ? null : () => _signOut(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),
          ArmxCard(
            title: context.l10n.settingsSessionsTitle,
            leading: const Icon(Icons.devices_other_outlined),
            action: (sessions.value ?? const <SessionInfo>[])
                    .where((SessionInfo s) => !s.current)
                    .isEmpty
                ? null
                : ArmxButton(
                    label: context.l10n.settingsSignOutOthers,
                    variant: ArmxButtonVariant.secondary,
                    size: ArmxButtonSize.small,
                    onPressed: () => _revokeOthers(context, ref),
                  ),
            child: switch (sessions) {
              AsyncLoading<List<SessionInfo>>() => const ArmxSkeletonCard(lines: 3),
              AsyncError<List<SessionInfo>>(:final Object error) => ArmxErrorState(
                  error: error,
                  compact: true,
                  onRetry: () => ref.invalidate(sessionsProvider),
                ),
              AsyncData<List<SessionInfo>>(:final List<SessionInfo> value) =>
                value.isEmpty
                    ? ArmxEmptyState(
                        icon: Icons.devices_other_outlined,
                        title: context.l10n.settingsSessionsEmpty,
                        compact: true,
                      )
                    : Column(
                        children: <Widget>[
                          for (final SessionInfo session in value) ...<Widget>[
                            _SessionRow(
                              session: session,
                              onRevoke: () => _revoke(context, ref, session),
                            ),
                            const Divider(height: Insets.xl),
                          ],
                        ],
                      ),
            },
          ),
          const SizedBox(height: Insets.xxl),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final bool confirmed = await ConfirmPolicy.confirm(
      context,
      ConfirmPolicy.forAction(
        context,
        title: context.l10n.shellLogoutConfirmTitle,
        action: 'logout',
        target: ref.read(authControllerProvider).user?.email ?? context.l10n.commonAll,
        consequence: context.l10n.authSignedOutBody,
        confirmLabel: context.l10n.shellLogout,
      ),
    );
    if (confirmed) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    SessionInfo session,
  ) async {
    final bool confirmed = await ConfirmPolicy.confirm(
      context,
      ConfirmPolicy.forAction(
        context,
        title: context.l10n.adminSessionRevokeTitle,
        action: 'revoke_sessions',
        target: session.deviceName,
        parameters: <ConfirmParameter>[
          ConfirmParameter(label: 'session_id', value: session.id, monospace: true),
          ConfirmParameter(label: 'platform', value: session.platform),
        ],
        consequence: context.l10n.adminSessionRevokeBody,
        confirmLabel: context.l10n.adminSessionRevoke,
      ),
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await ref.read(sessionsProvider.notifier).revoke(session.id);
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }

  Future<void> _revokeOthers(BuildContext context, WidgetRef ref) async {
    final bool confirmed = await ConfirmPolicy.confirm(
      context,
      ConfirmPolicy.forAction(
        context,
        title: context.l10n.settingsSignOutOthers,
        action: 'revoke_sessions',
        target: context.l10n.commonAll,
        parameters: const <ConfirmParameter>[
          ConfirmParameter(label: 'scope', value: 'all_except_current'),
        ],
        consequence: context.l10n.adminSessionRevokeBody,
        confirmLabel: context.l10n.settingsSignOutOthers,
      ),
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final int revoked = await ref.read(sessionsProvider.notifier).revokeOthers();
    if (!context.mounted) {
      return;
    }
    // The honest report: a count of what actually happened, not of what was attempted.
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(context.l10n.settingsSignOutOthersDone(revoked))),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.onRevoke});

  final SessionInfo session;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                session.deviceName,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            if (session.current)
              ArmxBadge(
                label: context.l10n.settingsSessionCurrent,
                tone: ArmxBadgeTone.accent,
                icon: Icons.check_circle_outline_rounded,
              ),
          ],
        ),
        const SizedBox(height: Insets.xs),
        ArmxStatusDot(
          status: session.current ? ArmxStatus.online : ArmxStatus.unknown,
          label: session.platform,
          compact: true,
        ),
        const SizedBox(height: Insets.sm),
        ArmxDetailRow(
          label: context.l10n.settingsSessionStarted,
          value: session.createdAt.toLocal().toString(),
          icon: Icons.play_circle_outline_rounded,
        ),
        ArmxDetailRow(
          label: context.l10n.settingsSessionLastUsed,
          value: session.lastUsedAt?.toLocal().toString() ??
              context.l10n.statusNever,
          icon: Icons.schedule_rounded,
        ),
        if (session.ipHint != null)
          ArmxDetailRow(
            label: 'IP',
            value: session.ipHint!,
            monospace: true,
            icon: Icons.lan_outlined,
          ),
        const SizedBox(height: Insets.sm),
        // The current session cannot be revoked from here: sign-out is the way out, and the
        // button explains that instead of disappearing.
        if (session.current)
          Text(
            context.l10n.settingsSessionCurrentNote,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.textMuted),
          )
        else
          ArmxButton(
            label: context.l10n.adminSessionRevoke,
            variant: ArmxButtonVariant.destructive,
            size: ArmxButtonSize.small,
            icon: Icons.logout_rounded,
            onPressed: onRevoke,
          ),
      ],
    );
  }
}
