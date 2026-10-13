// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/widgets.dart';

/// The three layout classes every screen in A.R.M.X AI must support.
///
/// The app is one codebase for phone, tablet, desktop and web. Layout adapts through
/// these breakpoints — **never** through `Platform.isAndroid` / `Platform.isIOS`
/// branching, which would fork behaviour per device instead of per available space.
///
/// | Class | Width (logical dp) | Navigation | Reference size |
/// | --- | --- | --- | --- |
/// | [compact] | `< 600` | bottom navigation bar | 360 × 800 (phone) |
/// | [medium] | `600 – 1024` | collapsible `NavigationRail` | 800 × 1280 (tablet) |
/// | [expanded] | `>= 1024` | persistent sidebar + secondary panel | 1440 × 900 (desktop) |
enum Breakpoint {
  /// Phones in portrait, and any window narrower than 600 dp.
  compact,

  /// Large phones, foldables, tablets, and narrow desktop windows.
  medium,

  /// Desktop, web-wide, tablets in landscape.
  expanded;

  /// The width, in logical pixels, at which [compact] becomes [medium].
  static const double compactMax = 600;

  /// The width, in logical pixels, at which [medium] becomes [expanded].
  static const double mediumMax = 1024;

  /// Widest a column of text/controls may grow before it is centred instead of stretched.
  ///
  /// Ultra-wide monitors are common; a form that spans 2560 dp is unreadable. Main content
  /// is capped at this width and centred, with the navigation sidebar sitting *outside*
  /// the constraint.
  static const double maxContentWidth = 1200;

  /// Resolves the breakpoint for a logical width.
  ///
  /// Boundaries are inclusive at the bottom: exactly 600 dp is [medium], exactly 1024 dp
  /// is [expanded].
  static Breakpoint fromWidth(double width) {
    if (width < compactMax) {
      return Breakpoint.compact;
    }
    if (width < mediumMax) {
      return Breakpoint.medium;
    }
    return Breakpoint.expanded;
  }
}

/// Convenience accessors so a widget can ask "how much room do I have?" in one line.
extension BreakpointContext on BuildContext {
  /// The current layout class, resolved from the enclosing [MediaQuery].
  ///
  /// Prefer `LayoutBuilder` + [Breakpoint.fromWidth] when a widget is nested inside a
  /// pane that is narrower than the window (for example the content area beside a
  /// sidebar); this getter reports the *window* width.
  Breakpoint get breakpoint => Breakpoint.fromWidth(MediaQuery.sizeOf(this).width);

  /// True on phone-sized layouts (`< 600` dp).
  bool get isCompact => breakpoint == Breakpoint.compact;

  /// True on tablet / foldable layouts (`600 – 1024` dp).
  bool get isMedium => breakpoint == Breakpoint.medium;

  /// True on desktop / wide-web layouts (`>= 1024` dp).
  bool get isExpanded => breakpoint == Breakpoint.expanded;

  /// True when the layout has no room for a bottom bar *and* a visible rail.
  bool get hasRoomForRail => breakpoint != Breakpoint.compact;

  /// Horizontal page padding appropriate to the current breakpoint.
  double get pagePadding => switch (breakpoint) {
        Breakpoint.compact => 16,
        Breakpoint.medium => 24,
        Breakpoint.expanded => 32,
      };

  /// Vertical rhythm between major blocks on a page.
  double get sectionGap => switch (breakpoint) {
        Breakpoint.compact => 16,
        Breakpoint.medium => 20,
        Breakpoint.expanded => 24,
      };

  /// Number of columns a card grid should use at this breakpoint.
  ///
  /// Grids that size cards by intrinsic width use
  /// `SliverGridDelegateWithMaxCrossAxisExtent` instead; this is for the rare grid that
  /// must land on an exact column count.
  int get gridColumns => switch (breakpoint) {
        Breakpoint.compact => 1,
        Breakpoint.medium => 2,
        Breakpoint.expanded => 3,
      };
}
