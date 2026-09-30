// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/foundation.dart';

/// A capability the product would like to use, but which is not available everywhere.
enum PlatformFeature {
  /// Speech-to-text capture (push-to-talk and wake-word mode).
  speechToText,

  /// Text-to-speech playback of assistant replies.
  textToSpeech,

  /// Camera preview/stream used by the vision module.
  camera,

  /// On-device face detection/landmarks (Google ML Kit).
  faceDetection,

  /// Pose-based palm gesture (Google ML Kit Pose).
  palmGesture,

  /// TensorFlow Lite inference for face embeddings.
  faceEmbedding,

  /// Platform biometric / device-credential prompt.
  systemBiometric,

  /// Background activity recognition (still, walking, driving, …).
  activityRecognition,

  /// Location fixes for geofences.
  geolocation,

  /// Hardware-backed key/value storage.
  secureStorage,

  /// Ability to block screenshots/screen recording for sensitive screens.
  screenshotGuard,
}

/// Answers "can this build use feature X on this platform, and if not, why?".
///
/// A.R.M.X targets Android (primary) plus Windows and Linux desktop. Several of the
/// plugins are mobile-only (ML Kit, activity recognition) or desktop-limited
/// (speech-to-text has no Linux implementation), so every screen asks this class first
/// and renders an explicit "unsupported here" state instead of crashing.
abstract final class PlatformCapabilities {
  /// Whether [feature] works on [platform] (defaults to the current platform).
  static bool supports(PlatformFeature feature, {TargetPlatform? platform}) {
    final target = platform ?? defaultTargetPlatform;
    if (kIsWeb) {
      return _webSupport.contains(feature);
    }
    return switch (feature) {
      PlatformFeature.speechToText =>
        target == TargetPlatform.android ||
            target == TargetPlatform.iOS ||
            target == TargetPlatform.macOS ||
            target == TargetPlatform.windows,
      PlatformFeature.textToSpeech =>
        target == TargetPlatform.android ||
            target == TargetPlatform.iOS ||
            target == TargetPlatform.macOS ||
            target == TargetPlatform.windows,
      PlatformFeature.camera => _cameraSupport.contains(target),
      // Google ML Kit ships Android/iOS native binaries only.
      PlatformFeature.faceDetection => _mobileOnly.contains(target),
      PlatformFeature.palmGesture => _mobileOnly.contains(target),
      PlatformFeature.faceEmbedding => _tfliteSupport.contains(target),
      PlatformFeature.systemBiometric =>
        target == TargetPlatform.android ||
            target == TargetPlatform.iOS ||
            target == TargetPlatform.macOS ||
            target == TargetPlatform.windows,
      PlatformFeature.activityRecognition => _mobileOnly.contains(target),
      PlatformFeature.geolocation => _geolocationSupport.contains(target),
      PlatformFeature.secureStorage => true,
      PlatformFeature.screenshotGuard => target == TargetPlatform.android,
    };
  }

  /// Human-readable reason [feature] is unavailable, or `null` when it is available.
  ///
  /// The string is diagnostic (English) and is shown in the "unsupported" card together
  /// with a localized headline.
  static String? unsupportedReason(PlatformFeature feature, {TargetPlatform? platform}) {
    final target = platform ?? defaultTargetPlatform;
    if (supports(feature, platform: target)) {
      return null;
    }
    return switch (feature) {
      PlatformFeature.faceDetection || PlatformFeature.palmGesture =>
        'Google ML Kit runs on Android and iOS only — desktop builds cannot detect faces '
            'or palm gestures on-device.',
      PlatformFeature.activityRecognition =>
        'Activity recognition is provided by Android/iOS system APIs.',
      PlatformFeature.speechToText =>
        'No offline speech-to-text engine is available on ${_name(target)}; '
            'use push-to-talk on Android or type your message.',
      PlatformFeature.textToSpeech =>
        'No system TTS engine is available on ${_name(target)}.',
      PlatformFeature.camera =>
        'The camera plugin has no ${_name(target)} implementation in this dependency set.',
      PlatformFeature.faceEmbedding =>
        'TensorFlow Lite desktop support requires the platform native library to be bundled.',
      PlatformFeature.systemBiometric =>
        'No biometric/device-credential provider on ${_name(target)}.',
      PlatformFeature.geolocation =>
        'Location services are unavailable on ${_name(target)}.',
      PlatformFeature.screenshotGuard =>
        'Screenshot blocking is implemented with the Android FLAG_SECURE flag only.',
      PlatformFeature.secureStorage => 'Secure storage backend unavailable.',
    };
  }

  /// Whether the current platform is a desktop target of this product.
  static bool get isDesktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// Whether the current platform is a mobile target of this product.
  static bool get isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  static const Set<TargetPlatform> _mobileOnly = <TargetPlatform>{
    TargetPlatform.android,
    TargetPlatform.iOS,
  };

  static const Set<TargetPlatform> _cameraSupport = <TargetPlatform>{
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  };

  static const Set<TargetPlatform> _tfliteSupport = <TargetPlatform>{
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  };

  static const Set<TargetPlatform> _geolocationSupport = <TargetPlatform>{
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  };

  static const Set<PlatformFeature> _webSupport = <PlatformFeature>{
    PlatformFeature.speechToText,
    PlatformFeature.textToSpeech,
    PlatformFeature.geolocation,
    PlatformFeature.secureStorage,
  };

  static String _name(TargetPlatform platform) => switch (platform) {
        TargetPlatform.android => 'Android',
        TargetPlatform.iOS => 'iOS',
        TargetPlatform.macOS => 'macOS',
        TargetPlatform.windows => 'Windows',
        TargetPlatform.linux => 'Linux',
        TargetPlatform.fuchsia => 'Fuchsia',
      };
}
