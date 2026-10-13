// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/breakpoints.dart';
import '../../../core/confirm/confirm_policy.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/armx_badge.dart';
import '../../../core/widgets/armx_confirm_dialog.dart';
import '../../../core/widgets/armx_empty_state.dart';
import '../../../core/widgets/armx_error_state.dart';
import '../../../core/widgets/armx_loading_skeleton.dart';
import '../../../core/widgets/armx_text_field.dart';
import '../../../data/models/admin.dart';
import '../application/admin_controller.dart';

/// Which capabilities the assistant may use.
///
/// A switch here decides whether the assistant can act at all, so each one states what it
/// enables and what its risk tier is, and the row shows the tier rather than hiding it in
/// documentation nobody reads.
///
/// **Turning a tool off applies immediately. Turning one back on is confirmed**, because the
/// tool was switched off for a reason and re-arming it should be a decision rather than a
/// slip of the thumb. Both directions are reported in place; the switch follows the backend's
/// answer, never the tap.
class ToolTogglesPage extends ConsumerWidget {
  /// Creates the page.
  const ToolTogglesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ToolToggle>> toggles = ref.watch(toolTogglesProvider);
    final int enabled = (toggles.value ?? const <ToolToggle>[])
        .where((ToolToggle tool) => tool.enabled)
        .length;

    return Scaffold(
      backgroundColor: ArmxColors.of(context).background,
      appBar: AppBar(
        title: Text(context.l10n.adminToolsTitle),
        actions: <Widget>[
          ArmxIconButton(
            icon: Icons.refresh_rounded,
            semanticLabel: context.l10n.commonRefresh,
            onPressed: () => ref.invalidate(toolTogglesProvider),
          ),
        ],
      ),
      body: PageBody(
        children: <Widget>[
          Text(
            context.l10n.adminToolsSubtitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: Insets.md),
          if (toggles.hasValue)
            ArmxBadge(
              label: context.l10n.adminToolsEnabledCount(enabled, toggles.value!.length),
              tone: enabled == 0 ? ArmxBadgeTone.danger : ArmxBadgeTone.accent,
              icon: Icons.tune_rounded,
            ),
          const SizedBox(height: Insets.lg),
          switch (toggles) {
            AsyncLoading<List<ToolToggle>>() => const ArmxSkeletonCard(lines: 6),
            AsyncError<List<ToolToggle>>(:final Object error) => ArmxErrorState(
                error: error,
                onRetry: () => ref.invalidate(toolTogglesProvider),
              ),
            AsyncData<List<ToolToggle>>(:final List<ToolToggle> value) =>
              value.isEmpty
                  ? ArmxEmptyState(
                      icon: Icons.tune_rounded,
                      title: context.l10n.adminToolsEmpty,
                      message: context.l10n.adminToolsEmptyBody,
                    )
                  : Column(
                      children: <Widget>[
                        for (final ToolToggle tool in value) ...<Widget>[
                          _ToolRow(tool: tool),
                          const SizedBox(height: Insets.sm),
                        ],
                      ],
                    ),
          },
        ],
      ),
    );
  }
}

class _ToolRow extends ConsumerStatefulWidget {
  const _ToolRow({required this.tool});

  final ToolToggle tool;

  @override
  ConsumerState<_ToolRow> createState() => _ToolRowState();
}

class _ToolRowState extends ConsumerState<_ToolRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final ToolToggle tool = widget.tool;
    final ArmxColors colors = ArmxColors.of(context);

    return ArmxCard(
      tone: tool.enabled ? ArmxCardTone.surface : ArmxCardTone.tinted,
      tint: tool.enabled ? null : colors.warning,
      title: tool.name,
      semanticLabel:
          '${tool.name}, ${tool.enabled ? context.l10n.commonEnabled : context.l10n.commonDisabled}',
      leading: Icon(
        tool.enabled ? Icons.bolt_rounded : Icons.bolt_outlined,
        color: tool.enabled ? colors.accent : colors.textMuted,
      ),
      trailing: ArmxBadge(
        label: tool.enabled ? context.l10n.commonEnabled : context.l10n.commonDisabled,
        tone: tool.enabled ? ArmxBadgeTone.success : ArmxBadgeTone.neutral,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(tool.description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: Insets.sm),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.xs,
            children: <Widget>[
              ArmxBadge(
                label: tool.riskTierName.toUpperCase(),
                tone: ArmxBadge.toneForRisk(tool.riskTierName),
                icon: Icons.shield_outlined,
              ),
              // A tool the backend has blocked says so here; the switch below still moves,
              // because the backend, not the widget, owns the real state.
              if (tool.blockedReason != null)
                ArmxBadge(
                  label: context.l10n.adminToolsBlocked,
                  tone: ArmxBadgeTone.danger,
                  icon: Icons.block_rounded,
                ),
            ],
          ),
          if (tool.blockedReason != null) ...<Widget>[
            const SizedBox(height: Insets.sm),
            ArmxNotice(
              tone: ArmxBadgeToneLike.warning,
              message: tool.blockedReason!,
            ),
          ],
          const SizedBox(height: Insets.md),
          ArmxSwitchRow(
            title: context.l10n.adminToolsEnable,
            subtitle: tool.enabled
                ? context.l10n.adminToolsDisableHint
                : context.l10n.adminToolsEnableHint,
            value: tool.enabled,
            enabled: !_busy,
            onChanged: (bool value) => _set(value),
          ),
        ],
      ),
    );
  }

  Future<void> _set(bool enabled) async {
    // Enabling is confirmed; disabling is not. The message on failure leaves the switch where
    // the backend put it.
    if (enabled) {
      final bool confirmed = await ConfirmPolicy.confirm(
        context,
        ConfirmPolicy.forAction(
          context,
          title: context.l10n.adminToolsEnableTitle(widget.tool.name),
          action: 'update_tool_toggle',
          target: widget.tool.name,
          parameters: <ConfirmParameter>[
            ConfirmParameter(
              label: 'tool_id',
              value: widget.tool.id,
              monospace: true,
            ),
            ConfirmParameter(
              label: 'risk_tier',
              value: widget.tool.riskTierName.toUpperCase(),
              monospace: true,
            ),
            const ConfirmParameter(label: 'enabled', value: 'true', monospace: true),
          ],
          consequence: context.l10n.adminToolsEnableBody,
          confirmLabel: context.l10n.commonEnable,
        ),
      );
      if (!confirmed || !mounted) {
        return;
      }
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(toolTogglesProvider.notifier)
          .setEnabled(toolId: widget.tool.id, enabled: enabled);
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
