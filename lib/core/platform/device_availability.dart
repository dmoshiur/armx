// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// Whether a hardware class is usable right now.
enum DeviceAvailability {
  /// Not probed yet.
  unknown,

  /// At least one device is present and permitted.
  available,

  /// No device of this class exists (or all are unplugged).
  missing,

  /// Devices exist but the OS permission is refused/denied.
  permissionDenied,

  /// This platform has no way to enumerate the class (see docs/desktop-mode.md).
  unsupported,
}

/// Snapshot of what the assistant can hear and see.
@immutable
class DeviceStatus {
  /// Creates a status snapshot.
  const DeviceStatus({
    this.microphone = DeviceAvailability.unknown,
    this.camera = DeviceAvailability.unknown,
    this.inputDevices = const <String>[],
    this.videoDevices = const <String>[],
    required this.checkedAt,
  });

  /// Fresh, empty snapshot (used before the first probe completes).
  factory DeviceStatus.empty(DateTime checkedAt) => DeviceStatus(checkedAt: checkedAt);

  /// Microphone availability.
  final DeviceAvailability microphone;

  /// Camera availability.
  final DeviceAvailability camera;

  /// Labels of the audio inputs (empty when unknown/unsupported).
  final List<String> inputDevices;

  /// Labels of the video inputs (empty when unknown/unsupported).
  final List<String> videoDevices;

  /// When this snapshot was taken (UTC).
  final DateTime checkedAt;

  /// True when wake-word listening can run at all.
  bool get microphoneUsable => microphone == DeviceAvailability.available;

  /// True when face verification can run at all.
  bool get cameraUsable => camera == DeviceAvailability.available;

  /// True when neither mic nor camera is usable — the "voice unavailable" tooltip state.
  bool get isDegraded => !microphoneUsable && !cameraUsable;

  /// True when the tray tooltip must carry the "Voice unavailable — use hotkey" hint.
  bool get voiceUnavailable => !microphoneUsable;

  /// True when face verification must fall back to a typed passphrase.
  bool get faceUnavailable => !cameraUsable;

  DeviceStatus copyWith({
    DeviceAvailability? microphone,
    DeviceAvailability? camera,
    List<String>? inputDevices,
    List<String>? videoDevices,
    DateTime? checkedAt,
  }) =>
      DeviceStatus(
        microphone: microphone ?? this.microphone,
        camera: camera ?? this.camera,
        inputDevices: inputDevices ?? this.inputDevices,
        videoDevices: videoDevices ?? this.videoDevices,
        checkedAt: checkedAt ?? this.checkedAt,
      );
}

/// Enumerates audio/video hardware and reports changes.
///
/// Re-probing happens on a timer and on app resume rather than through native device
/// callbacks: a per-OS listener (WASAPI `IMMNotificationClient`, AVFoundation
/// `AVCaptureDeviceWasConnected`, PulseAudio subscription) needs a platform channel, which
/// is listed as a follow-up in `docs/desktop-mode.md`. The timer keeps the tray tooltip
/// honest when a USB headset is plugged in or yanked out.
abstract interface class DeviceAvailabilityService {
  /// Current snapshot; probes on first call.
  Future<DeviceStatus> probe();

  /// Emits whenever the snapshot changes.
  Stream<DeviceStatus> get changes;

  /// Stops polling.
  Future<void> dispose();
}

/// Probe built on `package:record` (audio inputs) and `package:camera` (video inputs).
///
/// Documented platform gaps:
/// * `record` has no permission API on Windows or Linux (its own parity table), so a
///   refused microphone shows up as "missing" there — the app still degrades correctly,
///   the tooltip just cannot distinguish "unplugged" from "denied".
/// * `camera` has no Linux implementation and `availableCameras()` throws there, which this
///   class maps to [DeviceAvailability.unsupported]: face verification is unavailable on
///   Linux and MEDIUM/HIGH actions fall back to the system biometric plus a typed
///   passphrase instead of being silently downgraded.
class RecordDeviceAvailabilityService implements DeviceAvailabilityService {
  /// Creates the service. [interval] is the re-probe cadence.
  RecordDeviceAvailabilityService({this.interval = const Duration(seconds: 5)});

  /// Re-probe cadence.
  final Duration interval;

  final AudioRecorder _recorder = AudioRecorder();
  final StreamController<DeviceStatus> _changes = StreamController<DeviceStatus>.broadcast();
  DeviceStatus? _last;
  Timer? _timer;
  bool _disposed = false;

  @override
  Stream<DeviceStatus> get changes => _changes.stream;

  @override
  Future<DeviceStatus> probe() async {
    final now = DateTime.now().toUtc();
    var status = _last ?? DeviceStatus.empty(now);

    var microphone = DeviceAvailability.unsupported;
    var inputs = const <String>[];
    try {
      if (await _recorder.hasPermission()) {
        inputs = await _listInputs();
        microphone = inputs.isEmpty ? DeviceAvailability.missing : DeviceAvailability.available;
      } else {
        microphone = DeviceAvailability.permissionDenied;
      }
    } on Object {
      // Unsupported platform (no permission API) or a broken audio stack.
      microphone = DeviceAvailability.unsupported;
    }

    var camera = DeviceAvailability.unsupported;
    var videos = const <String>[];
    try {
      final cameras = await availableCameras();
      videos = <String>[for (final c in cameras) c.name];
      camera = cameras.isEmpty ? DeviceAvailability.missing : DeviceAvailability.available;
    } on Object {
      camera = DeviceAvailability.unsupported;
    }

    status = status.copyWith(
      microphone: microphone,
      camera: camera,
      inputDevices: inputs,
      videoDevices: videos,
      checkedAt: now,
    );
    _emitIfChanged(status);
    _startPolling();
    return status;
  }

  Future<List<String>> _listInputs() async {
    try {
      final devices = await _recorder.listInputDevices();
      return <String>[for (final device in devices) device.label];
    } on Object {
      // Older record builds without device enumeration.
      return const <String>['default'];
    }
  }

  void _startPolling() {
    if (_timer != null || _disposed) {
      return;
    }
    _timer = Timer.periodic(interval, (_) {
      if (!_disposed) {
        unawaited(probe());
      }
    });
  }

  void _emitIfChanged(DeviceStatus next) {
    final previous = _last;
    if (previous == null ||
        previous.microphone != next.microphone ||
        previous.camera != next.camera ||
        !listEquals(previous.inputDevices, next.inputDevices) ||
        !listEquals(previous.videoDevices, next.videoDevices)) {
      _last = next;
      if (!_changes.isClosed) {
        _changes.add(next);
      }
      return;
    }
    _last = next;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    await _recorder.dispose();
    await _changes.close();
  }
}

/// No-op service used on mobile, in tests and when the platform is unsupported.
class NoopDeviceAvailabilityService implements DeviceAvailabilityService {
  /// Creates the no-op service reporting everything [unsupported].
  const NoopDeviceAvailabilityService();

  @override
  Future<DeviceStatus> probe() async => DeviceStatus.empty(DateTime.now().toUtc());

  @override
  Stream<DeviceStatus> get changes => const Stream<DeviceStatus>.empty();

  @override
  Future<void> dispose() async {}
}

/// Convenience helper used by the UI: a short, language-neutral label for a probe result.
String deviceAvailabilityLabel(DeviceAvailability availability) => switch (availability) {
      DeviceAvailability.unknown => 'unknown',
      DeviceAvailability.available => 'available',
      DeviceAvailability.missing => 'missing',
      DeviceAvailability.permissionDenied => 'permission denied',
      DeviceAvailability.unsupported => 'unsupported',
    };
