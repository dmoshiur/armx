// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/config/app_config.dart';
import 'package:armx_ai/core/logging/armx_logger.dart';
import 'package:armx_ai/core/security/verification_evidence.dart';
import 'package:armx_ai/core/utils/clock.dart';
import 'package:armx_ai/data/api/mock/mock_api.dart';
import 'package:logger/logger.dart';

/// Shared builders for tests.
abstract final class Fixtures {
  /// A logger that discards everything (tests should not spam the console).
  static Logger silentLogger() => ArmxLogging.create(AppLogLevel.off);

  /// A fixed instant shared by every fixture.
  static final DateTime anchor = DateTime.utc(2026, 9, 30, 12);

  /// A mock backend with zero latency over [clock].
  static MockArmxApi mockApi({
    Clock? clock,
    AppConfig? config,
    String locale = 'en',
    MockBackendControl? control,
  }) =>
      MockArmxApi(
        config: config ??
            AppConfig(
              environment: AppEnvironment.development,
              apiBaseUrl: Uri.parse('https://api.armx.test'),
              wsUrl: Uri.parse('wss://api.armx.test/ws'),
              useMockBackend: true,
              mockLatencyMs: 0,
            ),
        logger: silentLogger(),
        clock: clock ?? FixedClock(anchor),
        random: MockArmxApi.deterministicRandom(),
        control: control ?? MockBackendControl(latency: Duration.zero, tokenInterval: Duration.zero),
        localeCode: locale,
      );

  /// Evidence containing the given freshly-verified factors at [now].
  static VerificationEvidence evidence(
    DateTime now, {
    bool face = false,
    bool voice = false,
    bool systemBiometric = false,
    Duration age = Duration.zero,
    bool facePassed = true,
  }) {
    final verifiedAt = now.subtract(age);
    var evidence = VerificationEvidence.empty(now);
    if (face) {
      evidence = evidence.withResult(
        FactorResult(
          factor: VerificationFactor.face,
          passed: facePassed,
          verifiedAt: verifiedAt,
          score: 0.91,
        ),
      );
    }
    if (voice) {
      evidence = evidence.withResult(
        FactorResult(
          factor: VerificationFactor.voice,
          passed: true,
          verifiedAt: verifiedAt,
          score: 0.88,
        ),
      );
    }
    if (systemBiometric) {
      evidence = evidence.withResult(
        FactorResult(
          factor: VerificationFactor.systemBiometric,
          passed: true,
          verifiedAt: verifiedAt,
        ),
      );
    }
    return evidence;
  }
}
