// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

part of 'ws_events.dart';

/// An Admin/Owner voice announcement is arriving on this device.
///
/// The receiving device must, in order: play the chime, show the overlay, then play the
/// audio. If the OS is silencing alerts the overlay still appears (rule 2) and the log
/// entry is still written — only the sound is skipped.
class IntercomAnnouncementEvent extends WsEvent {
  /// Creates the event.
  const IntercomAnnouncementEvent({
    required super.receivedAt,
    required this.announcementId,
    required this.fromName,
    required this.audioUrl,
    required this.durationMs,
    this.broadcast = false,
  });

  /// Id used for the download and for both log entries.
  final String announcementId;

  /// Who is speaking (Admin/Owner display name).
  final String fromName;

  /// Where the recording can be fetched.
  final String audioUrl;

  /// Length of the recording in milliseconds.
  final int durationMs;

  /// True when it went to every opted-in device.
  final bool broadcast;

  @override
  String get type => WsEventType.intercomAnnouncement;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'type': type,
        'announcement_id': announcementId,
        'from_name': fromName,
        'audio_url': audioUrl,
        'duration_ms': durationMs,
        'broadcast': broadcast,
      };
}

/// Delivery/playback outcome of one announcement.
///
/// Carried over the socket so the Admin's log updates live, and persisted locally by both
/// sides so the two views cannot disagree.
class IntercomOutcomeEvent extends WsEvent {
  /// Creates the event.
  const IntercomOutcomeEvent({
    required super.receivedAt,
    required this.announcementId,
    required this.targetUserId,
    required this.status,
  });

  /// Announcement the outcome belongs to.
  final String announcementId;

  /// Device the outcome belongs to (empty for a broadcast fan-out row).
  final String targetUserId;

  /// Wire status (`DELIVERED`, `PLAYED`, `MISSED`, `REVOKED`).
  final String status;

  @override
  String get type => WsEventType.intercomOutcome;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'type': type,
        'announcement_id': announcementId,
        'target_user_id': targetUserId,
        'status': status,
      };
}

/// A device changed its announcement consent.
///
/// Sent so the Admin's recipient list stays accurate without polling, and so the change is
/// visible in the audit trail rather than happening silently.
class IntercomConsentEvent extends WsEvent {
  /// Creates the event.
  const IntercomConsentEvent({
    required super.receivedAt,
    required this.userId,
    required this.consented,
  });

  /// Device whose consent changed.
  final String userId;

  /// New state.
  final bool consented;

  @override
  String get type => WsEventType.intercomConsent;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'type': type,
        'user_id': userId,
        'consented': consented,
      };
}
