// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/security/security_constants.dart';
import '../../../data/models/auth.dart';
import '../lock/app_lock_controller.dart';
import '../pairing/pairing_controller.dart';
import 'auth_repository.dart';
import 'login_rate_limiter.dart';

part 'auth_controller.g.dart';

/// Session lifecycle as the router and the screens see it.
enum AuthPhase {
  /// Cold-start restore has not finished yet (splash keeps showing).
  restoring,

  /// No session: the login screen is the entry point.
  signedOut,

  /// A valid session exists (refresh is scheduled while it ages).
  signedIn,

  /// The access token is inside the refresh window: requests still work, a refresh
  /// is in flight or scheduled.
  sessionExpiring,

  /// The refresh was rejected; tokens are wiped and login must re-authenticate,
  /// preserving the pending navigation intent.
  sessionExpired,
}

/// Immutable snapshot of the session, watched by the router and the screens.
@immutable
class AuthState {
  /// Creates an auth state.
  const AuthState({
    this.phase = AuthPhase.restoring,
    this.session,
    this.rememberDevice = true,
    this.pendingIntent,
  });

  /// Current lifecycle phase.
  final AuthPhase phase;

  /// The live session (tokens included — never logged, never rendered).
  final AuthSession? session;

  /// "Remember this device" toggle value (persisted on sign-in).
  final bool rememberDevice;

  /// Route to return to after the next successful sign-in.
  final String? pendingIntent;

  static const Object _clear = Object();

  /// Copies selected fields; [session] and [pendingIntent] clear on explicit `null`.
  AuthState copyWith({
    AuthPhase? phase,
    bool? rememberDevice,
    Object? session = _clear,
    Object? pendingIntent = _clear,
  }) =>
      AuthState(
        phase: phase ?? this.phase,
        rememberDevice: rememberDevice ?? this.rememberDevice,
        session: session == _clear ? this.session : session as AuthSession?,
        pendingIntent: pendingIntent == _clear
            ? this.pendingIntent
            : pendingIntent as String?,
      );
}

/// Owns the sign-in session: restore, proactive refresh (timer + dio interceptor
/// share [AuthRepository]'s single-flight), sign-out/unpair and the pending-navigation
/// intent preserved across a forced login.
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  bool _restored = false;
  Timer? _refreshTimer;
  late final AuthRepository _repository;
  final LoginRateLimiter _rateLimiter = LoginRateLimiter();

  @override
  AuthState build() {
    _repository = AuthRepository(
      api: ref.read(armxApiProvider),
      store: ref.read(secureStoreProvider),
      preferences: ref.read(preferencesRepositoryProvider),
      clock: ref.read(clockProvider),
      logger: ref.read(appLoggerProvider),
    );
    ref.onDispose(() => _refreshTimer?.cancel());
    return const AuthState();
  }

  /// Restores the stored session (called once from the bootstrap gate).
  ///
  /// An expired access token triggers an immediate refresh: success lands in
  /// [AuthPhase.signedIn], a rejected refresh in [AuthPhase.sessionExpired], and a
  /// transient network failure keeps [AuthPhase.sessionExpiring] so the shell stays
  /// reachable offline.
  Future<void> restore() async {
    if (_restored) {
      return;
    }
    _restored = true;

    AuthSession? session;
    try {
      session = await _repository.restoreSession();
    } on AppException catch (error) {
      session = null;
      ref.read(appLoggerProvider).w('auth: restore failed (${error.code})');
    }

    if (session == null) {
      var remember = true;
      try {
        remember = (await ref.read(preferencesRepositoryProvider).load()).rememberDevice;
      } on Object {
        remember = true;
      }
      state = state.copyWith(
        phase: AuthPhase.signedOut,
        session: null,
        rememberDevice: remember,
      );
      return;
    }

    if (!session.isExpiredAt(ref.read(clockProvider).now())) {
      state = state.copyWith(phase: AuthPhase.signedIn, session: session);
      _scheduleRefresh(session);
      return;
    }

    state = state.copyWith(phase: AuthPhase.sessionExpiring, session: session);
    try {
      final tokens = await _repository.refreshSession();
      final refreshed = session.copyWith(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        expiresAt: tokens.expiresAt,
      );
      state = state.copyWith(phase: AuthPhase.signedIn, session: refreshed);
      _scheduleRefresh(refreshed);
    } on AuthException {
      await _expireSession();
    } on AppException {
      // Offline cold start with a stale token: keep the shell, retry shortly.
      _scheduleRetry();
    }
  }

  /// Signs in through [AuthRepository]; failures feed the login rate limiter.
  Future<void> signIn({
    required String username,
    required String password,
    required bool rememberDevice,
  }) async {
    _refreshTimer?.cancel();
    try {
      final session = await _repository.signIn(
        username: username,
        password: password,
        rememberDevice: rememberDevice,
      );
      _rateLimiter.recordSuccess();
      state = state.copyWith(
        phase: AuthPhase.signedIn,
        session: session,
        rememberDevice: rememberDevice,
      );
      _scheduleRefresh(session);
      // The owner just proved possession of credentials: release the LOW-tier
      // app-lock gate so the post-login redirect is not blocked by it.
      ref.read(appLockControllerProvider.notifier).unlock();
    } on AppException catch (error) {
      _rateLimiter.recordFailure(ref.read(clockProvider).now());
      throw error;
    }
  }

  /// Remaining login lockout, or `null` when the form may be submitted.
  Duration? get loginBackoff => _rateLimiter.remaining(ref.read(clockProvider).now());

  /// Signs out of this device: tokens are wiped server-side (best effort) and locally,
  /// while pairing material is kept.
  Future<void> signOut() async {
    _refreshTimer?.cancel();
    await _repository.signOut();
    state = state.copyWith(
      phase: AuthPhase.signedOut,
      session: null,
      pendingIntent: null,
    );
  }

  /// Unpairs this device: tokens **and** keypair are erased, and the pairing flow is
  /// reset so the router sends the user back to the pairing screen.
  Future<void> unpair() async {
    _refreshTimer?.cancel();
    await _repository.unpair();
    state = state.copyWith(
      phase: AuthPhase.signedOut,
      session: null,
      pendingIntent: null,
    );
    await ref.read(pairingControllerProvider.notifier).resetAfterUnpair();
  }

  /// Remembers where the user was when a refresh failure forced the login screen.
  void setPendingIntent(String location) {
    if (location == AppRoutes.splash ||
        location == AppRoutes.login ||
        location == AppRoutes.pairing) {
      return;
    }
    state = state.copyWith(pendingIntent: location);
  }

  /// Returns (and forgets) the route the user should land on after signing in.
  String? consumePendingIntent() {
    final intent = state.pendingIntent;
    if (intent != null) {
      state = state.copyWith(pendingIntent: null);
    }
    return intent;
  }

  void _scheduleRefresh(AuthSession session) {
    _refreshTimer?.cancel();
    final now = ref.read(clockProvider).now();
    final fireAt = session.expiresAt.subtract(SecurityConstants.tokenRefreshLeeway);
    final delay = fireAt.isAfter(now) ? fireAt.difference(now) : Duration.zero;
    _refreshTimer = Timer(delay, () {
      unawaited(_refreshDue());
    });
  }

  void _scheduleRetry() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(seconds: 30), () {
      unawaited(_refreshDue());
    });
  }

  Future<void> _refreshDue() async {
    final phase = state.phase;
    if (phase != AuthPhase.signedIn && phase != AuthPhase.sessionExpiring) {
      return;
    }
    state = state.copyWith(phase: AuthPhase.sessionExpiring);
    try {
      final tokens = await _repository.refreshSession();
      final session = state.session;
      if (session == null) {
        return;
      }
      final refreshed = session.copyWith(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        expiresAt: tokens.expiresAt,
      );
      state = state.copyWith(phase: AuthPhase.signedIn, session: refreshed);
      _scheduleRefresh(refreshed);
    } on AuthException {
      await _expireSession();
    } on AppException {
      _scheduleRetry();
    }
  }

  Future<void> _expireSession() async {
    _refreshTimer?.cancel();
    await _repository.clearTokens();
    state = state.copyWith(phase: AuthPhase.sessionExpired, session: null);
  }
}
