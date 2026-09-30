// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/api/armx_api.dart';
import '../data/api/mock/mock_api.dart';
import '../data/db/armx_database.dart';
import '../data/models/preferences.dart';
import '../data/repositories/preferences_repository.dart';
import 'config/app_config.dart';
import 'errors/app_exception.dart';
import 'logging/armx_logger.dart';
import 'security/secure_store.dart';
import 'security/secure_screen.dart';
import 'utils/clock.dart';

part 'providers.g.dart';

/// Compile-time configuration.
///
/// **Must be overridden** in `main()` with `AppConfig.fromEnvironment()` (or with a test
/// configuration). Reading it without an override is a programming error.
@Riverpod(keepAlive: true)
AppConfig appConfig(Ref ref) =>
    throw const ConfigException('appConfigProvider must be overridden in main().');

/// In-memory log buffer shown by Settings → Diagnostics.
@Riverpod(keepAlive: true)
LogRingBuffer logBuffer(Ref ref) => LogRingBuffer();

/// App-wide redacting logger.
@Riverpod(keepAlive: true)
Logger appLogger(Ref ref) => ArmxLogging.create(
      ref.watch(appConfigProvider).logLevel,
      buffer: ref.watch(logBufferProvider),
    );

/// Wall clock (replaced with a fixed clock in tests).
@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const SystemClock();

/// Platform secure storage (tokens and key material only).
@Riverpod(keepAlive: true)
SecureStore secureStore(Ref ref) => PlatformSecureStore();

/// Screenshot/screen-recording protection.
@Riverpod(keepAlive: true)
ScreenSecurity screenSecurity(Ref ref) => PlatformScreenSecurity();

/// Local SQLite database. Tests override this with an in-memory executor.
@Riverpod(keepAlive: true)
ArmxDatabase armxDatabase(Ref ref) => ArmxDatabase.open();

/// Preference storage.
@Riverpod(keepAlive: true)
PreferencesRepository preferencesRepository(Ref ref) =>
    PreferencesRepository(ref.watch(armxDatabaseProvider));

/// Reactive preference snapshot (theme, locale, wake word, thresholds).
@Riverpod(keepAlive: true)
Stream<AppPreferences> appPreferences(Ref ref) =>
    ref.watch(preferencesRepositoryProvider).watch();

/// The A.R.M.X backend contract.
///
/// With `--dart-define=USE_MOCK=true` (the default while the backend does not exist) this
/// returns the deterministic in-app mock. The REST/WebSocket implementation arrives with
/// step 2 (auth), so a non-mock build fails fast with a clear message instead of silently
/// pretending to be connected.
@Riverpod(keepAlive: true)
ArmxApi armxApi(Ref ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    throw const ConfigException(
      'The REST/WebSocket transport is implemented in delivery step 2. '
      'Run with --dart-define=USE_MOCK=true (default) until then.',
    );
  }
  return MockArmxApi(
    config: config,
    logger: ref.watch(appLoggerProvider),
    clock: ref.watch(clockProvider),
    random: MockArmxApi.deterministicRandom(),
  );
}
