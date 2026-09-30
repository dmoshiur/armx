// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

/// Motion tokens for the whole app.
///
/// The assistant orb, streaming tokens and status transitions all read their timing from
/// here, and every animation is disabled when the platform asks for reduced motion
/// (Android "Remove animations", iOS "Reduce Motion", desktop equivalents).
abstract final class ArmxMotion {
  /// 120 ms — colour/opacity tweaks, chip state changes.
  static const Duration quick = Duration(milliseconds: 120);

  /// 240 ms — the default for panel, tab and page content transitions.
  static const Duration standard = Duration(milliseconds: 240);

  /// 420 ms — hero-ish entrances (splash wordmark, orb boot).
  static const Duration gentle = Duration(milliseconds: 420);

  /// 1.6 s — one full orb breathing cycle while idle.
  static const Duration breath = Duration(milliseconds: 1600);

  /// 900 ms — one orb pulse while listening.
  static const Duration pulse = Duration(milliseconds: 900);

  /// Standard easing for entrances.
  static const Curve enter = Curves.easeOutCubic;

  /// Standard easing for exits.
  static const Curve exit = Curves.easeInCubic;

  /// Easing used by the orb's breathing loop.
  static const Curve breathe = Curves.easeInOutSine;

  /// Respects the OS "reduce motion" switch.
  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Returns [duration], or [Duration.zero] when the user asked for reduced motion.
  static Duration respect(BuildContext context, Duration duration) =>
      reduceMotion(context) ? Duration.zero : duration;

  /// Returns [animation], or a completed equivalent when reduced motion is on.
  static Animation<double> respectAnimation(BuildContext context, Animation<double> animation) =>
      reduceMotion(context) ? const AlwaysStoppedAnimation<double>(1) : animation;

  /// Most restrictive route transition builder that still looks native on all three targets.
  static const PageTransitionsTheme pageTransitions = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
    },
  );
}
