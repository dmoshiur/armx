// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:meta/meta.dart';

/// Camera state of the guest greeter.
///
/// [killed] is deliberately distinct from [off]: `off` means "idle", `killed` means the
/// owner pressed the kill switch and nothing may re-enable it without an explicit action.
enum GreeterCameraState {
  /// Camera is streaming to the preview.
  live,

  /// Camera is idle and not capturing.
  off,

  /// The kill switch is engaged. The UI shows a persistent red banner and no preview, and
  /// enrollment is refused until the owner releases it.
  killed,

  /// Permission has not been granted.
  permissionRequired,

  /// This platform has no camera available to the app.
  unavailable;

  /// True when frames are actually being captured.
  bool get isCapturing => this == GreeterCameraState.live;

  /// The wire value the backend expects.
  String get wire => switch (this) {
        GreeterCameraState.live => 'live',
        GreeterCameraState.off => 'off',
        GreeterCameraState.killed => 'killed',
        GreeterCameraState.permissionRequired => 'permission_required',
        GreeterCameraState.unavailable => 'unavailable',
      };

  /// Parses a wire value. Anything unrecognised becomes [killed] — the state that captures
  /// nothing — because failing closed is the only acceptable direction for a camera.
  static GreeterCameraState fromWire(String? value) => switch (value?.toLowerCase()) {
        'live' || 'on' || 'streaming' => GreeterCameraState.live,
        'off' || 'idle' => GreeterCameraState.off,
        'permission_required' || 'denied' => GreeterCameraState.permissionRequired,
        'unavailable' || 'none' => GreeterCameraState.unavailable,
        _ => GreeterCameraState.killed,
      };
}

/// A person the greeter has been told about.
///
/// Stored only after an explicit, separate opt-in; deleting one removes the name and any
/// derived template, and the delete is immediate rather than a soft flag.
@immutable
class GuestProfile {
  /// Creates a guest profile.
  const GuestProfile({
    required this.id,
    required this.displayName,
    required this.enrolledAt,
    this.note,
    this.consentTextVersion = 'v1',
    this.encryptedTemplateRef,
  });

  /// Stable identifier.
  final String id;

  /// The guest's name. Never used to make a decision on its own.
  final String displayName;

  /// When the opt-in happened.
  final DateTime enrolledAt;

  /// Optional free-text note ("science fair judge", "meter reader").
  final String? note;

  /// Which consent wording the person agreed to, so a change in wording can invalidate
  /// old enrollments.
  final String consentTextVersion;

  /// Opaque reference to the encrypted template. The template itself never leaves the
  /// device and is never in this object.
  final String? encryptedTemplateRef;

  /// Parses from the wire.
  factory GuestProfile.fromJson(Map<String, Object?> json) => GuestProfile(
        id: json['id']! as String,
        displayName: (json['display_name'] ?? '') as String,
        enrolledAt: json['enrolled_at'] is String
            ? DateTime.parse(json['enrolled_at']! as String)
            : DateTime.now().toUtc(),
        note: json['note'] as String?,
        consentTextVersion: (json['consent_version'] ?? 'v1') as String,
        encryptedTemplateRef: json['template_ref'] as String?,
      );

  /// Serialises.
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'display_name': displayName,
        'enrolled_at': enrolledAt.toUtc().toIso8601String(),
        'note': note,
        'consent_version': consentTextVersion,
        'template_ref': encryptedTemplateRef,
      };

  @override
  bool operator ==(Object other) =>
      other is GuestProfile &&
      other.id == id &&
      other.displayName == displayName &&
      other.note == note;

  @override
  int get hashCode => Object.hash(id, displayName, note);
}

/// One greeting the greeter produced, for the on-screen log.
@immutable
class GreeterEvent {
  /// Creates an event.
  const GreeterEvent({
    required this.id,
    required this.occurredAt,
    required this.guestName,
    this.confidence,
    this.greetingSpoken = false,
  });

  /// Identifier.
  final String id;

  /// When it happened.
  final DateTime occurredAt;

  /// Who was recognised.
  final String guestName;

  /// Match confidence, when the backend supplies one. Shown so the owner can judge the
  /// system's reliability instead of trusting a bare name.
  final double? confidence;

  /// Whether the greeting was actually spoken aloud.
  final bool greetingSpoken;

  /// Parses from the wire.
  factory GreeterEvent.fromJson(Map<String, Object?> json) => GreeterEvent(
        id: json['id']! as String,
        occurredAt: json['occurred_at'] is String
            ? DateTime.parse(json['occurred_at']! as String)
            : DateTime.now().toUtc(),
        guestName: (json['guest_name'] ?? '') as String,
        confidence: (json['confidence'] as num?)?.toDouble(),
        greetingSpoken: json['greeting_spoken'] == true,
      );
}
