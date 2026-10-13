// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../../../../core/breakpoints.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/armx_brand.dart';

/// A scale mock-up of the floating handle, with a draggable stand-in.
///
/// The point is that the permission stops being abstract: the person can see the size the
/// bubble takes and — more usefully — **move it**, so they find out before granting anything
/// whether it will sit where they want it. The stand-in is confined to its box on purpose:
/// this is a preview of a window that lives over other apps, and it must not become a
/// floating window itself while explaining that floating windows are a big deal.
class BubblePreview extends StatefulWidget {
  /// Creates the preview.
  const BubblePreview({required this.enabled, super.key});

  /// Whether the real bubble is attached — the preview is tinted down when it is not, so it
  /// never looks like the live thing.
  final bool enabled;

  @override
  State<BubblePreview> createState() => _BubblePreviewState();
}

class _BubblePreviewState extends State<BubblePreview> {
  Offset _offset = const Offset(0.72, 0.62);

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final BorderRadius radius = BorderRadius.circular(Insets.cardRadius);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // The frame stands in for "some other app", drawn as a neutral placeholder rather
        // than a fake screenshot of an app the user does not have.
        ClipRRect(
          borderRadius: radius,
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                border: Border.all(color: colors.hairline),
                borderRadius: radius,
              ),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double handleSize = _handleSize(constraints.maxWidth);
                  final double maxX =
                      (constraints.maxWidth - handleSize).clamp(0, double.infinity);
                  final double maxY =
                      (constraints.maxHeight - handleSize).clamp(0, double.infinity);

                  return Stack(
                    children: <Widget>[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(Insets.md),
                          child: Text(
                            context.l10n.overlayPreviewBackdrop,
                            textAlign: TextAlign.center,
                            style: ArmxTypography.mono(
                              size: 11,
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: (_offset.dx * maxX).clamp(0, maxX),
                        top: (_offset.dy * maxY).clamp(0, maxY),
                        child: GestureDetector(
                          // Drag, but sized for a thumb: the mock-up is a touch target too.
                          onPanUpdate: (DragUpdateDetails details) {
                            if (maxX <= 0 || maxY <= 0) {
                              return;
                            }
                            setState(() {
                              _offset = Offset(
                                (_offset.dx + details.delta.dx / maxX).clamp(0, 1),
                                (_offset.dy + details.delta.dy / maxY).clamp(0, 1),
                              );
                            });
                          },
                          child: Semantics(
                            label: context.l10n.overlayPreviewHandle,
                            child: Opacity(
                              opacity: widget.enabled ? 1 : 0.55,
                              child: _Handle(size: handleSize),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: Insets.sm),
        Row(
          children: <Widget>[
            Icon(
              Icons.drag_indicator_rounded,
              size: 16,
              color: colors.textMuted,
            ),
            const SizedBox(width: Insets.xs),
            Expanded(
              child: Text(
                context.l10n.overlayPreviewHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Keeps the handle at least 48 dp on compact screens, and proportional above that.
  double _handleSize(double width) {
    final double scaled = width * 0.14;
    return scaled.clamp(Insets.minTouchTarget, 64);
  }
}

class _Handle extends StatelessWidget {
  const _Handle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surface,
        border: Border.all(color: colors.accent.withValues(alpha: 0.55), width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.background.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: ArmxOrb(size: size * 0.6)),
      ),
    );
  }
}
