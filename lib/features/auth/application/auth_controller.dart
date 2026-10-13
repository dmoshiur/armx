// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/token_store.dart';
import '../../../core/providers.dart';
import '../../../data/api/armx_api.dart';
import '../../../data/api/auth_session.dart';
import '../data/auth_models.dart';

/// The user profile cache key. **Non-secret**: it holds a name, an email and a role so the
/// shell can render before the network answers. Tokens never come near it.
const String _profileCacheKey = 'armx.session.profile.v1';

/// Owns the session: restore, sign in, sign up, verify, reset, sign out.
///
/// ## The rules this controller enforces
///
/// * **A session is only `signedIn` after the backend says so.** Nothing is optimistically
///   marked as signed in, and [AuthPhase.awaitingEmailVerification] is a first-class state
///   rather than a flag on a signed-in session.
/// * **Tokens go to `TokenStore`** (secure storage) and nowhere else. The profile cache is
///   `SharedPreferences` and contains no credential.
/// * **A rejected refresh token signs the user out** with [AuthPhase.sessionExpired], which
///   the router turns into a redirect carrying the "your session expired" notice.
/// * **Every failure is classified** into [AuthFailureReason] so the form can place the
///   message correctly instead of showing a generic error.
final NotifierProvider<AuthController, AuthState> authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Session state machine.
class AuthController extends Notifier<AuthState> {
  /// Restores any stored session. Called once by the splash bootstrap.
  Future<void> restore() async {
    final TokenStore store = ref.read(tokenStoreProvider);
    final ArmxApi api = ref.read(armxApiProvider);

    try {
      final AuthTokens? tokens = await store.read();
      if (tokens == null) {
        state = const AuthState(phase: AuthPhase.signedOut);
        return;
      }

      // Show the cached profile immediately, but stay in `signedIn` only if `me()`
      // confirms. A revoked account must not stay "signed in" because a cache said so.
      final AuthUser? cached = await _readCachedProfile();
      if (cached != null) {
        state = AuthState(phase: AuthPhase.signedIn, user: cached);
      }

      final AuthUser user = await api.me();
      await _cacheProfile(user);
      state = AuthState(
        phase: user.emailVerified
            ? AuthPhase.signedIn
            : AuthPhase.awaitingEmailVerification,
        user: user,
        pendingEmail: user.emailVerified ? null : user.email,
      );
    } on UnauthorizedException {
      await _clearSession();
      state = const AuthState(phase: AuthPhase.sessionExpired);
    } on AppException catch (error) {
      // A network failure at launch must not silently sign the user out: their tokens may
      // be perfectly good. Fall back to the cached profile and let the socket reconnect.
      final AuthUser? cached = await _readCachedProfile();
      if (cached != null) {
        state = AuthState(phase: AuthPhase.signedIn, user: cached);
      } else {
        state = AuthState(
          phase: AuthPhase.signedOut,
          failure: _reasonFor(error),
        );
      }
    }
  }

  /// Signs in with email and password.
  Future<void> signIn({required String email, required String password}) async {
    state = state.copyWith(busy: true, clearFailure: true);
    try {
      final AuthSession session = await ref.read(armxApiProvider).login(
            email: email.trim(),
            password: password,
            deviceName: await _deviceName(),
            platform: _platformName(),
          );
      await _persist(session);
      state = AuthState(
        phase: session.user.emailVerified
            ? AuthPhase.signedIn
            : AuthPhase.awaitingEmailVerification,
        user: session.user,
        pendingEmail: session.user.emailVerified ? null : session.user.email,
      );
    } on AppException catch (error) {
      state = state.copyWith(busy: false, failure: _reasonFor(error));
    }
  }

  /// Creates an account.
  ///
  /// Returns the receipt so the sign-up screen can show the verification instructions
  /// with the real address. The session stays signed out: an unverified account has no
  /// session to hold.
  Future<SignupReceipt?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = state.copyWith(busy: true, clearFailure: true);
    try {
      final SignupReceipt receipt = await ref.read(armxApiProvider).signup(
            email: email.trim(),
            password: password,
            displayName: displayName.trim(),
          );
      state = AuthState(
        phase: AuthPhase.signedOut,
        pendingEmail: receipt.email,
      );
      return receipt;
    } on AppException catch (error) {
      state = state.copyWith(busy: false, failure: _reasonFor(error));
      return null;
    }
  }

  /// Completes sign-in through the provider token.
  Future<void> signInWithGoogle({required String idToken}) async {
    state = state.copyWith(busy: true, clearFailure: true);
    try {
      final AuthSession session =
          await ref.read(armxApiProvider).signInWithGoogle(idToken: idToken);
      await _persist(session);
      state = AuthState(
        phase: session.user.emailVerified
            ? AuthPhase.signedIn
            : AuthPhase.awaitingEmailVerification,
        user: session.user,
        pendingEmail: session.user.emailVerified ? null : session.user.email,
      );
    } on AppException catch (error) {
      state = state.copyWith(busy: false, failure: _reasonFor(error));
    }
  }

  /// Consumes an emailed verification token.
  Future<bool> verifyEmail({required String token}) async {
    state = state.copyWith(busy: true, clearFailure: true);
    try {
      final AuthSession session =
          await ref.read(armxApiProvider).verifyEmail(token: token);
      await _persist(session);
      state = AuthState(phase: AuthPhase.signedIn, user: session.user);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(busy: false, failure: _reasonFor(error));
      return false;
    }
  }

  /// Re-sends the verification mail. Deliberately reports success even when the address is
  /// unknown, so the screen cannot be used to discover registered accounts.
  Future<void> resendVerification({String? email}) async {
    final String? target = email ?? state.pendingEmail;
    if (target == null || target.isEmpty) {
      return;
    }
    state = state.copyWith(busy: true, clearFailure: true);
    try {
      await ref.read(armxApiProvider).resendVerification(email: target);
      state = state.copyWith(busy: false);
    } on AppException catch (error) {
      state = state.copyWith(busy: false, failure: _reasonFor(error));
    }
  }

  /// Requests a password-reset mail. Always reports success to the caller.
  Future<void> requestPasswordReset({required String email}) async {
    state = state.copyWith(busy: true, clearFailure: true);
    try {
      await ref.read(armxApiProvider).requestPasswordReset(email: email.trim());
      state = state.copyWith(busy: false);
    } on AppException catch (error) {
      state = state.copyWith(busy: false, failure: _reasonFor(error));
    }
  }

  /// Sets a new password using a reset token.
  Future<bool> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    state = state.copyWith(busy: true, clearFailure: true);
    try {
      await ref
          .read(armxApiProvider)
          .resetPassword(token: token, newPassword: newPassword);
      state = state.copyWith(busy: false);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(busy: false, failure: _reasonFor(error));
      return false;
    }
  }

  /// Signs out. Local state is cleared even if the server call fails — a user who asks to
  /// sign out must not remain signed in because the network was down.
  Future<void> signOut() async {
    state = state.copyWith(busy: true);
    try {
      await ref.read(armxApiProvider).logout();
    } on AppException {
      // Intentionally ignored: signing out locally is not conditional on the server.
    }
    await _clearSession();
    state = const AuthState(phase: AuthPhase.signedOut);
  }

  /// Moves the session to `sessionExpired`, used when the transport reports a rejected
  /// refresh token from anywhere in the app.
  Future<void> markSessionExpired() async {
    await _clearSession();
    state = const AuthState(phase: AuthPhase.sessionExpired);
  }

  /// Clears the last failure so a form stops showing it after an edit.
  void clearFailure() {
    if (state.failure != null) {
      state = state.copyWith(clearFailure: true);
    }
  }

  // ---- internals -----------------------------------------------------------

  Future<void> _persist(AuthSession session) async {
    await ref.read(tokenStoreProvider).write(session.tokens);
    await _cacheProfile(session.user);
  }

  Future<void> _clearSession() async {
    try {
      await ref.read(tokenStoreProvider).clear();
    } on StorageException {
      // Nothing more we can do; the in-memory state is cleared regardless.
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileCacheKey);
  }

  Future<void> _cacheProfile(AuthUser user) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileCacheKey, _encodeProfile(user));
  }

  Future<AuthUser?> _readCachedProfile() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_profileCacheKey);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      return _decodeProfile(raw);
    } on Object {
      // A corrupted cache is not worth failing a launch over.
      return null;
    }
  }

  /// A deliberately tiny, dependency-free profile codec.
  ///
  /// Field order is fixed and the values are escaped, so the cache cannot be corrupted by
  /// an email containing the separator.
  String _encodeProfile(AuthUser user) {
    String esc(String? value) =>
        Uri.encodeComponent(value ?? '');
    return <String>[
      user.id,
      user.email,
      user.displayName,
      user.role.wire,
      user.emailVerified ? '1' : '0',
      esc(user.locale),
    ].map(Uri.encodeComponent).join('|');
  }

  AuthUser? _decodeProfile(String raw) {
    final List<String> parts = raw.split('|');
    if (parts.length < 5) {
      return null;
    }
    final List<String> decoded =
        parts.map(Uri.decodeComponent).toList(growable: false);
    return AuthUser(
      id: decoded[0],
      email: decoded[1],
      displayName: decoded[2],
      role: UserRole.fromWire(decoded[3]),
      emailVerified: decoded[4] == '1',
      locale: decoded.length > 5 && decoded[5].isNotEmpty ? decoded[5] : null,
    );
  }

  /// Classifies a failure. The backend's `code` wins over the status class, because
  /// `email_not_verified` arrives as a 401 alongside genuinely wrong credentials.
  AuthFailureReason _reasonFor(AppException error) => switch (error) {
        UnauthorizedException(code: 'email_not_verified') =>
          AuthFailureReason.emailNotVerified,
        UnauthorizedException(refreshRejected: true) =>
          AuthFailureReason.invalidToken,
        UnauthorizedException() => AuthFailureReason.invalidCredentials,
        ConflictException() => AuthFailureReason.emailAlreadyRegistered,
        RateLimitedException() => AuthFailureReason.rateLimited,
        ValidationException(code: 'invalid_token') => AuthFailureReason.invalidToken,
        ValidationException(code: 'expired_token') => AuthFailureReason.expiredToken,
        ValidationException() => AuthFailureReason.weakPassword,
        NetworkException() || TimeoutException() => AuthFailureReason.network,
        _ => AuthFailureReason.unknown,
      };

  String _platformName() {
    // Intentionally *not* `Platform.isX`: the platform string is metadata for the session
    // list, and using `defaultTargetPlatform` keeps the same code path on web, where
    // `dart:io` is unavailable.
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  Future<String> _deviceName() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    const String key = 'armx.device.name';
    final String? existing = prefs.getString(key);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final String generated = 'A.R.M.X on ${_platformName()}';
    await prefs.setString(key, generated);
    return generated;
  }
}

/// Keeps the controller in step with transport-level auth failures.
///
/// `ApiClient` reports a rejected refresh token through the sink; this listener converts
/// it into `sessionExpired`, so a mid-session revocation lands the user on the sign-in
/// screen with an explanation instead of a stream of failed calls.
final Provider<void> authFailureListenerProvider = Provider<void>((Ref ref) {
  ref.listen<AppException?>(authFailureSinkProvider, (AppException? previous, AppException? next) {
    if (next == null || next == previous) {
      return;
    }
    if (next is UnauthorizedException) {
      ref.read(authFailureSinkProvider.notifier).clear();
      unawaited(ref.read(authControllerProvider.notifier).markSessionExpired());
    }
  });
});
