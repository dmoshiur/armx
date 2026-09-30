// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/providers.dart';
import 'package:armx_ai/core/security/secure_store.dart';
import 'package:armx_ai/core/widgets/armx_controls.dart';
import 'package:armx_ai/features/auth/login/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_test_harness.dart';
import '../../support/fixtures.dart';
import '../../support/test_harness.dart';

/// The sign-in screen: distinct localized failures and the client-side
/// guessing lockout after five bad attempts.
void main() {
  Future<ProviderContainer> pumpLogin(WidgetTester tester) async {
    final container = await pumpArmxWidget(
      tester,
      const LoginPage(),
      overrides: <Override>[
        armxApiProvider.overrideWithValue(Fixtures.mockApi()),
      ],
      surfaceSize: const Size(1080, 1600),
    );
    // Pairing material + server URL, as the pairing flow would have left them.
    await container.read(secureStoreProvider).write(SecureKeys.deviceKey, 'device-key');
    await container
        .read(preferencesRepositoryProvider)
        .setLastServerUrl('https://api.armx.test');
    await tester.pump();
    return container;
  }

  Future<void> submit(WidgetTester tester, String username, String password) async {
    await tester.enterText(find.byType(ArmxTextField).at(0), username);
    await tester.enterText(find.byType(ArmxTextField).at(1), password);
    final l10n = l10nOf(tester, find.byType(LoginPage));
    await tester.tap(find.widgetWithText(ArmxButton, l10n.loginSubmit));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
  }

  testWidgets('an empty form fails validation without touching the backend',
      (tester) async {
    await pumpLogin(tester);
    final l10n = l10nOf(tester, find.byType(LoginPage));

    await tester.tap(find.widgetWithText(ArmxButton, l10n.loginSubmit));
    await tester.pump();

    expect(find.text(l10n.validationEmpty), findsNWidgets(2));
  });

  testWidgets('wrong credentials show the invalid-credentials copy', (tester) async {
    await pumpLogin(tester);
    final l10n = l10nOf(tester, find.byType(LoginPage));

    await submit(tester, 'wrong', 'wrong');

    expect(find.text(l10n.loginErrorInvalidCredentials), findsOneWidget);
    expect(find.text(l10n.loginErrorAccountLocked), findsNothing);
  });

  testWidgets('the locked account shows its own copy', (tester) async {
    await pumpLogin(tester);
    final l10n = l10nOf(tester, find.byType(LoginPage));

    await submit(tester, 'locked', 'whatever');

    expect(find.text(l10n.loginErrorAccountLocked), findsOneWidget);
    expect(find.text(l10n.loginErrorInvalidCredentials), findsNothing);
  });

  testWidgets('five failures arm the backoff and disable the button',
      (tester) async {
    await pumpLogin(tester);
    final l10n = l10nOf(tester, find.byType(LoginPage));

    for (var i = 0; i < 5; i++) {
      await submit(tester, 'wrong', 'wrong');
    }

    final prefix = l10n.loginRateLimited(seconds: 99999).split('99999').first;
    expect(find.textContaining(prefix), findsOneWidget);
    final button = tester.widget<ArmxButton>(
      find.widgetWithText(ArmxButton, l10n.loginSubmit),
    );
    expect(button.onPressed, isNull, reason: 'no guessing button while blocked');
  });

  testWidgets('a failed attempt keeps the username but never echoes the password',
      (tester) async {
    await pumpLogin(tester);
    final l10n = l10nOf(tester, find.byType(LoginPage));

    await submit(tester, 'wrong', 'hunter2secret');

    expect(find.text(l10n.loginErrorInvalidCredentials), findsOneWidget);
    expect(find.text('hunter2secret'), findsNothing);
    final passwordField = tester.widget<ArmxTextField>(
      find.byType(ArmxTextField).at(1),
    );
    expect(passwordField.obscure, isTrue);
  });
}
