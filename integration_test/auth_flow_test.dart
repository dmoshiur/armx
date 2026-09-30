// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/app.dart';
import 'package:armx_ai/core/providers.dart';
import 'package:armx_ai/core/security/secure_store.dart';
import 'package:armx_ai/core/widgets/armx_controls.dart';
import 'package:armx_ai/data/api/mock/mock_api.dart';
import 'package:armx_ai/features/auth/lock/app_lock_controller.dart';
import 'package:armx_ai/features/auth/lock/lock_page.dart';
import 'package:armx_ai/features/auth/login/login_page.dart';
import 'package:armx_ai/features/auth/pairing/pairing_page.dart';
import 'package:armx_ai/features/shell/app_shell.dart';
import 'package:armx_ai/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../test/support/auth_test_harness.dart';
import '../test/support/fixtures.dart';
import '../test/support/test_harness.dart';

/// The step-2 happy path, end to end on the real router:
///
/// pairing (URL → QR → approved) → sign in → dashboard → background with the
/// "immediately" auto-lock → resume behind the lock screen → system unlock →
/// back to the dashboard through the preserved pending intent.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pair → approve → login → resume locked → unlock → dashboard',
      (tester) async {
    final control = MockBackendControl(
      latency: Duration.zero,
      tokenInterval: Duration.zero,
    );
    final fakeAuth = FakeSystemAuthenticator(available: true, result: true);
    final container = ProviderContainer(
      overrides: <Override>[
        ...testOverrides(secureStore: InMemorySecureStore()),
        armxApiProvider.overrideWithValue(Fixtures.mockApi(control: control)),
        systemAuthenticatorProvider.overrideWithValue(fakeAuth),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const ArmxApp()),
    );

    // --- Launch lands on the pairing screen (unpaired device) -------------
    await _pumpUntil(tester, () => _mounted<PairingPage>(tester));
    final l10n = AppLocalizations.of(tester.element(find.byType(PairingPage)))!;

    await tester.enterText(
      find.byType(ArmxTextField).at(0),
      'https://home.example.com',
    );
    await tester.tap(find.widgetWithText(ArmxButton, l10n.pairingTestConnection));
    await _pumpUntil(tester, () => find.byType(QrImageView).evaluate().isNotEmpty);

    await tester.tap(find.widgetWithText(ArmxButton, l10n.pairingSubmit));
    await _pumpUntil(tester, () => find.text(l10n.pairingApprovedTitle).evaluate().isNotEmpty);

    await tester.tap(find.widgetWithText(ArmxButton, l10n.pairingApprovedAction));
    await _pumpUntil(tester, () => _mounted<LoginPage>(tester));

    // --- Owner signs in and reaches the five-tab shell --------------------
    await tester.enterText(find.byType(ArmxTextField).at(0), 'mohiur');
    await tester.enterText(find.byType(ArmxTextField).at(1), 'correct horse battery');
    await tester.tap(find.widgetWithText(ArmxButton, l10n.loginSubmit));
    await _pumpUntil(tester, () => _mounted<AppShell>(tester));
    expect(container.read(appLockControllerProvider).lockDue, isFalse);

    // --- Background with timeout 0 → resume behind the gate ---------------
    await container
        .read(appLockControllerProvider.notifier)
        .configure(enabled: true, timeoutSeconds: 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpUntil(tester, () => _mounted<LockPage>(tester));
    expect(container.read(appLockControllerProvider).lockDue, isTrue);

    // --- System challenge passes → pending intent returns to the shell ----
    await _pumpUntil(tester, () => _mounted<AppShell>(tester));
    expect(find.byType(LockPage), findsNothing);
    expect(container.read(appLockControllerProvider).lockDue, isFalse);
    expect(fakeAuth.authenticateCalls, 1);
    expect(fakeAuth.promptedWith.single, isNotEmpty);
  });
}

bool _mounted<T>(WidgetTester tester) => find.byType(T).evaluate().isNotEmpty;

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int steps = 80,
}) async {
  for (var i = 0; i < steps; i++) {
    if (condition()) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(condition(), isTrue, reason: 'expected condition never became true');
}
