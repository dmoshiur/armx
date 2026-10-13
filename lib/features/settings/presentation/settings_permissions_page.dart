// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/breakpoints.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/armx_badge.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/armx_card.dart';
import '../../../core/widgets/armx_empty_state.dart';
import '../../../core/widgets/armx_error_state.dart';
import '../../../core/widgets/armx_loading_skeleton.dart';
import '../../../core/widgets/armx_status_dot.dart';
import '../../../l10n/generated/app_localizations.dart';

/// What this app can actually reach on this device.
///
/// The list is read from the platform rather than remembered from a previous answer: a
/// permission can be revoked in system settings at any moment, and a screen that says
/// "granted" while the camera is blocked is worse than no screen at all.
///
/// Three states are distinguished, because they need different actions:
///
/// * **granted** — nothing to do;
/// * **denied** — asking again may work, so [_PermissionRow] offers the request;
/// * **permanently denied** — the system will not prompt again, so the row sends the user to
///   system settings and says so.
///
/// A permission that cannot be reported on this platform (web, desktop) shows as unknown
/// with the reason, never as granted.
class SettingsPermissionsPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const SettingsPermissionsPage({super.key});

  @override
  ConsumerState<SettingsPermissionsPage> createState() =>
      _SettingsPermissionsPageState();
}

class _SettingsPermissionsPageState
    extends ConsumerState<SettingsPermissionsPage> {
  late Future<List<_PermissionReport>> _reports = _read();

  /// The permissions this app can ask for at all.
  static const List<_PermissionSpec> _specs = <_PermissionSpec>[
    _PermissionSpec(
      permission: Permission.camera,
      titleKey: _PermissionKey.camera,
      whyKey: _PermissionKey.cameraWhy,
    ),
    _PermissionSpec(
      permission: Permission.microphone,
      titleKey: _PermissionKey.microphone,
      whyKey: _PermissionKey.microphoneWhy,
    ),
    _PermissionSpec(
      permission: Permission.notification,
      titleKey: _PermissionKey.notifications,
      whyKey: _PermissionKey.notificationsWhy,
    ),
    _PermissionSpec(
      permission: Permission.systemAlertWindow,
      titleKey: _PermissionKey.overlay,
      whyKey: _PermissionKey.overlayWhy,
      androidOnly: true,
    ),
    _PermissionSpec(
      permission: Permission.ignoreBatteryOptimizations,
      titleKey: _PermissionKey.background,
      whyKey: _PermissionKey.backgroundWhy,
      androidOnly: true,
    ),
  ];

  Future<List<_PermissionReport>> _read() async {
    final List<_PermissionReport> reports = <_PermissionReport>[];
    for (final _PermissionSpec spec in _specs) {
      reports.add(await _report(spec));
    }
    return reports;
  }

  Future<_PermissionReport> _report(_PermissionSpec spec) async {
    if (spec.androidOnly && (kIsWeb || defaultTargetPlatform != TargetPlatform.android)) {
      return _PermissionReport(spec: spec, status: null, reason: _Reason.notApplicable);
    }
    if (kIsWeb) {
      return _PermissionReport(spec: spec, status: null, reason: _Reason.unsupported);
    }
    try {
      return _PermissionReport(spec: spec, status: await spec.permission.status);
    } catch (_) {
      // A plugin that cannot answer must not be reported as "denied": those are different
      // situations and the user would go looking for a switch that does not exist.
      return _PermissionReport(spec: spec, status: null, reason: _Reason.unsupported);
    }
  }

  Future<void> _refresh() async {
    setState(() => _reports = _read());
    await _reports;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArmxColors.of(context).background,
      appBar: AppBar(
        title: Text(context.l10n.settingsPermissionsTitle),
        actions: <Widget>[
          ArmxIconButton(
            icon: Icons.refresh_rounded,
            semanticLabel: context.l10n.commonRefresh,
            onPressed: _refresh,
          ),
        ],
      ),
      body: PageBody(
        children: <Widget>[
          Text(
            context.l10n.settingsPermissionsBody,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: Insets.md),
          // Explains the rule the app follows, before the user has to infer it from a list.
          ArmxNotice(
            tone: ArmxBadgeToneLike.info,
            message: context.l10n.settingsPermissionWhy,
          ),
          const SizedBox(height: Insets.lg),
          FutureBuilder<List<_PermissionReport>>(
            future: _reports,
            builder: (
              BuildContext context,
              AsyncSnapshot<List<_PermissionReport>> snapshot,
            ) {
              if (snapshot.hasError) {
                return ArmxErrorState(error: snapshot.error, onRetry: _refresh);
              }
              final List<_PermissionReport>? reports = snapshot.data;
              if (reports == null) {
                return const ArmxSkeletonCard(lines: 5);
              }
              return Column(
                children: <Widget>[
                  for (final _PermissionReport report in reports) ...<Widget>[
                    _PermissionRow(report: report, onChanged: _refresh),
                    const SizedBox(height: Insets.md),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: Insets.lg),
          ArmxButton(
            label: context.l10n.settingsPermissionsOpenSystem,
            variant: ArmxButtonVariant.secondary,
            icon: Icons.settings_outlined,
            onPressed: () => openAppSettings(),
          ),
          const SizedBox(height: Insets.xxl),
        ],
      ),
    );
  }
}

/// Which permission a row describes. Kept as an enum so the l10n lookup stays exhaustive.
enum _PermissionKey {
  camera,
  cameraWhy,
  microphone,
  microphoneWhy,
  notifications,
  notificationsWhy,
  overlay,
  overlayWhy,
  background,
  backgroundWhy,
}

class _PermissionSpec {
  const _PermissionSpec({
    required this.permission,
    required this.titleKey,
    required this.whyKey,
    this.androidOnly = false,
  });

  final Permission permission;
  final _PermissionKey titleKey;
  final _PermissionKey whyKey;
  final bool androidOnly;
}

class _PermissionReport {
  const _PermissionReport({required this.spec, this.status, this.reason});

  final _PermissionSpec spec;
  final PermissionStatus? status;
  final _Reason? reason;

  /// Row headline.
  String title(AppLocalizations l10n) => switch (spec.titleKey) {
        _PermissionKey.camera => l10n.settingsPermissionCamera,
        _PermissionKey.microphone => l10n.settingsPermissionMicrophone,
        _PermissionKey.notifications => l10n.settingsPermissionNotifications,
        _PermissionKey.overlay => l10n.settingsPermissionOverlay,
        _PermissionKey.background => l10n.settingsPermissionBackground,
        _PermissionKey.cameraWhy ||
        _PermissionKey.microphoneWhy ||
        _PermissionKey.notificationsWhy ||
        _PermissionKey.overlayWhy ||
        _PermissionKey.backgroundWhy =>
          l10n.statusUnknown,
      };

  /// Why the app asks for it. Each row says what *this* permission buys, so the list is
  /// read once rather than guessed at.
  String why(AppLocalizations l10n) => switch (spec.whyKey) {
        _PermissionKey.cameraWhy => l10n.settingsPermissionCameraWhy,
        _PermissionKey.microphoneWhy => l10n.settingsPermissionMicrophoneWhy,
        _PermissionKey.notificationsWhy => l10n.settingsPermissionNotificationsWhy,
        _PermissionKey.overlayWhy => l10n.settingsPermissionOverlayWhy,
        _PermissionKey.backgroundWhy => l10n.settingsPermissionBackgroundWhy,
        _PermissionKey.camera ||
        _PermissionKey.microphone ||
        _PermissionKey.notifications ||
        _PermissionKey.overlay ||
        _PermissionKey.background =>
          l10n.settingsPermissionWhy,
      };

  String stateLabel(AppLocalizations l10n) {
    if (reason == _Reason.notApplicable) {
      return l10n.settingsPermissionNotApplicable;
    }
    if (reason == _Reason.unsupported) {
      return l10n.statusUnknown;
    }
    return switch (status) {
      PermissionStatus.granted ||
      PermissionStatus.provisional ||
      PermissionStatus.limited =>
        l10n.settingsPermissionGranted,
      PermissionStatus.permanentlyDenied => l10n.settingsPermissionPermanentlyDenied,
      PermissionStatus.restricted => l10n.settingsPermissionRestricted,
      _ => l10n.settingsPermissionDenied,
    };
  }

  ArmxStatus dot(AppLocalizations l10n) {
    if (reason != null) {
      return ArmxStatus.unknown;
    }
    return switch (status) {
      PermissionStatus.granted ||
      PermissionStatus.provisional ||
      PermissionStatus.limited =>
        ArmxStatus.online,
      PermissionStatus.permanentlyDenied => ArmxStatus.failed,
      PermissionStatus.restricted => ArmxStatus.warning,
      _ => ArmxStatus.offline,
    };
  }

  bool get canAsk =>
      reason == null &&
      status != null &&
      status != PermissionStatus.granted &&
      status != PermissionStatus.permanentlyDenied &&
      status != PermissionStatus.restricted;

  bool get needsSystemSettings =>
      status == PermissionStatus.permanentlyDenied ||
      status == PermissionStatus.restricted;
}

enum _Reason { notApplicable, unsupported }

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.report, required this.onChanged});

  final _PermissionReport report;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String state = report.stateLabel(l10n);

    return ArmxCard(
      title: report.title(l10n),
      semanticLabel: '${report.title(l10n)}. $state',
      leading: Icon(_iconFor(report.spec.permission)),
      trailing: ArmxBadge(
        label: state,
        tone: switch (report.dot(l10n)) {
          ArmxStatus.online => ArmxBadgeTone.success,
          ArmxStatus.warning => ArmxBadgeTone.warning,
          ArmxStatus.failed => ArmxBadgeTone.danger,
          _ => ArmxBadgeTone.neutral,
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ArmxStatusDot(
            status: report.dot(l10n),
            label: state,
            compact: true,
          ),
          const SizedBox(height: Insets.sm),
          Text(
            report.why(l10n),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: Insets.md),
          if (report.canAsk)
            ArmxButton(
              label: l10n.settingsPermissionRequest,
              variant: ArmxButtonVariant.secondary,
              size: ArmxButtonSize.small,
              icon: Icons.lock_open_rounded,
              onPressed: () async {
                await report.spec.permission.request();
                await onChanged();
              },
            )
          else if (report.needsSystemSettings)
            ArmxButton(
              label: l10n.settingsPermissionsOpenSystem,
              variant: ArmxButtonVariant.secondary,
              size: ArmxButtonSize.small,
              icon: Icons.settings_outlined,
              onPressed: () => openAppSettings(),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(Permission permission) {
    if (permission == Permission.camera) {
      return Icons.photo_camera_outlined;
    }
    if (permission == Permission.microphone) {
      return Icons.mic_none_rounded;
    }
    if (permission == Permission.notification) {
      return Icons.notifications_none_rounded;
    }
    if (permission == Permission.systemAlertWindow) {
      return Icons.picture_in_picture_alt_outlined;
    }
    return Icons.battery_saver_outlined;
  }
}
