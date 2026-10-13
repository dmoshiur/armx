// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:meta/meta.dart';

/// Every failure the app can surface, as a sealed hierarchy.
///
/// The layers above the network never see a `DioException`, an HTTP status code or a raw
/// string: `api_client.dart` maps transport and server failures onto these cases, and the
/// UI switches on the case to pick a localized message. That is what keeps error copy
/// translatable and keeps "never fake a success state" enforceable — an unknown outcome
/// has its own case rather than being reported as success.
@immutable
sealed class AppException implements Exception {
  /// Creates an exception with a developer-facing message and optional reference id.
  const AppException({
    required this.message,
    this.code,
    this.requestId,
    this.statusCode,
  });

  /// Developer-facing description. **Never rendered raw to the user** — the UI maps the
  /// case onto `l10n.error*` strings, and shows [requestId] only as a support reference.
  final String message;

  /// Stable machine code from the backend (`error.code`) when one was supplied.
  final String? code;

  /// Correlation id for support. Safe to display; contains no personal data.
  final String? requestId;

  /// HTTP status, when the failure came from a response.
  final int? statusCode;

  @override
  String toString() =>
      '$runtimeType(code: $code, status: $statusCode, requestId: $requestId, $message)';
}

/// No usable connection: DNS failure, refused socket, no route, airplane mode.
final class NetworkException extends AppException {
  /// Creates a network failure.
  const NetworkException({
    super.message = 'The server could not be reached.',
    super.code,
    super.requestId,
  });
}

/// The connection was established but the exchange took too long.
final class TimeoutException extends AppException {
  /// Creates a timeout failure.
  const TimeoutException({
    super.message = 'The request timed out.',
    super.code,
    super.requestId,
  });
}

/// `401` — the session is missing, expired or rejected. The caller must sign in again.
final class UnauthorizedException extends AppException {
  /// Creates an unauthorized failure.
  const UnauthorizedException({
    super.message = 'Your session is no longer valid.',
    super.code,
    super.statusCode = 401,
    super.requestId,
  });

  /// True when the server explicitly said the refresh token is dead, so retrying the
  /// refresh is pointless.
  bool get refreshRejected => code == 'refresh_rejected';
}

/// `403` — authenticated, but the role does not permit the action.
final class ForbiddenException extends AppException {
  /// Creates a forbidden failure.
  const ForbiddenException({
    super.message = 'Your role does not allow this action.',
    super.code,
    super.statusCode = 403,
    super.requestId,
  });
}

/// `404` — the object is gone.
final class NotFoundException extends AppException {
  /// Creates a not-found failure.
  const NotFoundException({
    super.message = 'The requested item was not found.',
    super.code,
    super.statusCode = 404,
    super.requestId,
  });
}

/// `409` — the write conflicts with current server state (already deployed, already
/// paired, concurrent edit).
final class ConflictException extends AppException {
  /// Creates a conflict failure.
  const ConflictException({
    super.message = 'The server state changed. Reload and try again.',
    super.code,
    super.statusCode = 409,
    super.requestId,
  });
}

/// `422`/`400` with field-level detail.
final class ValidationException extends AppException {
  /// Creates a validation failure.
  const ValidationException({
    super.message = 'The submitted data was rejected.',
    this.fieldErrors = const <String, String>{},
    super.code,
    super.statusCode = 422,
    super.requestId,
  });

  /// Field name → message, as returned by the server.
  final Map<String, String> fieldErrors;
}

/// `429` — rate limited. [retryAfter] comes from the `Retry-After` header when present.
final class RateLimitedException extends AppException {
  /// Creates a rate-limit failure.
  const RateLimitedException({
    super.message = 'Too many attempts. Please wait and try again.',
    this.retryAfter,
    super.code = 'rate_limited',
    super.statusCode = 429,
    super.requestId,
  });

  /// How long the client should wait before retrying, when the server said so.
  final Duration? retryAfter;
}

/// `5xx` — the server failed. The action did not take effect.
final class ServerException extends AppException {
  /// Creates a server failure.
  const ServerException({
    super.message = 'The server reported a problem.',
    super.code,
    super.statusCode = 500,
    super.requestId,
  });
}

/// The request was rejected by a client-side rule before it was ever sent.
///
/// Used for the pre-flight checks the UI must perform — a HIGH-risk action without a
/// fresh confirmation, a form that has not validated, a feature the current role cannot
/// reach. Distinct from [ValidationException] because no server round-trip happened.
final class PolicyException extends AppException {
  /// Creates a policy failure.
  const PolicyException({
    required super.message,
    required this.reason,
    super.code = 'policy_rejected',
  });

  /// A machine-readable reason, e.g. `high_risk_not_confirmed`.
  final String reason;
}

/// A required capability is missing: no camera, no microphone, no overlay permission, an
/// unsupported platform. The UI renders an explanatory state instead of a crash.
final class CapabilityException extends AppException {
  /// Creates a capability failure.
  const CapabilityException({
    required super.message,
    required this.capability,
    super.code = 'capability_missing',
  });

  /// The missing capability, e.g. `camera`, `microphone`, `system_alert_window`.
  final String capability;
}

/// Local persistence failed (secure storage unavailable, disk full, corrupted blob).
final class StorageException extends AppException {
  /// Creates a storage failure.
  const StorageException({
    super.message = 'Local storage is unavailable.',
    super.code = 'storage_failed',
  });
}

/// The response was understood as a status but its body did not match the contract.
///
/// This is deliberately its own case: a malformed 200 is **not** a success, and the UI
/// must show the error state rather than an empty screen.
final class MalformedResponseException extends AppException {
  /// Creates a malformed-response failure.
  const MalformedResponseException({
    super.message = 'The server response did not match the expected format.',
    super.code = 'malformed_response',
    super.statusCode,
    super.requestId,
  });
}

/// The user dismissed a prompt, closed a sheet or cancelled a request.
///
/// Cancellation is not a failure. Controllers swallow this case instead of rendering an
/// error, which is why it is modelled explicitly rather than as a `null` return.
final class CancelledException extends AppException {
  /// Creates a cancellation marker.
  const CancelledException({super.message = 'Cancelled by the user.'});
}

/// Anything that did not match a known case — an unmapped status code, a transport
/// failure with no `DioExceptionType`, a bug in a mapper.
///
/// It exists so that "unrecognised" is an explicit, renderable state instead of a
/// `null`/`false`/empty-list that the UI would draw as an empty success. The sealed base
/// class cannot be instantiated directly, which is what forces every mapper to name a
/// concrete outcome.
final class UnknownException extends AppException {
  /// Creates an unrecognised failure.
  const UnknownException({
    required super.message,
    super.code,
    super.statusCode,
    super.requestId,
  });
}
