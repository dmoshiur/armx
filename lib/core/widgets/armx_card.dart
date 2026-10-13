// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Card elevation steps.
enum ArmxCardTone {
  /// `navy` on dark / white on light. The default surface for content blocks.
  surface,

  /// `surfaceAlt`. For a card nested inside another card.
  raised,

  /// A tinted card whose tint carries meaning (a danger zone, an approval request).
  /// Always accompanied by an icon and text — never colour alone.
  tinted,
}

/// A padded, hairline-bordered panel.
///
/// The single content container in the app. It exists so padding, radius and border come
/// from `Insets` and `ArmxColors` rather than from twelve screens' worth of literals.
///
/// When [onTap] is supplied the whole card becomes an interactive, focusable target —
/// which is what makes a device tile usable with a keyboard on desktop instead of
/// requiring a precise click on a small inner button.
class ArmxCard extends StatelessWidget {
  /// Creates a card.
  const ArmxCard({
    required this.child,
    this.padding = const EdgeInsets.all(Insets.lg),
    this.tone = ArmxCardTone.surface,
    this.tint,
    this.onTap,
    this.semanticLabel,
    this.trailing,
    this.title,
    this.leading,
    this.dense = false,
    this.action,
    super.key,
  });

  /// Card content.
  final Widget child;

  /// Inner padding. Defaults to the 16 dp step of the system's 12/16/24 scale.
  final EdgeInsetsGeometry padding;

  /// Elevation/tone step.
  final ArmxCardTone tone;

  /// Tint used when [tone] is [ArmxCardTone.tinted]. Falls back to `accent`.
  final Color? tint;

  /// Makes the card tappable and keyboard-focusable.
  final VoidCallback? onTap;

  /// Accessible name for an interactive card. Required when [onTap] is set and the card's
  /// own text does not already describe the action.
  final String? semanticLabel;

  /// Optional header row: [leading] glyph, [title] and [trailing] widget.
  final Widget? leading;

  /// Optional header title.
  final String? title;

  /// Optional header trailing widget.
  final Widget? trailing;

  /// Tightens padding to the 12 dp step for dense desktop lists.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final Color tintColor = tint ?? colors.accent;

    final (Color fill, Color border) = switch (tone) {
      ArmxCardTone.surface => (colors.surface, colors.hairline),
      ArmxCardTone.raised => (colors.surfaceAlt, colors.hairline),
      ArmxCardTone.tinted => (
          Color.alphaBlend(tintColor.withValues(alpha: 0.10), colors.surface),
          tintColor.withValues(alpha: 0.45),
        ),
    };

    final EdgeInsetsGeometry effectivePadding =
        dense ? const EdgeInsets.all(Insets.md) : padding;

    final Widget body = Padding(
      padding: effectivePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (title != null || leading != null || trailing != null) ...<Widget>[
            Row(
              children: <Widget>[
                if (leading != null) ...<Widget>[
                  leading!,
                  const SizedBox(width: Insets.md),
                ],
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  )
                else
                  const Spacer(),
                if (trailing != null) trailing!,
                if (action != null) ...<Widget>[
                  const SizedBox(width: Insets.sm),
                  action!,
                ],
              ],
            ),
            const SizedBox(height: Insets.md),
          ],
          child,
        ],
      ),
    );

    final Widget decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(Insets.cardRadius),
        border: Border.all(color: border),
      ),
      child: body,
    );

    if (onTap == null) {
      return decorated;
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      container: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Insets.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Insets.cardRadius),
          hoverColor: colors.accent.withValues(alpha: 0.07),
          focusColor: colors.accent.withValues(alpha: 0.14),
          child: decorated,
        ),
      ),
    );
  }
}

/// A section band: a heading, optional supporting line and an optional trailing action,
/// followed by content.
///
/// Gives every screen the same section rhythm instead of each one inventing its own
/// spacing above and below headings.
class ArmxSection extends StatelessWidget {
  /// Creates a section.
  const ArmxSection({
    required this.title,
    required this.child,
    this.subtitle,
    this.action,
    this.icon,
    super.key,
  });

  /// Section heading (H2).
  final String title;

  /// Optional supporting line under the heading.
  final String? subtitle;

  /// Optional trailing action, typically a ghost [ArmxButton] or an [ArmxIconButton].
  final Widget? action;

  /// Optional heading glyph.
  final IconData? icon;

  /// Section content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Wraps rather than a Row so a long heading plus an action reflow instead of
        // overflowing at 360 dp or with a large text scale.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          spacing: Insets.md,
          runSpacing: Insets.sm,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 18, color: colors.accentText),
                  const SizedBox(width: Insets.sm),
                ],
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            if (action != null) action!,
          ],
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: Insets.xs),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: Insets.md),
        child,
      ],
    );
  }
}

/// A labelled key/value row used by detail panels and the admin table's detail drawer.
class ArmxDetailRow extends StatelessWidget {
  /// Creates a detail row.
  const ArmxDetailRow({
    required this.label,
    required this.value,
    this.monospace = false,
    this.valueColor,
    this.icon,
    super.key,
  });

  /// Left-hand label.
  final String label;

  /// Right-hand value.
  final String value;

  /// Renders the value in the monospace family (keys, ids, fingerprints, diffs).
  final bool monospace;

  /// Overrides the value colour, e.g. to a status tone.
  final Color? valueColor;

  /// Optional glyph before the label.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final TextStyle valueStyle = monospace
        ? ArmxTypography.mono(size: 13, color: valueColor ?? colors.text)
        : text.bodyMedium!.copyWith(color: valueColor ?? colors.text);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      // The value is allowed to wrap to a second line rather than being truncated, which
      // is what keeps a long fingerprint or repo path readable on a phone.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 15, color: colors.textMuted),
            const SizedBox(width: Insets.sm),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 96, maxWidth: 190),
            child: Text(label, style: text.bodySmall),
          ),
          const SizedBox(width: Insets.md),
          Expanded(child: SelectableText(value, style: valueStyle)),
        ],
      ),
    );
  }
}

/// The empty / error / loading trio's shared frame.
///
/// Not used directly by screens — [ArmxEmptyState], [ArmxErrorState] and
/// [ArmxLoadingSkeleton] build on it so the three states are visually consistent and a
/// progress or failure state can never be mistaken for "no data".
class ArmxStateFrame extends StatelessWidget {
  /// Creates a state frame.
  const ArmxStateFrame({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.body,
    this.action,
    this.secondaryAction,
    this.iconSize,
    super.key,
  });

  /// Glyph above the title.
  final IconData icon;

  /// Glyph colour, which always accompanies a text title.
  final Color iconColor;

  /// Headline.
  final String title;

  /// Explanation.
  final String? body;

  /// Primary action.
  final Widget? action;

  /// Optional second action (usually "Dismiss" or "Go back").
  final Widget? secondaryAction;

  /// Overrides the glyph size, which also sizes the disc behind it. Compact empty states
  /// use a smaller one so the explanation, not the decoration, takes the space.
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: (iconSize ?? 30) + 34,
                height: (iconSize ?? 30) + 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: 0.14),
                ),
                child: Icon(icon, size: iconSize ?? 30, color: iconColor),
              ),
              const SizedBox(height: Insets.lg),
              Text(title, textAlign: TextAlign.center, style: text.titleLarge),
              if (body != null) ...<Widget>[
                const SizedBox(height: Insets.sm),
                Text(body!, textAlign: TextAlign.center, style: text.bodyMedium),
              ],
              if (action != null) ...<Widget>[
                const SizedBox(height: Insets.xl),
                action!,
              ],
              if (secondaryAction != null) ...<Widget>[
                const SizedBox(height: Insets.sm),
                secondaryAction!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
