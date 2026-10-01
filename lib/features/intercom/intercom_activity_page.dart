// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/armx_colors.dart';
import '../../core/widgets/ambient_background.dart';
import '../../core/widgets/armx_controls.dart';
import '../../core/widgets/layout_blocks.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/models/announcement.dart';
import 'intercom_controller.dart';

/// The mutual activity log — the same rows the Admin sees, read-only, exportable.
///
/// Rule 3: whatever the Admin panel shows about this device, this screen shows too. There
/// is one shared audit table behind both, so the two views cannot drift: a row the Admin
/// can see for me is a row I can see about myself. The export is labelled exactly that way.
class IntercomActivityPage extends ConsumerWidget {
  /// Creates the page. [adminView] adds the per-user filter and the CSV button.
  const IntercomActivityPage({this.adminView = false, super.key});

  /// True when opened from the Admin panel (filterable + CSV, still read-only).
  final bool adminView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);
    final state = ref.watch(intercomControllerProvider);
    final controller = ref.read(intercomControllerProvider.notifier);

    return Scaffold(
      appBar: ArmxAppBar(
        title: adminView ? l10n.intercomAdminLogTitle : l10n.intercomMyActivityTitle,
        actions: <Widget>[
          if (adminView)
            IconButton(
              tooltip: l10n.intercomExportCsv,
              icon: const Icon(Icons.download_rounded),
              onPressed: () {
                final csv = controller.exportCsv();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.intercomExportNote(csv.split('\n').length - 2))),
                );
              },
            ),
        ],
      ),
      body: ArmxBackground(
        child: ArmxPageBody(
            scrollable: false,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (adminView)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    l10n.intercomExportNote(0),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.muted),
                  ),
                ),
              SectionHeader(
                title: l10n.intercomMyActivityTitle,
                subtitle: l10n.intercomMyActivitySubtitle,
              ),
              Expanded(
                child: state.log.isEmpty
                    ? EmptyView(
                        title: l10n.intercomLogEmptyTitle,
                        message: l10n.intercomLogEmptyBody,
                        icon: Icons.history_rounded,
                      )
                    : RefreshIndicator(
                        onRefresh: controller.refreshLog,
                        child: ListView.separated(
                          itemCount: state.log.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) =>
                              _AnnouncementRow(announcement: state.log[index]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementRow extends StatelessWidget {
  const _AnnouncementRow({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);
    return ListTile(
      dense: true,
      leading: Icon(Icons.campaign_outlined, color: colors.cyan),
      title: Text(
        l10n.intercomRowTitle(
          announcement.fromName,
          announcement.isBroadcast ? l10n.intercomEveryone : announcement.targetLabel,
        ),
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
