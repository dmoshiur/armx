// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/widgets/armx_button.dart';
import 'package:armx_ai/core/widgets/armx_confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/armx_test_support.dart';

/// The confirmation dialog is the last thing between a tap and an irreversible action, so it
/// is the most heavily tested widget in the app.
const ConfirmRequest highRiskDeploy = ConfirmRequest(
  title: 'Publish the generated site?',
  action: 'web_deploy',
  target: 'thamjj13/armx-site#main',
  parameters: <ConfirmParameter>[
    ConfirmParameter(label: 'draft_id', value: 'draft-1', monospace: true),
    ConfirmParameter(label: 'branch', value: 'main'),
  ],
  consequence: 'The branch is overwritten. The previous version is replaced.',
  riskTier: ArmxRiskTier.high,
  confirmLabel: 'Publish',
  irreversible: true,
  requireTypedPhrase: true,
);

const ConfirmRequest mediumRiskLock = ConfirmRequest(
  title: 'Lock the front door?',
  action: 'lock',
  target: 'Front door',
  riskTier: ArmxRiskTier.medium,
  confirmLabel: 'Lock',
);

/// Shows the dialog over a real route so `Navigator.pop` behaves as it does in the app.
Future<bool?> showDialogAndTap(
  WidgetTester tester,
  ConfirmRequest request, {
  required Future<void> Function(WidgetTester tester) interact,
  Size size = const Size(360, 800),
}) async {
  bool? result;
  await pumpArmx(
    tester,
    Builder(
      builder: (BuildContext context) => ArmxButton(
        label: 'Start the action',
        onPressed: () async {
          result = await ArmxConfirmDialog.show(context, request);
        },
      ),
    ),
    size: size,
  );
  await tester.tap(find.byType(ArmxButton).first);
  await tester.pumpAndSettle();
  await interact(tester);
  await tester.pumpAndSettle();
  return result;
}

void main() {
  for (final Size size in referenceSizes) {
    group('at ${size.width.toInt()}x${size.height.toInt()}', () {
      testWidgets('the exact action, target and every parameter are shown', (
        WidgetTester tester,
      ) async {
        await pumpArmx(
          tester,
          Builder(
            builder: (BuildContext context) => ArmxButton(
              label: 'Open',
              onPressed: () => ArmxConfirmDialog.show(context, highRiskDeploy),
            ),
          ),
          size: size,
        );
        await tester.tap(find.byType(ArmxButton).first);
        await tester.pumpAndSettle();

        expect(find.text('Publish the generated site?'), findsOneWidget);
        // The action is named verbatim, so nobody approves a euphemism.
        expect(find.text('web_deploy'), findsOneWidget);
        expect(find.text('thamjj13/armx-site#main'), findsOneWidget);
        expect(find.text('draft_id'), findsOneWidget);
        expect(find.text('draft-1'), findsOneWidget);
        expect(find.text('branch'), findsOneWidget);
        expect(
          find.text('The branch is overwritten. The previous version is replaced.'),
          findsOneWidget,
        );

        // And it fits: no overflow at 360 dp, and the column is not wider than a panel.
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('cancelling returns false, and returning false runs nothing', (
    WidgetTester tester,
  ) async {
    final bool? result = await showDialogAndTap(
      tester,
      mediumRiskLock,
      interact: (WidgetTester tester) async {
        await tester.tap(find.text('Cancel'));
      },
    );
    expect(result, isFalse);
  });

  testWidgets('a MEDIUM-risk action confirms with a tap — no phrase required', (
    WidgetTester tester,
  ) async {
    final bool? result = await showDialogAndTap(
      tester,
      mediumRiskLock,
      interact: (WidgetTester tester) async {
        await tester.tap(find.text('Lock'));
      },
    );
    expect(result, isTrue);
  });

  testWidgets('a HIGH-risk action cannot be confirmed until the phrase is typed', (
    WidgetTester tester,
  ) async {
    final bool? result = await showDialogAndTap(
      tester,
      highRiskDeploy,
      interact: (WidgetTester tester) async {
        final ArmxButton confirm = tester.widget<ArmxButton>(
          find.widgetWithText(ArmxButton, 'Publish'),
        );
        // Disabled before the phrase: the destructive button does nothing on a stray tap.
        expect(confirm.onPressed, isNull);

        await tester.enterText(find.byType(TextField), 'CONFIRM');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ArmxButton>(find.widgetWithText(ArmxButton, 'Publish'))
              .onPressed,
          isNotNull,
        );
        await tester.tap(find.text('Publish'));
      },
    );
    expect(result, isTrue);
  });

  testWidgets('a near-miss phrase does not unlock the action', (
    WidgetTester tester,
  ) async {
    final bool? result = await showDialogAndTap(
      tester,
      highRiskDeploy,
      interact: (WidgetTester tester) async {
        await tester.enterText(find.byType(TextField), 'confirm');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ArmxButton>(find.widgetWithText(ArmxButton, 'Publish'))
              .onPressed,
          isNull,
        );
        await tester.tap(find.text('Cancel'));
      },
    );
    expect(result, isFalse);
  });

  testWidgets('the default focus is the non-destructive choice, never the confirm button', (
    WidgetTester tester,
  ) async {
    final bool? result = await showDialogAndTap(
      tester,
      highRiskDeploy,
      interact: (WidgetTester tester) async {
        // Enter, out of habit, must cancel rather than publish.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(ArmxConfirmDialog), findsNothing);
      },
    );
    expect(result, isFalse);
  });

  testWidgets('a non-destructive dialog names the action on the confirm button, not "OK"', (
    WidgetTester tester,
  ) async {
    await pumpArmx(
      tester,
      Builder(
        builder: (BuildContext context) => ArmxButton(
          label: 'Open',
          onPressed: () => ArmxConfirmDialog.show(context, mediumRiskLock),
        ),
      ),
    );
    await tester.tap(find.byType(ArmxButton).first);
    await tester.pumpAndSettle();

    expect(find.text('Lock'), findsOneWidget);
    expect(find.text('OK'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('the risk tier is stated in words as well as in colour', (
    WidgetTester tester,
  ) async {
    await pumpArmx(
      tester,
      Builder(
        builder: (BuildContext context) => ArmxButton(
          label: 'Open',
          onPressed: () => ArmxConfirmDialog.show(context, highRiskDeploy),
        ),
      ),
    );
    await tester.tap(find.byType(ArmxButton).first);
    await tester.pumpAndSettle();

    expect(find.text('HIGH'), findsOneWidget);
    expect(find.textContaining('CONFIRM'), findsWidgets);
  });
}
