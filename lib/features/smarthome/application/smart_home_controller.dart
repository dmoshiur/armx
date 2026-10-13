// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';
import '../../../core/security/risk_tier.dart';
import '../../../data/models/device.dart';

/// Rooms and devices, as one consistent snapshot.
///
/// They are loaded together on purpose: a device whose room is not known cannot be grouped,
/// and fetching them separately would let the UI render a device into the wrong room for a
/// frame — or into none at all, which looks like a device that vanished.
class SmartHomeState {
  /// Creates a snapshot.
  const SmartHomeState({
    this.rooms = const <ArmxRoom>[],
    this.devices = const <ArmxDevice>[],
    this.busyDeviceIds = const <String>{},
  });

  /// Rooms, in backend order.
  final List<ArmxRoom> rooms;

  /// Every device the account can see, including ones it may not control.
  final List<ArmxDevice> devices;

  /// Devices with a command in flight, so a tile can disable its control instead of letting
  /// a second tap queue a contradictory command.
  final Set<String> busyDeviceIds;

  /// Devices in [roomId].
  List<ArmxDevice> inRoom(String roomId) =>
      devices.where((ArmxDevice device) => device.roomId == roomId).toList(growable: false);

  /// Devices whose room the client does not know. They are shown under a fallback heading
  /// rather than hidden: a device that disappears from the app is worse than an untidy one.
  List<ArmxDevice> get unassigned {
    final Set<String> known = rooms.map((ArmxRoom room) => room.id).toSet();
    return devices
        .where((ArmxDevice device) => !known.contains(device.roomId))
        .toList(growable: false);
  }

  /// Copy with changes.
  SmartHomeState copyWith({
    List<ArmxRoom>? rooms,
    List<ArmxDevice>? devices,
    Set<String>? busyDeviceIds,
  }) =>
      SmartHomeState(
        rooms: rooms ?? this.rooms,
        devices: devices ?? this.devices,
        busyDeviceIds: busyDeviceIds ?? this.busyDeviceIds,
      );
}

/// Loads the smart-home snapshot and issues device commands.
class SmartHomeController extends AsyncNotifier<SmartHomeState> {
  @override
  Future<SmartHomeState> build() async {
    final List<ArmxRoom> rooms = await ref.watch(armxApiProvider).rooms();
    final List<ArmxDevice> devices = await ref.watch(armxApiProvider).devices();
    return SmartHomeState(rooms: rooms, devices: devices);
  }

  /// Re-reads rooms and devices.
  Future<void> refresh() async {
    state = const AsyncValue<SmartHomeState>.loading();
    state = await AsyncValue.guard(build);
  }

  /// Sends [command] and reports what the backend did.
  ///
  /// Returns an outcome rather than throwing: every failure mode here (refused, queued,
  /// offline, transport error) is something the tile must be able to show. Nothing is
  /// applied optimistically; the device state shown is the one the backend returned.
  Future<DeviceCommandOutcome> command({
    required String deviceId,
    required String command,
    Map<String, Object?> parameters = const <String, Object?>{},
    RiskTier? declaredRisk,
  }) async {
    _setBusy(deviceId, true);
    try {
      final DeviceCommandResult result = await ref
          .read(armxApiProvider)
          .sendDeviceCommand(
            deviceId: deviceId,
            command: command,
            parameters: parameters,
            declaredRisk: declaredRisk,
          );
      _apply(result);
      return DeviceCommandOutcome.from(result);
    } on AppException catch (error) {
      return DeviceCommandOutcome.failed(error);
    } finally {
      _setBusy(deviceId, false);
    }
  }

  void _setBusy(String deviceId, bool busy) {
    final SmartHomeState? current = state.value;
    if (current == null) {
      return;
    }
    final Set<String> next = <String>{...current.busyDeviceIds};
    if (busy) {
      next.add(deviceId);
    } else {
      next.remove(deviceId);
    }
    state = AsyncValue<SmartHomeState>.data(
      current.copyWith(busyDeviceIds: next),
    );
  }

  void _apply(DeviceCommandResult result) {
    final SmartHomeState? current = state.value;
    final ArmxDevice? updated = result.state;
    if (current == null || updated == null) {
      return;
    }
    state = AsyncValue<SmartHomeState>.data(
      current.copyWith(
        devices: <ArmxDevice>[
          for (final ArmxDevice device in current.devices)
            device.id == updated.id ? updated : device,
        ],
      ),
    );
  }
}

/// The outcome of one command, phrased for the UI.
///
/// [pending] is a first-class outcome, not a variant of success: an offline device accepts a
/// command and applies it later, and calling that "done" would be a lie.
class DeviceCommandOutcome {
  /// Records an outcome.
  const DeviceCommandOutcome({
    required this.accepted,
    required this.pending,
    this.message,
    this.error,
  });

  /// Builds one from a backend result.
  factory DeviceCommandOutcome.from(DeviceCommandResult result) =>
      DeviceCommandOutcome(
        accepted: result.accepted,
        pending: result.pending,
        message: result.message,
      );

  /// Records a failure.
  factory DeviceCommandOutcome.failed(AppException error) =>
      DeviceCommandOutcome(accepted: false, pending: false, error: error);

  /// Whether the device accepted it.
  final bool accepted;

  /// Whether it is queued for a device that is currently unreachable.
  final bool pending;

  /// Backend message, if any.
  final String? message;

  /// Failure, if any.
  final AppException? error;

  /// True when the UI should report the command as applied.
  bool get isSuccess => accepted && !pending && error == null;

  /// True when the UI must say "queued", not "done".
  bool get isQueued => accepted && pending;
}

/// The smart-home snapshot.
final AsyncNotifierProvider<SmartHomeController, SmartHomeState>
    smartHomeProvider =
    AsyncNotifierProvider<SmartHomeController, SmartHomeState>(
  SmartHomeController.new,
);

/// The room list, for the room filter.
final FutureProvider<List<ArmxRoom>> roomsProvider =
    FutureProvider<List<ArmxRoom>>(
  (Ref ref) => ref.watch(armxApiProvider).rooms(),
);

/// One device by id.
final ProviderFamily<ArmxDevice?, String> deviceByIdProvider =
    Provider.family<ArmxDevice?, String>((Ref ref, String id) {
  final AsyncValue<List<ArmxDevice>> devices = ref.watch(devicesProvider);
  return devices.value
      ?.where((ArmxDevice device) => device.id == id)
      .firstOrNull;
});

/// The device list, for the dashboard summary.
final FutureProvider<List<ArmxDevice>> devicesProvider =
    FutureProvider<List<ArmxDevice>>(
  (Ref ref) => ref.watch(armxApiProvider).devices(),
);

/// The risk of a command a person is issuing from this screen.
///
/// ## Why the tier is computed here rather than sent by the server
///
/// For anything the *assistant* proposes, the server owns the tier: only it knows what the
/// tool does. Here the user is looking at the physical device and operating it, so the
/// client states the tier and passes it as `declaredRisk` — the backend may raise it, and
/// the UI has already asked for the confirmation the tier demands before the call goes out.
///
/// * a light, fan or plug is [RiskTier.low]: reversible, visible, and the switch is the
///   confirmation;
/// * locking is [RiskTier.medium]: reversible, but a lock changing state on its own is a
///   security event worth one dialog;
/// * unlocking is [RiskTier.high]: it removes a physical barrier and the app cannot put it
///   back, so the dialog names the door and the phrase must be typed.
RiskTier commandRiskFor(ArmxDevice device, String command) {
  if (device.kind == DeviceKind.lock) {
    return command == 'unlock' ? RiskTier.high : RiskTier.medium;
  }
  return RiskTier.low;
}

/// The wire command that switches [device] on or off (or locks and unlocks it).
String toggleCommandFor(ArmxDevice device, {required bool on}) =>
    device.kind == DeviceKind.lock
        ? (on ? 'unlock' : 'lock')
        : (on ? 'turn_on' : 'turn_off');

/// True when the command cannot be undone from inside the app.
bool isIrreversibleCommand(String command) => command == 'unlock';
