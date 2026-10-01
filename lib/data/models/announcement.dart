// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'announcement.freezed.dart';
part 'announcement.g.dart';

/// Lifecycle of one announcement.
///
/// The status is deliberately explicit so both sides of the log agree: the Admin sees
/// `delivered`/`played`/`offline`/`revoked`, and the receiving device writes the very same
/// value into its own copy of the log. There is exactly one source of truth — the audit
/// table — and no second store that could drift.
enum AnnouncementStatus {
  /// Accepted by the server, not yet pushed.
  @JsonValue('QUEUED')
  queued,

  /// Pushed to the device (chime + overlay shown).
  @JsonValue('DELIVERED')
  delivered,

  /// Playback finished.
  @JsonValue('PLAYED')
  played,

  /// The device was offline when it was sent (no silent queuing).
  @JsonValue('MISSED')
  missed,

  /// The recipient revoked consent before it arrived.
  @JsonValue('REVOKED')
  revoked,
}

/// Whether the announcement went to one user or to everybody who opted in.
enum AnnouncementScope {
  /// One named recipient.
  @JsonValue('USER')
  user,

  /// Every opted-in recipient.
  @JsonValue('BROADCAST')
  broadcast,
}

/// One voice announcement from the Admin/Owner.
@freezed
abstract class Announcement with _$Announcement {
  /// Creates an announcement.
  const factory Announcement({
    required String id,
    required String fromUserId,
    @Default('Admin') String fromName,
    @Default(AnnouncementScope.user) AnnouncementScope scope,
    @Default('') String targetUserId,
    @Default('') String targetLabel,
    @Default('') String audioUrl,
    @Default(0) int durationMs,
    @Default(AnnouncementStatus.queued) AnnouncementStatus status,
    required DateTime createdAt,
    DateTime? deliveredAt,
    DateTime? playedAt,
  }) = _Announcement;

  /// Creates an announcement from wire JSON.
  factory Announcement.fromJson(Map<String, dynamic> json) => _$AnnouncementFromJson(json);

  const Announcement._();

  /// True when this announcement went to every opted-in device.
  bool get isBroadcast => scope == AnnouncementScope.broadcast;

  /// True when the recipient should see it as an incoming alert.
  bool get isLive => status == AnnouncementStatus.delivered;

  /// Short label for the Admin's list.
  String get targetSummary => isBroadcast ? 'all opted-in devices' : targetLabel;
}

/// A device the Admin may target.
///
/// [consented] is the only gate: a device that has not turned the announcement switch on
/// is listed as not consented and the Admin cannot target it at all — the UI hides it
/// rather than showing a disabled button that would imply the attempt is possible.
@freezed
abstract class IntercomRecipient with _$IntercomRecipient {
  /// Creates a recipient entry.
  const factory IntercomRecipient({
    required String userId,
    @Default('') String displayName,
    @Default('') String role,
    @Default(false) bool consented,
    @Default(false) bool online,
    DateTime? lastSeenAt,
  }) = _IntercomRecipient;

  /// Creates a recipient from wire JSON.
  factory IntercomRecipient.fromJson(Map<String, dynamic> json) =>
      _$IntercomRecipientFromJson(json);

  const IntercomRecipient._();

  /// True when the Admin may send to this device.
  bool get isTargetable => consented && online;
}

/// The receiving device's consent state.
///
/// Rule 1 of the walkie-talkie contract: `enabled` starts `false` and can only be turned on
/// by the person holding the device. Nobody — including the Admin — can flip it remotely.
@freezed
abstract class IntercomConsent with _$IntercomConsent {
  /// Creates a consent state.
  const factory IntercomConsent({
    @Default(false) bool enabled,
    @Default(false) bool allowWhileLocked,
    DateTime? updatedAt,
  }) = _IntercomConsent;

  /// Creates a consent state from wire JSON.
  factory IntercomConsent.fromJson(Map<String, dynamic> json) => _$IntercomConsentFromJson(json);

  const IntercomConsent._();

  /// True when an announcement may play while the screen is locked.
  ///
  /// This is the separate, second opt-in: it never widens the main consent, it only
  /// decides whether playback is allowed on a locked device.
  bool get mayPlayWhileLocked => enabled && allowWhileLocked;
}
