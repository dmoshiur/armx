// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The platform host for the floating bubble.
///
/// The plugin is reached **only** through this interface, for one reason: `showOverlay` is a
/// call into Android that can fail for reasons this app does not control (the permission was
/// revoked while the app was in the background, the OEM killed the service, the window could
/// not be attached). Every implementation of this interface therefore returns or throws
/// something the caller can report, instead of a `void` that looks like success.
abstract interface class OverlayBubbleHost {
  /// Whether this platform can host a floating window at all.
  bool get isSupported;

  /// The platform's own answer about the overlay permission.
  Future<bool> isPermissionGranted();

  /// Asks for it. Returns whether it was granted.
  Future<bool> requestPermission();

  /// Shows the bubble.
  Future<void> show({
    required String notificationTitle,
    required String notificationBody,
  });

  /// Removes it. Always safe to call.
  Future<void> hide();

  /// Whether a window is attached right now.
  Future<bool> isActive();

  /// Events sent from the bubble isolate (`shareData`).
  Stream<Object?> get events;
}

/// The real Android host.
///
/// Pinned to `flutter_overlay_window`, whose window size is given in logical pixels: a 96 × 96
/// window is the bubble the design-system mock-up shows, dragged with `PositionGravity.right`
/// so it parks against the edge instead of floating mid-screen.
class FlutterOverlayBubbleHost implements OverlayBubbleHost {
  /// Creates the host.
  const FlutterOverlayBubbleHost();

  /// The bubble's window size in logical pixels. Comfortably above the 48 dp touch minimum.
  static const int bubbleSize = 96;

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> isPermissionGranted() async {
    if (!isSupported) {
      return false;
    }
    return FlutterOverlayWindow.isPermissionGranted();
  }

  @override
  Future<bool> requestPermission() async {
    if (!isSupported) {
      return false;
    }
    final bool? granted = await FlutterOverlayWindow.requestPermission();
    return granted ?? false;
  }

  @override
  Future<void> show({
    required String notificationTitle,
    required String notificationBody,
  }) async {
    if (!isSupported) {
      throw UnsupportedError(
        'A floating window only exists on Android; this platform cannot host one.',
      );
    }
    await FlutterOverlayWindow.showOverlay(
      width: bubbleSize,
      height: bubbleSize,
      alignment: OverlayAlignment.centerRight,
      positionGravity: PositionGravity.right,
      enableDrag: true,
      // The notification is public on purpose: a bubble that appears over other apps must be
      // visible as a running service, not a hidden one.
      visibility: NotificationVisibility.visibilityPublic,
      overlayTitle: notificationTitle,
      overlayContent: notificationBody,
      // The launcher mark doubles as the service icon; it is a drawable in the app already.
      notificationIcon: 'ic_launcher',
    );
  }

  @override
  Future<void> hide() async {
    if (!isSupported) {
      return;
    }
    await FlutterOverlayWindow.closeOverlay();
  }

  @override
  Future<bool> isActive() async {
    if (!isSupported) {
      return false;
    }
    return FlutterOverlayWindow.isActive();
  }

  @override
  Stream<Object?> get events =>
      isSupported ? FlutterOverlayWindow.overlayListener : const Stream<Object?>.empty();
}

/// A host that refuses, for platforms without a floating window.
///
/// Used by widget tests and by web/desktop builds, where "there is no bubble here" is the
/// truth to tell rather than an exception to swallow.
class UnsupportedOverlayBubbleHost implements OverlayBubbleHost {
  /// Creates the host.
  const UnsupportedOverlayBubbleHost();

  @override
  bool get isSupported => false;

  @override
  Future<bool> isPermissionGranted() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> show({
    required String notificationTitle,
    required String notificationBody,
  }) async =>
      throw UnsupportedError('No floating window on this platform.');

  @override
  Future<void> hide() async {}

  @override
  Future<bool> isActive() async => false;

  @override
  Stream<Object?> get events => const Stream<Object?>.empty();
}

/// The bubble host, overridable in tests.
final Provider<OverlayBubbleHost> overlayBubbleHostProvider =
    Provider<OverlayBubbleHost>((Ref ref) => const FlutterOverlayBubbleHost());
