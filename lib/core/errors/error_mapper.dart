// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'app_exception.dart';

/// Converts arbitrary errors (Dio, WebSocket, platform channels) into [AppException]s.
///
/// Every repository funnels errors through [ErrorMapper.map] so that UI code only ever
/// has to reason about the sealed [AppException] hierarchy.
abstract final class ErrorMapper {
  /// Normalises [error] into an [AppException].
  ///
  /// Already-normalised errors pass through unchanged, which keeps the mapping
  /// idempotent when layers are nested.
  static AppException map(Object error, [StackTrace? stackTrace]) {
    if (error is AppException) {
      return error;
    }
    if (error is DioException) {
      return _fromDio(error, stackTrace);
    }
    if (error is WebSocketChannelException) {
      return NetworkException(
        'Realtime channel error',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return ApiException(
      'Unexpected error: ${error.runtimeType}',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  static AppException _fromDio(DioException error, StackTrace? stackTrace) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return RequestTimeoutException(
          'The server did not answer in time',
          cause: error,
          stackTrace: stackTrace,
        );
      case DioExceptionType.badCertificate:
        return NetworkException(
          'TLS certificate rejected',
          cause: error,
          stackTrace: stackTrace,
        );
      case DioExceptionType.connectionError:
        return NetworkException(
          'Cannot reach the server',
          cause: error,
          stackTrace: stackTrace,
        );
      case DioExceptionType.cancel:
        return ApiException(
          'Request cancelled',
          cause: error,
          stackTrace: stackTrace,
        );
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return _fromResponse(error, stackTrace);
    }
  }

  static AppException _fromResponse(DioException error, StackTrace? stackTrace) {
    final response = error.response;
    final status = response?.statusCode;
    final data = response?.data;
    final serverCode = data is Map ? data['code']?.toString() : null;
    final message = data is Map && data['message'] is String
        ? data['message'] as String
        : 'Request failed${status == null ? '' : ' with status $status'}';

    if (status == 401 || status == 403) {
      // The error envelope's `code` decides which auth failure the user sees; the bare
      // status only picks a sensible default when a legacy server omits it.
      final reason = switch (serverCode) {
        'auth_invalid_credentials' => AuthFailureReason.invalidCredentials,
        'auth_account_locked' => AuthFailureReason.accountLocked,
        'auth_pairing_rejected' => AuthFailureReason.pairingRejected,
        'auth_refresh_rejected' => AuthFailureReason.refreshRejected,
        'auth_device_revoked' => AuthFailureReason.deviceRevoked,
        _ => status == 401
            ? AuthFailureReason.sessionExpired
            : AuthFailureReason.deviceRevoked,
      };
      return AuthException(
        reason,
        message: message,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (status == 423) {
      return const KillSwitchActiveException();
    }
    return ApiException(
      message,
      statusCode: status,
      serverCode: serverCode,
      cause: error,
      stackTrace: stackTrace,
      isRetryable: status == null || status >= 500,
    );
  }
}
