// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:ui' show FontVariation;

import 'package:flutter/material.dart';

/// Typography for A.R.M.X AI.
///
/// Fonts are bundled assets (Inter for body/UI, JetBrains Mono for logs, code, keys and
/// audit rows) — nothing is fetched at runtime. Both files are *variable* fonts, so each
/// style sets `fontVariations` in addition to `fontWeight`; that guarantees the requested
/// weight renders instead of being synthetically emboldened.
abstract final class ArmxTypography {
  /// Body/UI font family (matches the `fonts:` entry in pubspec.yaml).
  static const String bodyFamily = 'Inter';

  /// Monospace family for logs, code and cryptographic fingerprints.
  static const String monoFamily = 'JetBrainsMono';

  /// Builds the Material [TextTheme] for the given text colours.
  static TextTheme textTheme({required Color text, required Color muted}) {
    return TextTheme(
      displayLarge: inter(size: 44, weight: 700, height: 1.08, color: text),
      displayMedium: inter(size: 34, weight: 700, height: 1.12, color: text),
      displaySmall: inter(size: 28, weight: 600, height: 1.16, color: text),
      headlineMedium: inter(size: 24, weight: 600, height: 1.2, color: text),
      headlineSmall: inter(size: 20, weight: 600, height: 1.25, color: text),
      titleLarge: inter(size: 18, weight: 600, height: 1.3, color: text),
      titleMedium: inter(size: 16, weight: 600, height: 1.35, color: text),
      titleSmall: inter(size: 14, weight: 600, height: 1.35, color: text),
      bodyLarge: inter(size: 16, weight: 400, height: 1.45, color: text),
      bodyMedium: inter(size: 14, weight: 400, height: 1.45, color: text),
      bodySmall: inter(size: 12.5, weight: 400, height: 1.45, color: muted),
      labelLarge: inter(size: 14, weight: 600, height: 1.2, letterSpacing: 0.2, color: text),
      labelMedium: inter(size: 12, weight: 600, height: 1.2, letterSpacing: 0.4, color: muted),
      labelSmall: inter(size: 11, weight: 600, height: 1.2, letterSpacing: 0.5, color: muted),
    );
  }

  /// A single Inter style with an explicit variable weight.
  static TextStyle inter({
    required double size,
    required int weight,
    double? height,
    double? letterSpacing,
    Color? color,
    FontStyle style = FontStyle.normal,
  }) {
    return TextStyle(
      fontFamily: bodyFamily,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      fontStyle: style,
      fontWeight: _fontWeight(weight),
      fontVariations: <FontVariation>[FontVariation('wght', weight.toDouble())],
    );
  }

  /// A single JetBrains Mono style, used for logs, tokens, keys and sensor dumps.
  static TextStyle mono({
    double size = 13,
    int weight = 500,
    double? height = 1.4,
    double? letterSpacing,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      fontWeight: _fontWeight(weight),
      fontVariations: <FontVariation>[FontVariation('wght', weight.toDouble())],
    );
  }

  /// The `A.R.M.X` wordmark style: heavy Inter with wide tracking.
  static TextStyle wordmark({required double size, required Color color}) => inter(
        size: size,
        weight: 800,
        letterSpacing: size * 0.08,
        height: 1.05,
        color: color,
      );

  static FontWeight _fontWeight(int weight) {
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
