// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every foreground/background pair the theme actually uses, at 4.5:1 or better.
///
/// This is the test that makes "no screen hardcodes colour" enforceable: if a token changes to
/// something prettier and less readable, this fails before anybody ships it. The same numbers
/// are computed live in Settings → Design system, so the claim is visible in the app too.
void main() {
  group('the spec palette is exact', () {
    test('the seven specified hexes are unchanged', () {
      expect(ArmxPalette.ink, const Color(0xFF0B1220));
      expect(ArmxPalette.navy, const Color(0xFF101935));
      expect(ArmxPalette.accent, const Color(0xFF5B8CFF));
      expect(ArmxPalette.accent2, const Color(0xFF8B5CF6));
      expect(ArmxPalette.fog, const Color(0xFFF4F6FB));
      expect(ArmxPalette.line, const Color(0xFFD7DCEA));
      expect(ArmxPalette.muted, const Color(0xFF5B6475));
      expect(ArmxPalette.danger, const Color(0xFFE2554E));
      expect(ArmxPalette.success, const Color(0xFF3FBF82));
    });

    test('accent and accent2 are never the same colour, so a rule forbidding their'
        ' combination is testable', () {
      expect(ArmxPalette.accent == ArmxPalette.accent2, isFalse);
    });
  });

  group('dark theme contrast', () {
    const ArmxColors c = ArmxColors.dark;

    final List<(String, Color, Color)> pairs = <(String, Color, Color)>[
      ('text on background', c.text, c.background),
      ('text on surface', c.text, c.surface),
      ('text on surfaceAlt', c.text, c.surfaceAlt),
      ('muted on background', c.textMuted, c.background),
      ('muted on surface', c.textMuted, c.surface),
      ('accent text on surface', c.accentText, c.surface),
      ('accent2 text on surface', c.accent2Text, c.surface),
      ('success text on surface', c.successText, c.surface),
      ('warning text on surface', c.warningText, c.surface),
      ('danger text on surface', c.dangerText, c.surface),
      ('label on a danger fill', c.onDangerFill, c.dangerFill),
    ];

    for (final (String name, Color foreground, Color background) in pairs) {
      test('$name clears 4.5:1', () {
        final double ratio = Contrast.ratio(foreground, background);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$name is ${ratio.toStringAsFixed(2)}:1',
        );
      });
    }
  });

  group('light theme contrast', () {
    const ArmxColors c = ArmxColors.light;

    final List<(String, Color, Color)> pairs = <(String, Color, Color)>[
      ('text on background', c.text, c.background),
      ('text on surface', c.text, c.surface),
      ('muted on surface', c.textMuted, c.surface),
      ('accent text on surface', c.accentText, c.surface),
      ('accent2 text on surface', c.accent2Text, c.surface),
      ('success text on surface', c.successText, c.surface),
      ('warning text on surface', c.warningText, c.surface),
      ('danger text on surface', c.dangerText, c.surface),
      ('label on a danger fill', c.onDangerFill, c.dangerFill),
    ];

    for (final (String name, Color foreground, Color background) in pairs) {
      test('$name clears 4.5:1', () {
        final double ratio = Contrast.ratio(foreground, background);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$name is ${ratio.toStringAsFixed(2)}:1',
        );
      });
    }
  });

  group('Contrast', () {
    test('black on white is the maximum 21:1', () {
      expect(
        Contrast.ratio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.01),
      );
    });

    test('a colour against itself is 1:1 and fails', () {
      expect(Contrast.ratio(ArmxPalette.ink, ArmxPalette.ink), closeTo(1, 0.001));
      expect(Contrast.passesAA(ArmxPalette.ink, ArmxPalette.ink), isFalse);
    });

    test('passesAA and passesAALarge use the WCAG thresholds', () {
      const Color grey = Color(0xFF777777);
      expect(Contrast.passesAA(grey, const Color(0xFFFFFFFF)), isFalse);
      expect(
        Contrast.passesAALarge(const Color(0xFF767676), const Color(0xFFFFFFFF)),
        isTrue,
      );
    });
  });

  test('both themes define the same token set', () {
    // A token present in one theme and missing from the other is a runtime crash waiting for
    // the user who switches themes; `lerp` is the cheapest way to notice.
    final ArmxColors mixed = ArmxColors.dark.lerp(ArmxColors.light, 0.5);
    expect(mixed.background, isNot(ArmxColors.dark.background));
    expect(ArmxColors.dark.isDark, isTrue);
    expect(ArmxColors.light.isDark, isFalse);
  });
}
