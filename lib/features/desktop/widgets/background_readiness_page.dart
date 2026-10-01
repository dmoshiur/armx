// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/armx_colors.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/armx_controls.dart';
import '../../../core/widgets/armx_tile.dart';
import '../../../core/widgets/layout_blocks.dart';
import '../../../core/widgets/status_pill.dart';
import '../desktop_controller.dart';
import 'hotkey_field.dart';
import '../desktop_state.dart';

/// "Is A.R.M.X really running in the background?" — the desktop readiness checklist.
///
/// Every row answers one question the user (or a support chat) will ask: does it start at
/// login, is the tray icon there, did the hotkey register, can it hear, can it see, and is
/// the OS allowed to notify. Each row carries a fix action instead of a dead end.
class BackgroundReadinessPage extends ConsumerWidget {
  /// Creates the readiness screen.
  const BackgroundReadinessPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);
    final state = ref.watch(desktopControllerProvider);
    final controller = ref.read(desktopControllerProvider.notifier);

    return Scaffold(
      appBar: ArmxAppBar(title: l10n.desktopReadinessTitle),
      body: ArmxBackground(
        child: ArmxPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              GlassPanel(
                accent: state.isReady ? colors.green : colors.amber,
                child: Row(
                  children: <Widget>[
                    Icon(
                      state.isReady ? Icons.verified_user_outlined : Icons.warning_amber_rounded,
                      color: state.isReady ? colors.green : colors.amber,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            state.isReady
                                ? l10n.desktopReadinessAllGood
                                : l10n.desktopReadinessAttention,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${state.platformLabel} · ${state.hotkey.describe()}',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: colors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionHeader(title: l10n.desktopReadinessChecklist),
              for (final item in state.readiness)
                ArmxTile(
                  title: _titleFor(context, item.id),
                  subtitle: '${_summaryFor(context, item)}'
                      '${item.fixHint == null ? '' : ' · ${_fixFor(context, item.id)}'}',
                  leading: Icon(
                    item.ok ? Icons.check_circle_outline : Icons.error_outline,
                    color: item.ok ? colors.green : colors.amber,
                  ),
                  trailing: StatusPill(
                    label: item.ok ? l10n.commonOk : l10n.commonFix,
                    tone: item.ok ? SeverityTone.success : SeverityTone.warning,
                    compact: true,
                  ),
                  onTap: item.actionId == null ? null : () => _runFix(context, ref, item.actionId!),
                ),
              const SizedBox(height: 16),
              SectionHeader(title: l10n.desktopHotkeyTitle),
              HotkeyRecorderField(
                current: state.hotkey.describe(),
                onRecorded: (descriptor) =>
                    controller.rebindHotkey(descriptor).then(
                  (status) => status == HotkeyStatus.registered,
                ),
              ),
              const SizedBox(height: 16),
              ArmxButton(
                label: l10n.desktopReadinessRecheck,
                icon: Icons.refresh_rounded,
                variant: ArmxButtonVariant.outlined,
                expanded: true,
                onPressed: controller.refreshDevices,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.desktopReadinessFootnote,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _titleFor(BuildContext context, String id) {
    final l10n = context.l10n;
    return switch (id) {
      'autostart' => l10n.desktopAutostartTitle,
      'tray' => l10n.desktopTrayRow,
      'hotkey' => l10n.desktopHotkeyTitle,
      'microphone' => l10n.desktopMicRow,
      'camera' => l10n.desktopCameraRow,
      _ => id,
    };
  }

  String _summaryFor(BuildContext context, ReadinessItem item) {
    final l10n = context.l10n;
    if (item.id == 'autostart') {
      return item.ok ? l10n.desktopAutostartOn : l10n.desktopAutostartOff;
    }
    if (item.id == 'tray') {
      return item.ok ? l10n.desktopTrayRunning : l10n.desktopTrayStopped;
    }
    if (item.id == 'hotkey') {
      return item.ok ? l10n.desktopHotkeyRegistered : l10n.desktopHotkeyTaken;
    }
    if (item.id == 'microphone') {
      return item.ok ? l10n.desktopMicPresent : l10n.desktopMicMissing;
    }
    if (item.id == 'camera') {
      return item.ok ? l10n.desktopCameraPresent : l10n.desktopCameraMissing;
    }
    return item.summary;
  }

  String _fixFor(BuildContext context, String id) {
    final l10n = context.l10n;
    return switch (id) {
      'autostart' => l10n.desktopAutostartFix,
      'hotkey' => l10n.desktopHotkeyFix,
      'microphone' => l10n.desktopMicFix,
      'camera' => l10n.desktopCameraFix,
      _ => l10n.commonFix,
    };
  }

  void _runFix(BuildContext context, WidgetRef ref, String actionId) {
    final controller = ref.read(desktopControllerProvider.notifier);
    switch (actionId) {
      case 'autostart':
        unawaited(controller.setLaunchAtLogin(true));
      case 'hotkey':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.desktopHotkeyHint)),
        );
      default:
        unawaited(controller.refreshDevices());
    }
  }
}
