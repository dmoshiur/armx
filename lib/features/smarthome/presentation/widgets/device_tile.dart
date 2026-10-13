// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/breakpoints.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/armx_card.dart';
import '../../../../core/widgets/armx_empty_state.dart';
import '../../../../core/widgets/armx_status_dot.dart';
import '../../../../core/widgets/armx_text_field.dart';
import '../../../../data/models/device.dart';
import '../../application/smart_home_controller.dart';
import '../smart_home_page.dart';

/// One device, with its control.
///
/// Three states a naive switch does not have, all of them about telling the truth:
///
/// * **offline** — the control is offered but the tile says the command will be queued, not
///   applied, so nobody believes a light came on;
/// * **not permitted** — the role may see the device but not operate it, and the tile
///   explains that rather than rendering a dead switch;
/// * **read-only sensor** — the latest reading is shown with its unit, never as a bare
///   number.
class DeviceTile extends ConsumerWidget {
  /// Creates a tile.
  const DeviceTile({
    required this.device,
    required this.busy,
    required this.onOpen,
    super.key,
  });

  /// The device.
  final ArmxDevice device;

  /// Whether a command is in flight for it.
  final bool busy;

  /// Opens the detail page.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ArmxColors colors = ArmxColors.of(context);
    final String status = device.online
        ? context.l10n.statusOnline
        : context.l10n.statusOffline;

    return ArmxCard(
      semanticLabel: '${device.name}. $status',
      title: device.name,
      leading: Icon(_iconFor(device), color: _iconColor(colors)),
      onTap: onOpen,
      trailing: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ArmxStatusDot(
            status: busy
                ? ArmxStatus.pending
                : device.online
                    ? ArmxStatus.online
                    : ArmxStatus.offline,
            label: busy ? context.l10n.commonPending : status,
            compact: true,
          ),
          const SizedBox(height: Insets.sm),
          _body(context, ref),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref) {
    if (device.kind.isReadOnly && device.reading != null) {
      return ArmxDetailRow(
        label: context.l10n.smartHomeSensorReading,
        value: device.reading!.display,
        icon: Icons.sensors_rounded,
      );
    }
    if (!device.controllableByCurrentUser) {
      return ArmxEmptyHint(
        icon: Icons.lock_outline_rounded,
        message: context.l10n.smartHomeNotPermitted,
      );
    }
    if (device.kind == DeviceKind.camera) {
      // The greeter owns the camera; the smart-home grid must not offer a second way to
      // switch it on.
      return ArmxEmptyHint(
        icon: Icons.videocam_rounded,
        message: context.l10n.greeterCameraOwnedElsewhere,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ArmxSwitchRow(
          title: device.kind == DeviceKind.lock
              ? (device.isActive
                  ? context.l10n.smartHomeUnlocked
                  : context.l10n.smartHomeLocked)
              : (device.isActive ? context.l10n.commonOn : context.l10n.commonOff),
          value: device.isActive,
          // While a command is in flight the switch is disabled, so a double tap cannot
          // queue two contradictory commands.
          enabled: !busy,
          semanticLabel: device.name,
          onChanged: (bool on) => runDeviceCommand(
            context,
            ref,
            device: device,
            command: toggleCommandFor(device, on: on),
          ),
        ),
        if (!device.online) ...<Widget>[
          const SizedBox(height: Insets.xs),
          Text(
            context.l10n.smartHomeOfflineNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  IconData _iconFor(ArmxDevice device) => switch (device.kind) {
        DeviceKind.light => device.isActive
            ? Icons.lightbulb_rounded
            : Icons.lightbulb_outline_rounded,
        DeviceKind.fan => Icons.mode_fan_off_rounded,
        DeviceKind.plug => Icons.power_rounded,
        DeviceKind.sensor => Icons.sensors_rounded,
        DeviceKind.camera => Icons.videocam_rounded,
        DeviceKind.lock =>
          device.isActive ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
        DeviceKind.other => Icons.devices_other_rounded,
      };

  /// An active light is the one place the accent is earned: it is the device's own state.
  Color _iconColor(ArmxColors colors) => !device.online
      ? colors.textMuted
      : device.isActive
          ? colors.accentText
          : colors.textMuted;
}
