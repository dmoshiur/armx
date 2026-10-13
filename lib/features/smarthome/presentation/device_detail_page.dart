// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/breakpoints.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/armx_card.dart';
import '../../../core/widgets/armx_empty_state.dart';
import '../../../core/widgets/armx_error_state.dart';
import '../../../core/widgets/armx_loading_skeleton.dart';
import '../../../core/widgets/armx_status_dot.dart';
import '../../../core/widgets/armx_text_field.dart';
import '../../../data/models/device.dart';
import '../application/smart_home_controller.dart';
import 'smart_home_page.dart';

/// One device in full: state, readings, firmware and controls.
///
/// An id that is not in the snapshot is **not** treated as a new device. The page says the
/// device is unknown and offers the way back, which is what makes a stale link or a removed
/// device visible instead of confusing.
///
/// The brightness slider sends its value **once, on release**, rather than on every frame of
/// the drag: a dimmer that streams 60 commands a second is a dimmer that fights the user.
class DeviceDetailPage extends ConsumerWidget {
  /// Creates the page.
  const DeviceDetailPage({required this.deviceId, super.key});

  /// Device id from the route.
  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ArmxDevice?> device = ref.watch(deviceByIdProvider(deviceId));
    final ArmxColors colors = ArmxColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(device.value?.name ?? context.l10n.smartHomeTitle),
      ),
      body: switch (device) {
        AsyncLoading<ArmxDevice?>() => const Padding(
            padding: EdgeInsets.all(Insets.lg),
            child: ArmxSkeletonCard(lines: 4),
          ),
        AsyncError<ArmxDevice?>(:final Object error) => ArmxErrorState(
            error: error,
            onRetry: () => ref.invalidate(devicesProvider),
          ),
        AsyncData<ArmxDevice?>(:final ArmxDevice? value) => value == null
            ? ArmxErrorState(
                error: UnknownException(
                  message: context.l10n.smartHomeDeviceUnknown,
                  code: 'device_not_found',
                ),
                onRetry: () => context.go(Routes.smartHome),
              )
            : _Detail(device: value),
      },
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.device});

  final ArmxDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SmartHomeState? snapshot = ref.watch(smartHomeProvider).value;
    final bool busy = snapshot?.busyDeviceIds.contains(device.id) ?? false;
    final String room = snapshot?.rooms
            .where((ArmxRoom r) => r.id == device.roomId)
            .map((ArmxRoom r) => r.name)
            .firstOrNull ??
        context.l10n.smartHomeRoomUnknown;

    return ListView(
      padding: EdgeInsets.all(context.pagePadding),
      children: <Widget>[
        ArmxCard(
          title: device.name,
          leading: Icon(
            device.isActive ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ArmxStatusDot(
                status: busy
                    ? ArmxStatus.pending
                    : device.online
                        ? ArmxStatus.online
                        : ArmxStatus.offline,
                label: busy
                    ? context.l10n.commonPending
                    : device.online
                        ? context.l10n.statusOnline
                        : context.l10n.statusOffline,
              ),
              const SizedBox(height: Insets.md),
              ArmxDetailRow(
                label: context.l10n.smartHomeRoom,
                value: room,
                icon: Icons.meeting_room_outlined,
              ),
              ArmxDetailRow(
                label: 'ID',
                value: device.id,
                monospace: true,
                icon: Icons.tag_rounded,
              ),
              if (device.firmwareVersion != null)
                ArmxDetailRow(
                  label: context.l10n.smartHomeFirmware,
                  value: device.firmwareVersion!,
                  monospace: true,
                  icon: Icons.memory_rounded,
                ),
              if (device.lastSeenAt != null)
                ArmxDetailRow(
                  label: context.l10n.settingsSessionLastUsed,
                  value: device.lastSeenAt!.toLocal().toString(),
                  icon: Icons.history_rounded,
                ),
            ],
          ),
        ),
        const SizedBox(height: Insets.lg),
        if (device.kind.isReadOnly && device.reading != null)
          ArmxCard(
            title: context.l10n.smartHomeSensorReading,
            leading: const Icon(Icons.sensors_rounded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  device.reading!.display,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                if (device.reading!.recordedAt != null) ...<Widget>[
                  const SizedBox(height: Insets.xs),
                  Text(
                    device.reading!.recordedAt!.toLocal().toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          )
        else if (!device.controllableByCurrentUser)
          ArmxCard(
            tone: ArmxCardTone.tinted,
            child: ArmxEmptyHint(
              icon: Icons.lock_outline_rounded,
              message: context.l10n.smartHomeNotPermitted,
            ),
          )
        else ...<Widget>[
          _Controls(device: device, busy: busy),
          const SizedBox(height: Insets.lg),
          // The physical fallback is stated on the detail page too: it is the one control
          // that keeps working when the network, the backend and this app do not.
          ArmxNotice(
            tone: ArmxBadgeToneLike.info,
            message: context.l10n.smartHomeManualFallback,
          ),
        ],
      ],
    );
  }
}

class _Controls extends ConsumerStatefulWidget {
  const _Controls({required this.device, required this.busy});

  final ArmxDevice device;
  final bool busy;

  @override
  ConsumerState<_Controls> createState() => _ControlsState();
}

class _ControlsState extends ConsumerState<_Controls> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final ArmxDevice device = widget.device;
    final bool dimmable = device.brightness != null;
    final double level = _dragging ?? (device.brightness ?? 0).toDouble();

    return ArmxCard(
      title: device.kind == DeviceKind.lock
          ? context.l10n.smartHomeLocked
          : context.l10n.commonOn,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ArmxSwitchRow(
            title: device.kind == DeviceKind.lock
                ? (device.isActive
                    ? context.l10n.smartHomeUnlocked
                    : context.l10n.smartHomeLocked)
                : (device.isActive ? context.l10n.commonOn : context.l10n.commonOff),
            value: device.isActive,
            enabled: !widget.busy,
            onChanged: (bool on) => runDeviceCommand(
              context,
              ref,
              device: device,
              command: toggleCommandFor(device, on: on),
            ),
          ),
          if (dimmable) ...<Widget>[
            const SizedBox(height: Insets.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    context.l10n.smartHomeBrightness,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Text(
                  '${level.round()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            Semantics(
              slider: true,
              label: context.l10n.smartHomeBrightness,
              value: '${level.round()} percent',
              child: Slider(
                value: level.clamp(0, 100),
                max: 100,
                divisions: 20,
                label: '${level.round()}%',
                onChanged: widget.busy
                    ? null
                    : (double value) => setState(() => _dragging = value),
                onChangeEnd: (double value) async {
                  setState(() => _dragging = null);
                  await runDeviceCommand(
                    context,
                    ref,
                    device: device,
                    command: 'set_brightness',
                    parameters: <String, Object?>{'brightness': value.round()},
                  );
                },
              ),
            ),
          ],
          if (!device.online) ...<Widget>[
            const SizedBox(height: Insets.sm),
            Text(
              context.l10n.smartHomeOfflineNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
