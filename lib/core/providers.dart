// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/platform/desktop_shell.dart';
import '../core/platform/desktop_shell_native.dart';
import '../data/api/armx_api.dart';
import '../data/api/mock/mock_api.dart';
import '../data/db/armx_database.dart';
import '../data/models/preferences.dart';
import '../data/repositories/announcement_repository.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/preferences_repository.dart';
import 'config/app_config.dart';
import 'errors/app_exception.dart';
import 'logging/armx_logger.dart';
import 'security/secure_store.dart';
import 'security/secure_screen.dart';
import 'security/verification_gateway.dart';
import '../core/services/intercom_audio.dart';
import '../core/services/intercom_audio_native.dart';
import '../core/platform/autostart_service.dart';
import '../core/platform/device_availability.dart';
import '../core/platform/silence_probe.dart';
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

/// Chat transcript persistence (offline cache of the conversation).
@Riverpod(keepAlive: true)
ChatRepository chatRepository(Ref ref) => ChatRepository(ref.watch(armxDatabaseProvider));

/// On-device verification gateway (face / voice / system biometric prompts).
///
/// Defaults to the deterministic [SimulatedVerificationGateway] until the real
/// biometric pipelines land (voice = step 4, vision = step 7); tests override it
/// with a fake to exercise cancellation and failure paths.
@Riverpod(keepAlive: true)
VerificationGateway verificationGateway(Ref ref) =>
    SimulatedVerificationGateway(clock: ref.watch(clockProvider));

/// Local copy of the voice-announcement log (shared by the user and Admin views).
@Riverpod(keepAlive: true)
AnnouncementRepository announcementRepository(Ref ref) =>
    AnnouncementRepository(ref.watch(armxDatabaseProvider));

/// Recorder/player used by the walkie-talkie intercom.
///
/// Real implementation on desktop/mobile (`RecordIntercomAudio`), silent stub on the web.
@Riverpod(keepAlive: true)
IntercomAudio intercomAudio(Ref ref) =>
    kIsWeb ? const SilentIntercomAudio() : RecordIntercomAudio();

/// OS "do not disturb" detection.
///
/// [AlwaysAudibleProbe] is the current implementation: detecting the platform focus mode is
/// a per-OS follow-up tracked in `docs/desktop-mode.md`. Until then the feature *assumes
/// audio is allowed* once the device has consented, which is the conservative choice for
/// the demo but must not be mistaken for a completed integration.
@Riverpod(keepAlive: true)
SilenceProbe silenceProbe(Ref ref) => const AlwaysAudibleProbe();

/// Tray / hotkey / popup window shell.
///
/// [NoopDesktopShell] on mobile and the web (where the Android foreground service owns
/// background mode), the native adapter on Windows, macOS and Linux.
@Riverpod(keepAlive: true)
DesktopShell desktopShell(Ref ref) => kIsWeb
    ? const NoopDesktopShell()
    : NativeDesktopShell(iconDirectory: 'assets/tray');

/// Launch-at-login integration.
@Riverpod(keepAlive: true)
AutostartService autostartService(Ref ref) =>
    kIsWeb ? const NoopAutostartService() : LaunchAtStartupService();

/// Audio-input / video-device enumeration used by the tooltip and the readiness screen.
@Riverpod(keepAlive: true)
DeviceAvailabilityService deviceAvailability(Ref ref) => kIsWeb
    ? const NoopDeviceAvailabilityService()
    : RecordDeviceAvailabilityService();

/// Reactive preference snapshot (theme, locale, wake word, thresholds).
@Riverpod(keepAlive: true)
Stream<AppPreferences> appPreferences(Ref ref) =>
    ref.watch(preferencesRepositoryProvider).watch();

/// The A.R.M.X backend contract.
///
/// With `--dart-define=USE_MOCK=true` (the default while the backend does not
/// exist) this returns the deterministic in-app mock. The REST/WebSocket
/// transport is not wired yet, so a non-mock build fails fast with a clear
/// message instead of silently pretending to be connected.
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
