// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';
import '../../../data/api/armx_api.dart';
import '../../../data/models/guest.dart';
import '../../../data/models/linked_device.dart' show LinkedDevice;

/// The greeter camera state and the kill-switch.
///
/// The camera state shown is always the backend's. The client does not keep a local "I told
/// it to stop" flag, because a camera that is capturing while the app says it is off is the
/// single most serious lie this feature could tell.
class GreeterController extends AsyncNotifier<GreeterState> {
  @override
  Future<GreeterState> build() => ref.watch(armxApiProvider).greeterState();

  /// Re-reads the state.
  Future<void> refresh() async {
    state = const AsyncValue<GreeterState>.loading();
    state = await AsyncValue.guard(build);
  }

  /// Requests `live` | `off` | `killed` and adopts whatever comes back.
  Future<void> setCamera(GreeterCameraState camera) async {
    try {
      final GreeterState next =
          await ref.read(armxApiProvider).setGreeterCamera(state: camera.wire);
      state = AsyncValue<GreeterState>.data(next);
    } on AppException catch (error, stackTrace) {
      // The error is surfaced *and* the previous state is replaced, so the UI can say "the
      // camera did not stop" rather than silently keeping a green dot.
      state = AsyncValue<GreeterState>.error(error, stackTrace);
    }
  }

  /// Engages the kill-switch: one tap, no dialog. It is the emergency brake.
  Future<void> kill() => setCamera(GreeterCameraState.killed);

  /// Releases it, which resumes capture. The caller confirms first.
  Future<void> release() => setCamera(GreeterCameraState.live);
}

/// The greeter state.
final AsyncNotifierProvider<GreeterController, GreeterState> greeterProvider =
    AsyncNotifierProvider<GreeterController, GreeterState>(
  GreeterController.new,
);

/// Enrolled guests.
class GuestsController extends AsyncNotifier<List<GuestProfile>> {
  @override
  Future<List<GuestProfile>> build() => ref.watch(armxApiProvider).guests();

  /// Re-reads the list.
  Future<void> refresh() async {
    state = const AsyncValue<List<GuestProfile>>.loading();
    state = await AsyncValue.guard(build);
  }

  /// Enrols one guest. [consentGiven] must be true; the backend enforces it and the client
  /// does not attempt to work around that.
  Future<GuestProfile> enroll({
    required String displayName,
    required bool consentGiven,
    String? note,
  }) async {
    final GuestProfile enrolled = await ref.read(armxApiProvider).enrollGuest(
          displayName: displayName,
          consentGiven: consentGiven,
          note: note,
        );
    final List<GuestProfile> current = state.value ?? const <GuestProfile>[];
    state = AsyncValue<List<GuestProfile>>.data(
      <GuestProfile>[...current, enrolled],
    );
    ref.invalidate(greeterProvider);
    return enrolled;
  }

  /// Deletes a guest and everything held about them. Irreversible; the caller confirms.
  Future<void> delete(String guestId) async {
    await ref.read(armxApiProvider).deleteGuest(guestId);
    final List<GuestProfile> current = state.value ?? const <GuestProfile>[];
    state = AsyncValue<List<GuestProfile>>.data(
      current.where((GuestProfile g) => g.id != guestId).toList(growable: false),
    );
    ref.invalidate(greeterProvider);
  }
}

/// Enrolled guests.
final AsyncNotifierProvider<GuestsController, List<GuestProfile>> guestsProvider =
    AsyncNotifierProvider<GuestsController, List<GuestProfile>>(
  GuestsController.new,
);

/// Recent greetings.
final FutureProvider<List<GreeterEvent>> greeterEventsProvider =
    FutureProvider<List<GreeterEvent>>(
  (Ref ref) => ref.watch(armxApiProvider).greeterEvents(),
);

/// The ringable devices, for the greeter summary card.
final FutureProvider<List<LinkedDevice>> linkedForGreeterProvider =
    FutureProvider<List<LinkedDevice>>(
  (Ref ref) => ref.watch(armxApiProvider).linkedDevices(),
);
