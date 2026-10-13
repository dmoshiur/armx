// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The A.R.M.X AI design-system palette.
///
/// The first block is the **specified palette, byte-for-byte**. Nothing in the app may
/// hard-code a hex value: read the semantic tokens from [ArmxColors] instead, which are
/// built from these constants.
///
/// The second block holds a small number of **derived** values. They exist because the
/// specification's own accessibility bar (§7: "minimum contrast ratio 4.5:1 for body text
/// against its background in both themes") cannot be met by the specified values alone:
///
/// * `muted #5B6475` measures **3.16:1** on `ink` — it is readable on `fog` (5.50:1) but
///   not on the dark background, so [mutedDark] keeps its hue and lightness rises until
///   it clears AA.
/// * `accent #5B8CFF`, `accent2 #8B5CF6`, `danger #E2554E` and `success #3FBF82` all clear
///   4.5:1 against `ink`, but not against `fog`/white, so each has a darkened
///   `*Text` variant for light mode.
/// * no warning token is specified at all, although the risk tiers require one for
///   MEDIUM; `warning`/`warningLight` fill that gap.
/// * `dangerStrong` is the `danger` hue darkened until a **14 px white label** clears AA
///   on top of it (5.4:1). Filled destructive buttons use it as a fill; the exact
///   `danger` value remains the colour of kill-switch borders, glows, dots and icons.
///
/// Every one of those ratios is asserted by `test/unit/core/theme/contrast_test.dart`, so
/// this is a checked claim rather than a comment. See
/// `docs/decisions/0003-palette-and-contrast.md`.
abstract final class ArmxPalette {
  // ---- Specified tokens (exact) -------------------------------------------

  /// App background (dark mode default).
  static const Color ink = Color(0xFF0B1220);

  /// Cards, panels, section bands.
  static const Color navy = Color(0xFF101935);

  /// Primary buttons, links, active navigation item.
  static const Color accent = Color(0xFF5B8CFF);

  /// Secondary highlights only — never combined with [accent] on one element.
  static const Color accent2 = Color(0xFF8B5CF6);

  /// Light-mode surface / card background.
  static const Color fog = Color(0xFFF4F6FB);

  /// Hairline dividers and borders.
  static const Color line = Color(0xFFD7DCEA);

  /// Secondary text.
  static const Color muted = Color(0xFF5B6475);

  /// Kill-switch, destructive actions, denied / failed states.
  static const Color danger = Color(0xFFE2554E);

  /// Approved / connected states.
  static const Color success = Color(0xFF3FBF82);

  // ---- Derived tokens (see the class docs and the contrast test) ----------

  /// A raised panel surface: [navy] lifted just enough to separate nested cards.
  static const Color navyRaised = Color(0xFF16224A);

  /// [muted] with the same hue at 221°, lightened to clear 4.5:1 on [ink] and [navy].
  static const Color mutedDark = Color(0xFF7C8598);

  /// MEDIUM-risk / attention colour. Not specified; required by the risk tiers.
  static const Color warning = Color(0xFFF2B441);

  /// [warning] darkened for 4.5:1 on [fog] and white.
  static const Color warningText = Color(0xFF8A5A08);

  /// [danger] darkened for a 14 px white label at 4.5:1 on the fill.
  static const Color dangerStrong = Color(0xFFC0392F);

  /// [success] darkened for 4.5:1 on [fog] and white.
  static const Color successText = Color(0xFF1F7A4E);

  /// [accent] darkened for 4.5:1 on [fog] and white.
  static const Color accentText = Color(0xFF2E5FD9);

  /// [accent2] darkened for 4.5:1 on [fog] and white.
  static const Color accent2Text = Color(0xFF6D28D9);

  /// [accent2] lightened for 4.5:1 on [ink].
  static const Color accent2OnDark = Color(0xFFA78BFA);

  /// Pure white, used as the label colour on [dangerStrong] fills.
  static const Color onDangerStrong = Color(0xFFFFFFFF);
}

/// Semantic colour tokens, exposed through `ThemeData.extensions`.
///
/// Widgets ask for *meaning* ("the muted text colour", "the success colour") rather than
/// for a hue, so the dark and light themes stay in sync and a future brand refresh is a
/// single-file change.
@immutable
class ArmxColors extends ThemeExtension<ArmxColors> {
  /// Creates a token set. Prefer [ArmxColors.dark] / [ArmxColors.light].
  const ArmxColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.accent2,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.accentText,
    required this.accent2Text,
    required this.successText,
    required this.warningText,
    required this.dangerText,
    required this.dangerFill,
    required this.onDangerFill,
    required this.isDark,
  });

  /// Dark tokens — the product default.
  static const ArmxColors dark = ArmxColors(
    background: ArmxPalette.ink,
    surface: ArmxPalette.navy,
    surfaceAlt: ArmxPalette.navyRaised,
    border: ArmxPalette.line,
    text: ArmxPalette.fog,
    textMuted: ArmxPalette.mutedDark,
    accent: ArmxPalette.accent,
    accent2: ArmxPalette.accent2,
    onAccent: ArmxPalette.ink,
    success: ArmxPalette.success,
    warning: ArmxPalette.warning,
    danger: ArmxPalette.danger,
    accentText: ArmxPalette.accent,
    accent2Text: ArmxPalette.accent2OnDark,
    successText: ArmxPalette.success,
    warningText: ArmxPalette.warning,
    dangerText: ArmxPalette.danger,
    dangerFill: ArmxPalette.dangerStrong,
    onDangerFill: ArmxPalette.onDangerStrong,
    isDark: true,
  );

  /// Light tokens — `ink`/`navy` swap for `fog`/white; `accent`/`accent2` are unchanged
  /// wherever they are used as fills, and use their darkened text variants as foreground.
  static const ArmxColors light = ArmxColors(
    background: ArmxPalette.fog,
    surface: Color(0xFFFFFFFF),
    surfaceAlt: ArmxPalette.fog,
    border: ArmxPalette.line,
    text: ArmxPalette.ink,
    textMuted: ArmxPalette.muted,
    accent: ArmxPalette.accent,
    accent2: ArmxPalette.accent2,
    onAccent: ArmxPalette.ink,
    success: ArmxPalette.success,
    warning: ArmxPalette.warning,
    danger: ArmxPalette.danger,
    accentText: ArmxPalette.accentText,
    accent2Text: ArmxPalette.accent2Text,
    successText: ArmxPalette.successText,
    warningText: ArmxPalette.warningText,
    dangerText: ArmxPalette.dangerStrong,
    dangerFill: ArmxPalette.dangerStrong,
    onDangerFill: ArmxPalette.onDangerStrong,
    isDark: false,
  );

  /// App background.
  final Color background;

  /// Card / panel surface.
  final Color surface;

  /// Raised surface for nested cards, sheets and secondary bands.
  final Color surfaceAlt;

  /// Hairline border colour. In dark mode this is `line` at low alpha so it reads as a
  /// hairline rather than a bright rule; in light mode it is `line` itself.
  final Color border;

  /// Primary text colour.
  final Color text;

  /// Secondary text colour (AA-checked against [background] and [surface]).
  final Color textMuted;

  /// Brand accent: primary buttons, links, the active navigation item.
  final Color accent;

  /// Secondary accent. Never placed on the same element as [accent].
  final Color accent2;

  /// Label colour that sits **on** [accent] — `ink`, so the pair clears 5.9:1.
  final Color onAccent;

  /// Approved / connected.
  final Color success;

  /// Attention / MEDIUM risk.
  final Color warning;

  /// Destructive / denied / HIGH risk.
  final Color danger;

  /// [accent] as foreground text on this theme's surfaces.
  final Color accentText;

  /// [accent2] as foreground text on this theme's surfaces.
  final Color accent2Text;

  /// [success] as foreground text on this theme's surfaces.
  final Color successText;

  /// [warning] as foreground text on this theme's surfaces.
  final Color warningText;

  /// [danger] as foreground text on this theme's surfaces.
  final Color dangerText;

  /// Fill colour for destructive buttons (white label clears 4.5:1 on it).
  final Color dangerFill;

  /// Label colour for [dangerFill].
  final Color onDangerFill;

  /// Whether this set belongs to the dark theme.
  final bool isDark;

  /// Effective hairline border for the current theme.
  Color get hairline => isDark ? border.withValues(alpha: 0.20) : border;

  /// Translucent fill for glassy panels and sticky headers.
  Color get glassFill => (isDark ? Colors.white : Colors.white)
      .withValues(alpha: isDark ? 0.045 : 0.72);

  /// Scrim behind dialogs and modal sheets.
  Color get scrim =>
      (isDark ? ArmxPalette.ink : ArmxPalette.ink).withValues(alpha: 0.74);

  /// Convenience accessor: `ArmxColors.of(context)`.
  static ArmxColors of(BuildContext context) =>
      Theme.of(context).extension<ArmxColors>() ?? ArmxColors.dark;

  /// The colour for a semantic tone.
  Color tone(ArmxTone tone) => switch (tone) {
        ArmxTone.neutral => textMuted,
        ArmxTone.accent => accentText,
        ArmxTone.secondary => accent2Text,
        ArmxTone.success => successText,
        ArmxTone.warning => warningText,
        ArmxTone.danger => dangerText,
      };

  @override
  ArmxColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? accent,
    Color? accent2,
    Color? onAccent,
    Color? success,
    Color? warning,
    Color? danger,
    Color? accentText,
    Color? accent2Text,
    Color? successText,
    Color? warningText,
    Color? dangerText,
    Color? dangerFill,
    Color? onDangerFill,
    bool? isDark,
  }) {
    return ArmxColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      accent2: accent2 ?? this.accent2,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      accentText: accentText ?? this.accentText,
      accent2Text: accent2Text ?? this.accent2Text,
      successText: successText ?? this.successText,
      warningText: warningText ?? this.warningText,
      dangerText: dangerText ?? this.dangerText,
      dangerFill: dangerFill ?? this.dangerFill,
      onDangerFill: onDangerFill ?? this.onDangerFill,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  ArmxColors lerp(ThemeExtension<ArmxColors>? other, double t) {
    if (other is! ArmxColors) {
      return this;
    }
    return ArmxColors(
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t) ?? surfaceAlt,
      border: Color.lerp(border, other.border, t) ?? border,
      text: Color.lerp(text, other.text, t) ?? text,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      accent2: Color.lerp(accent2, other.accent2, t) ?? accent2,
      onAccent: Color.lerp(onAccent, other.onAccent, t) ?? onAccent,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      accentText: Color.lerp(accentText, other.accentText, t) ?? accentText,
      accent2Text: Color.lerp(accent2Text, other.accent2Text, t) ?? accent2Text,
      successText: Color.lerp(successText, other.successText, t) ?? successText,
      warningText: Color.lerp(warningText, other.warningText, t) ?? warningText,
      dangerText: Color.lerp(dangerText, other.dangerText, t) ?? dangerText,
      dangerFill: Color.lerp(dangerFill, other.dangerFill, t) ?? dangerFill,
      onDangerFill: Color.lerp(onDangerFill, other.onDangerFill, t) ?? onDangerFill,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// Semantic intents, so a widget asks for meaning instead of a specific hue.
enum ArmxTone {
  /// No particular meaning — secondary text.
  neutral,

  /// Brand accent.
  accent,

  /// Secondary brand accent.
  secondary,

  /// Allowed / connected / approved.
  success,

  /// Needs attention / MEDIUM risk.
  warning,

  /// Blocked / destructive / HIGH risk.
  danger,
}

/// WCAG 2.1 relative-luminance contrast maths.
///
/// Lives in `lib/` (not in `test/`) because the design-system gallery in
/// `Settings → Design system` renders the live ratio for every documented pair, which is
/// how a reviewer checks §7 without running the test suite.
abstract final class Contrast {
  /// Relative luminance of [color] per WCAG 2.1.
  static double luminance(Color color) {
    double channel(double c) {
      return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * channel(color.r) +
        0.7152 * channel(color.g) +
        0.0722 * channel(color.b);
  }

  /// Contrast ratio between two opaque colours, from 1.0 to 21.0.
  static double ratio(Color a, Color b) {
    final double la = luminance(a);
    final double lb = luminance(b);
    final double lighter = la > lb ? la : lb;
    final double darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// True when [foreground] on [background] meets WCAG AA for body text.
  static bool passesAA(Color foreground, Color background) =>
      ratio(foreground, background) >= 4.5;

  /// True when [foreground] on [background] meets WCAG AA for large text and for
  /// non-text UI components (borders, icons, focus rings).
  static bool passesAALarge(Color foreground, Color background) =>
      ratio(foreground, background) >= 3.0;
}
