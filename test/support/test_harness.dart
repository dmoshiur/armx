// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/config/app_config.dart';
import 'package:armx_ai/core/logging/armx_logger.dart';
import 'package:armx_ai/core/providers.dart';
import 'package:armx_ai/core/security/secure_screen.dart';
import 'package:armx_ai/core/security/secure_store.dart';
import 'package:armx_ai/core/theme/armx_theme.dart';
import 'package:armx_ai/core/utils/clock.dart';
import 'package:armx_ai/data/db/armx_database.dart';
import 'package:armx_ai/l10n/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

/// A fixed instant used by every test so relative timestamps never drift.
final DateTime testAnchor = DateTime.utc(2026, 9, 30, 12);

/// Test configuration: mock backend, no simulated latency, no certificate pins.
AppConfig testConfig({
  bool useMockBackend = true,
  AppEnvironment environment = AppEnvironment.development,
}) =>
    AppConfig(
      environment: environment,
      apiBaseUrl: Uri.parse('https://api.armx.test'),
      wsUrl: Uri.parse('wss://api.armx.test/ws'),
      useMockBackend: useMockBackend,
      logLevel: AppLogLevel.debug,
      mockLatencyMs: 0,
    );

/// Provider overrides that make the app fully offline and deterministic in tests.
///
/// * in-memory SQLite instead of the app file;
/// * in-memory secure storage instead of the platform keyring;
/// * no-op screenshot guard (no platform channel in the test binding);
/// * fixed clock and a zero-latency mock backend.
List<Override> testOverrides({
  AppConfig? config,
  FixedClock? clock,
  ArmxDatabase? database,
  InMemorySecureStore? secureStore,
}) {
  final fixedClock = clock ?? FixedClock(testAnchor);
  return <Override>[
    appConfigProvider.overrideWithValue(config ?? testConfig()),
    clockProvider.overrideWithValue(fixedClock),
    secureStoreProvider.overrideWithValue(secureStore ?? InMemorySecureStore()),
    screenSecurityProvider.overrideWithValue(const NoopScreenSecurity()),
    armxDatabaseProvider.overrideWithValue(database ?? ArmxDatabase(NativeDatabase.memory())),
  ];
}

/// Pumps a widget inside the app's theme, localization delegates and provider scope.
///
/// Returns the [ProviderContainer] so tests can read providers directly.
Future<ProviderContainer> pumpArmxWidget(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const <Override>[],
  ThemeMode themeMode = ThemeMode.dark,
  Locale locale = const Locale('en'),
  Size? surfaceSize,
}) async {
  if (surfaceSize != null) {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  final container = ProviderContainer(overrides: <Override>[...testOverrides(), ...overrides]);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ArmxTheme.light(),
        darkTheme: ArmxTheme.dark(),
        themeMode: themeMode,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
  await tester.pump();
  return container;
}

/// Expects that a widget offers at least the product's minimum touch target (48 dp).
void expectMinTouchTarget(WidgetTester tester, Finder finder) {
  final size = tester.getSize(finder);
  expect(
    size.height,
    greaterThanOrEqualTo(ArmxTheme.minimumTouchTarget - 0.01),
    reason: 'tap target height must be >= ${ArmxTheme.minimumTouchTarget} dp',
  );
  expect(
    size.width,
    greaterThanOrEqualTo(ArmxTheme.minimumTouchTarget - 0.01),
    reason: 'tap target width must be >= ${ArmxTheme.minimumTouchTarget} dp',
  );
}

/// Builds a logger whose lines are captured in an in-memory ring buffer.
///
/// Returns a record so callers can assert on `buffer.records` while passing the logger
/// itself into `appLoggerProvider.overrideWithValue(...)`.
(Logger, LogRingBuffer) buildTestLogger() {
  final buffer = LogRingBuffer();
  return (ArmxLogging.create(AppLogLevel.debug, buffer: buffer), buffer);
}
