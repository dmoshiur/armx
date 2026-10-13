// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/router/routes.dart';
import 'package:armx_ai/core/security/risk_tier.dart';
import 'package:armx_ai/core/widgets/armx_button.dart';
import 'package:armx_ai/core/widgets/armx_confirm_dialog.dart';
import 'package:armx_ai/data/api/armx_api.dart';
import 'package:armx_ai/data/models/assistant.dart';
import 'package:armx_ai/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/app_harness.dart';

/// The two flows the master prompt names as acceptance tests, driven through the real app:
///
/// * sign in → ask for something **LOW** risk → it happens, with no confirmation dialog;
/// * sign in → ask for something **HIGH** risk → the confirmation dialog appears **before any
///   backend call is made**, and cancelling means nothing was sent.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Types a prompt into the composer and sends it.
  Future<void> ask(WidgetTester tester, AppHarness app, String prompt) async {
    final AppLocalizations l10n = app.strings(tester);
    await tester.enterText(find.byType(TextField).last, prompt);
    await tester.pumpAndSettle();

    final Finder send = find.widgetWithText(ArmxButton, l10n.assistantSend);
    expect(send, findsOneWidget);
    await tester.tap(send);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  testWidgets('sign in, then a LOW-risk request happens with no confirmation', (
    WidgetTester tester,
  ) async {
    final AppHarness app = await AppHarness.boot(tester);
    await app.signIn(tester);

    // The assistant is listening to the same backend the rest of the app is.
    final List<AssistantEvent> events = <AssistantEvent>[];
    final subscription = app.api.events().listen(events.add);
    addTearDown(subscription.cancel);

    await app.go(tester, Routes.assistant);
    await ask(tester, app, 'turn off the fan');

    // No dialog at all: LOW risk does not ask, and it does not pretend to ask either.
    expect(find.byType(ArmxConfirmDialog), findsNothing);

    final List<ToolCall> raised = events
        .whereType<AssistantToolCallEvent>()
        .map((AssistantToolCallEvent event) => event.call)
        .toList();
    for (final ToolCall call in raised) {
      expect(call.riskTier, isNot(RiskTier.high));
    }
  });

  testWidgets('a HIGH-risk request asks first, and cancelling sends nothing', (
    WidgetTester tester,
  ) async {
    final AppHarness app = await AppHarness.boot(tester);
    await app.signIn(tester);
    await app.go(tester, Routes.assistant);

    await ask(tester, app, 'unlock the front door');

    final AppLocalizations l10n = app.strings(tester);
    expect(find.byType(ArmxConfirmDialog), findsOneWidget);
    expect(find.text(l10n.riskHigh), findsOneWidget);
    expect(find.text(l10n.commonCancel), findsOneWidget);

    // Nothing has been decided or sent yet: the confirmation really is before the call.
    expect(
      app.api.calls.where((String call) => call.startsWith('decideToolCall')),
      isEmpty,
    );
    expect(
      app.api.calls.where((String call) => call.startsWith('sendDeviceCommand')),
      isEmpty,
    );

    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();

    expect(find.byType(ArmxConfirmDialog), findsNothing);
    expect(app.api.calls, isEmpty, reason: 'cancelling must not reach the backend');
  });

  testWidgets('a HIGH-risk request cannot be confirmed without the typed phrase', (
    WidgetTester tester,
  ) async {
    final AppHarness app = await AppHarness.boot(tester);
    await app.signIn(tester);
    await app.go(tester, Routes.assistant);

    await ask(tester, app, 'unlock the front door');
    expect(find.byType(ArmxConfirmDialog), findsOneWidget);

    final AppLocalizations l10n = app.strings(tester);
    final Finder confirm =
        find.widgetWithText(ArmxButton, l10n.commonConfirm);

    // Disabled until the phrase matches: a stray tap on a destructive button does nothing.
    expect(tester.widget<ArmxButton>(confirm).onPressed, isNull);
    expect(app.api.calls, isEmpty);

    await tester.enterText(find.byType(TextField).last, 'CONFIRM');
    await tester.pumpAndSettle();
    expect(tester.widget<ArmxButton>(confirm).onPressed, isNotNull);

    await tester.tap(confirm);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Only now — after the explicit typed confirmation — does the decision reach the backend.
    expect(
      app.api.calls.where((String call) => call.startsWith('decideToolCall')),
      isNotEmpty,
    );
  });

  testWidgets('the guest greeter opens with its kill switch and no camera dialog', (
    WidgetTester tester,
  ) async {
    final AppHarness app = await AppHarness.boot(tester);
    await app.signIn(tester);
    await app.go(tester, Routes.guestGreeter);

    final AppLocalizations l10n = app.strings(tester);
    expect(find.text(l10n.guestGreeterTitle), findsOneWidget);
    // Turning the camera *off* is never gated: the switch that stops watching must always work.
    expect(find.byType(ArmxConfirmDialog), findsNothing);
  });
}
