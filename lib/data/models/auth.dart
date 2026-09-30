// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth.freezed.dart';
part 'auth.g.dart';

/// Signed-in user profile.
@freezed
abstract class UserProfile with _$UserProfile {
  /// Creates a profile.
  const factory UserProfile({
    required String id,
    required String displayName,
    @Default('') String email,
    @Default(<String>[]) List<String> roles,
    @Default('en') String preferredLanguage,
  }) = _UserProfile;

  /// Creates a profile from wire JSON.
  factory UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);

  const UserProfile._();

  /// True when the account may open the admin panel and the kill-switch.
  bool get isAdmin => roles.contains('admin') || roles.contains('owner');
}

/// Access + refresh token bundle and the identity it belongs to.
///
/// Never serialised to disk in plain form: the repository writes the two tokens into
/// `SecureKeys` and keeps only the profile in the local database.
@freezed
abstract class AuthSession with _$AuthSession {
  /// Creates a session.
  const factory AuthSession({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
    required UserProfile user,
    required String deviceId,
  }) = _AuthSession;

  /// Creates a session from wire JSON.
  factory AuthSession.fromJson(Map<String, dynamic> json) => _$AuthSessionFromJson(json);

  const AuthSession._();

  /// True when [expiresAt] is already in the past (with a small safety margin).
  bool isExpiredAt(DateTime now, {Duration leeway = const Duration(seconds: 30)}) =>
      !expiresAt.subtract(leeway).isAfter(now);

  /// Redacted description safe for logs.
  String get safeDescription => 'session(user=${user.id}, device=$deviceId)';

  /// The bare token pair, the shape `POST /auth/refresh` answers with.
  AuthTokens get tokens => AuthTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt,
      );
}

/// Access + refresh token pair returned by `POST /auth/refresh`.
///
/// Like [AuthSession], the raw values are written straight into
/// `flutter_secure_storage` (`SecureKeys`) and never reach logs or Drift.
@freezed
abstract class AuthTokens with _$AuthTokens {
  /// Creates a token pair.
  const factory AuthTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) = _AuthTokens;

  /// Creates a token pair from wire JSON.
  factory AuthTokens.fromJson(Map<String, dynamic> json) => _$AuthTokensFromJson(json);

  const AuthTokens._();

  /// True when [expiresAt] is already in the past (with a small safety margin).
  bool isExpiredAt(DateTime now, {Duration leeway = const Duration(seconds: 30)}) =>
      !expiresAt.subtract(leeway).isAfter(now);
}

/// Local pairing material produced by `POST /devices/pair`.
///
/// [fingerprint] is a **digest of the public key**, so it can be shown on screen and
/// compared out-of-band without leaking anything secret.
@freezed
abstract class PairingChallenge with _$PairingChallenge {
  /// Creates a pairing challenge.
  const factory PairingChallenge({
    required String serverUrl,
    required String publicKey,
    required String fingerprintHex,
    required String challengeNonce,
    required DateTime expiresAt,
  }) = _PairingChallenge;

  /// Creates a challenge from wire JSON.
  factory PairingChallenge.fromJson(Map<String, dynamic> json) =>
      _$PairingChallengeFromJson(json);
}

/// Result of a successful pairing handshake.
@freezed
abstract class PairingResult with _$PairingResult {
  /// Creates a pairing result.
  const factory PairingResult({
    required String deviceId,
    required String deviceKey,
    @Default('default') String site,
    required DateTime pairedAt,
  }) = _PairingResult;

  /// Creates a result from wire JSON.
  factory PairingResult.fromJson(Map<String, dynamic> json) => _$PairingResultFromJson(json);
}

/// Lifecycle of the pairing handshake as the UI sees it.
///
/// The wire contract contributes `pending`/`approved` (a `202`/`200` from
/// `POST /devices/pair`) and a `403 auth_pairing_rejected` rejection; `unpaired`
/// is the local state before any request has been made.
enum PairingState {
  /// No pairing completed from this device yet.
  unpaired,

  /// The request was accepted and waits for an administrator to approve it.
  pending,

  /// The server installed the device key; sign-in is allowed.
  approved,

  /// The administrator (or server policy) refused this device.
  rejected,
}

/// Outcome of one `POST /devices/pair` attempt.
@freezed
abstract class PairingStatus with _$PairingStatus {
  /// Creates a pairing status.
  const factory PairingStatus({
    required PairingState state,
    @Default('') String deviceId,
    @Default('') String message,
    PairingResult? result,
  }) = _PairingStatus;

  /// Creates a status from wire JSON.
  factory PairingStatus.fromJson(Map<String, dynamic> json) =>
      _$PairingStatusFromJson(json);

  const PairingStatus._();

  /// True only when the server issued an installable device key.
  bool get isPaired => state == PairingState.approved;

  /// True while an administrator decision is still outstanding.
  bool get isPending => state == PairingState.pending;
}

/// The on-device identity presented during pairing.
///
/// [publicKey] is the base64 **SPKI DER** encoding of the Ed25519 key (the exact
/// bytes `POST /devices/pair` receives). [fingerprintHex] is the SHA-256 digest of
/// those bytes so the owner can compare it out-of-band, grouped in 4s on screen.
/// The private half of the key never appears here — it lives only in secure storage.
@freezed
abstract class DeviceIdentity with _$DeviceIdentity {
  /// Creates a device identity.
  const factory DeviceIdentity({
    required String deviceName,
    required String platform,
    required String publicKey,
    required String fingerprintHex,
    @Default('') String deviceId,
    DateTime? pairedAt,
  }) = _DeviceIdentity;

  /// Creates an identity from wire JSON.
  factory DeviceIdentity.fromJson(Map<String, dynamic> json) =>
      _$DeviceIdentityFromJson(json);
}

/// Health/identity probe used by the "Test connection" button on the pairing screen.
@freezed
abstract class ServerProbe with _$ServerProbe {
  /// Creates a probe result.
  const factory ServerProbe({
    required bool reachable,
    required DateTime at,
    @Default('') String serverVersion,
    @Default('') String message,
    @Default(false) bool requiresPairing,
    @Default(false) bool tlsFingerprintMatched,
  }) = _ServerProbe;

  /// Creates a probe result from wire JSON.
  factory ServerProbe.fromJson(Map<String, dynamic> json) => _$ServerProbeFromJson(json);
}
