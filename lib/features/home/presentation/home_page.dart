// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/breakpoints.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/armx_card.dart';
import '../../../core/widgets/armx_empty_state.dart';
import '../../../core/widgets/armx_error_state.dart';
import '../../../core/widgets/armx_loading_skeleton.dart';
import '../../../core/widgets/armx_status_dot.dart';
import '../../../data/api/armx_api.dart';
import '../../../data/models/alarm.dart';
import '../../../data/models/device.dart';
import '../../../data/models/guest.dart';
import '../../alarms/application/alarms_controller.dart';
import '../../auth/application/auth_controller.dart';
import '../../greeter/application/greeter_controller.dart';
import '../../shell/presentation/widgets/kill_switch_button.dart';
import '../../smarthome/application/smart_home_controller.dart';

/// The dashboard.
///
/// Answers "what is the state of the estate" in one screen: device health, the next alarm,
/// the greeter camera, and the kill-switch within one hold. Every figure comes from a
/// provider that reads the backend — there is no placeholder that could be mistaken for
/// live data, and a failed read renders as an error with a retry rather than as zero.
class HomePage extends ConsumerWidget {
  /// Creates the page.
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ArmxColors colors = ArmxColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(context.l10n.navDashboard),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.only(end: Insets.md),
            child: KillSwitchButton(
              // A kill-switch changes what the backend will accept, so the device list is
              // re-read rather than left showing pre-switch state.
              onChanged: () => ref.invalidate(smartHomeProvider),
            ),
          ),
        ],
      ),
      body: PageBody(
        children: <Widget>[
          _Greeting(name: ref.watch(authControllerProvider).user?.displayName),
          const SizedBox(height: Insets.lg),
          const _StatusStrip(),
          const SizedBox(height: Insets.lg),
          _QuickActions(),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    // The greeting follows the clock; a missing profile name degrades to the plain
    // greeting rather than rendering an email address or an empty comma.
    final int hour = DateTime.now().hour;
    final String greeting = hour < 12
        ? context.l10n.homeGreetingMorning
        : hour < 17
            ? context.l10n.homeGreetingAfternoon
            : context.l10n.homeGreetingEvening;
    final String trimmed = name?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          trimmed.isEmpty ? greeting : '$greeting, $trimmed',
          style: Theme.of(context).textTheme.displaySmall,
          softWrap: true,
        ),
        const SizedBox(height: Insets.xs),
        Text(
          context.l10n.homeSubtitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// The three headline figures, as cards that reflow from one column (360 dp) to three.
class _StatusStrip extends ConsumerWidget {
  const _StatusStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SmartHomeState> smart = ref.watch(smartHomeProvider);
    final AsyncValue<List<ArmxAlarm>> alarms = ref.watch(alarmsProvider);
    final AsyncValue<GreeterState> greeter = ref.watch(greeterProvider);

    return AdaptiveCardGrid(
      maxCardWidth: 320,
      aspectRatio: 2.0,
      children: <Widget>[
        ArmxCard(
          title: context.l10n.smartHomeTitle,
          leading: Icon(Icons.devices_rounded, color: ArmxColors.of(context).accentText),
          child: switch (smart) {
            AsyncLoading<SmartHomeState>() =>
              const ArmxLoadingSkeleton(height: 20),
            AsyncError<SmartHomeState>(:final Object error) => ArmxErrorState(
                error: error,
                compact: true,
                onRetry: () => ref.invalidate(smartHomeProvider),
              ),
            AsyncData<SmartHomeState>(:final SmartHomeState value) => _DeviceSummary(
                devices: value.devices,
                onOpen: () => context.go(Routes.smartHome),
              ),
          },
        ),
        ArmxCard(
          title: context.l10n.homeNextAlarm,
          leading: Icon(Icons.alarm_rounded, color: ArmxColors.of(context).accent2Text),
          child: switch (alarms) {
            AsyncLoading<List<ArmxAlarm>>() =>
              const ArmxLoadingSkeleton(height: 20),
            AsyncError<List<ArmxAlarm>>(:final Object error) => ArmxErrorState(
                error: error,
                compact: true,
                onRetry: () => ref.invalidate(alarmsProvider),
              ),
            AsyncData<List<ArmxAlarm>>(:final List<ArmxAlarm> value) => _NextAlarmSummary(
                alarms: value,
                onOpen: () => context.go(Routes.alarms),
              ),
          },
        ),
        ArmxCard(
          title: context.l10n.homeGreeterState,
          leading: Icon(Icons.videocam_rounded, color: ArmxColors.of(context).textMuted),
          child: switch (greeter) {
            AsyncLoading<GreeterState>() =>
              const ArmxLoadingSkeleton(height: 20),
            AsyncError<GreeterState>(:final Object error) => ArmxErrorState(
                error: error,
                compact: true,
                onRetry: () => ref.invalidate(greeterProvider),
              ),
            AsyncData<GreeterState>(:final GreeterState value) => ArmxButton(
                label: value.camera.isCapturing
                    ? context.l10n.greeterCameraLive
                    : value.camera == GreeterCameraState.killed
                        ? context.l10n.greeterCameraKilled
                        : context.l10n.greeterCameraOff,
                variant: ArmxButtonVariant.ghost,
                icon: value.camera.isCapturing
                    ? Icons.videocam_rounded
                    : Icons.videocam_off_rounded,
                onPressed: () => context.go(Routes.guestGreeter),
              ),
          },
        ),
      ],
    );
  }
}

class _DeviceSummary extends StatelessWidget {
  const _DeviceSummary({required this.devices, required this.onOpen});

  final List<ArmxDevice> devices;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return Text(
        context.l10n.smartHomeEmptyTitle,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    final int online = devices.where((ArmxDevice d) => d.online).length;
    final bool allOnline = online == devices.length;

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.l10n.homeDevicesOnline(online, devices.length),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: Insets.sm),
            // The label carries the meaning; the colour only reinforces it.
            ArmxStatusDot(
              status: allOnline ? ArmxStatus.online : ArmxStatus.pending,
              label: allOnline
                  ? context.l10n.statusOnline
                  : context.l10n.statusWarning,
            ),
          ],
        ),
      ),
    );
  }
}

class _NextAlarmSummary extends StatelessWidget {
  const _NextAlarmSummary({required this.alarms, required this.onOpen});

  final List<ArmxAlarm> alarms;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final List<ArmxAlarm> armed = alarms.where((ArmxAlarm a) => a.enabled).toList()
      ..sort(
        (ArmxAlarm a, ArmxAlarm b) =>
            (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
      );

    if (armed.isEmpty) {
      return InkWell(
        onTap: onOpen,
        child: Text(
          context.l10n.homeNoAlarms,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    // A ringing alarm outranks the schedule: it is the thing needing attention now.
    final List<ArmxAlarm> ringingAlarms =
        alarms.where((ArmxAlarm a) => a.isRinging).toList(growable: false);
    final ArmxAlarm? ringing =
        ringingAlarms.isEmpty ? null : ringingAlarms.first;
    final ArmxAlarm shown = ringing ?? armed.first;

    return InkWell(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${shown.timeLabel} · ${shown.label}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: Insets.sm),
          ArmxStatusDot(
            status: ringing != null ? ArmxStatus.pending : ArmxStatus.online,
            label: ringing != null
                ? context.l10n.alarmsRinging
                : context.l10n.alarmsEnabled,
            pulse: ringing != null,
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return ArmxSection(
      title: context.l10n.homeQuickActions,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AdaptiveWrap(
            children: <Widget>[
              ArmxButton(
                label: context.l10n.homeOpenAssistant,
                icon: Icons.graphic_eq_rounded,
                onPressed: () => context.go(Routes.assistant),
              ),
              ArmxButton(
                label: context.l10n.alarmsNew,
                variant: ArmxButtonVariant.secondary,
                icon: Icons.add_alarm_rounded,
                onPressed: () => context.go(Routes.alarmFor('new')),
              ),
              ArmxButton(
                label: context.l10n.linkedPair,
                variant: ArmxButtonVariant.secondary,
                icon: Icons.qr_code_rounded,
                onPressed: () => context.go(Routes.linkedDevices),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          ArmxNotice(
            message: context.l10n.homeKillSwitchHint,
            tone: ArmxBadgeToneLike.info,
          ),
        ],
      ),
    );
  }
}
