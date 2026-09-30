// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

/// Layout breakpoints. Phone is the primary target, desktop must look intentional.
enum ArmxBreakpoint {
  /// Phones in portrait (width < 600).
  compact,

  /// Large phones, tablets, small desktop windows (600 ≤ width < 1024).
  medium,

  /// Desktop windows and tablets in landscape (width ≥ 1024).
  expanded;

  /// Resolves the breakpoint for [width] in logical pixels.
  static ArmxBreakpoint fromWidth(double width) {
    if (width < 600) {
      return ArmxBreakpoint.compact;
    }
    if (width < 1024) {
      return ArmxBreakpoint.medium;
    }
    return ArmxBreakpoint.expanded;
  }
}

/// Convenience accessors for responsive layout decisions.
extension ArmxResponsive on BuildContext {
  /// Current breakpoint.
  ArmxBreakpoint get breakpoint =>
      ArmxBreakpoint.fromWidth(MediaQuery.sizeOf(this).width);

  /// True on phone-sized layouts.
  bool get isCompact => breakpoint == ArmxBreakpoint.compact;

  /// True when a persistent side rail is worth the pixels.
  bool get isExpanded => breakpoint == ArmxBreakpoint.expanded;

  /// Horizontal page padding for the current breakpoint.
  double get pagePadding => switch (breakpoint) {
        ArmxBreakpoint.compact => 16,
        ArmxBreakpoint.medium => 24,
        ArmxBreakpoint.expanded => 32,
      };

  /// Maximum content width so text does not stretch across a 4K desktop window.
  double get maxContentWidth => switch (breakpoint) {
        ArmxBreakpoint.compact => double.infinity,
        ArmxBreakpoint.medium => 720,
        ArmxBreakpoint.expanded => 1080,
      };
}
