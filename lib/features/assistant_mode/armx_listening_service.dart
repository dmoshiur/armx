// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// States reported by the Android foreground listening-service shell.
enum ArmxListenPhase {
  /// The service is not running.
  stopped,

  /// A user-started foreground-service request is being handed to Android.
  starting,

  /// The foreground service is active. This does not imply audio capture is active.
  running,

  /// The foreground service is paused.
  paused,

  /// The user has engaged the kill-switch.
  killed,

  /// Android rejected the request or the native service failed.
  error,

  /// Background listening is not implemented for this platform yet.
  unsupported,
}

/// A privacy-safe status snapshot. It intentionally carries no transcript or audio data.
@immutable
class ArmxListenStatus {
  /// Creates a status snapshot.
  const ArmxListenStatus({
    required this.phase,
    this.serviceRunning = false,
    this.wakeWordEngineReady = false,
    this.microphonePermissionGranted = false,
    this.notificationPermissionGranted = false,
    this.errorCode,
  });

  /// Current state of the native service.
  final ArmxListenPhase phase;

  /// Whether Android reports the service as active.
  final bool serviceRunning;

  /// Whether a real on-device wake-word engine is attached.
  final bool wakeWordEngineReady;

  /// Whether the OS currently grants microphone access.
  final bool microphonePermissionGranted;

  /// Whether Android notifications are allowed for this app.
  final bool notificationPermissionGranted;

  /// Stable, non-sensitive error code. Native exception text is never surfaced here.
  final String? errorCode;

  /// Whether the service currently owns a foreground-service lifecycle.
  bool get isForegroundServiceActive =>
      serviceRunning || phase == ArmxListenPhase.starting || phase == ArmxListenPhase.paused;

  /// Creates a status from the StandardMessageCodec map returned by Android.
  factory ArmxListenStatus.fromMap(Map<Object?, Object?> map) {
    final phase = switch (map['phase']) {
      'starting' => ArmxListenPhase.starting,
      'running' => ArmxListenPhase.running,
      'paused' => ArmxListenPhase.paused,
      'killed' => ArmxListenPhase.killed,
      'error' => ArmxListenPhase.error,
      _ => ArmxListenPhase.stopped,
    };

    return ArmxListenStatus(
      phase: phase,
      serviceRunning: map['serviceRunning'] == true,
      wakeWordEngineReady: map['wakeWordEngineReady'] == true,
      microphonePermissionGranted: map['microphonePermissionGranted'] == true,
      notificationPermissionGranted: map['notificationPermissionGranted'] == true,
      errorCode: map['errorCode'] as String?,
    );
  }

  /// A safe response on platforms that do not host the Android service.
  static const ArmxListenStatus unsupported = ArmxListenStatus(
    phase: ArmxListenPhase.unsupported,
  );

  /// A safe error state when the platform bridge is missing or rejects a call.
  factory ArmxListenStatus.error(String code) => ArmxListenStatus(
        phase: ArmxListenPhase.error,
        errorCode: code,
      );
}

/// Event kinds reserved by the bridge. Wake-word events are emitted once the detector is
/// implemented; this service-skeleton delivery currently emits status and error events only.
enum ArmxListenEventType { status, wakeWordDetected, error, unknown }

/// A privacy-safe event from the native Android service.
@immutable
class ArmxListenEvent {
  /// Creates a bridge event.
  const ArmxListenEvent({
    required this.type,
    this.status,
    this.errorCode,
  });

  /// Event discriminator.
  final ArmxListenEventType type;

  /// Status snapshot, for [ArmxListenEventType.status].
  final ArmxListenStatus? status;

  /// Stable error code, for [ArmxListenEventType.error].
  final String? errorCode;

  /// Decodes a native event without accepting arbitrary transcript/tool content.
  factory ArmxListenEvent.fromObject(Object? value) {
    if (value is! Map<Object?, Object?>) {
      return const ArmxListenEvent(type: ArmxListenEventType.unknown);
    }

    final type = switch (value['type']) {
      'status' => ArmxListenEventType.status,
      'wakeWordDetected' => ArmxListenEventType.wakeWordDetected,
      'error' => ArmxListenEventType.error,
      _ => ArmxListenEventType.unknown,
    };
    final rawStatus = value['status'];
    final rawCode = value['code'];

    return ArmxListenEvent(
      type: type,
      status: rawStatus is Map<Object?, Object?>
          ? ArmxListenStatus.fromMap(rawStatus)
          : null,
      errorCode: rawCode is String ? rawCode : null,
    );
  }
}

/// MethodChannel/EventChannel bridge for the Android foreground service.
///
/// The methods are intentionally user-driven. Android 14+ can reject a microphone
/// foreground service started while the app is in the background. This class never starts
/// a service on its own, on app launch, or after reboot.
class ArmxListeningService {
  /// Creates a bridge, optionally with test channels and platform overrides.
  ArmxListeningService({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
    TargetPlatform? platform,
    bool isWeb = kIsWeb,
  })  : _methodChannel = methodChannel ?? const MethodChannel(_methodChannelName),
        _eventChannel = eventChannel ?? const EventChannel(_eventChannelName),
        _platform = platform ?? defaultTargetPlatform,
        _isWeb = isWeb;

  static const String _methodChannelName = 'top.thamjj13.armx/assistant_listening';
  static const String _eventChannelName = 'top.thamjj13.armx/assistant_listening_events';

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  final TargetPlatform _platform;
  final bool _isWeb;

  /// Whether this build has the native Android host for the service.
  bool get isSupported => !_isWeb && _platform == TargetPlatform.android;

  /// Streams status/error events. Transcript/audio payloads are never accepted by this API.
  Stream<ArmxListenEvent> get events {
    if (!isSupported) {
      return const Stream<ArmxListenEvent>.empty();
    }
    return _eventChannel
        .receiveBroadcastStream()
        .map<ArmxListenEvent>(ArmxListenEvent.fromObject);
  }

  /// Reads the service's persisted native state.
  Future<ArmxListenStatus> status() async {
    if (!isSupported) {
      return ArmxListenStatus.unsupported;
    }
    try {
      final map = await _methodChannel.invokeMapMethod<Object?, Object?>('status');
      return map == null ? ArmxListenStatus.error('empty_status') : ArmxListenStatus.fromMap(map);
    } on MissingPluginException {
      return ArmxListenStatus.error('native_bridge_missing');
    } on PlatformException catch (error) {
      return ArmxListenStatus.error(error.code);
    }
  }

  /// Requests OS permissions while the Flutter UI is visible, then asks Android to start
  /// the foreground service. No audio is captured by this step's service skeleton.
  Future<ArmxListenStatus> start({String? languageCode}) async {
    if (!isSupported) {
      return ArmxListenStatus.unsupported;
    }

    final microphone = await Permission.microphone.request();
    if (!microphone.isGranted) {
      return ArmxListenStatus.error('microphone_permission_denied');
    }

    final notifications = await Permission.notification.request();
    if (!notifications.isGranted) {
      return ArmxListenStatus.error('notification_permission_denied');
    }

    return _invoke(
      'start',
      arguments: <String, Object?>{
        if (languageCode == 'en' || languageCode == 'bn') 'languageCode': languageCode,
      },
    );
  }

  /// Pauses the service while retaining its ongoing notification.
  Future<ArmxListenStatus> pause() => _invoke('pause');

  /// Resumes a paused service. Android still requires the call to originate from a
  /// user-visible app interaction or an allowed notification action.
  Future<ArmxListenStatus> resume() => _invoke('resume');

  /// Stops the foreground service without engaging the kill-switch.
  Future<ArmxListenStatus> stop() => _invoke('stop');

  /// Permanently marks the service killed until the user explicitly starts it again.
  Future<ArmxListenStatus> killSwitch() => _invoke('killSwitch');

  Future<ArmxListenStatus> _invoke(String method, {Object? arguments}) async {
    if (!isSupported) {
      return ArmxListenStatus.unsupported;
    }
    try {
      final map = await _methodChannel.invokeMapMethod<Object?, Object?>(
        method,
        arguments: arguments,
      );
      return map == null ? ArmxListenStatus.error('empty_status') : ArmxListenStatus.fromMap(map);
    } on MissingPluginException {
      return ArmxListenStatus.error('native_bridge_missing');
    } on PlatformException catch (error) {
      return ArmxListenStatus.error(error.code);
    }
  }
}
