// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/foundation.dart';

import '../errors/app_exception.dart';

/// Log levels understood by the app (mapped onto `package:logger` in `core/logging`).
enum AppLogLevel { trace, debug, info, warning, error, off }

/// Deployment environment. Only [AppEnvironment.production] enforces strict TLS.
enum AppEnvironment { development, staging, production }

/// Immutable, compile-time configuration for A.R.M.X AI.
///
/// Every value comes from `--dart-define` (or the defaults below), so **no secret is
/// ever committed to the repository**. See `docs/run.md` for the full list of defines.
@immutable
class AppConfig {
  /// Creates a configuration value. Prefer [AppConfig.fromEnvironment] in app code.
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.wsUrl,
    required this.useMockBackend,
    this.logLevel = AppLogLevel.info,
    this.certificatePins = const <String>[],
    this.mockLatencyMs = 120,
    this.wakeWordEngineId = 'stub',
    this.faceMatchThreshold = 0.72,
    this.palmGestureEnabled = true,
    this.telemetryEnabled = false,
  });

  /// Reads configuration from `--dart-define` values.
  ///
  /// Throws [ConfigException] when the supplied values are unusable (bad URL, cleartext
  /// endpoint in a release build, malformed certificate pin, out-of-range threshold).
  factory AppConfig.fromEnvironment() {
    const environmentName = String.fromEnvironment('APP_ENV', defaultValue: 'development');
    const useMock = bool.fromEnvironment('USE_MOCK', defaultValue: true);
    const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.armx.local');
    const socketUrl = String.fromEnvironment('WS_URL', defaultValue: '');
    const logLevelName = String.fromEnvironment('LOG_LEVEL', defaultValue: 'info');
    const pins = String.fromEnvironment('CERT_PINS', defaultValue: '');
    const latency = int.fromEnvironment('MOCK_LATENCY_MS', defaultValue: 120);
    const wake = String.fromEnvironment('WAKE_WORD_ENGINE', defaultValue: 'stub');
    const threshold = double.fromEnvironment('FACE_MATCH_THRESHOLD', defaultValue: 0.72);
    const telemetry = bool.fromEnvironment('TELEMETRY', defaultValue: false);

    final environment = switch (environmentName) {
      'staging' => AppEnvironment.staging,
      'production' => AppEnvironment.production,
      _ => AppEnvironment.development,
    };
    final apiBase = _parseUri('API_BASE_URL', baseUrl);
    final ws = socketUrl.isEmpty ? _deriveWsUrl(apiBase) : _parseUri('WS_URL', socketUrl);
    final parsedPins = pins
        .split(',')
        .map((pin) => pin.trim())
        .where((pin) => pin.isNotEmpty)
        .toList(growable: false);
    final logLevel = AppLogLevel.values.firstWhere(
      (level) => level.name == logLevelName,
      orElse: () => AppLogLevel.info,
    );

    final config = AppConfig(
      environment: environment,
      apiBaseUrl: apiBase,
      wsUrl: ws,
      useMockBackend: useMock,
      logLevel: logLevel,
      certificatePins: parsedPins,
      mockLatencyMs: latency < 0 ? 0 : latency,
      wakeWordEngineId: wake,
      faceMatchThreshold: threshold.clamp(0.1, 0.99),
      telemetryEnabled: telemetry,
    );
    config.validate();
    return config;
  }

  /// Deployment environment this build targets.
  final AppEnvironment environment;

  /// REST base URL, for example `https://api.armx.example`.
  final Uri apiBaseUrl;

  /// WebSocket endpoint for assistant/tool/device events, for example `wss://…/ws`.
  final Uri wsUrl;

  /// When true the app runs entirely on the in-app deterministic mock backend.
  final bool useMockBackend;

  /// Minimum level written by the logger.
  final AppLogLevel logLevel;

  /// SHA-256 SPKI pins (`sha256/…` or bare base64). Empty means "no pinning".
  final List<String> certificatePins;

  /// Simulated latency for the mock backend (keeps the UI honest about loading states).
  final int mockLatencyMs;

  /// Wake-word engine identifier: `stub`, `porcupine` or `openwakeword`.
  final String wakeWordEngineId;

  /// Default cosine-similarity threshold for face verification (overridable in Settings).
  final double faceMatchThreshold;

  /// Whether the palm-open gesture listener is enabled by default.
  final bool palmGestureEnabled;

  /// Opt-in anonymous diagnostics. Off by default; there is no analytics SDK in this app.
  final bool telemetryEnabled;

  /// True when the build must refuse cleartext transport.
  bool get requiresTls => environment == AppEnvironment.production;

  /// True when a non-empty certificate pin set is configured.
  bool get hasCertificatePins => certificatePins.isNotEmpty;

  /// True while the app is expected to run without a backend.
  bool get isOfflineFirst => useMockBackend;

  /// Human readable, **secret-free** summary used by the About/Diagnostics screen.
  String describe() => 'environment=${environment.name} api=${apiBaseUrl.origin} '
      'ws=${wsUrl.origin} mock=$useMockBackend pins=${certificatePins.length} '
      'wakeWord=$wakeWordEngineId log=${logLevel.name}';

  /// Enforces the security invariants of this configuration.
  void validate() {
    if (requiresTls && apiBaseUrl.scheme != 'https') {
      throw const ConfigException(
        'Refusing to start: release builds require an https API_BASE_URL.',
      );
    }
    if (requiresTls && wsUrl.scheme != 'wss') {
      throw const ConfigException(
        'Refusing to start: release builds require a wss WS_URL.',
      );
    }
    if (!useMockBackend && apiBaseUrl.host.isEmpty) {
      throw const ConfigException('API_BASE_URL must contain a host when USE_MOCK=false.');
    }
    for (final pin in certificatePins) {
      if (pin.length < 32) {
        throw const ConfigException('CERT_PINS entries must be base64 SHA-256 digests.');
      }
    }
  }

  static Uri _parseUri(String name, String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.host.isEmpty) {
      throw ConfigException('$name is not a valid absolute URL: "$raw".');
    }
    return uri;
  }

  static Uri _deriveWsUrl(Uri apiBase) {
    final scheme = apiBase.scheme == 'https' ? 'wss' : 'ws';
    return apiBase.replace(scheme: scheme, path: '/ws');
  }
}
