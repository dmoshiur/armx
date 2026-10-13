// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:meta/meta.dart';

import '../../../core/router/routes.dart';

/// The signed-in account.
@immutable
class AuthUser {
  /// Creates a user.
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.emailVerified,
    this.locale,
    this.avatarUrl,
    this.createdAt,
  });

  /// Server-side identifier.
  final String id;

  /// Sign-in address.
  final String email;

  /// Name shown in the UI.
  final String displayName;

  /// Authorisation role.
  final UserRole role;

  /// False until the emailed link is followed. An unverified account may sign in but is
  /// held on the verification screen.
  final bool emailVerified;

  /// Preferred language the account was last used in (`en` / `bn`).
  final String? locale;

  /// Optional avatar URL. Never fetched eagerly.
  final String? avatarUrl;

  /// Account creation time.
  final DateTime? createdAt;

  /// Parses a user from the wire.
  ///
  /// Throws [FormatException] when a required field is missing, so a malformed payload
  /// surfaces as an error state rather than as a user named `null`.
  factory AuthUser.fromJson(Map<String, Object?> json) {
    final Object? id = json['id'];
    final Object? email = json['email'];
    if (id is! String || email is! String) {
      throw const FormatException('User payload is missing id or email.');
    }
    final Object? createdAt = json['created_at'] ?? json['createdAt'];
    return AuthUser(
      id: id,
      email: email,
      displayName: (json['display_name'] ?? json['displayName'] ?? email) as String,
      role: UserRole.fromWire(json['role'] as String?),
      emailVerified: (json['email_verified'] ?? json['emailVerified']) == true,
      locale: json['locale'] as String?,
      avatarUrl: json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
      createdAt: createdAt is String ? DateTime.tryParse(createdAt) : null,
    );
  }

  /// Serialises for the non-secret profile cache.
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'email': email,
        'display_name': displayName,
        'role': role.wire,
        'email_verified': emailVerified,
        'locale': locale,
        'avatar_url': avatarUrl,
        'created_at': createdAt?.toIso8601String(),
      };

  /// Copy with changes.
  AuthUser copyWith({
    String? id,
    String? email,
    String? displayName,
    UserRole? role,
    bool? emailVerified,
    String? locale,
    String? avatarUrl,
    DateTime? createdAt,
  }) =>
      AuthUser(
        id: id ?? this.id,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        emailVerified: emailVerified ?? this.emailVerified,
        locale: locale ?? this.locale,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.id == id &&
      other.email == email &&
      other.displayName == displayName &&
      other.role == role &&
      other.emailVerified == emailVerified &&
      other.locale == locale;

  @override
  int get hashCode =>
      Object.hash(id, email, displayName, role, emailVerified, locale);
}

/// How far the session has got.
///
/// [restoring] is the only state in which the app has not yet decided where to send the
/// user; the splash screen owns it. There is deliberately no "assume signed in" state.
enum AuthPhase {
  /// Reading the stored session at launch.
  restoring,

  /// No session.
  signedOut,

  /// A session exists and the email is verified.
  signedIn,

  /// A session exists but the email has not been verified; the user is held on the
  /// verification screen and the assistant stays unavailable.
  awaitingEmailVerification,

  /// The session ended because the server rejected the refresh token. The UI shows a
  /// distinct "your session expired" notice on the sign-in screen instead of a silent
  /// bounce.
  sessionExpired,
}

/// Why a sign-in or sign-up attempt failed, so the form can render the right message in
/// the right place.
enum AuthFailureReason {
  /// Email and password do not match.
  invalidCredentials,

  /// The account exists but the email has not been verified.
  emailNotVerified,

  /// The email already has an account.
  emailAlreadyRegistered,

  /// Too many attempts; the caller shows the wait time.
  rateLimited,

  /// The Google sign-in flow was cancelled by the user.
  googleCancelled,

  /// The Google flow failed on the provider side.
  googleFailed,

  /// The reset/verification token is malformed, unknown or already used.
  invalidToken,

  /// The token was valid but has expired.
  expiredToken,

  /// The new password was rejected by the password policy.
  weakPassword,

  /// The request never reached the server.
  network,

  /// Anything else.
  unknown,
}

/// Connection attempt outcome for the "Continue with Google" button.
@immutable
class GoogleSignInOutcome {
  /// Creates an outcome.
  const GoogleSignInOutcome({required this.idToken, this.email});

  /// The OpenID Connect id token to hand to the backend. The app never sees a client
  /// secret: the token exchange happens in a browser tab, not in Dart.
  final String idToken;

  /// Email the provider reported, for pre-filling the verification screen.
  final String? email;
}

/// The full session state the UI reads.
@immutable
class AuthState {
  /// Creates a session state.
  const AuthState({
    this.phase = AuthPhase.restoring,
    this.user,
    this.pendingEmail,
    this.failure,
    this.busy = false,
  });

  /// The launch state: nothing decided yet.
  static const AuthState restoring = AuthState();

  /// Current phase.
  final AuthPhase phase;

  /// The signed-in user, when there is one.
  final AuthUser? user;

  /// Email awaiting verification, so the verification screen can say which inbox to check
  /// even though no session exists yet.
  final String? pendingEmail;

  /// The last failure, cleared when a new attempt starts.
  final AuthFailureReason? failure;

  /// True while an auth call is in flight. Drives the button spinners and blocks
  /// double-submits.
  final bool busy;

  /// True when a usable session exists.
  bool get isSignedIn => phase == AuthPhase.signedIn && user != null;

  /// The current role. Falls back to the least-privileged role while signed out, so a
  /// guard evaluated too early can only ever be *more* restrictive.
  UserRole get role => user?.role ?? UserRole.user;

  /// True while the launch sequence has not finished.
  bool get isRestoring => phase == AuthPhase.restoring;

  /// Copy with changes. Pass [clearFailure] to drop the last error.
  AuthState copyWith({
    AuthPhase? phase,
    AuthUser? user,
    String? pendingEmail,
    AuthFailureReason? failure,
    bool clearFailure = false,
    bool? busy,
  }) =>
      AuthState(
        phase: phase ?? this.phase,
        user: user ?? this.user,
        pendingEmail: pendingEmail ?? this.pendingEmail,
        failure: clearFailure ? null : (failure ?? this.failure),
        busy: busy ?? this.busy,
      );

  @override
  bool operator ==(Object other) =>
      other is AuthState &&
      other.phase == phase &&
      other.user == user &&
      other.pendingEmail == pendingEmail &&
      other.failure == failure &&
      other.busy == busy;

  @override
  int get hashCode => Object.hash(phase, user, pendingEmail, failure, busy);
}

/// The result of a password-reset or verification token check.
enum TokenValidity {
  /// The token is well-formed and unused.
  valid,

  /// The token is unknown, malformed or already used.
  invalid,

  /// The token was valid once, but its window has closed.
  expired,
}
