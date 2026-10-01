// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';

import 'intercom_audio.dart';

/// Recording + playback built on `package:record` (7.1.1) and `package:audioplayers`
/// (6.6.0).
///
/// `record` supplies the microphone and the level meter; `audioplayers` plays the chime
/// asset and the downloaded announcement. Pinned versions are recorded in `pubspec.yaml`.
///
/// Linux caveat (from `record`'s own parity table): encoding needs `parecord`, `pactl` and
/// `ffmpeg` on the host, and there is no permission API. When any of that is missing the
/// recorder reports "no microphone" and the app degrades to typed input — see
/// `docs/desktop-mode.md` § Audio.
class RecordIntercomAudio implements IntercomAudio {
  /// Creates the adapter.
  RecordIntercomAudio();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final StreamController<double> _amplitude = StreamController<double>.broadcast();
  StreamSubscription<Amplitude>? _levelSubscription;
  Timer? _levelTimer;
  String? _recordingPath;
  bool _recording = false;

  @override
  Stream<double> get amplitude => _amplitude.stream;

  @override
  Future<bool> get hasMicrophone async {
    try {
      return await _recorder.hasPermission();
    } on Object {
      return false;
    }
  }

  @override
  Future<void> startRecording() async {
    if (_recording) {
      throw StateError('already recording');
    }
    // No `path_provider` dependency: a recording is disposable, so the OS temp directory is
    // enough (and keeps the dependency list honest — see docs/decisions/0002).
    _recordingPath =
        '${Directory.systemTemp.path}/armx_intercom_${DateTime.now().microsecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: _recordingPath);
    _recording = true;
    _forwardLevels();
  }

  /// Feeds the waveform.
  ///
  /// `record` 7 exposes `onAmplitudeChanged(Duration)`; older builds expose a plain getter.
  /// Both are attempted, and a missing method degrades to a synthetic meter instead of
  /// breaking the overlay.
  void _forwardLevels() {
    try {
      final dynamicRecorder = _recorder;
      final Object? stream = dynamicRecorder.onAmplitudeChanged(const Duration(milliseconds: 80));
      if (stream is Stream<Amplitude>) {
        _levelSubscription = stream.listen((Amplitude level) {
          final normalised = ((level.current + 60) / 60).clamp(0.0, 1.0).toDouble();
          if (!_amplitude.isClosed) {
            _amplitude.add(normalised);
          }
        });
        return;
      }
    } on Object {
      // Fall through to the synthetic meter.
    }
    _syntheticLevels();
  }

  void _syntheticLevels() {
    var phase = 0.0;
    _levelTimer = Timer.periodic(const Duration(milliseconds: 90), (Timer timer) {
      if (!_recording) {
        timer.cancel();
        return;
      }
      phase += 0.55;
      if (!_amplitude.isClosed) {
        _amplitude.add(0.35 + 0.35 * (phase % 1.0));
      }
    });
  }

  @override
  Future<IntercomClip> stopRecording() async {
    if (!_recording) {
      return IntercomClip.empty;
    }
    _recording = false;
    await _levelSubscription?.cancel();
    _levelSubscription = null;
    final path = await _recorder.stop();
    _recordingPath = null;
    if (path == null) {
      return IntercomClip.empty;
    }
    final file = File(path);
    if (!await file.exists()) {
      return IntercomClip.empty;
    }
    final bytes = await file.readAsBytes();
    await file.delete();
    return IntercomClip(
      bytes: bytes,
      durationMs: _estimateDurationMs(bytes.length),
      mimeType: 'audio/mp4',
    );
  }

  @override
  Future<void> cancelRecording() async {
    if (!_recording) {
      return;
    }
    _recording = false;
    await _levelSubscription?.cancel();
    _levelSubscription = null;
    await _recorder.cancel();
    _recordingPath = null;
  }

  /// ~64 kbit/s AAC estimate; the real duration is reported by the server response.
  static int _estimateDurationMs(int byteLength) => (byteLength * 8) ~/ 64000;

  @override
  Future<void> playChime() => _player.play(AssetSource('audio/intercom_chime.wav'));

  @override
  Future<void> playFile(String path) => _player.play(DeviceFileSource(path));

  @override
  Future<void> stopPlayback() => _player.stop();

  @override
  Future<void> dispose() async {
    _recording = false;
    await _levelSubscription?.cancel();
    _levelTimer?.cancel();
    await _recorder.dispose();
    await _player.dispose();
    await _amplitude.close();
  }
}
