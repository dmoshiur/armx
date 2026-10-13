// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/breakpoints.dart';
import '../../../core/config/app_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/network/websocket_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/armx_badge.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/armx_card.dart';
import '../../../core/widgets/armx_empty_state.dart';
import '../../../core/widgets/armx_error_state.dart';
import '../../../core/widgets/armx_loading_skeleton.dart';
import '../../../core/widgets/armx_status_dot.dart';

/// What the app is actually talking to, and whether it is working.
///
/// Read-only by design: nothing here can change the configuration, because the
/// configuration is a build-time decision and a "fix it" button would only be able to lie
/// about it. What it *does* do is refuse to be quiet about the two things that mislead:
///
/// * a **mock** build says so at the top, in words, because a screen full of plausible
///   numbers with no backend behind it is the most expensive kind of confusion;
/// * **no token is ever displayed**, only the fact that preferences hold no credential —
///   which is the one check worth showing, because it is the failure that matters.
class SettingsDiagnosticsPage extends ConsumerWidget {
  /// Creates the page.
  const SettingsDiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppConfig config = ref.watch(appConfigProvider);
    final WebSocketClient socket = ref.watch(webSocketProvider);
    final AsyncValue<SocketStatus> status =
        ref.watch(_socketStatusProvider(socket.statuses));
    final AsyncValue<Map<String, Object?>> prefs =
        ref.watch(preferenceDiagnosticsProvider);

    return Scaffold(
      backgroundColor: ArmxColors.of(context).background,
      appBar: AppBar(
        title: Text(context.l10n.settingsDiagnostics),
        actions: <Widget>[
          ArmxIconButton(
            icon: Icons.refresh_rounded,
            semanticLabel: context.l10n.commonRefresh,
            onPressed: () => ref.invalidate(preferenceDiagnosticsProvider),
          ),
        ],
      ),
      body: PageBody(
        children: <Widget>[
          Text(
            context.l10n.settingsDiagnosticsBody,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: Insets.lg),
          if (config.useMockBackend) ...<Widget>[
            ArmxNotice(
              tone: ArmxBadgeToneLike.warning,
              title: context.l10n.commonSimulated,
              message: context.l10n.settingsDiagnosticsMockWarning,
            ),
            const SizedBox(height: Insets.lg),
          ],
          ArmxCard(
            title: context.l10n.settingsDiagnosticsConfig,
            leading: const Icon(Icons.tune_rounded),
            child: Column(
              children: <Widget>[
                for (final MapEntry<String, Object?> entry
                    in config.describe().entries)
                  ArmxDetailRow(
                    label: entry.key,
                    value: '${entry.value}',
                    monospace: true,
                  ),
                ArmxDetailRow(
                  label: 'build',
                  value: AppConfig.buildLabel,
                  monospace: true,
                  icon: Icons.tag_rounded,
                ),
                ArmxDetailRow(
                  label: 'version',
                  value: AppConfig.appVersion,
                  monospace: true,
                  icon: Icons.info_outline_rounded,
                ),
                ArmxDetailRow(
                  label: 'platform',
                  value: kIsWeb
                      ? 'web'
                      : defaultTargetPlatform.name,
                  monospace: true,
                  icon: Icons.devices_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),
          ArmxCard(
            title: context.l10n.settingsDiagnosticsTransport,
            leading: const Icon(Icons.cable_rounded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                switch (status) {
                  AsyncLoading<SocketStatus>() => const ArmxSkeletonCard(lines: 1),
                  AsyncError<SocketStatus>(:final Object error) => ArmxErrorState(
                      error: error,
                      compact: true,
                      onRetry: () => ref.invalidate(
                        _socketStatusProvider(socket.statuses),
                      ),
                    ),
                  AsyncData<SocketStatus>(:final SocketStatus value) =>
                    ArmxStatusPill(
                      status: value.isLive
                          ? ArmxStatus.online
                          : value.state == SocketState.offline
                              ? ArmxStatus.failed
                              : ArmxStatus.unknown,
                      label: value.state.name,
                      pulse: value.isLive,
                    ),
                },
                const SizedBox(height: Insets.md),
                ArmxDetailRow(
                  label: 'socket url',
                  value: config.webSocketUrl.toString(),
                  monospace: true,
                  icon: Icons.link_rounded,
                ),
                ArmxDetailRow(
                  label: context.l10n.settingsDiagnosticsDropped,
                  value: '${socket.droppedFrameCount}',
                  monospace: true,
                  icon: Icons.speed_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),
          ArmxCard(
            title: context.l10n.settingsDiagnosticsTokensNote,
            leading: const Icon(Icons.key_outlined),
            child: switch (prefs) {
              AsyncLoading<Map<String, Object?>>() =>
                const ArmxSkeletonCard(lines: 2),
              AsyncError<Map<String, Object?>>(:final Object error) =>
                ArmxErrorState(error: error, compact: true),
              AsyncData<Map<String, Object?>>(:final Map<String, Object?> value) =>
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ArmxDetailRow(
                      label: 'preference keys',
                      value: '${value['keys']}',
                      monospace: true,
                      icon: Icons.list_alt_rounded,
                    ),
                    const SizedBox(height: Insets.sm),
                    // The check that matters: a token in SharedPreferences would be a
                    // credential on disk in the clear.
                    ArmxStatusPill(
                      status: value['containsTokens'] == true
                          ? ArmxStatus.failed
                          : ArmxStatus.online,
                      label: value['containsTokens'] == true
                          ? context.l10n.settingsContrastFail
                          : context.l10n.settingsPermissionGranted,
                    ),
                    const SizedBox(height: Insets.sm),
                    Text(
                      context.l10n.settingsDiagnosticsTokensNote,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
            },
          ),
          const SizedBox(height: Insets.xxl),
        ],
      ),
    );
  }
}

/// Turns the socket's status stream into a watchable value.
final _socketStatusProvider = StreamProvider.family<SocketStatus, Stream<SocketStatus>>(
  (Ref ref, Stream<SocketStatus> stream) => stream,
);
