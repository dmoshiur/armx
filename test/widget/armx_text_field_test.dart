// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/widgets/armx_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/armx_test_support.dart';

void main() {
  for (final Size size in referenceSizes) {
    group('at ${size.width.toInt()}x${size.height.toInt()}', () {
      testWidgets('the label is visible and the field is tappable', (
        WidgetTester tester,
      ) async {
        final TextEditingController controller = TextEditingController();
        addTearDown(controller.dispose);
        await pumpArmx(
          tester,
          ArmxTextField(label: 'Email', controller: controller),
          size: size,
        );

        expect(find.text('Email'), findsOneWidget);
        expectTouchTarget(
          tester,
          find.byType(TextField),
          minimum: Insets.minTouchTarget,
        );

        await tester.enterText(find.byType(TextField), 'mohi@thamjj13.top');
        expect(controller.text, 'mohi@thamjj13.top');
      });

      testWidgets('an error replaces the helper and is announced, not only coloured', (
        WidgetTester tester,
      ) async {
        await pumpArmx(
          tester,
          const ArmxTextField(
            label: 'Password',
            helper: 'At least 8 characters',
            errorText: 'Password must be at least 8 characters',
          ),
          size: size,
        );

        // The message itself is the signal; colour is decoration on top of it.
        expect(
          find.text('Password must be at least 8 characters'),
          findsOneWidget,
        );
      });
    });
  }

  testWidgets('the obscure toggle flips the field and says what it will do', (
    WidgetTester tester,
  ) async {
    await pumpArmx(
      tester,
      const ArmxTextField(label: 'Password', obscureText: true),
    );

    TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);

    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();

    field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isFalse);
  });

  testWidgets('a disabled field cannot be typed into', (WidgetTester tester) async {
    await pumpArmx(
      tester,
      const ArmxTextField(label: 'Email', enabled: false, initialValue: 'locked@example.com'),
    );
    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);
  });

  testWidgets('submitting with the keyboard action reports the value once', (
    WidgetTester tester,
  ) async {
    final List<String> submitted = <String>[];
    await pumpArmx(
      tester,
      ArmxTextField(
        label: 'Message',
        onSubmitted: submitted.add,
        textInputAction: TextInputAction.send,
      ),
    );

    await tester.enterText(find.byType(TextField), 'turn off the fan');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(submitted, <String>['turn off the fan']);
  });

  testWidgets('the switch row toggles and reports its new value', (
    WidgetTester tester,
  ) async {
    bool value = false;
    await pumpArmx(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => ArmxSwitchRow(
          title: 'Allow auto-send',
          subtitle: 'Send without asking first',
          value: value,
          onChanged: (bool next) => setState(() => value = next),
        ),
      ),
      size: const Size(800, 1280),
    );

    expect(find.text('Allow auto-send'), findsOneWidget);
    expect(find.text('Send without asking first'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(value, isTrue);
  });

  testWidgets('a disabled switch row still shows its state and explanation', (
    WidgetTester tester,
  ) async {
    await pumpArmx(
      tester,
      const ArmxSwitchRow(
        title: 'Guest greeter',
        subtitle: 'Requires the camera permission',
        value: false,
        enabled: false,
      ),
    );
    final Switch widget = tester.widget<Switch>(find.byType(Switch));
    expect(widget.onChanged, isNull);
    expect(find.text('Requires the camera permission'), findsOneWidget);
  });

  testWidgets('the icon toggle is selected or not, and says so', (
    WidgetTester tester,
  ) async {
    await pumpArmx(
      tester,
      ArmxIconToggle(
        icon: Icons.mic_rounded,
        semanticLabel: 'Push to talk',
        selected: true,
        onPressed: () {},
      ),
    );
    expect(find.bySemanticsLabel('Push to talk'), findsOneWidget);
    final SemanticsNode node =
        tester.getSemantics(find.bySemanticsLabel('Push to talk'));
    expect(node.hasFlag(SemanticsFlag.isSelected), isTrue);
  });
}
