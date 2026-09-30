// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

/// Single source of truth for the security-relevant numbers in the product spec.
///
/// Keeping them here (instead of scattering `Duration(seconds: 60)` through the codebase)
/// means the risk policy, the UI countdowns and the token signer can never disagree.
abstract final class SecurityConstants {
  /// How long a successful face/voice/biometric verification stays valid.
  static const Duration verificationTrustWindow = Duration(seconds: 60);

  /// Maximum lifetime of an unlock token handed to the backend (`exp <= 30 s`).
  static const Duration unlockTokenTtl = Duration(seconds: 30);

  /// How long the "owner_verified" assertion sent to the backend stays valid.
  static const Duration ownerVerifiedTtl = Duration(seconds: 60);

  /// Wall-clock allowance for clock skew when validating a token's `exp`.
  static const Duration clockSkewAllowance = Duration(seconds: 5);

  /// Number of frames captured per enrolment angle (face enrolment uses 5 angles).
  static const int faceEnrolmentAngles = 5;

  /// Cosine-similarity threshold floor/ceiling exposed in Settings.
  static const double minFaceThreshold = 0.10;
  static const double maxFaceThreshold = 0.99;

  /// Default cosine-similarity threshold for a positive face match.
  static const double defaultFaceThreshold = 0.72;

  /// Minimum spoken-sample duration before a voice factor can pass.
  static const Duration minVoiceSampleDuration = Duration(milliseconds: 1200);

  /// How long the kill-switch long-press must be held.
  static const Duration killSwitchHoldDuration = Duration(seconds: 1);

  /// Minimum password length accepted by the login form.
  static const int minPasswordLength = 8;

  /// Background seconds offered for the auto-lock timeout (`0` = immediately).
  static const List<int> autoLockTimeoutOptions = <int>[0, 30, 60, 300];

  /// Default auto-lock timeout after the app is backgrounded (seconds).
  static const int defaultAutoLockSeconds = 30;

  /// How long before `expires_at` the client proactively refreshes the access token.
  static const Duration tokenRefreshLeeway = Duration(seconds: 60);
}
