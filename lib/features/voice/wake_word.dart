// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../assistant_mode/armx_listening_service.dart';

/// What the wake-word layer reports upwards.
enum WakeWordSignalKind {
  /// The phrase was recognised **on device**.
  detected,

  /// The listening service changed phase (`running`, `paused`, `stopped`, …).
  serviceState,

  /// The engine or the service failed ([WakeWordSignal.errorCode]).
  error,
}

/// One privacy-safe wake-word signal. Never carries audio or a transcript.
@immutable
class WakeWordSignal {
  /// Creates a signal.
  const WakeWordSignal({required this.kind, this.state = '', this.errorCode});

  /// Signal kind.
  final WakeWordSignalKind kind;

  /// Service phase, for [WakeWordSignalKind.serviceState].
  final String state;

  /// Stable error code, for [WakeWordSignalKind.error].
  final String? errorCode;
}

/// The wake-word adapter contract (Dart side).
///
/// ## Adapter points
///
/// * **Android** — [NativeWakeWordAdapter] drives `ArmxListenService`; the detector itself
///   is `top.thamjj13.armx.voice.WakeWordEngine`, selected in that one factory. A real
///   detector (Porcupine, openWakeWord, an ONNX TFLite model, …) plugs in there and keeps
///   this Dart contract unchanged: only "detected" crosses the bridge, never audio.
/// * **Desktop** — the shipped wake path is the rebindable global hotkey
///   (`docs/desktop-mode.md`); [StubWakeWordAdapter] is the honest default, and the UI
///   says that always-on listening is not available.
/// * **Tests** — [StubWakeWordAdapter.simulateDetection] fires the same signal a real
///   detector would, so the pipeline is testable without hardware.
abstract interface class WakeWordAdapter {
  /// Stable identifier, reported in the voice screen's engine row.
  String get engineId;

  /// Whether this adapter is the no-audio stub.
  bool get isStub;

  /// Whether the host platform can run background listening at all.
  bool get isSupported;

  /// Stream of detections/state changes.
  Stream<WakeWordSignal> get signals;

  /// Arms detection for [phrase] (the phrase is passed to the detector for diagnostics and
  /// for adapters that support custom phrases; the shipped Android stub ignores it).
  Future<WakeWordSignal> start({
    required String phrase,
    required double sensitivity,
    required String localeCode,
  });

  /// Suspends detection while keeping the service notification.
  Future<void> pause();

  /// Stops detection and removes the notification.
  Future<void> stop();

  /// Releases everything.
  Future<void> close();

  /// Fires a detection without audio. Only the stub implements this meaningfully; a real
  /// detector must not expose such a hook.
  void simulateDetection();
}

/// Android adapter over the foreground listening service.
///
/// Starting this service is what makes background listening **visible**: Android requires
/// the ongoing notification, and the notification actions are the user's pause/stop/kill
/// controls. No audio is captured while the native engine is the stub.
class NativeWakeWordAdapter implements WakeWordAdapter {
  /// Creates the adapter over the existing bridge.
  NativeWakeWordAdapter({ArmxListeningService? service, this.stubEngine = true})
      : _service = service ?? ArmxListeningService();

  final ArmxListeningService _service;
  final StreamController<WakeWordSignal> _controller =
      StreamController<WakeWordSignal>.broadcast();
  StreamSubscription<ArmxListenEvent>? _subscription;

  /// Whether the native engine is known to be the no-audio stub.
  bool stubEngine;

  @override
  String get engineId => 'android_foreground_service';

  @override
  bool get isStub => stubEngine;

  @override
  bool get isSupported => _service.isSupported;

  @override
  Stream<WakeWordSignal> get signals => _controller.stream;

  void _attach() {
    _subscription ??= _service.events.listen((event) {
      switch (event.type) {
        case ArmxListenEventType.wakeWordDetected:
          _controller.add(const WakeWordSignal(kind: WakeWordSignalKind.detected));
        case ArmxListenEventType.status:
          _controller.add(
            WakeWordSignal(
              kind: WakeWordSignalKind.serviceState,
              state: event.status?.phase.name ?? 'unknown',
            ),
          );
        case ArmxListenEventType.error:
          _controller.add(
            WakeWordSignal(
              kind: WakeWordSignalKind.error,
              errorCode: event.errorCode ?? 'wake_word_engine_error',
            ),
          );
        case ArmxListenEventType.unknown:
          break;
      }
    });
  }

  @override
  Future<WakeWordSignal> start({
    required String phrase,
    required double sensitivity,
    required String localeCode,
  }) async {
    _attach();
    final status = await _service.start(languageCode: localeCode);
    stubEngine = !status.wakeWordEngineReady;
    if (status.phase == ArmxListenPhase.error) {
      return WakeWordSignal(
        kind: WakeWordSignalKind.error,
        errorCode: status.errorCode ?? 'wake_word_engine_error',
      );
    }
    return WakeWordSignal(
      kind: WakeWordSignalKind.serviceState,
      state: status.phase.name,
    );
  }

  @override
  Future<void> pause() => _service.pause();

  @override
  Future<void> stop() => _service.stop();

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
  }

  @override
  void simulateDetection() {
    // The native host owns detection; the Dart side never fabricates a wake event on a
    // platform that has a real engine. Kept as a no-op for interface symmetry.
  }
}

/// The honest default on every platform without a background listener.
///
/// `isSupported` is false, so the UI shows "background listening is unavailable here" and
/// points at the desktop hotkey instead of pretending to listen.
class StubWakeWordAdapter implements WakeWordAdapter {
  /// Creates the stub. [supported] exists for tests that exercise the Android branch.
  StubWakeWordAdapter({bool supported = false}) : _supported = supported;

  final bool _supported;
  final StreamController<WakeWordSignal> _controller =
      StreamController<WakeWordSignal>.broadcast();

  @override
  String get engineId => 'stub';

  @override
  bool get isStub => true;

  @override
  bool get isSupported => _supported;

  @override
  Stream<WakeWordSignal> get signals => _controller.stream;

  @override
  Future<WakeWordSignal> start({
    required String phrase,
    required double sensitivity,
    required String localeCode,
  }) async {
    if (!_supported) {
      return const WakeWordSignal(
        kind: WakeWordSignalKind.error,
        errorCode: 'background_listening_unsupported',
      );
    }
    return const WakeWordSignal(kind: WakeWordSignalKind.serviceState, state: 'running');
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> close() => _controller.close();

  /// Fires a detection as if the on-device detector had matched the phrase.
  @override
  void simulateDetection() {
    if (!_controller.isClosed) {
      _controller.add(const WakeWordSignal(kind: WakeWordSignalKind.detected));
    }
  }
}
