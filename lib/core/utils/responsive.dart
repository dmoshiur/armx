// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../breakpoints.dart';
import '../theme/app_theme.dart';

/// A value that differs per breakpoint.
///
/// Used for the handful of places where a number genuinely changes with the layout class
/// (grid extents, panel widths, how many stat cards fit). Anything that can adapt on its
/// own — `Expanded`, `Flexible`, `Wrap`, `SliverGridDelegateWithMaxCrossAxisExtent` —
/// should adapt on its own instead of being switched here.
@immutable
class Responsive<T> {
  /// Creates a responsive value. Omitted values fall back to [compact]'s.
  const Responsive({required this.compact, this.medium, this.expanded});

  /// Value used at `< 600` dp.
  final T compact;

  /// Value used at `600 – 1024` dp. Defaults to [compact].
  final T? medium;

  /// Value used at `>= 1024` dp. Defaults to [medium], then [compact].
  final T? expanded;

  /// Resolves the value for a breakpoint.
  T resolve(Breakpoint breakpoint) => switch (breakpoint) {
        Breakpoint.compact => compact,
        Breakpoint.medium => medium ?? compact,
        Breakpoint.expanded => expanded ?? medium ?? compact,
      };

  /// Resolves the value for the width of the enclosing window.
  T resolveForWidth(double width) => resolve(Breakpoint.fromWidth(width));
}

/// Builds a subtree from the **local** constraints rather than the window width.
///
/// This matters wherever a pane is narrower than the window — the content area beside the
/// desktop sidebar, or the chat column beside the device panel. Using
/// `MediaQuery.sizeOf(context)` there would report "expanded" while the pane itself is
/// 400 dp wide, and the layout would overflow.
class BreakpointBuilder extends StatelessWidget {
  /// Creates a breakpoint-aware builder.
  const BreakpointBuilder({required this.builder, super.key});

  /// Receives the breakpoint derived from this widget's own constraints.
  final Widget Function(BuildContext context, Breakpoint breakpoint) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return builder(context, Breakpoint.fromWidth(constraints.maxWidth));
      },
    );
  }
}

/// Caps content at [Breakpoint.maxContentWidth] and centres it.
///
/// The sidebar and rail live *outside* this constraint, so on a 2560 px monitor the
/// navigation stays pinned to the window edge while the reading column stays readable and
/// centred. Every page body in the app is wrapped in one of these.
class ContentConstraint extends StatelessWidget {
  /// Wraps [child].
  const ContentConstraint({
    required this.child,
    this.maxWidth = Breakpoint.maxContentWidth,
    this.padding,
    super.key,
  });

  /// The subtree to constrain.
  final Widget child;

  /// Maximum width of the centred column.
  final double maxWidth;

  /// Optional padding applied *outside* the constraint, so the gutter is preserved on
  /// narrow windows and the column is centred on wide ones.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final EdgeInsetsGeometry effective = padding ??
        EdgeInsets.symmetric(
          horizontal: context.isCompact ? Insets.lg : Insets.xl,
          vertical: Insets.lg,
        );
    return Padding(
      padding: effective,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

/// A scrollable page body with the standard gutter and content cap.
///
/// Screens use this instead of hand-rolling `SingleChildScrollView` + padding, which is
/// how the "no fixed pixel widths on root layouts" rule is enforced in practice.
class PageBody extends StatelessWidget {
  /// Creates a page body around [children], laid out in a vertical column.
  const PageBody({
    required this.children,
    this.padding,
    this.maxWidth = Breakpoint.maxContentWidth,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.scrollable = true,
    super.key,
  });

  /// The column's children, separated by the breakpoint's section gap.
  final List<Widget> children;

  /// Overrides the outer padding.
  final EdgeInsetsGeometry? padding;

  /// Overrides the content width cap.
  final double maxWidth;

  /// Column cross-axis alignment.
  final CrossAxisAlignment crossAxisAlignment;

  /// When false the body fills the viewport without a scroll view (for pages that host
  /// their own scrolling list).
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final double gap = context.sectionGap;
    final List<Widget> spaced = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        spaced.add(SizedBox(height: gap));
      }
      spaced.add(children[i]);
    }

    final Widget column = Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: spaced,
    );

    final Widget constrained = ContentConstraint(
      maxWidth: maxWidth,
      padding: padding,
      child: column,
    );

    if (!scrollable) {
      return constrained;
    }
    return SingleChildScrollView(
      // `AlwaysScrollableScrollPhysics` keeps pull-to-refresh working even when the
      // content is shorter than the viewport (desktop, web).
      physics: const AlwaysScrollableScrollPhysics(),
      child: constrained,
    );
  }
}

/// A band of items that flows onto the next line when it runs out of width.
///
/// Preferred over `Row` for toolbars and filter strips: on a 360 dp phone a `Row` of five
/// chips overflows, while a `Wrap` reflows. No child is ever clipped or unreachable.
class AdaptiveWrap extends StatelessWidget {
  /// Creates a wrapping row.
  const AdaptiveWrap({
    required this.children,
    this.spacing = Insets.sm,
    this.runSpacing = Insets.sm,
    this.alignment = WrapAlignment.start,
    super.key,
  });

  /// Items to lay out.
  final List<Widget> children;

  /// Horizontal gap between items on the same line.
  final double spacing;

  /// Vertical gap between lines.
  final double runSpacing;

  /// Alignment of each line.
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      alignment: alignment,
      children: children,
    );
  }
}

/// Lays [primary] and [secondary] side by side when there is room, stacked when there is
/// not.
///
/// This is the pattern the assistant screen (chat + device panel), the web builder
/// (prompt + preview) and the guest greeter (preview + consent) all need: a primary pane
/// that must stay usable and an optional secondary pane that only appears when the layout
/// class can afford it.
class AdaptiveSplit extends StatelessWidget {
  /// Creates a split layout.
  const AdaptiveSplit({
    required this.primary,
    this.secondary,
    this.secondaryWidth = 360,
    this.primaryFlex = 2,
    this.secondaryFlex = 1,
    this.gap = Insets.xl,
    this.showSecondaryAt = Breakpoint.expanded,
    super.key,
  });

  /// The pane that is always visible.
  final Widget primary;

  /// The pane shown only at or above [showSecondaryAt].
  final Widget? secondary;

  /// Fixed width of the secondary pane when it is shown side by side, in logical pixels.
  /// Ignored when [secondaryFlex] is used instead.
  final double secondaryWidth;

  /// Flex of the primary pane in the side-by-side layout.
  final int primaryFlex;

  /// Flex of the secondary pane in the side-by-side layout.
  final int secondaryFlex;

  /// Gap between the panes.
  final double gap;

  /// The breakpoint at which the secondary pane appears next to the primary one.
  ///
  /// Below it the secondary pane is rendered *under* the primary pane rather than being
  /// dropped: an unreachable control is worse than a longer scroll.
  final Breakpoint showSecondaryAt;

  @override
  Widget build(BuildContext context) {
    final Widget? side = secondary;
    if (side == null) {
      return primary;
    }
    return BreakpointBuilder(
      builder: (BuildContext context, Breakpoint breakpoint) {
        final bool sideBySide = breakpoint.index >= showSecondaryAt.index;
        if (!sideBySide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              primary,
              SizedBox(height: gap),
              side,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: primaryFlex, child: primary),
            SizedBox(width: gap),
            ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: 280,
                maxWidth: secondaryWidth,
              ),
              child: side,
            ),
          ],
        );
      },
    );
  }
}

/// A card grid that grows its column count with the available width.
///
/// Always `SliverGridDelegateWithMaxCrossAxisExtent` — never a fixed `crossAxisCount` —
/// so a phone gets one card per row, a tablet two or three, and a 2560 px monitor does not
/// render a single absurdly wide card.
class AdaptiveCardGrid extends StatelessWidget {
  /// Creates a grid of [children].
  const AdaptiveCardGrid({
    required this.children,
    this.maxCardWidth = 320,
    this.aspectRatio = 1.4,
    this.spacing = Insets.lg,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  /// The cards.
  final List<Widget> children;

  /// Maximum width of one card before another column is added.
  final double maxCardWidth;

  /// Card aspect ratio.
  final double aspectRatio;

  /// Gap between cards, horizontally and vertically.
  final double spacing;

  /// Padding inside the grid.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCardWidth,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: aspectRatio,
      ),
      itemCount: children.length,
      itemBuilder: (BuildContext context, int index) => children[index],
    );
  }
}

/// Selects one of up to four named panes based on the breakpoint, used by shell chrome.
///
/// Kept separate from [Responsive] so navigation code reads as intent
/// (`AdaptivePane(compact: …, medium: …, expanded: …)`) rather than as a value lookup.
class AdaptivePane extends StatelessWidget {
  /// Creates an adaptive pane.
  const AdaptivePane({
    required this.compact,
    this.medium,
    this.expanded,
    super.key,
  });

  /// Pane built at `< 600` dp.
  final WidgetBuilder compact;

  /// Pane built at `600 – 1024` dp.
  final WidgetBuilder? medium;

  /// Pane built at `>= 1024` dp.
  final WidgetBuilder? expanded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Breakpoint breakpoint = Breakpoint.fromWidth(constraints.maxWidth);
        return switch (breakpoint) {
          Breakpoint.compact => compact(context),
          Breakpoint.medium => (medium ?? expanded ?? compact)(context),
          Breakpoint.expanded => (expanded ?? medium ?? compact)(context),
        };
      },
    );
  }
}
