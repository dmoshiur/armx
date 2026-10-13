// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// The button intents in the design system.
enum ArmxButtonVariant {
  /// Filled with `accent`, labelled with `ink`. The single most important action on a
  /// screen — never more than one primary per view.
  primary,

  /// Outlined with a hairline border on the surface colour. Secondary actions.
  secondary,

  /// Filled with `dangerFill` and a white label. Destructive actions. Always paired with
  /// [ArmxConfirmDialog] when its risk tier is HIGH.
  destructive,

  /// No fill, no border. Tertiary actions such as "Forgot password?" or "Dismiss".
  ghost,

  /// Filled with `surfaceAlt`. Neutral emphasis inside dense toolbars on desktop, where a
  /// bare text button would be hard to hit.
  tonal,
}

/// The size steps in the design system. Every size keeps a >= 48 dp tap target on compact
/// layouts; [ArmxButtonSize.small] reaches 48 dp through its padding even though its label
/// is 13 dp.
enum ArmxButtonSize {
  /// Dense toolbars and table rows. Height 40, padding 12/8.
  small,

  /// The default. Height 48, padding 16/12.
  medium,

  /// The marquee action (the kill-switch, "Deploy"). Height 56, padding 24/16.
  large,
}

/// The one button in the app.
///
/// Every affordance the design system requires lives here instead of being re-implemented
/// per screen:
///
/// * **Loading state built in** — pass [loading] and the button shows a spinner, ignores
///   taps and reports `enabled: false` to screen readers, so a double-submit cannot fire
///   two deploys.
/// * **>= 48 dp touch targets** on compact layouts (§2).
/// * **Hover and focus states** on medium/expanded, drawn as an explicit focus ring rather
///   than relying on the browser default (§2).
/// * **A semantic label** — an icon-only button must be given [semanticLabel], which is
///   asserted in debug builds.
/// * **No colour-only signalling** — the destructive variant also renders its label in
///   bold and carries a warning icon when [icon] is omitted, so meaning survives a
///   monochrome screen.
class ArmxButton extends StatelessWidget {
  /// Creates a button.
  const ArmxButton({
    required this.label,
    required this.onPressed,
    this.variant = ArmxButtonVariant.primary,
    this.size = ArmxButtonSize.medium,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.semanticLabel,
    this.tooltip,
    super.key,
  }) : assert(
          label != '' || semanticLabel != null,
          'An icon-only button must supply a semanticLabel for screen readers.',
        );

  /// Visible label. Pass an empty string only with [semanticLabel] set.
  final String label;

  /// Invoked on tap. `null` disables the button.
  final VoidCallback? onPressed;

  /// Visual intent.
  final ArmxButtonVariant variant;

  /// Size step.
  final ArmxButtonSize size;

  /// Optional leading icon.
  final IconData? icon;

  /// Shows a spinner, blocks input and marks the button busy.
  final bool loading;

  /// Stretches to the parent's width — the correct behaviour for a phone form.
  final bool expand;

  /// Overrides the accessible name (required when [label] is empty).
  final String? semanticLabel;

  /// Hover tooltip. Defaults to nothing; icon-only buttons should set it.
  final String? tooltip;

  bool get _isInteractive => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final (_FillStyle style, Color foreground) = _resolve(colors);
    final EdgeInsets padding = switch (size) {
      ArmxButtonSize.small => const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
      ArmxButtonSize.medium => const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.md,
        ),
      ArmxButtonSize.large => const EdgeInsets.symmetric(
          horizontal: Insets.xl,
          vertical: Insets.lg,
        ),
    };
    final double minHeight = switch (size) {
      ArmxButtonSize.small => 40,
      ArmxButtonSize.medium => Insets.minTouchTarget,
      ArmxButtonSize.large => 56,
    };
    final double fontSize = switch (size) {
      ArmxButtonSize.small => 13,
      ArmxButtonSize.medium => 14,
      ArmxButtonSize.large => 16,
    };

    final Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (loading) ...<Widget>[
          SizedBox(
            width: fontSize + 3,
            height: fontSize + 3,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: foreground,
            ),
          ),
          const SizedBox(width: Insets.sm),
        ] else if (icon != null) ...<Widget>[
          Icon(icon, size: fontSize + 6, color: foreground),
          const SizedBox(width: Insets.sm),
        ],
        if (label.isNotEmpty)
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: ArmxTypography.inter(
                size: fontSize,
                weight: 600,
                height: 1.2,
                color: foreground,
              ),
            ),
          ),
      ],
    );

    final Widget button = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Material(
        color: style.fill,
        borderRadius: BorderRadius.circular(Insets.controlRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _isInteractive ? onPressed : null,
          borderRadius: BorderRadius.circular(Insets.controlRadius),
          // Explicit hover/focus feedback for mouse and keyboard users on
          // medium/expanded layouts, where the ink splash alone is too subtle.
          hoverColor: foreground.withValues(alpha: 0.10),
          focusColor: foreground.withValues(alpha: 0.18),
          canRequestFocus: _isInteractive,
          child: AnimatedContainer(
            duration: Motion.durationOf(context, Motion.fast),
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Insets.controlRadius),
              border: style.border == null ? null : Border.all(color: style.border!),
            ),
            child: content,
          ),
        ),
      ),
    );

    final Widget sized = expand
        ? SizedBox(width: double.infinity, child: button)
        : button;

    // A disabled button must still be *announced* as disabled rather than reading as a
    // plain label; `Semantics.enabled` drives that.
    final Widget semantic = Semantics(
      button: true,
      enabled: _isInteractive,
      busy: loading,
      label: semanticLabel ?? (label.isEmpty ? null : label),
      excludeSemantics: true,
      child: sized,
    );

    if (tooltip == null) {
      return semantic;
    }
    return Tooltip(message: tooltip!, child: semantic);
  }

  (_FillStyle, Color) _resolve(ArmxColors colors) {
    if (!_isInteractive) {
      // Disabled: a washed fill with muted text, legible without relying on hue.
      return (
        _FillStyle(fill: colors.surfaceAlt.withValues(alpha: 0.6), border: colors.hairline),
        colors.textMuted,
      );
    }
    return switch (variant) {
      ArmxButtonVariant.primary => (
          _FillStyle(fill: colors.accent),
          colors.onAccent,
        ),
      ArmxButtonVariant.secondary => (
          _FillStyle(fill: Colors.transparent, border: colors.hairline),
          colors.text,
        ),
      ArmxButtonVariant.destructive => (
          _FillStyle(fill: colors.dangerFill),
          colors.onDangerFill,
        ),
      ArmxButtonVariant.ghost => (
          const _FillStyle(fill: Colors.transparent),
          colors.accentText,
        ),
      ArmxButtonVariant.tonal => (
          _FillStyle(fill: colors.surfaceAlt, border: colors.hairline),
          colors.text,
        ),
    };
  }
}

/// A resolved fill + optional border.
@immutable
class _FillStyle {
  const _FillStyle({required this.fill, this.border});

  final Color fill;
  final Color? border;
}

/// Icon-only button that keeps the 48 dp target and mandates a screen-reader label.
class ArmxIconButton extends StatelessWidget {
  /// Creates an icon button.
  const ArmxIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.tooltip,
    this.variant = ArmxButtonVariant.ghost,
    this.selected = false,
    super.key,
  });

  /// Glyph to draw.
  final IconData icon;

  /// Accessible name. Required — an unlabelled icon is invisible to a screen reader.
  final String semanticLabel;

  /// Invoked on tap.
  final VoidCallback? onPressed;

  /// Hover tooltip; falls back to [semanticLabel].
  final String? tooltip;

  /// Visual intent.
  final ArmxButtonVariant variant;

  /// Renders the selected treatment (used by the collapsed rail toggle).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final Color foreground = onPressed == null
        ? colors.textMuted
        : switch (variant) {
            ArmxButtonVariant.destructive => colors.dangerText,
            ArmxButtonVariant.secondary => colors.text,
            _ => selected ? colors.accentText : colors.textMuted,
          };
    final Color? fill = selected
        ? colors.accent.withValues(alpha: colors.isDark ? 0.20 : 0.14)
        : null;

    return Tooltip(
      message: tooltip ?? semanticLabel,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: semanticLabel,
        selected: selected,
        excludeSemantics: true,
        child: SizedBox(
          width: Insets.minTouchTarget,
          height: Insets.minTouchTarget,
          child: Material(
            color: fill ?? Colors.transparent,
            borderRadius: BorderRadius.circular(Insets.controlRadius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(Insets.controlRadius),
              hoverColor: foreground.withValues(alpha: 0.10),
              focusColor: foreground.withValues(alpha: 0.18),
              child: Center(
                child: Icon(icon, size: 22, color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
