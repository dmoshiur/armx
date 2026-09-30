// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

/// Base type for every error A.R.M.X surfaces to the user.
///
/// The type hierarchy is *sealed* so that UI code can switch exhaustively and the
/// analyzer proves that no error case was forgotten.
sealed class AppException implements Exception {
  /// Const constructor for subclasses.
  const AppException(
    this.message, {
    this.cause,
    this.stackTrace,
    this.isRetryable = false,
  });

  /// Developer-facing English description. Never rendered directly: use
  /// `core/errors/error_messages.dart` to obtain a localized string.
  final String message;

  /// Underlying error, if any.
  final Object? cause;

  /// Stack trace captured at the throw site, if any.
  final StackTrace? stackTrace;

  /// Whether retrying the same operation may plausibly succeed.
  final bool isRetryable;

  /// Stable machine-readable code, safe to log and to show in diagnostics.
  String get code;

  @override
  String toString() => '$runtimeType($code): $message';
}

/// Misconfiguration detected at startup (bad `--dart-define`, unreachable pin set, …).
final class ConfigException extends AppException {
  /// Creates a configuration error.
  const ConfigException(super.message, {super.cause, super.stackTrace})
      : super(isRetryable: false);

  @override
  String get code => 'config';
}

/// Transport failure: DNS, TLS, socket, or a refused connection.
final class NetworkException extends AppException {
  /// Creates a transport error.
  const NetworkException(super.message, {super.cause, super.stackTrace})
      : super(isRetryable: true);

  @override
  String get code => 'network';
}

/// The request was accepted but did not complete in the allotted time.
final class RequestTimeoutException extends AppException {
  /// Creates a timeout error.
  const RequestTimeoutException(super.message, {super.cause, super.stackTrace})
      : super(isRetryable: true);

  @override
  String get code => 'timeout';
}

/// The server answered with a non-success status or an unparsable payload.
final class ApiException extends AppException {
  /// Creates an API error.
  const ApiException(
    super.message, {
    this.statusCode,
    this.serverCode,
    super.cause,
    super.stackTrace,
    super.isRetryable,
  });

  /// HTTP status code when one was received.
  final int? statusCode;

  /// Machine-readable error code returned by the backend, when present.
  final String? serverCode;

  @override
  String get code => serverCode ?? 'api_${statusCode ?? 'unknown'}';
}

/// Authentication, pairing and session failures.
final class AuthException extends AppException {
  /// Creates an authentication error.
  const AuthException(this.reason, {super.message, super.cause, super.stackTrace})
      : super(message ?? 'Authentication failed');

  /// What specifically went wrong.
  final AuthFailureReason reason;

  @override
  String get code => 'auth_${reason.name}';

  @override
  String get message => switch (reason) {
        AuthFailureReason.invalidCredentials => 'Invalid credentials',
        AuthFailureReason.accountLocked => 'Account locked',
        AuthFailureReason.sessionExpired => 'Session expired',
        AuthFailureReason.refreshRejected => 'Session refresh rejected',
        AuthFailureReason.pairingRejected => 'Pairing rejected by the server',
        AuthFailureReason.deviceRevoked => 'This device was revoked',
        AuthFailureReason.appLockFailed => 'App lock could not be satisfied',
        AuthFailureReason.biometricUnavailable => 'Biometrics unavailable',
        AuthFailureReason.serverUrlRejected => 'Server URL rejected',
      };
}

/// Why an authentication attempt failed.
enum AuthFailureReason {
  /// Wrong username/password or device key.
  invalidCredentials,

  /// The account is temporarily locked (too many attempts or an admin action).
  accountLocked,

  /// The access token expired and no refresh is available.
  sessionExpired,

  /// The refresh token was rejected; a new login is required.
  refreshRejected,

  /// The pairing handshake (device key) was refused.
  pairingRejected,

  /// The device is no longer trusted (revoked by an administrator).
  deviceRevoked,

  /// `local_auth` reported a failed biometric/PIN prompt.
  appLockFailed,

  /// No biometric hardware/enrolment on this platform.
  biometricUnavailable,

  /// The user-supplied server URL is not acceptable (scheme/host).
  serverUrlRejected,
}

/// The risk policy refused an action because verification was insufficient or stale.
final class PolicyException extends AppException {
  /// Creates a policy error.
  const PolicyException({
    required this.requiredTier,
    required this.satisfiedTier,
    required this.reason,
  }) : super('Verification does not satisfy the required risk tier');

  /// Tier demanded by the action.
  final String requiredTier;

  /// Tier actually satisfied by the presented evidence.
  final String satisfiedTier;

  /// Why the evidence was rejected.
  final String reason;

  @override
  String get code => 'policy_insufficient_verification';
}

/// A verification prompt (face / voice / biometric) failed or was cancelled.
final class VerificationException extends AppException {
  /// Creates a verification error.
  const VerificationException(this.reason, {super.message, super.cause, super.stackTrace})
      : super(message ?? 'Verification failed');

  /// What failed.
  final VerificationFailureReason reason;

  @override
  String get code => 'verification_${reason.name}';

  @override
  String get message => switch (reason) {
        VerificationFailureReason.noFaceDetected => 'No face detected',
        VerificationFailureReason.multipleFaces => 'More than one face detected',
        VerificationFailureReason.lowMatchScore => 'Face did not match the enrolled template',
        VerificationFailureReason.livenessFailed => 'Liveness challenge not completed',
        VerificationFailureReason.noTemplateEnrolled => 'No face template enrolled yet',
        VerificationFailureReason.voiceNotHeard => 'Voice sample not recognised',
        VerificationFailureReason.voiceTooShort => 'Voice sample too short',
        VerificationFailureReason.userCancelled => 'Verification cancelled',
        VerificationFailureReason.hardwareUnavailable => 'Camera or microphone unavailable',
      };
}

/// Why a verification attempt failed.
enum VerificationFailureReason {
  /// No face in frame.
  noFaceDetected,

  /// More than one face in frame (spoofing attempt or a bystander).
  multipleFaces,

  /// Cosine similarity below the configured threshold.
  lowMatchScore,

  /// The user did not complete the blink / head-turn challenge.
  livenessFailed,

  /// Nothing enrolled to match against.
  noTemplateEnrolled,

  /// Wake/speech recognition did not match the enrolled voice profile.
  voiceNotHeard,

  /// Sample shorter than the minimum duration.
  voiceTooShort,

  /// The user dismissed the prompt.
  userCancelled,

  /// No camera/microphone or permission denied.
  hardwareUnavailable,
}

/// Secure storage / local database failure.
final class StorageException extends AppException {
  /// Creates a storage error.
  const StorageException(super.message, {super.cause, super.stackTrace})
      : super(isRetryable: true);

  @override
  String get code => 'storage';
}

/// A permission (camera, microphone, activity, location, notifications) was denied.
final class PermissionDeniedException extends AppException {
  /// Creates a permission error.
  const PermissionDeniedException(this.permission, {this.permanentlyDenied = false})
      : super('Permission denied');

  /// Platform permission name, for example `camera`.
  final String permission;

  /// True when the OS will no longer show the rationale dialog.
  final bool permanentlyDenied;

  @override
  String get code => 'permission_denied_$permission';

  @override
  String get message => 'Permission "$permission" denied';
}

/// The requested capability does not exist on this platform (for example ML Kit on Linux).
final class PlatformUnsupportedException extends AppException {
  /// Creates an unsupported-platform error.
  const PlatformUnsupportedException(this.feature, {this.platformName})
      : super('Feature not supported on this platform');

  /// Feature identifier, for example `face_detection`.
  final String feature;

  /// Platform that was probed, for example `linux`.
  final String? platformName;

  @override
  String get code => 'unsupported_$feature';

  @override
  String get message => 'Feature "$feature" is not supported'
      '${platformName == null ? '' : ' on $platformName'}';
}

/// The WebSocket session dropped and is currently reconnecting.
final class TransportClosedException extends AppException {
  /// Creates a transport-closed error.
  const TransportClosedException([super.message = 'Realtime connection closed'])
      : super(isRetryable: true);

  @override
  String get code => 'transport_closed';
}

/// The global kill-switch is engaged; privileged actions are blocked.
final class KillSwitchActiveException extends AppException {
  /// Creates a kill-switch error.
  const KillSwitchActiveException()
      : super('KILL-SWITCH is engaged: the assistant is disabled');

  @override
  String get code => 'kill_switch_active';
}
