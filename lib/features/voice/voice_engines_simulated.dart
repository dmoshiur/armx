// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'voice_engines.dart';

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
