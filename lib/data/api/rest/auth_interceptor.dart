// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/security/security_constants.dart';
import '../../../features/auth/session/auth_repository.dart';
import '../../models/auth.dart';

/// Auto-refreshing auth layer for the dio transport (the REST client itself arrives
/// with the real backend; the interceptor ships now because session refresh is part
/// of step 2).
///
/// * **Before a request** — when the stored access token is inside [refreshLeeway]
///   of its expiry, one single-flight refresh runs (shared with the controller's
///   timer through [AuthRepository]) and the fresh token is attached.
/// * **On `401`** — the request is replayed exactly once with a new token; if the
///   refresh is rejected, [onSessionExpired] fires so the controller can sign out
///   and the router lands on login while preserving the pending navigation intent.
///
/// Certificate pinning stays where step 1 put it: `AppConfig.certificatePins`
/// validation plus the `badCertificate` branch of `ErrorMapper`; enforcing the pins
/// on the socket happens when `RestArmxApi` builds its client.
class AuthInterceptor extends QueuedInterceptor {
  /// Creates the interceptor.
  AuthInterceptor({
    required this.repository,
    required this.onSessionExpired,
    this.refreshLeeway = SecurityConstants.tokenRefreshLeeway,
  });

  /// Token store/refresh (single-flight), shared with `AuthController`.
  final AuthRepository repository;

  /// Called exactly when the session can no longer be refreshed.
  final void Function() onSessionExpired;

  /// How long before expiry the proactive refresh kicks in.
  final Duration refreshLeeway;

  /// Owning client, set once wired; enables the one-shot `401` replay.
  Dio? dio;

  /// Marks a request that already consumed its single auth retry.
  static const String retryExtraKey = 'armx_auth_retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      var token = await repository.readAccessToken();
      if (token != null &&
          token.isNotEmpty &&
          await repository.accessTokenNeedsRefresh(leeway: refreshLeeway)) {
        final outcome = await _tryRefresh();
        if (outcome.tokens != null) {
          token = outcome.tokens!.accessToken;
        } else if (outcome.sessionRejected) {
          onSessionExpired();
          token = null;
        }
        // Transient failure keeps the current (still usable) token.
      }
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    } on Object {
      // Never let bookkeeping break the transport; the request goes out as-is.
      handler.next(options);
    }
  }

  @override
  Future<void> onError(DioException error, ErrorInterceptorHandler handler) async {
    final status = error.response?.statusCode;
    final owner = dio;
    if (status != 401 ||
        owner == null ||
        error.requestOptions.extra[retryExtraKey] == true) {
      handler.next(error);
      return;
    }
    final outcome = await _tryRefresh();
    final tokens = outcome.tokens;
    if (tokens == null) {
      if (outcome.sessionRejected) {
        onSessionExpired();
      }
      handler.next(error);
      return;
    }
    final options = error.requestOptions;
    options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    options.extra[retryExtraKey] = true;
    final response = await owner.fetch<dynamic>(options);
    handler.resolve(response);
  }

  /// One single-flight refresh, classified for the two call sites: a rejected
  /// refresh ends the session, a transport failure only means "try later".
  Future<({bool sessionRejected, AuthTokens? tokens})> _tryRefresh() async {
    try {
      final tokens = await repository.refreshSession();
      return (sessionRejected: false, tokens: tokens);
    } on AuthException {
      return (sessionRejected: true, tokens: null);
    } on AppException {
      return (sessionRejected: false, tokens: null);
    } on Object {
      return (sessionRejected: false, tokens: null);
    }
  }
}
