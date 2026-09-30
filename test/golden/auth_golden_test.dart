// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/providers.dart';
import 'package:armx_ai/features/auth/lock/app_lock_controller.dart';
import 'package:armx_ai/features/auth/lock/lock_page.dart';
import 'package:armx_ai/features/auth/login/login_page.dart';
import 'package:armx_ai/features/auth/pairing/pairing_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/auth_test_harness.dart';
import '../support/fixtures.dart';
import '../support/test_harness.dart';

/// Visual goldens for the three step-2 entry screens, in both themes.
///
/// The PNG baselines are **not** committed blind: run
/// `flutter test --update-goldens test/golden` once (see docs/run.md) to
/// generate them, eyeball the result, then run plain `flutter test` to lock
/// them in.
void main() {
  const surface = Size(1080, 1600);

  for (final theme in <ThemeMode>[ThemeMode.dark, ThemeMode.light]) {
    final suffix = theme == ThemeMode.dark ? 'dark' : 'light';

    testWidgets('login screen ($suffix)', (tester) async {
      await pumpArmxWidget(
        tester,
        const LoginPage(),
        overrides: <Override>[armxApiProvider.overrideWithValue(Fixtures.mockApi())],
        themeMode: theme,
        surfaceSize: surface,
      );
      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/login_$suffix.png'),
      );
    });

    testWidgets('pairing screen ($suffix)', (tester) async {
      await pumpArmxWidget(
        tester,
        const PairingPage(),
        overrides: <Override>[armxApiProvider.overrideWithValue(Fixtures.mockApi())],
        themeMode: theme,
        surfaceSize: surface,
      );
      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/pairing_$suffix.png'),
      );
    });

    testWidgets('lock screen first-run PIN setup ($suffix)', (tester) async {
      final fake = FakeSystemAuthenticator(available: false);
      await pumpAuthApp(
        tester,
        home: () => const LockPage(),
        overrides: <Override>[systemAuthenticatorProvider.overrideWithValue(fake)],
        prime: (container) =>
            container.read(appLockControllerProvider.notifier).restore(sessionRestored: true),
        themeMode: theme,
        surfaceSize: surface,
      );
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/lock_$suffix.png'),
      );
    });
  }
}
