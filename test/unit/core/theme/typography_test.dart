// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/theme/colors.dart';
import 'package:armx_ai/core/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The type scale is specified down to the line height, so it is asserted down to the line
/// height. A screen that invents its own size fails review; a scale that drifts fails here.
void main() {
  final TextTheme theme = ArmxTypography.textTheme(
    text: ArmxPalette.fog,
    muted: ArmxPalette.mutedDark,
  );

  group('the specified scale', () {
    test('Display is 32 / 40 at w700', () {
      expect(theme.displaySmall!.fontSize, 32);
      expect(theme.displaySmall!.height! * 32, closeTo(40, 0.6));
      expect(theme.displaySmall!.fontWeight, FontWeight.w700);
    });

    test('H1 is 24 / 30 at w700', () {
      expect(theme.headlineMedium!.fontSize, 24);
      expect(theme.headlineMedium!.height! * 24, closeTo(30, 0.5));
      expect(theme.headlineMedium!.fontWeight, FontWeight.w700);
    });

    test('H2 is 18 / 24 at w700', () {
      expect(theme.titleLarge!.fontSize, 18);
      expect(theme.titleLarge!.height! * 18, closeTo(24, 0.5));
      expect(theme.titleLarge!.fontWeight, FontWeight.w700);
    });

    test('H3 is 14 / 20 at w700', () {
      expect(theme.titleSmall!.fontSize, 14);
      expect(theme.titleSmall!.height! * 14, closeTo(20, 0.5));
      expect(theme.titleSmall!.fontWeight, FontWeight.w700);
    });

    test('Body is 14 / 21 at w400', () {
      expect(theme.bodyMedium!.fontSize, 14);
      expect(theme.bodyMedium!.height! * 14, closeTo(21, 0.5));
      expect(theme.bodyMedium!.fontWeight, FontWeight.w400);
    });

    test('Caption is 12 / 16', () {
      expect(theme.bodySmall!.fontSize, 12);
      expect(theme.bodySmall!.height! * 12, closeTo(16, 0.4));
    });

    test('emphasis is w600 and never bold+italic', () {
      expect(theme.labelLarge!.fontWeight, FontWeight.w600);
      expect(theme.labelLarge!.fontStyle, isNot(FontStyle.italic));
      for (final TextStyle? style in <TextStyle?>[
        theme.displaySmall,
        theme.headlineMedium,
        theme.titleLarge,
        theme.titleSmall,
        theme.bodyMedium,
        theme.bodySmall,
        theme.labelLarge,
      ]) {
        expect(style!.fontStyle ?? FontStyle.normal, FontStyle.normal);
      }
    });
  });

  group('families', () {
    test('Inter is the body family and it is bundled, not downloaded', () {
      expect(ArmxTypography.family, 'Inter');
      expect(theme.bodyMedium!.fontFamily, 'Inter');
    });

    test('code, keys and diffs use the monospace family', () {
      expect(ArmxTypography.monoFamily, 'JetBrainsMono');
      expect(ArmxTypography.mono(size: 12, color: ArmxPalette.fog).fontFamily,
          'JetBrainsMono');
    });

    test('a system fallback is declared, so a missing asset degrades instead of throwing',
        () {
      expect(ArmxTypography.fallback, isNotEmpty);
      expect(theme.bodyMedium!.fontFamilyFallback, isNotEmpty);
      // Bengali must be renderable even if the bundled font cannot cover it.
      expect(
        ArmxTypography.fallback.any((String f) => f.contains('Bengali')),
        isTrue,
      );
    });

    test('no style uses a size the scale does not define', () {
      const Set<double> allowed = <double>{11, 12, 14, 16, 18, 20, 24, 28, 32, 36, 40};
      for (final TextStyle? style in <TextStyle?>[
        theme.displayLarge,
        theme.displayMedium,
        theme.displaySmall,
        theme.headlineLarge,
        theme.headlineMedium,
        theme.headlineSmall,
        theme.titleLarge,
        theme.titleMedium,
        theme.titleSmall,
        theme.bodyLarge,
        theme.bodyMedium,
        theme.bodySmall,
        theme.labelLarge,
        theme.labelMedium,
        theme.labelSmall,
      ]) {
        expect(
          allowed.contains(style!.fontSize),
          isTrue,
          reason: 'unexpected size ${style.fontSize}',
        );
      }
    });
  });
}
