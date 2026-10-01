// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'voice_engines_platform.dart';
import 'voice_engines_simulated.dart';

export 'voice_engines_platform.dart';
export 'voice_engines_simulated.dart';

/// Speech-to-text contract.
///
/// Implementations must never retain audio: the transcript is the only artefact that may
/// leave the engine, exactly like the Android wake-word contract.
abstract interface class SpeechToTextEngine {
  /// Stable identifier (diagnostics only).
  String get engineId;

  /// Whether a real engine exists on this platform (no microphone, no capture).
  bool get isAvailable;

  /// Whether the engine is a simulator: no audio is captured, the transcript is canned.
  bool get isSimulated => false;

  /// Prepares the engine for [localeCode] (`en` or `bn`). Returns false when unavailable.
  Future<bool> initialize({
    required String localeCode,
    void Function(String code)? onError,
  });

  /// Opens the microphone and reports partial results, the final result and the level.
  Future<void> startListening({
    required String localeCode,
    required void Function(String words, bool isFinal) onResult,
    void Function(double level)? onLevel,
  });

  /// Closes the microphone and resolves the final transcript.
  Future<String> stopListening();

  /// Abandons the capture without producing a transcript.
  Future<void> cancelListening();

  /// Releases platform resources.
  Future<void> dispose();
}

/// Text-to-speech contract.
abstract interface class SpeechSynthesisEngine {
  /// Stable identifier (diagnostics only).
  String get engineId;

  /// Whether a real engine exists on this platform.
  bool get isAvailable;

  /// Whether playback is simulated (the future completes, but nothing is audible).
  bool get isSimulated;

  /// Applies voice parameters.
  Future<void> configure({
    required String localeCode,
    double rate = 0.5,
    double pitch = 1,
    double volume = 1,
  });

  /// Whether the platform has a voice for [localeCode].
  Future<bool> isLanguageAvailable(String localeCode);

  /// Speaks [text]; the future completes when playback finished (or immediately when
  /// simulated).
  Future<void> speak(String text);

  /// Stops playback immediately.
  Future<void> stop();

  /// Releases platform resources.
  Future<void> dispose();
}

/// Locale identifiers understood by both engines.
///
/// English is pinned to `en_US`/`en-US` and Bengali to `bn_BD`/`bn-BD` because both
/// plugins expect BCP-47 style tags with a region for the system engines.
abstract final class VoiceLocales {
  /// BCP-47 tag for the speech engines (`en_US` / `bn_BD`).
  static String pluginTag(String localeCode) => localeCode == 'bn' ? 'bn_BD' : 'en_US';

  /// TTS tag (`en-US` / `bn-BD`).
  static String ttsTag(String localeCode) => localeCode == 'bn' ? 'bn-BD' : 'en-US';

  /// Locale code used by the API/preferences from a plugin tag.
  static String fromTag(String tag) => tag.toLowerCase().startsWith('bn') ? 'bn' : 'en';
}

/// Chooses the engines for the running platform.
///
/// The real plugin engines are used where `PlatformCapabilities` says they exist; the
/// simulated pair is the documented fallback everywhere else, and reports itself as
/// simulated so the UI can be honest about it.
abstract final class VoiceEngineFactory {
  /// The speech-to-text engine for this platform.
  static SpeechToTextEngine speechToText() {
    final engine = PluginSpeechToTextEngine();
    return engine.isAvailable ? engine : SimulatedSpeechToTextEngine();
  }

  /// The text-to-speech engine for this platform.
  static SpeechSynthesisEngine speechSynthesis() {
    final engine = PluginSpeechSynthesisEngine();
    return engine.isAvailable ? engine : SimulatedSpeechSynthesisEngine();
  }
}
