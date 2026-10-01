// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/utils/platform_capabilities.dart';
import 'voice_engines.dart';

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
