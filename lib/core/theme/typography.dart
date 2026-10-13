// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:ui' show FontVariation;

import 'package:flutter/material.dart';

/// Typography for A.R.M.X AI.
///
/// ## Families
///
/// Inter is bundled as a local asset (`assets/fonts/Inter.ttf`) rather than fetched by
/// `google_fonts`, so the app renders identically offline, on a locked-down estate
/// network, and in `flutter test` where no network is available. The spec permits either
/// ("bundle via google_fonts package or local assets"). A system sans-serif fallback is
/// declared on every style, so a missing asset degrades to the platform font instead of
/// throwing.
///
/// ## Scale (dp: size / line-height)
///
/// | Role | Spec | `TextTheme` slot |
/// | --- | --- | --- |
/// | Display | 32 / 40 | `displaySmall` |
/// | H1 | 24 / 30 | `headlineMedium` |
/// | H2 | 18 / 24 | `titleLarge` |
/// | H3 | 14 / 20 | `titleSmall` |
/// | Body | 14 / 21 | `bodyMedium` |
/// | Caption | 12 / 16 | `bodySmall` / `labelMedium` |
///
/// Headings are `w700`, body is `w400`, emphasis is `w600`. Bold + italic is never
/// combined.
///
/// Because both bundled files are *variable* fonts, each style sets `fontVariations` as
/// well as `fontWeight`; without the axis value Flutter would pick the default instance
/// and synthesise the rest.
abstract final class ArmxTypography {
  /// Body/UI family (matches `fonts:` in pubspec.yaml).
  static const String family = 'Inter';

  /// Monospace family for code, diffs, keys, audit rows and sensor dumps.
  static const String monoFamily = 'JetBrainsMono';

  /// System fallback list, applied when a bundled asset is unavailable.
  static const List<String> fallback = <String>[
    'Roboto',
    'SF Pro Text',
    'Segoe UI',
    'Noto Sans Bengali',
    'sans-serif',
  ];

  /// The Material text theme for a pair of text colours.
  static TextTheme textTheme({required Color text, required Color muted}) {
    return TextTheme(
      // Display — 32 / 40, w700.
      displayLarge: inter(size: 40, weight: 700, height: 1.10, color: text),
      displayMedium: inter(size: 36, weight: 700, height: 1.15, color: text),
      displaySmall: inter(size: 32, weight: 700, height: 1.25, color: text),

      // H1 — 24 / 30, w700.
      headlineLarge: inter(size: 28, weight: 700, height: 1.25, color: text),
      headlineMedium: inter(size: 24, weight: 700, height: 1.25, color: text),
      headlineSmall: inter(size: 20, weight: 700, height: 1.30, color: text),

      // H2 — 18 / 24, w700.
      titleLarge: inter(size: 18, weight: 700, height: 1.34, color: text),

      // H3 — 14 / 20, w700 (emphasis variant is w600, see `emphasisSmall`).
      titleMedium: inter(size: 16, weight: 700, height: 1.35, color: text),
      titleSmall: inter(size: 14, weight: 700, height: 1.43, color: text),

      // Body — 14 / 21, w400.
      bodyLarge: inter(size: 16, weight: 400, height: 1.50, color: text),
      bodyMedium: inter(size: 14, weight: 400, height: 1.50, color: text),

      // Caption — 12 / 16, w400.
      bodySmall: inter(size: 12, weight: 400, height: 1.34, color: muted),

      // Labels — w600 emphasis, never bold+italic.
      labelLarge: inter(size: 14, weight: 600, height: 1.43, color: text),
      labelMedium: inter(size: 12, weight: 600, height: 1.34, letterSpacing: 0.3, color: muted),
      labelSmall: inter(size: 11, weight: 600, height: 1.30, letterSpacing: 0.5, color: muted),
    );
  }

  /// A single Inter style at an exact variable weight.
  static TextStyle inter({
    required double size,
    required int weight,
    double? height,
    double? letterSpacing,
    Color? color,
    FontStyle style = FontStyle.normal,
  }) {
    assert(
      !(weight >= 700 && style == FontStyle.italic),
      'Emphasis rules: never combine bold with italic.',
    );
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: fallback,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      fontStyle: style,
      fontWeight: fontWeightOf(weight),
      fontVariations: <FontVariation>[FontVariation('wght', weight.toDouble())],
    );
  }

  /// A single JetBrains Mono style, used for code, diffs, tokens and audit rows.
  static TextStyle mono({
    double size = 13,
    int weight = 500,
    double? height = 1.45,
    double? letterSpacing,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontFamilyFallback: <String>['Menlo', 'Consolas', 'monospace'],
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      fontWeight: fontWeightOf(weight),
      fontVariations: <FontVariation>[FontVariation('wght', weight.toDouble())],
    );
  }

  /// The `A.R.M.X` wordmark: heavy Inter with wide tracking.
  static TextStyle wordmark({required double size, required Color color}) => inter(
        size: size,
        weight: 800,
        letterSpacing: size * 0.09,
        height: 1.05,
        color: color,
      );

  /// Maps an integer variable-font weight onto a [FontWeight].
  static FontWeight fontWeightOf(int weight) {
    if (weight <= 100) {
      return FontWeight.w100;
    }
    if (weight <= 200) {
      return FontWeight.w200;
    }
    if (weight <= 300) {
      return FontWeight.w300;
    }
    if (weight <= 400) {
      return FontWeight.w400;
    }
    if (weight <= 500) {
      return FontWeight.w500;
    }
    if (weight <= 600) {
      return FontWeight.w600;
    }
    if (weight <= 700) {
      return FontWeight.w700;
    }
    if (weight <= 800) {
      return FontWeight.w800;
    }
    return FontWeight.w900;
  }
}
