// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:meta/meta.dart';

import '../../core/network/token_store.dart';
import '../../features/auth/data/auth_models.dart';

/// A signed-in session: the token pair plus the account it belongs to.
@immutable
class AuthSession {
  /// Creates a session.
  const AuthSession({required this.tokens, required this.user});

  /// Access/refresh pair.
  final AuthTokens tokens;

  /// The account.
  final AuthUser user;

  /// Parses from the wire.
  ///
  /// Throws [FormatException] when the payload is missing the pieces the app depends on,
  /// so a malformed login response becomes an error state rather than a half-session.
  factory AuthSession.fromJson(Map<String, Object?> json) {
    final Object? access = json['access_token'] ?? json['accessToken'];
    final Object? refresh = json['refresh_token'] ?? json['refreshToken'];
    if (access is! String || refresh is! String) {
      throw const FormatException('Session payload is missing its tokens.');
    }
    final Object? user = json['user'];
    if (user is! Map<String, Object?>) {
      throw const FormatException('Session payload is missing its user.');
    }
    final Object? expiresIn = json['expires_in'] ?? json['expiresIn'];
    return AuthSession(
      tokens: AuthTokens(
        accessToken: access,
        refreshToken: refresh,
        // Default to the documented 15-minute access-token life when the server omits it,
        // which means the client refreshes early rather than failing a call.
        accessExpiresAt: DateTime.now().toUtc().add(
              Duration(seconds: expiresIn is num ? expiresIn.toInt() : 900),
            ),
      ),
      user: AuthUser.fromJson(user),
    );
  }
}

/// The result of creating an account.
///
/// Deliberately carries **no** tokens: an unverified account is not signed in, and the UI
/// must say "check your inbox" rather than dropping the user into the app.
@immutable
class SignupReceipt {
  /// Creates a receipt.
  const SignupReceipt({
    required this.email,
    required this.verificationSent,
    this.resendAfter,
  });

  /// The address the verification mail went to.
  final String email;

  /// Whether the backend reports the mail as sent.
  final bool verificationSent;

  /// Earliest the user may request another mail, so the button can be disabled with a
  /// countdown instead of letting the user trip a rate limit.
  final Duration? resendAfter;

  /// Parses from the wire.
  factory SignupReceipt.fromJson(Map<String, Object?> json) => SignupReceipt(
        email: (json['email'] ?? '') as String,
        verificationSent: json['verification_sent'] != false,
        resendAfter: json['resend_after_seconds'] is num
            ? Duration(seconds: (json['resend_after_seconds']! as num).toInt())
            : null,
      );
}
