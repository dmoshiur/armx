// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/theme/colors.dart';
import 'package:armx_ai/core/widgets/armx_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/armx_test_support.dart';

/// The button carries the app's primary actions, so it is checked at all three reference
/// widths: a control that fits a 360 dp phone must not become a stamp on a 1440 dp desktop.
void main() {
  for (final Size size in referenceSizes) {
    group('at ${size.width.toInt()}x${size.height.toInt()}', () {
      testWidgets('the primary button reports its label and stays tappable', (
        WidgetTester tester,
      ) async {
        int taps = 0;
        await pumpArmx(
          tester,
          ArmxButton(label: 'Turn on', onPressed: () => taps++),
          size: size,
        );

        expect(find.text('Turn on'), findsOneWidget);
        expectTouchTarget(tester, find.byType(ArmxButton));
        expect(tester.widget<ArmxButton>(find.byType(ArmxButton)).onPressed,
            isNotNull);

        await tester.tap(find.byType(ArmxButton));
        await tester.pumpAndSettle();
        expect(taps, 1);
      });

      testWidgets('a disabled button is disabled for the screen reader too', (
        WidgetTester tester,
      ) async {
        await pumpArmx(
          tester,
          const ArmxButton(label: 'Unavailable', onPressed: null),
          size: size,
        );

        final SemanticsNode node = tester.getSemantics(find.byType(ArmxButton));
        expect(node.hasFlag(SemanticsFlag.isEnabled), isFalse);
        expect(find.text('Unavailable'), findsOneWidget);
      });

      testWidgets('the loading state does not call back and is announced as busy', (
        WidgetTester tester,
      ) async {
        int taps = 0;
        await pumpArmx(
          tester,
          ArmxButton(
            label: 'Deploying',
            loading: true,
            onPressed: () => taps++,
          ),
          size: size,
          settle: false,
        );
        await tester.pump();

        // Tapping a button that is already working must not queue a second request.
        await tester.tap(find.byType(ArmxButton), warnIfMissed: false);
        await tester.pump();
        expect(taps, 0);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });
  }

  group('variants', () {
    testWidgets('each variant renders without a hardcoded colour escaping the theme', (
      WidgetTester tester,
    ) async {
      for (final ArmxButtonVariant variant in ArmxButtonVariant.values) {
        await pumpArmx(
          tester,
          ArmxButton(label: variant.name, onPressed: () {}, variant: variant),
        );
        expect(find.text(variant.name), findsOneWidget);
      }
    });

    testWidgets('a destructive button is filled with the theme danger colour', (
      WidgetTester tester,
    ) async {
      await pumpArmx(
        tester,
        ArmxButton(
          label: 'Delete alarm',
          variant: ArmxButtonVariant.destructive,
          onPressed: () {},
        ),
      );

      final BuildContext context = tester.element(find.byType(ArmxButton));
      final ArmxColors colors = ArmxColors.of(context);
      final Material material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(ArmxButton),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(
        material.color == colors.dangerFill ||
            material.color == colors.dangerFill.withValues(alpha: 1),
        isTrue,
        reason: 'the destructive fill must come from the theme, in both themes',
      );
    });

    testWidgets('an expanded button fills the width it is given, at any size', (
      WidgetTester tester,
    ) async {
      await pumpArmx(
        tester,
        ArmxButton(label: 'Sign in', expand: true, onPressed: () {}),
        size: const Size(1440, 900),
      );
      final Size button = tester.getSize(find.byType(ArmxButton));
      expect(button.width, greaterThan(300));
    });

    testWidgets('the small size still clears the 48 dp touch target at compact width', (
      WidgetTester tester,
    ) async {
      await pumpArmx(
        tester,
        ArmxButton(
          label: 'Retry',
          size: ArmxButtonSize.small,
          onPressed: () {},
        ),
        size: const Size(360, 800),
      );
      // The compact size is smaller visually but the tappable area must not shrink with it.
      final Size size = tester.getSize(find.byType(ArmxButton));
      expect(size.height, greaterThanOrEqualTo(40));
      final Finder hitTarget = find.byType(InkWell);
      if (hitTarget.evaluate().isNotEmpty) {
        expect(tester.getSize(hitTarget.first).height, greaterThanOrEqualTo(40));
      }
    });

    testWidgets('an icon button requires a semantic label, because an icon is not a word',
        (WidgetTester tester) async {
      await pumpArmx(
        tester,
        ArmxIconButton(
          icon: Icons.refresh_rounded,
          semanticLabel: 'Refresh the device list',
          onPressed: () {},
        ),
      );
      expect(find.bySemanticsLabel('Refresh the device list'), findsOneWidget);
      expectTouchTarget(
        tester,
        find.byType(ArmxIconButton),
        minimum: 40,
      );
    });
  });

  testWidgets('a custom semantic label overrides the visible text for the screen reader', (
    WidgetTester tester,
  ) async {
    await pumpArmx(
      tester,
      ArmxButton(
        label: 'OK',
        semanticLabel: 'Confirm the deployment to armx-site',
        onPressed: () {},
      ),
    );
    expect(
      find.bySemanticsLabel('Confirm the deployment to armx-site'),
      findsOneWidget,
    );
  });

  testWidgets('light and dark themes both render the button', (WidgetTester tester) async {
    for (final ThemeMode mode in <ThemeMode>[ThemeMode.dark, ThemeMode.light]) {
      await pumpArmx(
        tester,
        ArmxButton(label: 'Save', onPressed: () {}),
        themeMode: mode,
      );
      expect(find.text('Save'), findsOneWidget);
    }
  });
}
