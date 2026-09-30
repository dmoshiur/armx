// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

/// The A.R.M.X brand palette, exactly as specified in the brand PDF.
///
/// Dark is the default product look; the light palette mirrors the same hues with
/// darkened values so that contrast still meets WCAG AA on a light surface.
abstract final class ArmxPalette {
  // ---- Dark (primary) ------------------------------------------------------
  /// App background.
  static const Color darkBackground = Color(0xFF0B1020);

  /// Primary panel surface.
  static const Color darkPanel = Color(0xFF141B33);

  /// Secondary/elevated panel surface.
  static const Color darkPanel2 = Color(0xFF1B2444);

  /// Accent cyan (brand, "AI" in the wordmark, active states).
  static const Color darkCyan = Color(0xFF22D3EE);

  /// Accent violet (secondary brand accent).
  static const Color darkViolet = Color(0xFF8B5CF6);

  /// Primary text.
  static const Color darkText = Color(0xFFE5E9F5);

  /// Muted/secondary text.
  static const Color darkMuted = Color(0xFF93A0C0);

  /// Hairline borders and dividers.
  static const Color darkBorder = Color(0xFF263056);

  /// Warning / MEDIUM risk.
  static const Color darkAmber = Color(0xFFF59E0B);

  /// Success / LOW risk / online.
  static const Color darkGreen = Color(0xFF34D399);

  /// Danger / HIGH risk / kill-switch.
  static const Color darkRed = Color(0xFFF87171);

  // ---- Light ---------------------------------------------------------------
  /// Light app background.
  static const Color lightBackground = Color(0xFFF5F7FC);

  /// Light primary panel surface.
  static const Color lightPanel = Color(0xFFFFFFFF);

  /// Light secondary panel surface.
  static const Color lightPanel2 = Color(0xFFEAEEF8);

  /// Light accent cyan (darkened for AA contrast on white).
  static const Color lightCyan = Color(0xFF0E7490);

  /// Light accent violet.
  static const Color lightViolet = Color(0xFF6D28D9);

  /// Light primary text.
  static const Color lightText = Color(0xFF0B1020);

  /// Light muted text.
  static const Color lightMuted = Color(0xFF556180);

  /// Light hairline borders.
  static const Color lightBorder = Color(0xFFCFD7EA);

  /// Light warning / MEDIUM risk.
  static const Color lightAmber = Color(0xFFB45309);

  /// Light success / LOW risk.
  static const Color lightGreen = Color(0xFF047857);

  /// Light danger / HIGH risk.
  static const Color lightRed = Color(0xFFB91C1C);
}

/// Semantic colour tokens exposed through [ThemeData.extensions].
///
/// Widgets must never hard-code hex values: read tokens from here so that the dark and
/// light themes stay in sync and a future brand refresh touches a single file.
@immutable
class ArmxColors extends ThemeExtension<ArmxColors> {
  /// Creates a token set.
  const ArmxColors({
    required this.background,
    required this.panel,
    required this.panel2,
    required this.cyan,
    required this.violet,
    required this.text,
    required this.muted,
    required this.border,
    required this.amber,
    required this.green,
    required this.red,
    required this.isDark,
  });

  /// Default dark token set used by the product.
  static const ArmxColors dark = ArmxColors(
    background: ArmxPalette.darkBackground,
    panel: ArmxPalette.darkPanel,
    panel2: ArmxPalette.darkPanel2,
    cyan: ArmxPalette.darkCyan,
    violet: ArmxPalette.darkViolet,
    text: ArmxPalette.darkText,
    muted: ArmxPalette.darkMuted,
    border: ArmxPalette.darkBorder,
    amber: ArmxPalette.darkAmber,
    green: ArmxPalette.darkGreen,
    red: ArmxPalette.darkRed,
    isDark: true,
  );

  /// Light token set.
  static const ArmxColors light = ArmxColors(
    background: ArmxPalette.lightBackground,
    panel: ArmxPalette.lightPanel,
    panel2: ArmxPalette.lightPanel2,
    cyan: ArmxPalette.lightCyan,
    violet: ArmxPalette.lightViolet,
    text: ArmxPalette.lightText,
    muted: ArmxPalette.lightMuted,
    border: ArmxPalette.lightBorder,
    amber: ArmxPalette.lightAmber,
    green: ArmxPalette.lightGreen,
    red: ArmxPalette.lightRed,
    isDark: false,
  );

  /// App background behind the shell.
  final Color background;

  /// Default card/panel surface.
  final Color panel;

  /// Elevated panel surface.
  final Color panel2;

  /// Cyan accent.
  final Color cyan;

  /// Violet accent.
  final Color violet;

  /// Primary text colour.
  final Color text;

  /// Secondary text colour.
  final Color muted;

  /// Border/divider colour.
  final Color border;

  /// Warning/MEDIUM colour.
  final Color amber;

  /// Success/LOW colour.
  final Color green;

  /// Danger/HIGH colour.
  final Color red;

  /// Whether this set belongs to a dark theme.
  final bool isDark;

  /// Returns the token set for [context], falling back to [ArmxColors.dark].
  static ArmxColors of(BuildContext context) =>
      Theme.of(context).extension<ArmxColors>() ?? ArmxColors.dark;

  /// Subtle translucent fill used by glass panels.
  Color get glassFill =>
      (isDark ? Colors.white : Colors.white).withValues(alpha: isDark ? 0.04 : 0.65);

  /// Translucent border used by glass panels.
  Color get glassBorder => border.withValues(alpha: isDark ? 0.9 : 1);

  /// Scrim for dialogs and bottom sheets.
  Color get scrim => (isDark ? const Color(0xFF05070F) : const Color(0xFF0B1020))
      .withValues(alpha: 0.72);

  /// Colour associated with a semantic severity, used by chips and pills.
  Color severity(SeverityTone tone) => switch (tone) {
        SeverityTone.neutral => muted,
        SeverityTone.info => cyan,
        SeverityTone.success => green,
        SeverityTone.warning => amber,
        SeverityTone.danger => red,
        SeverityTone.accent => violet,
      };

  @override
  ArmxColors copyWith({
    Color? background,
    Color? panel,
    Color? panel2,
    Color? cyan,
    Color? violet,
    Color? text,
    Color? muted,
    Color? border,
    Color? amber,
    Color? green,
    Color? red,
    bool? isDark,
  }) {
    return ArmxColors(
      background: background ?? this.background,
      panel: panel ?? this.panel,
      panel2: panel2 ?? this.panel2,
      cyan: cyan ?? this.cyan,
      violet: violet ?? this.violet,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      border: border ?? this.border,
      amber: amber ?? this.amber,
      green: green ?? this.green,
      red: red ?? this.red,
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
      panel: Color.lerp(panel, other.panel, t) ?? panel,
      panel2: Color.lerp(panel2, other.panel2, t) ?? panel2,
      cyan: Color.lerp(cyan, other.cyan, t) ?? cyan,
      violet: Color.lerp(violet, other.violet, t) ?? violet,
      text: Color.lerp(text, other.text, t) ?? text,
      muted: Color.lerp(muted, other.muted, t) ?? muted,
      border: Color.lerp(border, other.border, t) ?? border,
      amber: Color.lerp(amber, other.amber, t) ?? amber,
      green: Color.lerp(green, other.green, t) ?? green,
      red: Color.lerp(red, other.red, t) ?? red,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// Semantic colour intents, so widgets ask for meaning instead of a specific hue.
enum SeverityTone {
  /// No particular meaning.
  neutral,

  /// Informational / connected.
  info,

  /// Success / allowed / online.
  success,

  /// Warning / needs approval.
  warning,

  /// Danger / blocked / offline-critical.
  danger,

  /// Brand accent.
  accent,
}
