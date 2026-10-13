// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/providers.dart';
import 'package:armx_ai/core/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/app_harness.dart';

/// Every screen, at every size the master prompt names — including the two ends of the web
/// range, where a layout is most likely to break.
///
/// A `RenderFlex` overflow throws in a widget test, so simply driving the app at these sizes
/// and letting the framework fail is a real check: it is the same failure a user would see as
/// a yellow-and-black bar.
const List<Size> widths = <Size>[
  Size(320, 640), // the narrowest phone browser the app claims to support
  Size(360, 800), // the reference phone
  Size(600, 960), // exactly at the compact → medium breakpoint
  Size(800, 1280), // the reference tablet
  Size(1024, 768), // exactly at the medium → expanded breakpoint
  Size(1440, 900), // the reference desktop
  Size(2560, 1440), // a wide monitor: the content cap must hold
];

/// Screens that need no session.
const List<String> publicRoutes = <String>[
  Routes.splash,
  Routes.login,
  Routes.signup,
  Routes.forgotPassword,
];

/// Screens behind the session, including the admin surface (the owner account is an admin).
const List<String> signedInRoutes = <String>[
  Routes.home,
  Routes.assistant,
  Routes.smartHome,
  Routes.alarms,
  Routes.linkedDevices,
  Routes.guestGreeter,
  Routes.webBuilder,
  Routes.messaging,
  Routes.settings,
  Routes.settingsPreferences,
  Routes.settingsPermissions,
  Routes.settingsAccount,
  Routes.settingsDiagnostics,
  Routes.settingsAbout,
  Routes.admin,
  Routes.adminAudit,
  Routes.adminTools,
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final Size size in widths) {
    final String label = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('the public screens lay out cleanly at $label', (
      WidgetTester tester,
    ) async {
      final AppHarness app = await AppHarness.boot(tester, size: size);
      for (final String route in publicRoutes) {
        await app.go(tester, route);
        expect(
          tester.takeException(),
          isNull,
          reason: '$route overflowed or threw at $label',
        );
      }
    });

    testWidgets('every signed-in screen lays out cleanly at $label', (
      WidgetTester tester,
    ) async {
      final AppHarness app = await AppHarness.boot(tester, size: size);
      await app.signIn(tester);

      for (final String route in signedInRoutes) {
        await app.go(tester, route);
        expect(
          find.byType(Scaffold),
          findsWidgets,
          reason: '$route did not render a screen at $label',
        );
        expect(
          tester.takeException(),
          isNull,
          reason: '$route overflowed or threw at $label',
        );
      }
    });
  }

  testWidgets('a large text scale does not break the layout at 360 dp', (
    WidgetTester tester,
  ) async {
    // Bengali runs longer than English and users may scale text; 1.6 is the cap the app
    // applies, so it is the value worth testing.
    final AppHarness app = await AppHarness.boot(
      tester,
      size: const Size(360, 800),
      textScale: 1.6,
    );
    await app.signIn(tester);
    for (final String route in <String>[
      Routes.home,
      Routes.smartHome,
      Routes.settings,
    ]) {
      await app.go(tester, route);
      expect(tester.takeException(), isNull, reason: '$route broke at 1.6x text');
    }
  });

  testWidgets('Bengali renders without overflowing its controls', (
    WidgetTester tester,
  ) async {
    final AppHarness app = await AppHarness.boot(tester, size: const Size(360, 800));
    await app.signIn(tester);

    // Switch the app to Bengali the way the user does, then walk the same screens.
    await app.go(tester, Routes.settingsPreferences);
    await app.container.read(preferencesProvider.notifier).setLocale('bn');
    await tester.pumpAndSettle();
    for (final String route in <String>[
      Routes.login,
      Routes.settings,
      Routes.smartHome,
    ]) {
      await app.go(tester, route);
      expect(tester.takeException(), isNull, reason: '$route broke in Bengali');
    }
  });
}
