// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:meta/meta.dart';

/// Lifecycle of a device linked to the account.
enum LinkStatus {
  /// Linked, reachable and usable.
  active,

  /// Linked but not reachable right now.
  offline,

  /// The pairing request is waiting for the owner to approve it on an already-trusted
  /// device. Nothing is linked until that happens.
  pendingApproval,

  /// The pairing code or QR expired before it was scanned.
  expired,

  /// Access was revoked. Kept in the list so the audit trail is visible.
  revoked,

  /// The owner rejected the request.
  rejected;

  /// Parses a wire value. Unknown values become [pendingApproval] — the state that grants
  /// the least, so an unrecognised status cannot read as "active".
  static LinkStatus fromWire(String? value) => switch (value?.toLowerCase()) {
        'active' || 'linked' => LinkStatus.active,
        'offline' => LinkStatus.offline,
        'expired' => LinkStatus.expired,
        'revoked' => LinkStatus.revoked,
        'rejected' || 'denied' => LinkStatus.rejected,
        _ => LinkStatus.pendingApproval,
      };

  /// True when the device currently has access.
  bool get hasAccess => this == LinkStatus.active || this == LinkStatus.offline;

  /// True while a decision is outstanding.
  bool get isOpen => this == LinkStatus.pendingApproval;
}

/// A device linked to this account.
@immutable
class LinkedDevice {
  /// Creates a linked device.
  const LinkedDevice({
    required this.id,
    required this.name,
    required this.platform,
    required this.status,
    this.ownerEmail,
    this.lastActiveAt,
    this.linkMethod = LinkMethod.qr,
    this.isCurrentDevice = false,
    this.fingerprint,
  });

  /// Stable identifier.
  final String id;

  /// Human name the owner gave it.
  final String name;

  /// `android`, `windows`, `linux`, `macos`, `web`.
  final String platform;

  /// Lifecycle state.
  final LinkStatus status;

  /// The account that linked it. Shown so a household can see who linked what.
  final String? ownerEmail;

  /// Last time the backend heard from it.
  final DateTime? lastActiveAt;

  /// How it was linked.
  final LinkMethod linkMethod;

  /// True for the device running this instance of the app. The unlink flow refuses this
  /// one — you cannot unlink the device you are holding.
  final bool isCurrentDevice;

  /// Short public-key fingerprint shown for verification during pairing.
  final String? fingerprint;

  /// Parses from the wire.
  factory LinkedDevice.fromJson(Map<String, Object?> json) => LinkedDevice(
        id: json['id']! as String,
        name: (json['name'] ?? 'Device') as String,
        platform: (json['platform'] ?? 'unknown') as String,
        status: LinkStatus.fromWire(json['status'] as String?),
        ownerEmail: json['owner_email'] as String?,
        lastActiveAt: json['last_active_at'] is String
            ? DateTime.tryParse(json['last_active_at']! as String)
            : null,
        linkMethod: LinkMethod.fromWire(json['link_method'] as String?),
        isCurrentDevice: json['current'] == true,
        fingerprint: json['fingerprint'] as String?,
      );

  /// Serialises.
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'platform': platform,
        'status': status.name,
        'owner_email': ownerEmail,
        'last_active_at': lastActiveAt?.toIso8601String(),
        'link_method': linkMethod.name,
        'current': isCurrentDevice,
        'fingerprint': fingerprint,
      };

  /// Copy with changes.
  LinkedDevice copyWith({
    String? id,
    String? name,
    String? platform,
    LinkStatus? status,
    String? ownerEmail,
    DateTime? lastActiveAt,
    LinkMethod? linkMethod,
    bool? isCurrentDevice,
    String? fingerprint,
  }) =>
      LinkedDevice(
        id: id ?? this.id,
        name: name ?? this.name,
        platform: platform ?? this.platform,
        status: status ?? this.status,
        ownerEmail: ownerEmail ?? this.ownerEmail,
        lastActiveAt: lastActiveAt ?? this.lastActiveAt,
        linkMethod: linkMethod ?? this.linkMethod,
        isCurrentDevice: isCurrentDevice ?? this.isCurrentDevice,
        fingerprint: fingerprint ?? this.fingerprint,
      );

  @override
  bool operator ==(Object other) =>
      other is LinkedDevice &&
      other.id == id &&
      other.name == name &&
      other.status == status &&
      other.lastActiveAt == lastActiveAt &&
      other.isCurrentDevice == isCurrentDevice;

  @override
  int get hashCode => Object.hash(id, name, status, lastActiveAt, isCurrentDevice);
}

/// How a device was linked.
enum LinkMethod {
  /// QR code scanned from an already-trusted device.
  qr,

  /// Eight-character pairing code typed by hand. The fallback when a camera is missing or
  /// refused (desktop, web, permission denied).
  code,

  /// Approved by an admin from the dashboard.
  adminApproval;

  /// Parses a wire value.
  static LinkMethod fromWire(String? value) => switch (value?.toLowerCase()) {
        'code' || 'manual' => LinkMethod.code,
        'admin' || 'admin_approval' => LinkMethod.adminApproval,
        _ => LinkMethod.qr,
      };
}

/// A pairing session started on this device, waiting for approval elsewhere.
@immutable
class PairingOffer {
  /// Creates an offer.
  const PairingOffer({
    required this.code,
    required this.expiresAt,
    required this.deviceName,
    this.qrPayload,
    this.approvedBy,
  });

  /// The short code to type on the trusted device.
  final String code;

  /// When the offer stops being valid. The UI counts down; at zero it shows the expired
  /// state rather than a stale code.
  final DateTime expiresAt;

  /// Name this device will have once linked.
  final String deviceName;

  /// Full payload to encode in the QR image.
  final String? qrPayload;

  /// Who approved it, once someone does.
  final String? approvedBy;

  /// True when the offer is past its window.
  bool isExpired({DateTime? now}) =>
      expiresAt.isBefore(now ?? DateTime.now().toUtc());

  /// Seconds remaining, floored at zero.
  int secondsRemaining({DateTime? now}) {
    final int seconds = expiresAt
        .difference(now ?? DateTime.now().toUtc())
        .inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  /// Parses from the wire.
  factory PairingOffer.fromJson(Map<String, Object?> json) => PairingOffer(
        code: (json['code'] ?? '') as String,
        expiresAt: json['expires_at'] is String
            ? DateTime.parse(json['expires_at']! as String)
            : DateTime.now().toUtc().add(const Duration(minutes: 10)),
        deviceName: (json['device_name'] ?? '') as String,
        qrPayload: json['qr_payload'] as String?,
        approvedBy: json['approved_by'] as String?,
      );
}

/// Why an unlink attempt was refused.
///
/// The unlink flow is gated on **the device owner's own password**, never a shared or
/// admin password, so a household member cannot remove someone else's device.
enum UnlinkRefusal {
  /// The typed password was wrong for the target device's owner.
  wrongPassword,

  /// The account is locked out after repeated failures.
  tooManyAttempts,

  /// The target is this very device.
  currentDevice,

  /// The caller's role may not unlink the target.
  notPermitted,
}
