// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/security/security_constants.dart';

part 'preferences.freezed.dart';

/// Storage keys for the preferences table. Namespaced so a future export/import is easy.
abstract final class PreferenceKeys {
  /// `system` | `light` | `dark`.
  static const String themeMode = 'armx.theme.mode';

  /// `system` | `en` | `bn`.
  static const String language = 'armx.locale.language';

  /// Whether wake-word listening is enabled.
  static const String wakeWordEnabled = 'armx.voice.wake_word_enabled';

  /// Phrase that wakes the assistant (default `Armex`).
  static const String wakeWordPhrase = 'armx.voice.wake_word_phrase';

  /// Wake-word sensitivity 0.0–1.0.
  static const String wakeWordSensitivity = 'armx.voice.sensitivity';

  /// Face match cosine threshold.
  static const String faceMatchThreshold = 'armx.vision.face_threshold';

  /// Whether the palm-open gesture is enabled.
  static const String palmGestureEnabled = 'armx.vision.palm_gesture';

  /// Whether the camera is allowed to start at all (one-tap privacy switch).
  static const String cameraEnabled = 'armx.vision.camera_enabled';

  /// Whether the microphone may be used.
  static const String microphoneEnabled = 'armx.vision.microphone_enabled';

  /// Whether TTS auto-speaks assistant replies.
  static const String ttsAutoSpeak = 'armx.voice.tts_auto_speak';

  /// Whether haptic feedback is used for approvals.
  static const String hapticsEnabled = 'armx.ui.haptics';

  /// Whether the app requires a biometric/PIN unlock on launch.
  static const String appLockEnabled = 'armx.security.app_lock';

  /// Background seconds before the app lock re-arms: `0` | `30` | `60` | `300`.
  static const String autoLockTimeout = 'armx.security.auto_lock_timeout';

  /// Whether background activity recognition may run.
  static const String activityRecognitionEnabled = 'armx.activity.enabled';

  /// Last authorised server URL (only used to prefill the pairing form).
  static const String lastServerUrl = 'armx.network.last_server_url';

  /// Pairing state machine marker: `unpaired` | `pending` | `approved` | `rejected`.
  static const String pairingStatus = 'armx.pairing.status';

  /// Human-readable name given to this device during pairing (non-secret).
  static const String pairingDeviceName = 'armx.pairing.device_name';

  /// ISO-8601 timestamp of a completed pairing (non-secret).
  static const String pairingPairedAt = 'armx.pairing.paired_at';

  /// Whether sign-in tokens survive an app restart ("Remember this device").
  static const String rememberDevice = 'armx.auth.remember_device';

  /// JSON of the signed-in user profile (non-secret session metadata).
  static const String sessionUser = 'armx.auth.session_user';

  /// Keys that hold no personal information and may be exported.
  static const List<String> exportable = <String>[
    themeMode,
    language,
    wakeWordEnabled,
    wakeWordPhrase,
    wakeWordSensitivity,
    faceMatchThreshold,
    palmGestureEnabled,
    ttsAutoSpeak,
    hapticsEnabled,
    activityRecognitionEnabled,
  ];
}

/// Typed view over the preference rows.
@freezed
abstract class AppPreferences with _$AppPreferences {
  /// Creates a preference snapshot. Every field has a fail-safe default.
  const factory AppPreferences({
    @Default('system') String themeMode,
    @Default('system') String language,
    @Default(false) bool wakeWordEnabled,
    @Default('Armex') String wakeWordPhrase,
    @Default(0.6) double wakeWordSensitivity,
    @Default(SecurityConstants.defaultFaceThreshold) double faceMatchThreshold,
    @Default(true) bool palmGestureEnabled,
    @Default(false) bool cameraEnabled,
    @Default(false) bool microphoneEnabled,
    @Default(true) bool ttsAutoSpeak,
    @Default(true) bool hapticsEnabled,
    @Default(true) bool appLockEnabled,
    @Default(SecurityConstants.defaultAutoLockSeconds) int autoLockTimeoutSeconds,
    @Default(false) bool activityRecognitionEnabled,
    @Default('') String lastServerUrl,
    @Default('unpaired') String pairingStatus,
    @Default('') String pairingDeviceName,
    @Default('') String pairingPairedAt,
    @Default(true) bool rememberDevice,
    @Default('') String sessionUserJson,
  }) = _AppPreferences;

  const AppPreferences._();

  /// Whether a face-match threshold is inside the supported band.
  bool get hasValidThreshold =>
      faceMatchThreshold >= SecurityConstants.minFaceThreshold &&
      faceMatchThreshold <= SecurityConstants.maxFaceThreshold;
}
