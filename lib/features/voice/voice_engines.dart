// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/utils/platform_capabilities.dart';

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

// ---------------------------------------------------------------------------------------
// Real engines (speech_to_text / flutter_tts)
// ---------------------------------------------------------------------------------------

/// [SpeechToTextEngine] over `package:speech_to_text`.
///
/// Everything is wrapped: a device without a recognizer, or a platform whose plugin is
/// missing, degrades to [isAvailable] = false instead of throwing into the UI.
class PluginSpeechToTextEngine implements SpeechToTextEngine {
  /// Creates the engine.
  PluginSpeechToTextEngine({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  String _lastTranscript = '';
  bool _initialized = false;

  @override
  String get engineId => 'speech_to_text';

  @override
  bool get isAvailable =>
      !kIsWeb && PlatformCapabilities.supports(PlatformFeature.speechToText);

  @override
  Future<bool> initialize({
    required String localeCode,
    void Function(String code)? onError,
  }) async {
    if (!isAvailable) {
      return false;
    }
    if (_initialized) {
      return true;
    }
    try {
      final ready = await _speech.initialize(
        onError: (error) => onError?.call(error.errorMsg),
        onStatus: (_) {},
      );
      _initialized = ready;
      return ready;
    } on Object catch (error) {
      onError?.call('stt_init_failed');
      debugPrint('A.R.M.X stt init failed: ${error.runtimeType}');
      return false;
    }
  }

  @override
  Future<void> startListening({
    required String localeCode,
    required void Function(String words, bool isFinal) onResult,
    void Function(double level)? onLevel,
  }) async {
    _lastTranscript = '';
    await _speech.listen(
      onResult: (result) {
        _lastTranscript = result.recognizedWords;
        onResult(result.recognizedWords, result.finalResult);
      },
      onSoundLevelChange: onLevel,
      localeId: VoiceLocales.pluginTag(localeCode),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
      ),
    );
  }

  @override
  Future<String> stopListening() async {
    await _speech.stop();
    return _lastTranscript;
  }

  @override
  Future<void> cancelListening() async {
    _lastTranscript = '';
    await _speech.cancel();
  }

  @override
  Future<void> dispose() async {
    await _speech.cancel();
  }
}

/// [SpeechSynthesisEngine] over `package:flutter_tts`.
class PluginSpeechSynthesisEngine implements SpeechSynthesisEngine {
  /// Creates the engine.
  PluginSpeechSynthesisEngine({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  String get engineId => 'flutter_tts';

  @override
  bool get isAvailable =>
      !kIsWeb && PlatformCapabilities.supports(PlatformFeature.textToSpeech);

  @override
  bool get isSimulated => !isAvailable;

  @override
  Future<void> configure({
    required String localeCode,
    double rate = 0.5,
    double pitch = 1,
    double volume = 1,
  }) async {
    if (!isAvailable) {
      return;
    }
    try {
      await _tts.setLanguage(VoiceLocales.ttsTag(localeCode));
      await _tts.setSpeechRate(rate);
      await _tts.setPitch(pitch);
      await _tts.setVolume(volume);
      await _tts.awaitSpeakCompletion(true);
    } on Object catch (error) {
      debugPrint('A.R.M.X tts configure failed: ${error.runtimeType}');
    }
  }

  @override
  Future<bool> isLanguageAvailable(String localeCode) async {
    if (!isAvailable) {
      return false;
    }
    try {
      final result = await _tts.isLanguageAvailable(VoiceLocales.ttsTag(localeCode));
      return result == true;
    } on Object catch (_) {
      return false;
    }
  }

  @override
  Future<void> speak(String text) async {
    if (!isAvailable || text.trim().isEmpty) {
      return;
    }
    try {
      await _tts.speak(text);
    } on Object catch (error) {
      debugPrint('A.R.M.X tts speak failed: ${error.runtimeType}');
    }
  }

  @override
  Future<void> stop() async {
    if (!isAvailable) {
      return;
    }
    try {
      await _tts.stop();
    } on Object catch (_) {
      // Stopping a silent engine is not an error.
    }
  }

  @override
  Future<void> dispose() => stop();
}

// ---------------------------------------------------------------------------------------
// Simulated engines (tests, web, Linux desktop, demo fallback)
// ---------------------------------------------------------------------------------------

/// Deterministic stand-in for [SpeechToTextEngine].
///
/// It captures **no audio**. Tests and the science-fair demo use it so the whole
/// push-to-talk → chat → TTS path is exercisable without a microphone; the UI labels it
/// "simulated" whenever it is active.
class SimulatedSpeechToTextEngine implements SpeechToTextEngine {
  /// Creates a simulator that reports [responses] in order.
  SimulatedSpeechToTextEngine({
    List<String>? responses,
    this.transcriptDelay = const Duration(milliseconds: 600),
    this.levelStep = 0.08,
  }) : responses = responses ??
            const <String>['Turn on the living room lights', 'Open the main gate'];

  /// Transcripts returned by successive captures.
  final List<String> responses;

  /// How long a capture "listens" before returning the transcript.
  final Duration transcriptDelay;

  /// Amount added to the reported level on every tick (drives the level meter).
  final double levelStep;

  int _index = 0;
  double _level = 0.2;
  Completer<String> _capture = Completer<String>();
  String _partial = '';
  void Function(double level)? _onLevel;

  @override
  String get engineId => 'simulated';

  @override
  bool get isAvailable => true;

  @override
  bool get isSimulated => true;

  @override
  Future<bool> initialize({
    required String localeCode,
    void Function(String code)? onError,
  }) async =>
      true;

  @override
  Future<void> startListening({
    required String localeCode,
    required void Function(String words, bool isFinal) onResult,
    void Function(double level)? onLevel,
  }) async {
    _onLevel = onLevel;
    _partial = '';
    _level = 0.2;
    if (_capture.isCompleted) {
      _capture = Completer<String>();
    }
    final phrase = responses[_index % responses.length];
    _index += 1;

    // Simulate a growing transcript so the UI exercises partial results too.
    final words = phrase.split(' ');
    for (var i = 1; i <= words.length; i++) {
      if (_capture.isCompleted) {
        return;
      }
      _partial = words.take(i).join(' ');
      _level = (_level + levelStep).clamp(0.0, 1.0);
      _onLevel?.call(_level);
      onResult(_partial, i == words.length);
      await Future<void>.delayed(transcriptDelay ~/ words.length);
    }
  }

  @override
  Future<String> stopListening() async {
    if (!_capture.isCompleted) {
      _capture.complete(_partial);
    }
    await _capture.future;
    return _partial;
  }

  @override
  Future<void> cancelListening() async {
    if (!_capture.isCompleted) {
      _capture.complete('');
    }
    _partial = '';
  }

  @override
  Future<void> dispose() async {
    await cancelListening();
  }
}

/// Deterministic stand-in for [SpeechSynthesisEngine]: no audio, but the timing contract
/// (the future completes when "playback" ends) is preserved so tests can await it.
class SimulatedSpeechSynthesisEngine implements SpeechSynthesisEngine {
  /// Creates the simulator.
  SimulatedSpeechSynthesisEngine({
    this.wordsPerMinute = 600,
    this.simulated = true,
  });

  /// How fast the simulated playback drains (higher = quicker tests).
  final int wordsPerMinute;

  /// Whether this engine reports itself as simulated (false = silent real engine).
  final bool simulated;

  /// Every text handed to [speak], in order.
  final List<String> spoken = <String>[];

  bool _cancelled = false;

  @override
  String get engineId => 'simulated_tts';

  @override
  bool get isAvailable => true;

  @override
  bool get isSimulated => simulated;

  @override
  Future<void> configure({
    required String localeCode,
    double rate = 0.5,
    double pitch = 1,
    double volume = 1,
  }) async {}

  @override
  Future<bool> isLanguageAvailable(String localeCode) async => true;

  @override
  Future<void> speak(String text) async {
    _cancelled = false;
    spoken.add(text);
    final words = text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
    final duration = Duration(
      milliseconds: (words / wordsPerMinute * 60000).round().clamp(1, 60000),
    );
    final step = Duration(milliseconds: (duration.inMilliseconds / 4).round().clamp(1, 1000));
    for (var i = 0; i < 4; i++) {
      if (_cancelled) {
        return;
      }
      await Future<void>.delayed(step);
    }
  }

  @override
  Future<void> stop() async {
    _cancelled = true;
  }

  @override
  Future<void> dispose() => stop();
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
