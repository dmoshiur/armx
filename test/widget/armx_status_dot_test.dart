// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/theme/colors.dart';
import 'package:armx_ai/core/theme/app_theme.dart';
import 'package:armx_ai/core/widgets/armx_status_dot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/armx_test_support.dart';

void main() {
  for (final Size size in referenceSizes) {
    group('at ${size.width.toInt()}x${size.height.toInt()}', () {
      testWidgets('the status dot always states its status in words', (
        WidgetTester tester,
      ) async {
        await pumpArmx(
          tester,
          const ArmxStatusDot(status: ArmxStatus.offline, label: 'Offline'),
          size: size,
        );
        // A dot alone would be a colour-only signal; the label is what makes it accessible.
        expect(find.text('Offline'), findsOneWidget);
        expect(find.bySemanticsLabel('Offline'), findsOneWidget);
      });
    });
  }

  group('colourFor', () {
    const ArmxColors dark = ArmxColors.dark;

    test('online is the success colour and offline is the muted one', () {
      expect(ArmxStatusDot.colorFor(ArmxStatus.online, dark), dark.successText);
      expect(ArmxStatusDot.colorFor(ArmxStatus.offline, dark), dark.textMuted);
    });

    test('failed and stopped are the danger colour; warning and pending are not', () {
      expect(ArmxStatusDot.colorFor(ArmxStatus.failed, dark), dark.dangerText);
      expect(ArmxStatusDot.colorFor(ArmxStatus.stopped, dark), dark.dangerText);
      expect(ArmxStatusDot.colorFor(ArmxStatus.warning, dark), dark.warningText);
      expect(ArmxStatusDot.colorFor(ArmxStatus.pending, dark), dark.warningText);
    });

    test('unknown is distinguishable from online — it never looks healthy', () {
      expect(
        ArmxStatusDot.colorFor(ArmxStatus.unknown, dark),
        isNot(ArmxStatusDot.colorFor(ArmxStatus.online, dark)),
      );
    });

    test('every status has a colour in both themes', () {
      for (final ArmxStatus status in ArmxStatus.values) {
        expect(ArmxStatusDot.colorFor(status, ArmxColors.dark), isNotNull);
        expect(ArmxStatusDot.colorFor(status, ArmxColors.light), isNotNull);
      }
    });

    test('all seven statuses exist, because the UI names them', () {
      expect(ArmxStatus.values.toSet(), <ArmxStatus>{
        ArmxStatus.online,
        ArmxStatus.warning,
        ArmxStatus.offline,
        ArmxStatus.failed,
        ArmxStatus.pending,
        ArmxStatus.stopped,
        ArmxStatus.unknown,
      });
    });
  });

  testWidgets('the compact dot takes less room and is still labelled', (
    WidgetTester tester,
  ) async {
    await pumpArmx(
      tester,
      const Row(
        children: <Widget>[
          ArmxStatusDot(status: ArmxStatus.online, label: 'Online'),
          ArmxStatusDot(status: ArmxStatus.online, label: 'On', compact: true),
        ],
      ),
    );
    final Size full = tester.getSize(find.byType(ArmxStatusDot).first);
    final Size compact = tester.getSize(find.byType(ArmxStatusDot).last);
    expect(compact.width, lessThan(full.width));
    expect(find.text('On'), findsOneWidget);
  });

  testWidgets('a pulsing dot animates but still reads as one node', (
    WidgetTester tester,
  ) async {
    await pumpArmx(
      tester,
      const ArmxStatusDot(
        status: ArmxStatus.pending,
        label: 'Waiting for the device',
        pulse: true,
      ),
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Waiting for the device'), findsOneWidget);
    // Leaving the animation running is fine for a test, but the tree must still be sound.
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the theme supplies the colour, so light mode is not hardcoded dark', (
    WidgetTester tester,
  ) async {
    await pumpArmx(
      tester,
      const ArmxStatusDot(status: ArmxStatus.online, label: 'Online'),
      themeMode: ThemeMode.light,
    );
    final BuildContext context = tester.element(find.byType(ArmxStatusDot));
    expect(AppTheme.light().brightness, Brightness.light);
    expect(ArmxColors.of(context).isDark, isFalse);
  });
}
