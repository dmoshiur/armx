// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/security/secure_store.dart';
import 'package:armx_ai/core/theme/armx_theme.dart';
import 'package:armx_ai/core/utils/clock.dart';
import 'package:armx_ai/data/db/armx_database.dart';
import 'package:armx_ai/features/auth/lock/system_authenticator.dart';
import 'package:armx_ai/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'test_harness.dart';

/// Deterministic [SystemAuthenticator] for widget/golden/integration tests.
///
/// Flip [available] to simulate a device without biometrics/screen PIN and
/// [result] to simulate a passed/failed challenge; [failWith] throws instead
/// of answering, mimicking a platform error.
class FakeSystemAuthenticator implements SystemAuthenticator {
  /// Creates the fake with the desired behaviour.
  FakeSystemAuthenticator({
    this.available = true,
    this.result = true,
    this.failWith,
  });

  /// Whether the device offers a system challenge at all.
  bool available;

  /// Answer returned by a successful (not throwing) challenge.
  bool result;

  /// When set, [authenticate] throws this instead of answering.
  Object? failWith;

  /// Every localized reason the fake was prompted with (assert localization).
  final List<String> promptedWith = <String>[];

  /// How many times [authenticate] ran.
  int authenticateCalls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String localizedReason) async {
    authenticateCalls += 1;
    promptedWith.add(localizedReason);
    final error = failWith;
    if (error != null) {
      throw error;
    }
    return result;
  }
}

/// Pumps a widget under the standard test overrides, optionally *before* the
/// first frame (so pages that react in `initState` — e.g. the lock screen —
/// already see a primed controller state) and optionally behind a real
/// `GoRouter` so `context.go(...)` navigation is observable.
///
/// Either [home] (plain `MaterialApp.home`) or [router] must be provided.
Future<ProviderContainer> pumpAuthApp(
  WidgetTester tester, {
  Widget Function()? home,
  GoRouter? router,
  List<Override> overrides = const <Override>[],
  Future<void> Function(ProviderContainer container)? prime,
  InMemorySecureStore? secureStore,
  ArmxDatabase? database,
  FixedClock? clock,
  ThemeMode themeMode = ThemeMode.dark,
  Locale locale = const Locale('en'),
  Size? surfaceSize,
}) async {
  assert(home != null || router != null, 'provide home() or a router');
  if (surfaceSize != null) {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  final container = ProviderContainer(
    overrides: <Override>[
      ...testOverrides(clock: clock, database: database, secureStore: secureStore),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  if (prime != null) {
    await prime(container);
  }

  final app = router != null
      ? MaterialApp.router(
          theme: ArmxTheme.light(),
          darkTheme: ArmxTheme.dark(),
          themeMode: themeMode,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        )
      : MaterialApp(
          theme: ArmxTheme.light(),
          darkTheme: ArmxTheme.dark(),
          themeMode: themeMode,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home!(),
        );

  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: app));
  await tester.pump();
  return container;
}

/// Localized copy for [finder]'s context (tests stay language-agnostic).
AppLocalizations l10nOf(WidgetTester tester, Finder finder) =>
    AppLocalizations.of(tester.element(finder))!;
