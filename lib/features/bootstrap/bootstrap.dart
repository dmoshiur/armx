// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../data/models/preferences.dart';
import '../auth/lock/app_lock_controller.dart';
import '../auth/pairing/pairing_controller.dart';
import '../auth/session/auth_controller.dart';

part 'bootstrap.g.dart';

/// Outcome of the launch sequence, consumed by the splash gate.
class BootstrapReport {
  /// Creates a report.
  const BootstrapReport({
    required this.config,
    required this.preferences,
    required this.secureStorageAvailable,
    required this.warnings,
    required this.duration,
  });

  /// Effective configuration.
  final AppConfig config;

  /// Preferences loaded from the local database.
  final AppPreferences preferences;

  /// False when the platform keyring refused access (desktop Linux without libsecret).
  final bool secureStorageAvailable;

  /// Non-fatal problems worth surfacing in Diagnostics.
  final List<String> warnings;

  /// How long the launch sequence took.
  final Duration duration;
}

/// Runs the launch sequence: storage probes, preference load and diagnostics.
///
/// Deliberately network-free: A.R.M.X opens offline and syncs later. Any failure here is
/// reported in [BootstrapReport.warnings] rather than thrown, except for a broken database,
/// which is fatal because the app cannot function without local storage.
@Riverpod(keepAlive: true)
Future<BootstrapReport> bootstrap(Ref ref) async {
  final started = DateTime.now();
  final logger = ref.watch(appLoggerProvider);
  final config = ref.watch(appConfigProvider);
  final warnings = <String>[];

  var secureStorageAvailable = true;
  try {
    final store = ref.watch(secureStoreProvider);
    // Probe with a throwaway key: never touch real material during startup.
    await store.write('armx.diag.probe', '1');
    await store.delete('armx.diag.probe');
  } on StorageException catch (error) {
    secureStorageAvailable = false;
    warnings.add('Secure storage unavailable (${error.code}); tokens cannot be persisted.');
    logger.w('bootstrap: secure storage probe failed: ${error.message}');
  }

  final repository = ref.watch(preferencesRepositoryProvider);
  AppPreferences preferences;
  try {
    preferences = await repository.load();
  } on Object catch (error, stackTrace) {
    throw StorageException(
      'The local database could not be opened.',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  // Step-2 restore sequence, in spec order: pairing → auth → app lock. The
  // bootstrap gate only navigates once this provider completes, so the very
  // first redirect already sees the restored gates (each restore is
  // idempotent, so a retry after a fatal error cannot double-apply).
  try {
    await ref.read(pairingControllerProvider.notifier).restore();
  } on Object catch (error) {
    // Corrupt stored material must not brick launch: pairing falls back to
    // "unpaired" (fail-closed) and the flow starts over on the pairing screen.
    logger.w('bootstrap: pairing restore failed (${error.runtimeType})');
  }
  await ref.read(authControllerProvider.notifier).restore();
  final phase = ref.read(authControllerProvider).phase;
  await ref.read(appLockControllerProvider.notifier).restore(
        sessionRestored: phase == AuthPhase.signedIn ||
            phase == AuthPhase.sessionExpiring,
      );

  if (config.useMockBackend) {
    warnings.add('Running against the in-app mock backend (USE_MOCK=true).');
  }
  if (config.hasCertificatePins) {
    warnings.add('Certificate pinning enabled with ${config.certificatePins.length} pin(s).');
  }
  if (!preferences.hasValidThreshold) {
    warnings.add('Face threshold out of range; falling back to the default.');
  }

  final report = BootstrapReport(
    config: config,
    preferences: preferences,
    secureStorageAvailable: secureStorageAvailable,
    warnings: warnings,
    duration: DateTime.now().difference(started),
  );
  logger.i('bootstrap finished in ${report.duration.inMilliseconds} ms '
      '(${warnings.length} warning(s))');
  return report;
}
