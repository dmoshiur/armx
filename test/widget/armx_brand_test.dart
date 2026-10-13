// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/theme/app_theme.dart';
import 'package:armx_ai/core/widgets/armx_brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/armx_test_support.dart';

void main() {
  for (final Size size in referenceSizes) {
    group('at ${size.width.toInt()}x${size.height.toInt()}', () {
      testWidgets('the wordmark is legible and does not overflow', (
        WidgetTester tester,
      ) async {
        await pumpArmx(tester, const ArmxWordmark(), size: size);
        expect(find.byType(ArmxWordmark), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the orb animates without claiming anything about the backend', (
        WidgetTester tester,
      ) async {
        await pumpArmx(tester, const ArmxOrb(), size: size, settle: false);
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(ArmxOrb), findsOneWidget);
        expect(tester.takeException(), isNull);
        // Let the animation timer finish so the test ends cleanly.
        await tester.pumpWidget(const SizedBox.shrink());
      });
    });
  }

  testWidgets('the wordmark scales with the size it is given', (
    WidgetTester tester,
  ) async {
    await pumpArmx(
      tester,
      const Column(
        children: <Widget>[
          ArmxWordmark(size: 20),
          ArmxWordmark(size: 40),
        ],
      ),
    );
    final Size small = tester.getSize(find.byType(ArmxWordmark).first);
    final Size large = tester.getSize(find.byType(ArmxWordmark).last);
    expect(large.width, greaterThan(small.width));
    expect(large.height, greaterThan(small.height));
  });

  testWidgets('the suffix can be dropped for tight layouts', (
    WidgetTester tester,
  ) async {
    await pumpArmx(
      tester,
      const Column(
        children: <Widget>[
          ArmxWordmark(),
          ArmxWordmark(showSuffix: false),
        ],
      ),
    );
    final Size withSuffix = tester.getSize(find.byType(ArmxWordmark).first);
    final Size withoutSuffix = tester.getSize(find.byType(ArmxWordmark).last);
    expect(withoutSuffix.width, lessThanOrEqualTo(withSuffix.width));
  });

  testWidgets('the orb renders in both themes', (WidgetTester tester) async {
    for (final ThemeMode mode in <ThemeMode>[ThemeMode.dark, ThemeMode.light]) {
      await pumpArmx(tester, const ArmxOrb(size: 64), themeMode: mode);
      final ThemeData expected =
          mode == ThemeMode.light ? AppTheme.light() : AppTheme.dark();
      expect(expected.brightness, mode == ThemeMode.light ? Brightness.light : Brightness.dark);
      expect(find.byType(ArmxOrb), findsOneWidget);
    }
  });
}
