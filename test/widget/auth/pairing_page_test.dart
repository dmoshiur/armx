// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/providers.dart';
import 'package:armx_ai/core/widgets/armx_controls.dart';
import 'package:armx_ai/data/api/mock/mock_api.dart';
import 'package:armx_ai/features/auth/pairing/pairing_controller.dart';
import 'package:armx_ai/features/auth/pairing/pairing_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../support/auth_test_harness.dart';
import '../../support/fixtures.dart';
import '../../support/test_harness.dart';

/// The pairing screen states: form → QR/fingerprint identity → approved /
/// pending / rejected, plus URL validation.
void main() {
  const surface = Size(1080, 1600);

  Future<({ProviderContainer container, MockBackendControl control})> pumpPairing(
    WidgetTester tester, {
    MockPairingOutcome outcome = MockPairingOutcome.approved,
  }) async {
    final control = MockBackendControl(
      latency: Duration.zero,
      tokenInterval: Duration.zero,
      pairingOutcome: outcome,
    );
    final container = await pumpArmxWidget(
      tester,
      const PairingPage(),
      overrides: <Override>[
        armxApiProvider.overrideWithValue(Fixtures.mockApi(control: control)),
      ],
      surfaceSize: surface,
    );
    return (container: container, control: control);
  }

  Future<void> connect(WidgetTester tester) async {
    final l10n = l10nOf(tester, find.byType(PairingPage));
    await tester.enterText(find.byType(ArmxTextField).at(0), 'https://home.example.com');
    await tester.tap(find.widgetWithText(ArmxButton, l10n.pairingTestConnection));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
  }

  Future<void> submitRequest(WidgetTester tester) async {
    final l10n = l10nOf(tester, find.byType(PairingPage));
    await tester.tap(find.widgetWithText(ArmxButton, l10n.pairingSubmit));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
  }

  testWidgets('the first screen asks for a server URL and a health check',
      (tester) async {
    await pumpPairing(tester);
    final l10n = l10nOf(tester, find.byType(PairingPage));

    expect(find.text(l10n.pairingServerUrlLabel), findsOneWidget);
    expect(find.widgetWithText(ArmxButton, l10n.pairingTestConnection), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('an invalid URL renders the localized validation issue',
      (tester) async {
    await pumpPairing(tester);
    final l10n = l10nOf(tester, find.byType(PairingPage));

    await tester.enterText(find.byType(ArmxTextField).at(0), 'not-a-url');
    await tester.tap(find.widgetWithText(ArmxButton, l10n.pairingTestConnection));
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text(l10n.validationNotAbsoluteUrl), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('a healthy connection shows the QR code and fingerprint',
      (tester) async {
    await pumpPairing(tester);
    final l10n = l10nOf(tester, find.byType(PairingPage));

    await connect(tester);

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text(l10n.pairingFingerprintLabel), findsOneWidget);
    expect(find.widgetWithText(ArmxButton, l10n.pairingSubmit), findsOneWidget);
  });

  testWidgets('an approved answer shows the continue gate', (tester) async {
    final harness = await pumpPairing(tester);
    final l10n = l10nOf(tester, find.byType(PairingPage));

    await connect(tester);
    await submitRequest(tester);

    expect(find.text(l10n.pairingApprovedTitle), findsOneWidget);
    expect(harness.container.read(pairingControllerProvider).paired, isFalse);

    await tester.tap(find.widgetWithText(ArmxButton, l10n.pairingApprovedAction));
    await tester.pump();

    expect(harness.container.read(pairingControllerProvider).paired, isTrue);
  });

  testWidgets('a pending answer waits for approval and can re-check',
      (tester) async {
    final harness = await pumpPairing(tester, outcome: MockPairingOutcome.pending);
    final l10n = l10nOf(tester, find.byType(PairingPage));

    await connect(tester);
    await submitRequest(tester);

    expect(find.text(l10n.pairingPendingTitle), findsOneWidget);
    expect(harness.container.read(pairingControllerProvider).paired, isFalse);

    harness.control.pairingOutcome = MockPairingOutcome.approved;
    await tester.tap(find.widgetWithText(ArmxButton, l10n.pairingCheckStatus));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text(l10n.pairingApprovedTitle), findsOneWidget);
    expect(harness.container.read(pairingControllerProvider).paired, isFalse);
  });

  testWidgets('a rejected answer offers the retry copy and stays unpaired',
      (tester) async {
    final harness = await pumpPairing(tester, outcome: MockPairingOutcome.rejected);
    final l10n = l10nOf(tester, find.byType(PairingPage));

    await connect(tester);
    await submitRequest(tester);

    expect(find.text(l10n.pairingRejectedTitle), findsOneWidget);
    expect(harness.container.read(pairingControllerProvider).paired, isFalse);
    expect(
      harness.container.read(pairingControllerProvider).error,
      isNotNull,
    );
  });
}
