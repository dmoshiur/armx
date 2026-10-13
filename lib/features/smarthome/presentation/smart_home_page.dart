// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/breakpoints.dart';
import '../../../core/confirm/confirm_policy.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/security/risk_tier.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/armx_badge.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/armx_empty_state.dart';
import '../../../core/widgets/armx_error_state.dart';
import '../../../core/widgets/armx_loading_skeleton.dart';
import '../../../data/models/device.dart';
import '../application/smart_home_controller.dart';
import 'widgets/device_tile.dart';

/// Rooms, their devices, and the controls for them.
///
/// ## Responsive
///
/// * **compact** — the room filter is a horizontally scrollable chip row (a wrapping row
///   would push the first device below the fold) and devices are one full-width card each.
/// * **medium / expanded** — a max-width card grid, so a 2560 dp window shows more devices
///   rather than bigger ones.
///
/// ## Integrity
///
/// A device whose room the backend did not name is shown under a fallback heading rather
/// than dropped, and a device the current role may not control says so instead of rendering
/// a switch that silently does nothing.
class SmartHomePage extends ConsumerStatefulWidget {
  /// Creates the page.
  const SmartHomePage({super.key});

  @override
  ConsumerState<SmartHomePage> createState() => _SmartHomePageState();
}

class _SmartHomePageState extends ConsumerState<SmartHomePage> {
  String? _roomFilter;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SmartHomeState> snapshot = ref.watch(smartHomeProvider);
    final ArmxColors colors = ArmxColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(context.l10n.smartHomeTitle),
        actions: <Widget>[
          ArmxIconButton(
            icon: Icons.refresh_rounded,
            semanticLabel: context.l10n.commonRefresh,
            onPressed: () => ref.read(smartHomeProvider.notifier).refresh(),
          ),
        ],
      ),
      body: switch (snapshot) {
        AsyncLoading<SmartHomeState>() => const Padding(
            padding: EdgeInsets.all(Insets.lg),
            child: ArmxLoadingSkeletonGrid(count: 4),
          ),
        AsyncError<SmartHomeState>(:final Object error) => ArmxErrorState(
            error: error,
            onRetry: () => ref.invalidate(smartHomeProvider),
          ),
        AsyncData<SmartHomeState>(:final SmartHomeState value) => Column(
            children: <Widget>[
              _RoomFilterBar(
                rooms: value.rooms,
                selected: _roomFilter,
                onSelected: (String? roomId) =>
                    setState(() => _roomFilter = roomId),
              ),
              Expanded(
                child: _Rooms(state: value, roomFilter: _roomFilter),
              ),
            ],
          ),
      },
    );
  }
}

class _Rooms extends StatelessWidget {
  const _Rooms({required this.state, required this.roomFilter});

  final SmartHomeState state;
  final String? roomFilter;

  @override
  Widget build(BuildContext context) {
    if (state.devices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: ArmxEmptyState(
            icon: Icons.lightbulb_outline_rounded,
            title: context.l10n.smartHomeEmptyTitle,
            message: context.l10n.smartHomeEmptyBody,
          ),
        ),
      );
    }

    final List<Widget> sections = <Widget>[
      for (final ArmxRoom room in state.rooms)
        if (roomFilter == null || roomFilter == room.id)
          if (state.inRoom(room.id).isNotEmpty)
            _RoomSection(title: room.name, devices: state.inRoom(room.id), state: state),
      if (state.unassigned.isNotEmpty && roomFilter == null)
        _RoomSection(
          title: context.l10n.smartHomeRoomUnknown,
          devices: state.unassigned,
          state: state,
        ),
    ];

    if (sections.isEmpty) {
      return Center(
        child: ArmxEmptyState(
          icon: Icons.filter_alt_off_rounded,
          title: context.l10n.commonNoResults,
          compact: true,
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        Insets.sm,
        context.pagePadding,
        Insets.xxl,
      ),
      children: <Widget>[
        for (final Widget section in sections) ...<Widget>[
          section,
          const SizedBox(height: Insets.xl),
        ],
      ],
    );
  }
}

class _RoomSection extends StatelessWidget {
  const _RoomSection({
    required this.title,
    required this.devices,
    required this.state,
  });

  final String title;
  final List<ArmxDevice> devices;
  final SmartHomeState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            ArmxBadge(
              label: '${devices.where((ArmxDevice d) => d.online).length}/'
                  '${devices.length}',
              tone: devices.every((ArmxDevice d) => d.online)
                  ? ArmxBadgeTone.success
                  : ArmxBadgeTone.warning,
              icon: Icons.wifi_rounded,
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        AdaptiveDeviceGrid(
          children: <Widget>[
            for (final ArmxDevice device in devices)
              DeviceTile(
                device: device,
                busy: state.busyDeviceIds.contains(device.id),
                onOpen: () => context.go(Routes.deviceFor(device.id)),
              ),
          ],
        ),
      ],
    );
  }
}

class _RoomFilterBar extends StatelessWidget {
  const _RoomFilterBar({
    required this.rooms,
    required this.selected,
    required this.onSelected,
  });

  final List<ArmxRoom> rooms;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final List<Widget> chips = <Widget>[
      ArmxChip(
        label: context.l10n.smartHomeAllRooms,
        selected: selected == null,
        onSelected: (_) => onSelected(null),
      ),
      for (final ArmxRoom room in rooms)
        ArmxChip(
          label: room.name,
          selected: selected == room.id,
          count: null,
          onSelected: (_) => onSelected(room.id),
        ),
    ];

    final EdgeInsets padding = EdgeInsets.symmetric(
      horizontal: context.pagePadding,
      vertical: Insets.sm,
    );

    if (context.isCompact) {
      // Scrollable, not wrapped: a second filter row would eat the fold.
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(
          children: <Widget>[
            for (final Widget chip in chips)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: Insets.sm),
                child: chip,
              ),
          ],
        ),
      );
    }
    return Padding(
      padding: padding,
      child: Wrap(spacing: Insets.sm, runSpacing: Insets.sm, children: chips),
    );
  }
}

/// The only path a device command takes.
///
/// Confirm first (when the tier requires it), then call, then report the backend's answer —
/// applied, queued for an offline device, or refused. Nothing is shown as done until the
/// backend says so.
Future<void> runDeviceCommand(
  BuildContext context,
  WidgetRef ref, {
  required ArmxDevice device,
  required String command,
  Map<String, Object?> parameters = const <String, Object?>{},
}) async {
  final RiskTier tier = commandRiskFor(device, command);

  final bool confirmed = await ConfirmPolicy.confirm(
    context,
    ConfirmPolicy.forDeviceCommand(
      context,
      device: device,
      command: command,
      tier: tier,
      parameters: parameters,
    ),
  );
  if (!confirmed || !context.mounted) {
    return;
  }

  final DeviceCommandOutcome outcome =
      await ref.read(smartHomeProvider.notifier).command(
            deviceId: device.id,
            command: command,
            parameters: parameters,
            declaredRisk: tier,
          );
  if (!context.mounted) {
    return;
  }

  final String message = outcome.error != null
      ? '${context.l10n.smartHomeToggleFailed} ${outcome.error!.message}'
      : outcome.isQueued
          ? context.l10n.smartHomeQueued
          : outcome.message ?? context.l10n.statusSuccess;

  ScaffoldMessenger.maybeOf(context)
    ?..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        // A queued command is not an error, but it is not success either; it stays a little
        // longer because "it will happen later" is easy to miss.
        duration: outcome.isQueued
            ? const Duration(seconds: 5)
            : const Duration(seconds: 3),
      ),
    );
}

/// The tile grid.
///
/// `SliverGridDelegateWithMaxCrossAxisExtent` under the hood, so cards keep a usable width
/// from 360 dp to 2560 dp instead of stretching.
class AdaptiveDeviceGrid extends StatelessWidget {
  /// Creates the grid.
  const AdaptiveDeviceGrid({
    required this.children,
    this.maxCardWidth = 320,
    this.aspectRatio = 1.5,
    super.key,
  });

  /// Tiles.
  final List<Widget> children;

  /// Widest a tile may grow.
  final double maxCardWidth;

  /// Tile aspect ratio.
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return GridView.extent(
      maxCrossAxisExtent: maxCardWidth,
      childAspectRatio: aspectRatio,
      mainAxisSpacing: Insets.md,
      crossAxisSpacing: Insets.md,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}
