// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/armx_colors.dart';
import '../../core/widgets/ambient_background.dart';
import '../../core/widgets/armx_controls.dart';
import '../../core/widgets/armx_tile.dart';
import '../../core/widgets/layout_blocks.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/glass_panel.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/models/announcement.dart';
import 'intercom_controller.dart';
import 'intercom_state.dart';

/// The Admin/Owner "Talk" screen.
///
/// Only devices that have turned announcements ON are listed — a non-consented device is
/// not shown as a greyed-out row, because a disabled send button would still imply the
/// Admin may aim at that person. It is simply absent, and the screen says why.
///
/// Delivery status is shown per send (`delivered`, `played`, `missed` when the device was
/// offline, `revoked` when consent was withdrawn mid-flight).
class AdminTalkPage extends ConsumerStatefulWidget {
  /// Creates the Talk screen.
  const AdminTalkPage({super.key});

  @override
  ConsumerState<AdminTalkPage> createState() => _AdminTalkPageState();
}

class _AdminTalkPageState extends ConsumerState<AdminTalkPage> {
  bool _broadcast = false;
  String? _targetUserId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);
    final state = ref.watch(intercomControllerProvider);
    final controller = ref.read(intercomControllerProvider.notifier);

    if (!state.enabled) {
      return Scaffold(
        appBar: ArmxAppBar(title: l10n.intercomTalkTitle),
        body: ArmxBackground(
          child: ArmxPageBody(
            child: EmptyView(
              title: l10n.intercomDisabledTitle,
              message: l10n.intercomDisabledBody,
              icon: Icons.record_voice_over_outlined,
              action: ArmxButton(
                label: l10n.intercomEnableFeature,
                onPressed: () => unawaited(controller.setEnabled(true)),
              ),
            ),
          ),
        ),
      );
    }

    final targets = state.targetable;

    return Scaffold(
      appBar: ArmxAppBar(
        title: l10n.intercomTalkTitle,
        actions: <Widget>[
          IconButton(
            tooltip: l10n.commonRefresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => unawaited(controller.refreshRecipients()),
          ),
        ],
      ),
      body: ArmxBackground(
        child: ArmxPageBody(
            scrollable: false,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              GlassPanel(
                accent: colors.cyan,
                child: Row(
                  children: <Widget>[
                    Icon(Icons.campaign_outlined, color: colors.cyan),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _broadcast ? l10n.intercomBroadcastBody : l10n.intercomDirectBody,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Switch(
                      value: _broadcast,
                      onChanged: (bool value) => setState(() {
                        _broadcast = value;
                        _targetUserId = null;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionHeader(
                title: l10n.intercomRecipientsTitle,
                subtitle: l10n.intercomRecipientsSubtitle,
              ),
              if (state.hasNoTargets)
                EmptyView(
                  title: l10n.intercomNoTargetsTitle,
                  message: l10n.intercomNoTargetsBody,
                  icon: Icons.volume_off_outlined,
                )
              else
                for (final recipient in targets)
                  ArmxTile(
                    title: recipient.displayName.isEmpty ? recipient.userId : recipient.displayName,
                    subtitle: recipient.online ? l10n.devicesOnline : l10n.devicesOffline,
                    leading: Icon(
                      recipient.online ? Icons.circle : Icons.circle_outlined,
                      color: recipient.online ? colors.green : colors.muted,
                      size: 14,
                    ),
                    trailing: _broadcast
                        ? StatusPill(
                            label: l10n.intercomIncluded,
                            tone: SeverityTone.info,
                            compact: true,
                          )
                        : StatusPill(
                            label: recipient.userId == _targetUserId
                                ? l10n.intercomSelected
                                : l10n.intercomTapToSelect,
                            tone: recipient.userId == _targetUserId
                                ? SeverityTone.success
                                : SeverityTone.neutral,
                            compact: true,
                          ),
                    onTap: _broadcast
                        ? null
                        : () => setState(() => _targetUserId = recipient.userId),
                  ),
              const SizedBox(height: 16),
              _TalkButton(
                recording: state.talk == TalkPhase.recording,
                enabled: _broadcast || _targetUserId != null,
                onStart: controller.startTalking,
                onSend: () => unawaited(controller.stopTalkingAndSend(
                      targetUserId: _broadcast ? '' : (_targetUserId ?? ''),
                    )),
                onCancel: controller.cancelTalking,
              ),
              if (state.talk == TalkPhase.sending)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: <Widget>[
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(l10n.intercomSending),
                    ],
                  ),
                ),
              if (state.lastOutcome != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: StatusPill(
                    label: l10n.intercomOutcomeLabel(state.lastOutcome!),
                    tone: switch (state.lastOutcome) {
                      'delivered' => SeverityTone.success,
                      'played' => SeverityTone.success,
                      'missed' => SeverityTone.warning,
                      'revoked' => SeverityTone.danger,
                      _ => SeverityTone.info,
                    },
                    icon: Icons.outbound_rounded,
                  ),
                ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    l10n.intercomSendBlocked(state.error!),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.red),
                  ),
                ),
              const SizedBox(height: 16),
              SectionHeader(
                title: l10n.intercomRecentTitle,
                subtitle: l10n.intercomRecentSubtitle,
                trailing: TextButton.icon(
                  onPressed: () => _export(context, controller),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: Text(l10n.intercomExportCsv),
                ),
              ),
              Expanded(
                child: state.log.isEmpty
                    ? EmptyView(
                        title: l10n.intercomLogEmptyTitle,
                        message: l10n.intercomLogEmptyBody,
                        icon: Icons.history_rounded,
                      )
                    : ListView.separated(
                        itemCount: state.log.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) => _LogRow(announcement: state.log[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _export(BuildContext context, IntercomController controller) {
    final csv = controller.exportCsv();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${context.l10n.intercomExportCsv} · ${csv.split('\n').length - 2} rows'),
      ),
    );
  }
}

/// Hold-to-talk button. Pressing and holding records; releasing sends.
class _TalkButton extends StatelessWidget {
  const _TalkButton({
    required this.recording,
    required this.enabled,
    required this.onStart,
    required this.onSend,
    required this.onCancel,
  });

  final bool recording;
  final bool enabled;
  final Future<bool> Function() onStart;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);

    return GestureDetector(
      onLongPressStart: (_) => unawaited(onStart()),
      onLongPressEnd: (_) => onSend(),
      onTap: recording ? onCancel : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
          color: recording ? colors.cyan : colors.border,
          width: recording ? 2 : 1,
        ),
          color: recording ? colors.cyan.withValues(alpha: 0.12) : colors.panel,
        ),
        child: Column(
          children: <Widget>[
            Icon(
              recording ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: recording ? colors.cyan : (enabled ? colors.text : colors.muted),
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              recording ? l10n.intercomReleaseToSend : l10n.intercomHoldToTalk,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);
    return ListTile(
      dense: true,
      leading: Icon(Icons.graphic_eq_rounded, color: colors.cyan),
      title: Text(
        '${announcement.fromName} → ${announcement.targetSummary}',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: Text(
        ArmxFormatters.time(announcement.createdAt),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.muted),
      ),
      trailing: StatusPill(
        label: l10n.intercomOutcomeLabel(announcement.status.name),
        tone: switch (announcement.status) {
          AnnouncementStatus.played => SeverityTone.success,
          AnnouncementStatus.delivered => SeverityTone.info,
          AnnouncementStatus.missed => SeverityTone.warning,
          AnnouncementStatus.revoked => SeverityTone.danger,
          AnnouncementStatus.queued => SeverityTone.neutral,
        },
        compact: true,
      ),
    );
  }
}
