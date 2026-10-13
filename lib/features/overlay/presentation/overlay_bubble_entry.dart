// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../../../core/theme/colors.dart';
import '../../../core/widgets/armx_brand.dart';

/// The bubble's own UI, running in the overlay isolate.
///
/// ## Why this file is separate from the app
///
/// The floating window is a second Flutter engine: it has no `ProviderScope`, no router, no
/// session and — importantly — **no socket**. It must therefore not attempt to show live
/// state: a bubble that rendered "connected" out of its own imagination would be lying about
/// the very thing it exists to represent.
///
/// What it does instead is honest and small:
///
/// * it looks like the assistant (the orb, the accent ring);
/// * **tap** sends `open-assistant` to the main isolate and closes the bubble;
/// * **long-press** sends `bring-app`, which the main isolate turns into navigating to the
///   assistant without leaving the bubble covering the screen.
///
/// The colours come from [ArmxColors.dark] rather than the active theme, because an overlay
/// isolate cannot read the user's preference without a second disk read on every show; the
/// bubble is a handle, and it is the same in both themes.
void overlayBubbleMain() {
  runApp(const _OverlayBubbleApp());
}

/// The entry point the Android host invokes.
///
/// Annotated so the AOT compiler keeps it: a tree-shaken entry point is the classic reason a
/// floating window comes up black on a release build.
@pragma('vm:entry-point')
void overlayMain() {
  runApp(const _OverlayBubbleApp());
}

class _OverlayBubbleApp extends StatelessWidget {
  const _OverlayBubbleApp();

  @override
  Widget build(BuildContext context) {
    // The window is transparent around the bubble; only the handle draws.
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      home: _BubbleHandle(),
    );
  }
}

class _BubbleHandle extends StatelessWidget {
  const _BubbleHandle();

  /// What the main isolate receives when the bubble is used.
  static const String openAssistant = 'open-assistant';

  /// Long-press: bring the app forward without dismissing the bubble's intent to help.
  static const String bringApp = 'bring-app';

  @override
  Widget build(BuildContext context) {
    const ArmxColors colors = ArmxColors.dark;

    return Center(
      child: Semantics(
        label: 'A.R.M.X AI assistant bubble',
        button: true,
        child: GestureDetector(
          onTap: () async {
            await FlutterOverlayWindow.shareData(<String, Object?>{
              'event': openAssistant,
            });
            await FlutterOverlayWindow.closeOverlay();
          },
          onLongPress: () => FlutterOverlayWindow.shareData(<String, Object?>{
            'event': bringApp,
          }),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surface,
              border: Border.all(
                color: colors.accent.withValues(alpha: 0.55),
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: const ArmxOrb(size: 44),
          ),
        ),
      ),
    );
  }
}
