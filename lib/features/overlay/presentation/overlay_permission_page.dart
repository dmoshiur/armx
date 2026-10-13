// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/breakpoints.dart';
import '../../../core/confirm/confirm_policy.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/armx_badge.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/armx_card.dart';
import '../../../core/widgets/armx_confirm_dialog.dart';
import '../../../core/widgets/armx_empty_state.dart';
import '../../../core/widgets/armx_status_dot.dart';
import '../application/overlay_bubble_controller.dart';
import 'widgets/bubble_preview.dart';

/// The floating assistant bubble: what it is, what it costs, and how to switch it on.
///
/// ## Why this is a page and not a switch
///
/// "Draw over other apps" is the most invasive permission on Android: it lets a window sit
/// on top of whatever the person is actually doing. So the screen does three things before
/// it asks for anything:
///
/// 1. **States what the bubble does and does not do** — it shows a small assistant handle,
///    it does not read the screen behind it, and it stops when the kill-switch is engaged.
/// 2. **Shows a mock-up** of the bubble so the permission is not abstract.
/// 3. **Keeps intent and fact apart.** The switch records that the owner wants it; the
///    "on screen now" line reflects whether a window is really attached, which the host
///    reports. If the host cannot attach one, the status says so instead of glowing green.
///
/// Turning it off needs no confirmation — removing a floating window is always safe.
class OverlayPermissionPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const OverlayPermissionPage({super.key});

  @override
  ConsumerState<OverlayPermissionPage> createState() =>
      _OverlayPermissionPageState();
}

class _OverlayPermissionPageState extends ConsumerState<OverlayPermissionPage> {
  @override
  void initState() {
    super.initState();
    // The permission can be revoked in system settings at any time, so it is read on entry
    // rather than trusted from a previous session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(overlayBubbleProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final OverlayBubbleState state = ref.watch(overlayBubbleProvider);
    final ArmxColors colors = ArmxColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(context.l10n.overlayTitle),
        actions: <Widget>[
          ArmxIconButton(
            icon: Icons.refresh_rounded,
            semanticLabel: context.l10n.commonRefresh,
            onPressed: () => ref.read(overlayBubbleProvider.notifier).refresh(),
          ),
        ],
      ),
      body: PageBody(
        children: <Widget>[
          Text(
            context.l10n.overlayLead,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: Insets.lg),

          // ---- Status --------------------------------------------------------
          ArmxCard(
            title: context.l10n.overlayStatusTitle,
            leading: const Icon(Icons.picture_in_picture_alt_outlined),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ArmxStatusPill(
                  status: switch (state.permission) {
                    BubblePermission.granted => ArmxStatus.online,
                    BubblePermission.denied => ArmxStatus.offline,
                    BubblePermission.permanentlyDenied => ArmxStatus.failed,
                    BubblePermission.unsupported => ArmxStatus.unknown,
                    BubblePermission.unknown => ArmxStatus.pending,
                  },
                  label: switch (state.permission) {
                    BubblePermission.granted => context.l10n.overlayPermissionGranted,
                    BubblePermission.denied => context.l10n.overlayPermissionDenied,
                    BubblePermission.permanentlyDenied =>
                      context.l10n.settingsPermissionPermanentlyDenied,
                    BubblePermission.unsupported =>
                      context.l10n.settingsPermissionNotApplicable,
                    BubblePermission.unknown => context.l10n.commonPending,
                  },
                  pulse: state.busy,
                ),
                const SizedBox(height: Insets.sm),
                // Intent and fact, side by side and separately labelled.
                ArmxStatusDot(
                  status: state.attached ? ArmxStatus.online : ArmxStatus.unknown,
                  label: state.attached
                      ? context.l10n.overlayRunning
                      : context.l10n.overlayNotRunning,
                  compact: true,
                ),
                if (state.failure != null) ...<Widget>[
                  const SizedBox(height: Insets.md),
                  ArmxNotice(
                    tone: ArmxBadgeToneLike.danger,
                    message: state.failure!,
                  ),
                ],
                const SizedBox(height: Insets.md),
                Text(
                  context.l10n.overlayExplain,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),

          // ---- Mock-up -------------------------------------------------------
          ArmxCard(
            title: context.l10n.overlayPreviewTitle,
            leading: const Icon(Icons.drag_indicator_rounded),
            child: BubblePreview(
              enabled: state.requested && state.attached,
            ),
          ),
          const SizedBox(height: Insets.lg),

          // ---- What it will not do -------------------------------------------
          ArmxCard(
            title: context.l10n.overlayLimitsTitle,
            leading: const Icon(Icons.shield_outlined),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Limit(icon: Icons.visibility_off_outlined, text: context.l10n.overlayLimitScreen),
                _Limit(icon: Icons.do_not_disturb_on_outlined, text: context.l10n.overlayLimitKillSwitch),
                _Limit(icon: Icons.mic_none_rounded, text: context.l10n.overlayLimitMic),
                _Limit(icon: Icons.password_rounded, text: context.l10n.overlayLimitTyping),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),

          // ---- Controls ------------------------------------------------------
          ArmxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ArmxSwitchRow(
                  title: context.l10n.overlayEnable,
                  subtitle: state.supported
                      ? context.l10n.overlayExplain
                      : context.l10n.settingsPermissionNotApplicable,
                  value: state.requested && state.permission == BubblePermission.granted,
                  enabled: state.supported && !state.busy,
                  onChanged: (bool value) => value ? _enable() : _disable(),
                ),
                const SizedBox(height: Insets.md),
                if (state.permission == BubblePermission.permanentlyDenied)
                  ArmxButton(
                    label: context.l10n.settingsPermissionsOpenSystem,
                    variant: ArmxButtonVariant.secondary,
                    icon: Icons.settings_outlined,
                    onPressed: () => openAppSettings(),
                  )
                else if (state.permission != BubblePermission.granted &&
                    state.supported)
                  ArmxButton(
                    label: context.l10n.overlayGrantAction,
                    icon: Icons.lock_open_rounded,
                    loading: state.busy,
                    onPressed: state.busy ? null : () => _requestOnly(),
                  ),
                const SizedBox(height: Insets.md),
                ArmxButton(
                  label: context.l10n.commonDone,
                  variant: ArmxButtonVariant.ghost,
                  onPressed: () => context.go(Routes.home),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xxl),
        ],
      ),
    );
  }

  Future<void> _requestOnly() async {
    await ref.read(overlayBubbleProvider.notifier).request();
  }

  Future<void> _enable() async {
    // Asking for the permission is confirmed first: it is a system-level grant, and the
    // dialog names exactly which one.
    final bool confirmed = await ConfirmPolicy.confirm(
      context,
      ConfirmPolicy.forAction(
        context,
        title: context.l10n.overlayGrantTitle,
        action: 'overlay_permission',
        target: 'SYSTEM_ALERT_WINDOW',
        parameters: const <ConfirmParameter>[
          ConfirmParameter(label: 'scope', value: 'draw_over_other_apps'),
          ConfirmParameter(label: 'bubble', value: 'assistant_handle'),
        ],
        consequence: context.l10n.overlayExplain,
        confirmLabel: context.l10n.overlayGrantAction,
      ),
    );
    if (!confirmed || !mounted) {
      return;
    }
    await ref.read(overlayBubbleProvider.notifier).enable();
    if (!mounted) {
      return;
    }
    if (ref.read(overlayBubbleProvider).permission != BubblePermission.granted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.overlayDeniedNotice)),
      );
    }
  }

  /// Switching off is unconditional and unconfirmed.
  Future<void> _disable() async {
    ref.read(overlayBubbleProvider.notifier).disable();
    await ref.read(overlayBubbleProvider.notifier).refresh();
  }
}

class _Limit extends StatelessWidget {
  const _Limit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: ArmxColors.of(context).successText),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
