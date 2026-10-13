// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/breakpoints.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/armx_badge.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/armx_card.dart';
import '../../../core/widgets/armx_empty_state.dart';
import '../../../core/widgets/armx_error_state.dart';
import '../../../core/widgets/armx_loading_skeleton.dart';
import '../../../core/widgets/armx_status_dot.dart';
import '../../../core/widgets/armx_text_field.dart';
import '../../../data/models/admin.dart';
import '../application/admin_controller.dart';

/// The audit log: who did what, and what the backend answered.
///
/// The log is read-only and complete. Every row carries the five things needed to follow an
/// action up — actor, action, target, outcome, and the backend request id — and the detail
/// text is shown as text, never rendered as markup, because a log that executes its own
/// contents is an attack surface.
///
/// Actor and action are filtered on the server, where the data lives; outcome is filtered
/// here, and the page says so, so nobody assumes a server-side filter that is not there.
class AuditLogPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const AuditLogPage({super.key});

  @override
  ConsumerState<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends ConsumerState<AuditLogPage> {
  final TextEditingController _actor = TextEditingController();
  final TextEditingController _action = TextEditingController();

  @override
  void dispose() {
    _actor.dispose();
    _action.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuditFilter filter = ref.watch(auditFilterProvider);
    final AsyncValue<List<AuditEntry>> log = ref.watch(auditLogProvider);

    return Scaffold(
      backgroundColor: ArmxColors.of(context).background,
      appBar: AppBar(
        title: Text(context.l10n.adminAuditTitle),
        actions: <Widget>[
          ArmxIconButton(
            icon: Icons.refresh_rounded,
            semanticLabel: context.l10n.commonRefresh,
            onPressed: () => ref.invalidate(auditLogProvider),
          ),
        ],
      ),
      body: PageBody(
        children: <Widget>[
          ArmxCard(
            title: context.l10n.adminAuditFilters,
            leading: const Icon(Icons.filter_alt_outlined),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AdaptiveWrap(
                  children: <Widget>[
                    SizedBox(
                      width: 260,
                      child: ArmxTextField(
                        label: context.l10n.adminAuditActor,
                        hint: 'mohi@thamjj13.top',
                        controller: _actor,
                        onSubmitted: (String value) =>
                            ref.read(auditFilterProvider.notifier).setActor(value),
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: ArmxTextField(
                        label: context.l10n.adminAuditAction,
                        hint: 'set_light, web_deploy…',
                        controller: _action,
                        onSubmitted: (String value) =>
                            ref.read(auditFilterProvider.notifier).setAction(value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.md),
                Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.sm,
                  children: <Widget>[
                    for (final AuditOutcome outcome in AuditOutcome.values)
                      ArmxChip(
                        label: outcomeLabel(context, outcome),
                        selected: filter.outcome == outcome,
                        onSelected: (_) => ref
                            .read(auditFilterProvider.notifier)
                            .setOutcome(filter.outcome == outcome ? null : outcome),
                      ),
                  ],
                ),
                const SizedBox(height: Insets.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        // Where each filter is applied, stated rather than implied.
                        context.l10n.adminAuditFilterScope,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (!filter.isEmpty)
                      ArmxButton(
                        label: context.l10n.commonReset,
                        variant: ArmxButtonVariant.ghost,
                        size: ArmxButtonSize.small,
                        onPressed: () {
                          _actor.clear();
                          _action.clear();
                          ref.read(auditFilterProvider.notifier).clear();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),
          switch (log) {
            AsyncLoading<List<AuditEntry>>() => const ArmxSkeletonTable(rows: 8),
            AsyncError<List<AuditEntry>>(:final Object error) => ArmxErrorState(
                error: error,
                onRetry: () => ref.invalidate(auditLogProvider),
              ),
            AsyncData<List<AuditEntry>>(:final List<AuditEntry> value) =>
              value.isEmpty
                  ? ArmxEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: context.l10n.adminAuditEmpty,
                      message: context.l10n.adminAuditEmptyBody,
                    )
                  : Column(
                      children: <Widget>[
                        for (final AuditEntry entry in value) ...<Widget>[
                          _AuditRow(entry: entry),
                          const SizedBox(height: Insets.sm),
                        ],
                      ],
                    ),
          },
          const SizedBox(height: Insets.xxl),
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    return ArmxCard(
      dense: true,
      semanticLabel: '${entry.action}. ${outcomeLabel(context, entry.outcome)}. '
          '${entry.actorEmail}',
      title: entry.action,
      leading: Icon(
        switch (entry.outcome) {
          AuditOutcome.success => Icons.check_circle_outline_rounded,
          AuditOutcome.denied => Icons.block_outlined,
          AuditOutcome.failed => Icons.error_outline_rounded,
          AuditOutcome.pending => Icons.hourglass_empty_rounded,
        },
        color: ArmxStatusDot.colorFor(
          switch (entry.outcome) {
            AuditOutcome.success => ArmxStatus.online,
            AuditOutcome.denied => ArmxStatus.warning,
            AuditOutcome.failed => ArmxStatus.failed,
            AuditOutcome.pending => ArmxStatus.pending,
          },
          colors,
        ),
      ),
      trailing: ArmxBadge(
        label: outcomeLabel(context, entry.outcome),
        tone: switch (entry.outcome) {
          AuditOutcome.success => ArmxBadgeTone.success,
          AuditOutcome.denied => ArmxBadgeTone.warning,
          AuditOutcome.failed => ArmxBadgeTone.danger,
          AuditOutcome.pending => ArmxBadgeTone.neutral,
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            entry.occurredAt.toLocal().toString(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: Insets.xs),
          Row(
            children: <Widget>[
              Icon(Icons.person_outline_rounded, size: 16, color: colors.textMuted),
              const SizedBox(width: Insets.xs),
              Expanded(
                child: SelectableText(
                  entry.actorEmail,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          if (entry.riskTierName != null) ...<Widget>[
            const SizedBox(height: Insets.sm),
            ArmxBadge(
              label: entry.riskTierName!.toUpperCase(),
              tone: ArmxBadge.toneForRisk(entry.riskTierName),
              icon: Icons.shield_outlined,
            ),
          ],
          if (entry.targetLabel != null) ...<Widget>[
            const SizedBox(height: Insets.sm),
            // The target is verbatim: "which device" is the whole question an audit answers.
            SelectableText(
              entry.targetLabel!,
              style: ArmxTypography.mono(size: 12, color: colors.text),
            ),
          ],
          if (entry.detail != null) ...<Widget>[
            const SizedBox(height: Insets.xs),
            SelectableText(
              entry.detail!,
              style: ArmxTypography.mono(size: 12, color: colors.textMuted),
            ),
          ],
          if (entry.requestId != null) ...<Widget>[
            const SizedBox(height: Insets.sm),
            Text(
              '${context.l10n.adminAuditRequestId}: ${entry.requestId}',
              style: ArmxTypography.mono(size: 11, color: colors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// An outcome as a localized word.
String outcomeLabel(BuildContext context, AuditOutcome outcome) =>
    switch (outcome) {
      AuditOutcome.success => context.l10n.statusSuccess,
      AuditOutcome.denied => context.l10n.statusDenied,
      AuditOutcome.failed => context.l10n.statusFailed,
      AuditOutcome.pending => context.l10n.commonPending,
    };
