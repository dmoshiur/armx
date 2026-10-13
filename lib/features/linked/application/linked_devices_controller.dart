// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';
import '../../../data/models/linked_device.dart';

/// Every device signed in to this account.
class LinkedDevicesController extends AsyncNotifier<List<LinkedDevice>> {
  @override
  Future<List<LinkedDevice>> build() => ref.watch(armxApiProvider).linkedDevices();

  /// Re-reads the list.
  Future<void> refresh() async {
    state = const AsyncValue<List<LinkedDevice>>.loading();
    state = await AsyncValue.guard(build);
  }

  /// Unlinks [deviceId], gated by the **owner's own password**.
  ///
  /// The password is passed straight through and never stored. A refusal throws and the list
  /// is left untouched: the row disappears only when the backend has confirmed, because a
  /// locally-removed row that still has access is the exact failure this flow exists to
  /// prevent.
  Future<void> unlink({
    required String deviceId,
    required String ownerPassword,
  }) async {
    await ref
        .read(armxApiProvider)
        .unlinkDevice(deviceId: deviceId, ownerPassword: ownerPassword);
    final List<LinkedDevice> current = state.value ?? const <LinkedDevice>[];
    state = AsyncValue<List<LinkedDevice>>.data(
      current.where((LinkedDevice d) => d.id != deviceId).toList(growable: false),
    );
  }
}

/// The linked-device list.
final AsyncNotifierProvider<LinkedDevicesController, List<LinkedDevice>>
    linkedDevicesProvider =
    AsyncNotifierProvider<LinkedDevicesController, List<LinkedDevice>>(
  LinkedDevicesController.new,
);

/// Where a pairing attempt has got to.
enum PairingStatus {
  /// Nothing started.
  idle,

  /// A code exists and is waiting to be approved on a trusted device.
  waiting,

  /// Approved: the new device now has access.
  approved,

  /// Refused, or the code expired.
  rejected,

  /// Cancelled by the user.
  cancelled;

  /// True when the flow has finished.
  bool get isTerminal =>
      this == PairingStatus.approved ||
      this == PairingStatus.rejected ||
      this == PairingStatus.cancelled;
}

/// The pairing flow's state.
class PairingState {
  /// Creates a state.
  const PairingState({
    this.offer,
    this.deviceName = '',
    this.status = PairingStatus.idle,
    this.error,
  });

  /// The live offer, if any.
  final PairingOffer? offer;

  /// The name the new device will carry.
  final String deviceName;

  /// Where the flow is.
  final PairingStatus status;

  /// Last failure.
  final AppException? error;
}

/// Drives the pairing flow.
///
/// ## The two-person rule
///
/// A new device cannot grant itself access. It asks for a code; the code must be approved on
/// a device that is *already* trusted. The client does not decide either side — it shows the
/// code with its expiry and, separately, offers to approve a code typed in from elsewhere.
class PairingController extends Notifier<PairingState> {
  /// Ticks the expiry countdown once a second while an offer is live.
  Timer? _expiryTicker;

  @override
  PairingState build() {
    ref.onDispose(() => _expiryTicker?.cancel());
    return const PairingState(deviceName: '');
  }

  /// Asks the backend for an offer: a short code plus a QR payload.
  Future<void> start({required String deviceName, required String platform}) async {
    _expiryTicker?.cancel();
    _expiryTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final PairingOffer? offer = state.offer;
      if (offer != null && !DateTime.now().toUtc().isBefore(offer.expiresAt)) {
        _expiryTicker?.cancel();
        // The offer's death is a state change, not an error: the code simply stops working.
        state = PairingState(
          deviceName: state.deviceName,
          status: PairingStatus.rejected,
        );
      }
    });

    try {
      final PairingOffer offer = await ref
          .read(armxApiProvider)
          .startPairing(deviceName: deviceName, platform: platform);
      state = PairingState(
        offer: offer,
        deviceName: deviceName,
        status: PairingStatus.waiting,
      );
    } on AppException catch (error) {
      _expiryTicker?.cancel();
      state = PairingState(deviceName: deviceName, error: error);
    }
  }

  /// Approves an offer **from an already-trusted device**, using the code shown on the new
  /// one.
  Future<void> approve(String code) async {
    try {
      await ref.read(armxApiProvider).approvePairing(code.trim());
      await ref.read(linkedDevicesProvider.notifier).refresh();
      state = const PairingState(status: PairingStatus.approved);
    } on AppException catch (error) {
      state = PairingState(status: PairingStatus.rejected, error: error);
    }
  }

  /// Abandons the current offer.
  Future<void> cancel() async {
    _expiryTicker?.cancel();
    try {
      await ref.read(armxApiProvider).cancelPairing();
    } on AppException {
      // Best effort: the offer expires on its own, and failing here would trap the user on a
      // screen they are trying to leave.
    }
    state = const PairingState(status: PairingStatus.cancelled);
  }
}

/// The pairing flow state.
final NotifierProvider<PairingController, PairingState> pairingProvider =
    NotifierProvider<PairingController, PairingState>(PairingController.new);
