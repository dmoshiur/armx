// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/security/risk_tier.dart';
import 'converters.dart';

part 'unlock.freezed.dart';
part 'unlock.g.dart';

/// Machine types A.R.M.X can be asked to unlock.
enum UnlockTargetKind {
  /// Windows desktop/laptop.
  @JsonValue('WINDOWS_PC')
  windowsPc,

  /// Android device running a Linux userland (the "Linux phone" target).
  @JsonValue('LINUX_PHONE')
  linuxPhone,

  /// Linux desktop/laptop.
  @JsonValue('LINUX_PC')
  linuxPc,

  /// macOS machine.
  @JsonValue('MAC')
  mac,

  /// Anything else with an A.R.M.X agent.
  @JsonValue('OTHER')
  other,
}

/// A machine paired for unlock, shown on the paired-devices screen.
@freezed
abstract class UnlockTarget with _$UnlockTarget {
  /// Creates a target.
  const factory UnlockTarget({
    required String id,
    required String name,
    @JsonKey(unknownEnumValue: UnlockTargetKind.other)
    @Default(UnlockTargetKind.other)
    UnlockTargetKind kind,
    @Default(false) bool online,
    required DateTime lastSeenAt,
    @JsonKey(fromJson: riskTierFromJson, toJson: riskTierToJson)
    @Default(RiskTier.high)
    RiskTier riskTier,
    @Default(true) bool paired,
    @Default('') String agentVersion,
  }) = _UnlockTarget;

  /// Creates a target from wire JSON.
  factory UnlockTarget.fromJson(Map<String, dynamic> json) => _$UnlockTargetFromJson(json);
}

/// Progress of an unlock attempt, rendered as a four-step timeline.
enum UnlockStatus {
  /// Running face + voice (+ biometric) verification locally.
  @JsonValue('VERIFYING')
  verifying,

  /// Signed token posted to `POST /unlock/request`.
  @JsonValue('SENT')
  sent,

  /// The target reported success.
  @JsonValue('UNLOCKED')
  unlocked,

  /// Verification, transport or the target failed.
  @JsonValue('FAILED')
  failed,

  /// The 30 s token expired before the target could use it.
  @JsonValue('EXPIRED')
  expired,
}

/// The exact payload that gets Ed25519-signed and posted to the backend.
///
/// Field names and the `exp` cap (`<= 30 s`) are part of the API contract in `docs/api.md`.
/// The signature covers the canonical JSON of every other field, so a server can verify it
/// without ever seeing a biometric template.
@freezed
abstract class UnlockTokenPayload with _$UnlockTokenPayload {
  /// Creates a token payload.
  const factory UnlockTokenPayload({
    @JsonKey(name: 'device_id') required String deviceId,
    required String nonce,
    @JsonKey(name: 'exp') required DateTime expiresAt,
    required String action,
    @JsonKey(name: 'issued_at') required DateTime issuedAt,
  }) = _UnlockTokenPayload;

  /// Creates a payload from wire JSON.
  factory UnlockTokenPayload.fromJson(Map<String, dynamic> json) =>
      _$UnlockTokenPayloadFromJson(json);

  const UnlockTokenPayload._();

  /// Seconds until the token expires (never negative when rendered).
  int secondsRemaining(DateTime now) {
    final remaining = expiresAt.difference(now).inSeconds;
    return remaining < 0 ? 0 : remaining;
  }
}

/// A signed unlock request, ready to be POSTed.
@freezed
abstract class SignedUnlockToken with _$SignedUnlockToken {
  /// Creates a signed token.
  const factory SignedUnlockToken({
    required UnlockTokenPayload payload,
    required String signature,
    @Default('Ed25519') String algorithm,
    required String publicKey,
  }) = _SignedUnlockToken;

  /// Creates a signed token from wire JSON.
  factory SignedUnlockToken.fromJson(Map<String, dynamic> json) =>
      _$SignedUnlockTokenFromJson(json);

  const SignedUnlockToken._();

  /// Wire payload for `POST /unlock/request`.
  Map<String, Object?> toRequestBody() => <String, Object?>{
        'device_id': payload.deviceId,
        'nonce': payload.nonce,
        'exp': payload.expiresAt.toUtc().toIso8601String(),
        'action': payload.action,
        'issued_at': payload.issuedAt.toUtc().toIso8601String(),
        'signature': signature,
        'algorithm': algorithm,
        'public_key': publicKey,
      };
}

/// Server acknowledgement of an unlock attempt.
@freezed
abstract class UnlockRequestOutcome with _$UnlockRequestOutcome {
  /// Creates an outcome.
  const factory UnlockRequestOutcome({
    required String requestId,
    required UnlockStatus status,
    required DateTime at,
    @Default('') String message,
    @Default('') String targetId,
  }) = _UnlockRequestOutcome;

  /// Creates an outcome from wire JSON.
  factory UnlockRequestOutcome.fromJson(Map<String, dynamic> json) =>
      _$UnlockRequestOutcomeFromJson(json);
}

/// Short-lived, single-use, scoped assertion that the owner was verified on this device.
///
/// This is the **only** verification artefact A.R.M.X ever sends over the network; face
/// templates and voice prints never leave the device.
@freezed
abstract class OwnerVerifiedToken with _$OwnerVerifiedToken {
  /// Creates the assertion.
  const factory OwnerVerifiedToken({
    required String token,
    required DateTime issuedAt,
    required DateTime expiresAt,
    @Default('owner_verified') String scope,
    @Default(true) bool singleUse,
    @JsonKey(fromJson: riskTierFromJson, toJson: riskTierToJson)
    @Default(RiskTier.high)
    RiskTier riskTier,
    @Default(<String>[]) List<String> satisfiedFactors,
  }) = _OwnerVerifiedToken;

  /// Creates the assertion from wire JSON.
  factory OwnerVerifiedToken.fromJson(Map<String, dynamic> json) =>
      _$OwnerVerifiedTokenFromJson(json);

  const OwnerVerifiedToken._();

  /// True when the assertion is still usable at [now].
  bool isValidAt(DateTime now) => expiresAt.isAfter(now) && singleUse;
}
