// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/armx_colors.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/risk_tier_chip.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../data/models/chat.dart';

/// The Approve/Deny card the assistant raises for every MEDIUM/HIGH tool call.
///
/// Product rules rendered here (see `docs/api.md` § Risk tiers):
/// * LOW-tier calls never reach this card — they run immediately and arrive as
///   a plain tool-result line;
/// * MEDIUM/HIGH show the tier, the required verification and the parameters
///   read-only, and demand an explicit decision;
/// * approving a MEDIUM/HIGH call runs the [RiskPolicy] verification first,
///   which the controller reports back through [verifying];
/// * a denied or failed decision is final for that card — the buttons go away
///   and the outcome stays visible in the transcript.
class ToolApprovalCard extends StatelessWidget {
  /// Creates a card for [call].
  const ToolApprovalCard({
    required this.call,
    this.verifying = false,
    this.onApprove,
    this.onDeny,
    super.key,
  });

  /// The tool call this card represents.
  final ToolCall call;

  /// True while the verification gateway is capturing factors.
  final bool verifying;

  /// Approve handler; `null` hides the button.
  final VoidCallback? onApprove;

  /// Deny handler; `null` hides the button.
  final VoidCallback? onDeny;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final accent = colors.severity(RiskTierChip.describe(context, call.riskTier).$1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GlassPanel(
        accent: accent,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.build_outlined, size: 16, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    call.toolName,
                    style: textTheme.labelLarge?.copyWith(fontFamily: 'JetBrainsMono'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                RiskTierChip(tier: call.riskTier, compact: true),
              ],
            ),
            if (call.reason.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                call.reason,
                style: textTheme.bodySmall?.copyWith(color: colors.muted),
              ),
            ],
            if (call.parameters.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              _ParametersBlock(parameters: call.parameters),
            ],
            const SizedBox(height: 12),
            _statusArea(context),
            if (call.needsDecision) ...<Widget>[
              if (call.requiresVerification) ...<Widget>[
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Icon(Icons.verified_user_outlined, size: 13, color: colors.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.chatVerificationNeeded,
                        style: textTheme.labelSmall?.copyWith(color: colors.muted),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ArmxButton(
                      label: l10n.commonApprove,
                      icon: Icons.check_rounded,
                      onPressed: verifying ? null : onApprove,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ArmxButton(
                      label: l10n.commonDeny,
                      variant: ArmxButtonVariant.danger,
                      icon: Icons.close_rounded,
                      onPressed: verifying ? null : onDeny,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusArea(BuildContext context) {
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    if (verifying) {
      return _busy(context, l10n.chatVerifying);
    }
    switch (call.status) {
      case ToolCallStatus.pending:
        return const SizedBox.shrink();
      case ToolCallStatus.approved:
      case ToolCallStatus.running:
        return _busy(context, l10n.chatToolRunning);
      case ToolCallStatus.succeeded:
        return StatusPill(
          label: call.resultSummary.isNotEmpty ? call.resultSummary : l10n.chatToolSucceeded,
          tone: SeverityTone.success,
          icon: Icons.check_circle_outline,
          compact: true,
        );
      case ToolCallStatus.failed:
        return StatusPill(
          label: call.resultSummary.isNotEmpty ? call.resultSummary : l10n.chatToolFailed,
          tone: SeverityTone.danger,
          icon: Icons.error_outline,
          compact: true,
        );
      case ToolCallStatus.denied:
        return StatusPill(
          label: l10n.chatToolDenied,
          tone: SeverityTone.warning,
          icon: Icons.block,
          compact: true,
        );
      case ToolCallStatus.expired:
        return StatusPill(
          label: l10n.chatToolExpired,
          tone: SeverityTone.neutral,
          icon: Icons.timer_off_outlined,
          compact: true,
        );
    }
  }

  Widget _busy(BuildContext context, String label) {
    final colors = ArmxColors.of(context);
    return Row(
      children: <Widget>[
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: colors.cyan),
        ),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colors.cyan)),
      ],
    );
  }
}

/// Read-only rendering of the tool parameters (never editable, never a link).
class _ParametersBlock extends StatelessWidget {
  const _ParametersBlock({required this.parameters});

  /// Parameters as received on the wire.
  final Map<String, Object?> parameters;

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.chatToolParameters,
            style: textTheme.labelSmall?.copyWith(color: colors.muted),
          ),
          const SizedBox(height: 6),
          for (final entry in parameters.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${entry.key}: ${_formatValue(entry.value)}',
                style: textTheme.labelSmall?.copyWith(fontFamily: 'JetBrainsMono'),
              ),
            ),
        ],
      ),
    );
  }

  String _formatValue(Object? value) => switch (value) {
        null => '—',
        final Map<Object?, Object?> map => jsonEncode(
            <String, Object?>{for (final entry in map.entries) entry.key.toString(): entry.value},
          ),
        final List<Object?> list => jsonEncode(list),
        _ => value.toString(),
      };
}
