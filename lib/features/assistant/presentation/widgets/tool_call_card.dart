// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/breakpoints.dart';
import '../../../../core/confirm/confirm_policy.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/security/risk_tier.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/armx_badge.dart';
import '../../../../core/widgets/armx_button.dart';
import '../../../../core/widgets/armx_card.dart';
import '../../../../core/widgets/armx_empty_state.dart';
import '../../../../core/widgets/armx_status_dot.dart';
import '../../../../data/models/assistant.dart';
import '../../application/assistant_controller.dart';

/// A proposed action, and the only place a proposal can be approved.
///
/// ## The rule this widget enforces
///
/// **No backend call happens before the user confirms.** Approving funnels through
/// [ConfirmPolicy], which returns immediately for LOW risk and shows [ArmxConfirmDialog]
/// for MEDIUM and HIGH. Only a `true` result reaches
/// [AssistantController.decideToolCall] — so a declined dialog performs no request, no
/// optimistic state change and no audit row.
///
/// ## What is shown, always
///
/// The tool's wire name, the target, and **every parameter verbatim** — monospace, in full,
/// no truncation and no "and 3 more". If the assistant would send
/// `{"room": "lab", "relay": 3}`, that is what the card says.
///
/// ## Responsive
///
/// The parameter block is a wrapping list rather than a two-column table, so a long target
/// or a large number of parameters never pushes the Approve/Decline buttons off screen at
/// 360 dp.
class ToolCallCard extends ConsumerWidget {
  /// Creates a card.
  const ToolCallCard({required this.call, super.key});

  /// The proposal.
  final ToolCall call;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ArmxColors colors = ArmxColors.of(context);
    final bool open = call.status.isOpen;
    final bool destructive = call.riskTier == RiskTier.high;

    final (ArmxStatus dot, String statusLabel) = switch (call.status) {
      ToolCallStatus.awaitingDecision => (ArmxStatus.pending, context.l10n.toolNeedsDecision),
      ToolCallStatus.running => (ArmxStatus.pending, context.l10n.toolRunning),
      ToolCallStatus.succeeded => (ArmxStatus.online, context.l10n.statusSuccess),
      ToolCallStatus.denied => (ArmxStatus.stopped, context.l10n.toolDenied),
      ToolCallStatus.failed => (ArmxStatus.failed, context.l10n.statusFailed),
      ToolCallStatus.expired => (ArmxStatus.unknown, context.l10n.toolExpired),
    };

    return ArmxCard(
      tone: open ? ArmxCardTone.tinted : ArmxCardTone.surface,
      tint: open && destructive ? colors.danger : null,
      semanticLabel: '${context.l10n.toolProposalTitle}. '
          '${call.tool}. ${call.summary}. '
          '${context.l10n.toolRiskLabel}: ${call.riskTier.label(context.l10n)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.l10n.toolProposalTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ArmxBadge(
                label: call.riskTier.label(context.l10n),
                tone: switch (call.riskTier) {
                  RiskTier.low => ArmxBadgeTone.success,
                  RiskTier.medium => ArmxBadgeTone.warning,
                  RiskTier.high => ArmxBadgeTone.danger,
                },
                tooltip: call.riskTier.explainFor(context),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          ArmxStatusDot(
            status: dot,
            label: statusLabel,
            compact: true,
            pulse: call.status == ToolCallStatus.running,
          ),
          const SizedBox(height: Insets.md),
          if (call.summary.isNotEmpty)
            Text(call.summary, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: Insets.md),
          ArmxDetailRow(
            label: context.l10n.confirmActionLabel,
            value: call.tool,
            monospace: true,
            icon: Icons.build_outlined,
          ),
          if (call.targetLabel != null)
            ArmxDetailRow(
              label: context.l10n.confirmTargetLabel,
              value: call.targetLabel!,
              icon: Icons.my_location_rounded,
            ),
          if (call.parameters.isNotEmpty) ...<Widget>[
            const SizedBox(height: Insets.sm),
            Text(
              context.l10n.toolParametersLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: Insets.xs),
            _ParameterList(parameters: call.parameters),
          ],
          if (call.resultMessage != null) ...<Widget>[
            const SizedBox(height: Insets.md),
            ArmxNotice(
              tone: call.status.isSuccess
                  ? ArmxBadgeToneLike.success
                  : ArmxBadgeToneLike.danger,
              message: call.resultMessage!,
            ),
          ],
          if (open) ...<Widget>[
            const SizedBox(height: Insets.md),
            Text(
              context.l10n.toolIdempotentNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: Insets.md),
            // Wrap, not Row: at 360 dp with a large text scale the two buttons stack
            // instead of overflowing.
            Wrap(
              spacing: Insets.md,
              runSpacing: Insets.sm,
              children: <Widget>[
                ArmxButton(
                  label: context.l10n.toolApprove,
                  variant: destructive
                      ? ArmxButtonVariant.destructive
                      : ArmxButtonVariant.primary,
                  icon: Icons.check_rounded,
                  onPressed: () => _approve(context, ref),
                ),
                ArmxButton(
                  label: context.l10n.toolDeny,
                  variant: ArmxButtonVariant.secondary,
                  icon: Icons.close_rounded,
                  // Declining needs no dialog: it performs nothing.
                  onPressed: () => ref
                      .read(assistantControllerProvider.notifier)
                      .decideToolCall(call, approve: false),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Confirms, then decides. A refused or dismissed dialog sends nothing at all.
  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final bool confirmed = await ConfirmPolicy.confirm(
      context,
      ConfirmPolicy.forToolCall(context, call),
    );
    if (!confirmed) {
      return;
    }
    await ref
        .read(assistantControllerProvider.notifier)
        .decideToolCall(call, approve: true);
  }
}

/// Every parameter, verbatim.
class _ParameterList extends StatelessWidget {
  const _ParameterList({required this.parameters});

  final Map<String, Object?> parameters;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(Insets.controlRadius),
        border: Border.all(color: colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final MapEntry<String, Object?> entry in parameters.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // The key is ordinary text; the value is monospace, because the value is
                  // the part that must be reproduced exactly.
                  Text(
                    '${entry.key} = ',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Expanded(
                    child: SelectableText(
                      _render(entry.value),
                      style: ArmxTypography.mono(
                        size: 12,
                        color: colors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Renders a value without guessing: maps and lists are shown in full, `null` is shown as
  /// `null` rather than as an empty string.
  String _render(Object? value) {
    if (value == null) {
      return 'null';
    }
    if (value is Map) {
      return value.entries
          .map((MapEntry<Object?, Object?> e) => '${e.key}: ${_render(e.value)}')
          .join(', ');
    }
    if (value is Iterable) {
      return value.map(_render).join(', ');
    }
    return '$value';
  }
}
