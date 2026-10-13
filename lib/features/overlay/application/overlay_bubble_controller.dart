// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Whether the app may draw a floating window over other apps.
///
/// The platform's answer is the only one that counts: it can be revoked in system settings
/// while the app is in the background, so it is read on every visit rather than cached for
/// the session.
enum BubblePermission {
  /// Not asked yet.
  unknown,

  /// Granted by the system.
  granted,

  /// Refused, but asking again is still possible.
  denied,

  /// Refused permanently: only system settings can change it.
  permanentlyDenied,

  /// The platform has no such permission (web, desktop, iOS).
  unsupported,
}

/// The overlay bubble's state.
@immutable
class OverlayBubbleState {
  /// Creates a state.
  const OverlayBubbleState({
    this.permission = BubblePermission.unknown,
    this.requested = false,
    this.attached = false,
    this.busy = false,
    this.failure,
  });

  /// The platform's answer about drawing over other apps.
  final BubblePermission permission;

  /// Whether the owner has asked for the bubble.
  ///
  /// Kept separate from [permission] and from [attached]: the permission is the system's,
  /// [requested] is the person's intent, and [attached] is the fact of a window being on
  /// screen right now. Collapsing them would let the UI show "on" for a bubble that is not
  /// there.
  final bool requested;

  /// True only while a floating window is actually attached.
  final bool attached;

  /// True while a permission request or a toggle is in flight.
  final bool busy;

  /// The last failure, plainly described.
  final String? failure;

  /// Whether the bubble can be turned on at all on this platform.
  bool get supported => permission != BubblePermission.unsupported;

  /// Copy with changes.
  OverlayBubbleState copyWith({
    BubblePermission? permission,
    bool? requested,
    bool? attached,
    bool? busy,
    String? failure,
    bool clearFailure = false,
  }) =>
      OverlayBubbleState(
        permission: permission ?? this.permission,
        requested: requested ?? this.requested,
        attached: attached ?? this.attached,
        busy: busy ?? this.busy,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

/// Reads and requests the overlay permission, and remembers the owner's intent.
///
/// **Nothing here claims the bubble is running.** Attaching the Android window is the job of
/// the platform host (`flutter_overlay_window`), which is wired in the overlay phase; until a
/// host reports back through [reportAttached], [OverlayBubbleState.attached] stays false and
/// the UI says the bubble is not on screen. A switch that flips to "on" while no window
/// exists is exactly the lie this class is built to avoid.
class OverlayBubbleController extends Notifier<OverlayBubbleState> {
  @override
  OverlayBubbleState build() => const OverlayBubbleState();

  /// True when the platform can host a floating window at all.
  static bool get hostSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Re-reads the platform permission.
  Future<void> refresh() async {
    if (!hostSupported) {
      state = state.copyWith(
        permission: BubblePermission.unsupported,
        attached: false,
        clearFailure: true,
      );
      return;
    }
    try {
      final PermissionStatus status = await Permission.systemAlertWindow.status;
      state = state.copyWith(
        permission: _map(status),
        clearFailure: true,
      );
    } catch (error) {
      state = state.copyWith(
        permission: BubblePermission.unknown,
        failure: '$error',
      );
    }
  }

  /// Asks the platform for the permission.
  ///
  /// A refusal is reported as a refusal: the state is re-read afterwards rather than being
  /// assumed from the reply, because Android reports the result of the settings screen
  /// asynchronously.
  Future<void> request() async {
    if (!hostSupported) {
      await refresh();
      return;
    }
    state = state.copyWith(busy: true, clearFailure: true);
    try {
      await Permission.systemAlertWindow.request();
    } catch (error) {
      state = state.copyWith(failure: '$error');
    } finally {
      state = state.copyWith(busy: false);
    }
    await refresh();
  }

  /// Records that the owner wants the bubble, if the permission allows it.
  Future<void> enable() async {
    if (!state.supported) {
      return;
    }
    if (state.permission != BubblePermission.granted) {
      await request();
    }
    if (state.permission != BubblePermission.granted) {
      // Still refused: intent is *not* recorded, so nothing downstream can believe the
      // bubble was switched on.
      return;
    }
    state = state.copyWith(requested: true, busy: false);
  }

  /// Records that the owner no longer wants it. Always succeeds: turning something off must
  /// never be blocked.
  void disable() => state = state.copyWith(requested: false, attached: false);

  /// Called by the platform host when a window is attached or detached.
  void reportAttached({required bool attached}) =>
      state = state.copyWith(attached: attached);

  /// Called by the platform host when an attach attempt failed.
  void reportFailure(String message) =>
      state = state.copyWith(attached: false, failure: message);

  static BubblePermission _map(PermissionStatus status) => switch (status) {
        PermissionStatus.granted ||
        PermissionStatus.provisional ||
        PermissionStatus.limited =>
          BubblePermission.granted,
        PermissionStatus.permanentlyDenied => BubblePermission.permanentlyDenied,
        PermissionStatus.restricted => BubblePermission.permanentlyDenied,
        _ => BubblePermission.denied,
      };
}

/// The overlay bubble state. Loaded on first read by the page, which calls [refresh].
final NotifierProvider<OverlayBubbleController, OverlayBubbleState>
    overlayBubbleProvider =
    NotifierProvider<OverlayBubbleController, OverlayBubbleState>(
  OverlayBubbleController.new,
);
