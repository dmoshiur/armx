// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';

/// A shimmering placeholder block.
///
/// Skeletons are used **instead of** a bare spinner wherever the shape of the incoming
/// content is known, because they communicate what is about to appear and keep the layout
/// from jumping. The animation is suppressed under reduced-motion and the widget is
/// announced once as "Loading content" rather than reading out every grey box.
///
/// A skeleton is only ever rendered while a request is genuinely in flight. It never
/// stands in for an empty or failed result — those have their own widgets.
class ArmxLoadingSkeleton extends StatefulWidget {
  /// Creates a skeleton block.
  const ArmxLoadingSkeleton({
    this.width,
    this.height = 14,
    this.radius = 6,
    this.shape = BoxShape.rectangle,
    super.key,
  }) : assert(
          !(shape == BoxShape.circle && width == null),
          'A circular skeleton needs an explicit width.',
        );

  /// Block width. `null` fills the available width.
  final double? width;

  /// Block height.
  final double height;

  /// Corner radius for rectangular blocks.
  final double radius;

  /// Circle or rectangle.
  final BoxShape shape;

  @override
  State<ArmxLoadingSkeleton> createState() => _ArmxLoadingSkeletonState();
}

class _ArmxLoadingSkeletonState extends State<ArmxLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _start();
  }

  void _start() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0.5;
      return;
    }
    if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final Color base = colors.border.withValues(alpha: colors.isDark ? 0.14 : 0.55);

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = 0.45 + (_controller.value * 0.35);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.rectangle
                ? BorderRadius.circular(widget.radius)
                : null,
            color: base.withValues(alpha: base.a * t + 0.25),
          ),
        );
      },
    );
  }
}

/// A skeleton that mimics a card: a title line, two body lines and an optional action row.
class ArmxSkeletonCard extends StatelessWidget {
  /// Creates a card skeleton.
  const ArmxSkeletonCard({this.lines = 2, this.showAction = false, super.key});

  /// Body lines to draw.
  final int lines;

  /// Draws a placeholder button row at the bottom.
  final bool showAction;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(Insets.cardRadius),
        border: Border.all(color: colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              const ArmxLoadingSkeleton(width: 36, height: 36, radius: 10),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const ArmxLoadingSkeleton(width: 140, height: 13),
                    const SizedBox(height: Insets.sm),
                    ArmxLoadingSkeleton(
                      width: 90,
                      height: 11,
                      radius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          for (int i = 0; i < lines; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: Insets.sm),
            ArmxLoadingSkeleton(
              height: 12,
              // The last line is short, the way a real paragraph ends.
              width: i == lines - 1 ? 180 : null,
            ),
          ],
          if (showAction) ...<Widget>[
            const SizedBox(height: Insets.lg),
            const ArmxLoadingSkeleton(width: 120, height: 36, radius: 10),
          ],
        ],
      ),
    );
  }
}

/// A grid of card skeletons that adapts its column count the same way the real grid does.
///
/// This is what makes a loading state on desktop not look like a stretched phone layout.
class ArmxLoadingSkeletonGrid extends StatelessWidget {
  /// Creates a grid of skeletons.
  const ArmxLoadingSkeletonGrid({
    this.count = 4,
    this.maxCardWidth = 320,
    this.aspectRatio = 1.5,
    super.key,
  });

  /// How many placeholder cards to draw.
  final int count;

  /// Maximum card width before another column is added.
  final double maxCardWidth;

  /// Placeholder aspect ratio.
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.a11yLoading,
      liveRegion: true,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxCardWidth,
          mainAxisSpacing: Insets.lg,
          crossAxisSpacing: Insets.lg,
          childAspectRatio: aspectRatio,
        ),
        itemCount: count,
        itemBuilder: (BuildContext context, int index) =>
            const ArmxSkeletonCard(lines: 2, showAction: true),
      ),
    );
  }
}

/// A skeleton shaped like a table, for the admin user list and the audit log.
class ArmxSkeletonTable extends StatelessWidget {
  /// Creates a table skeleton.
  const ArmxSkeletonTable({this.rows = 6, super.key});

  /// Rows to draw.
  final int rows;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    return Semantics(
      label: context.l10n.a11yLoading,
      liveRegion: true,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(Insets.cardRadius),
          border: Border.all(color: colors.hairline),
        ),
        child: Column(
          children: <Widget>[
            for (int i = 0; i < rows; i++) ...<Widget>[
              if (i > 0) Divider(height: 1, color: colors.hairline),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.lg,
                  vertical: Insets.md,
                ),
                child: Row(
                  children: <Widget>[
                    const ArmxLoadingSkeleton(width: 28, height: 28, radius: 8),
                    const SizedBox(width: Insets.md),
                    const Expanded(
                      flex: 3,
                      child: ArmxLoadingSkeleton(height: 12),
                    ),
                    const SizedBox(width: Insets.md),
                    const Expanded(
                      flex: 2,
                      child: ArmxLoadingSkeleton(height: 12),
                    ),
                    const SizedBox(width: Insets.md),
                    const ArmxLoadingSkeleton(width: 64, height: 20, radius: 8),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
