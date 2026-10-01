// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';
import 'dart:typed_data';

/// A recorded announcement ready to be uploaded.
@immutable
class IntercomClip {
  /// Creates a clip.
  const IntercomClip({
    required this.bytes,
    required this.durationMs,
    required this.mimeType,
  });

  /// Empty clip used when recording produced nothing.
  static const IntercomClip empty = IntercomClip(
    bytes: _emptyBytes,
    durationMs: 0,
    mimeType: 'audio/mp4',
  );

  static const Uint8List _emptyBytes = Uint8List(0);

  /// Encoded audio (m4a/AAC on desktop, wav where AAC is unavailable).
  final Uint8List bytes;

  /// How long the user held the button.
  final int durationMs;

  /// MIME type of [bytes].
  final String mimeType;

  /// True when there is nothing to send.
  bool get isEmpty => bytes.isEmpty || durationMs <= 0;
}

/// Microphone capture and playback for the Admin/Owner intercom.
///
/// Kept behind an interface so the intercom state machine (consent, delivery status, the
/// overlay rules) is pure Dart and unit-testable: [SilentIntercomAudio] stands in for the
/// recorder/player in tests and on platforms without audio support.
abstract interface class IntercomAudio {
  /// True when a usable microphone exists.
  Future<bool> get hasMicrophone;

  /// Starts capturing; throws [StateError] when already recording.
  Future<void> startRecording();

  /// Stops capturing and returns the encoded clip.
  Future<IntercomClip> stopRecording();

  /// Abandons the current capture without producing a clip.
  Future<void> cancelRecording();

  /// Live level 0.0–1.0 driving the waveform.
  Stream<double> get amplitude;

  /// Plays the distinct announcement chime (always before any voice).
  Future<void> playChime();

  /// Plays an announcement from a local file.
  Future<void> playFile(String path);

  /// Stops playback immediately ("Mute this once").
  Future<void> stopPlayback();

  /// Releases the recorder and the player.
  Future<void> dispose();
}

/// No-op audio: no microphone, no playback. Used in tests and on unsupported platforms.
class SilentIntercomAudio implements IntercomAudio {
  /// Creates the silent implementation.
  const SilentIntercomAudio();

  final StreamController<double> _amplitude = StreamController<double>.broadcast();

  @override
  Future<bool> get hasMicrophone async => false;

  @override
  Future<void> startRecording() async {}

  @override
  Future<IntercomClip> stopRecording() async => IntercomClip.empty;

  @override
  Future<void> cancelRecording() async {}

  @override
  Stream<double> get amplitude => _amplitude.stream;

  @override
  Future<void> playChime() async {}

  @override
  Future<void> playFile(String path) async {}

  @override
  Future<void> stopPlayback() async {}

  @override
  Future<void> dispose() async {
    await _amplitude.close();
  }
}
