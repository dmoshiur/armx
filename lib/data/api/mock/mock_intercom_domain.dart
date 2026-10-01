// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

part of 'mock_api.dart';

/// MockIntercomDomain — the Admin/Owner voice-announcement slice of [MockArmxApi].
///
/// The mock is also the receiver: after a send it pushes an `intercom.announcement` frame
/// on the same socket, so the whole chain (record → upload → chime → overlay → playback →
/// both logs) can be demonstrated and tested on one device without a backend.
///
/// The three safety rules are enforced here, not only in the UI:
/// * consent starts `false` and is per device;
/// * a send to a non-consented or offline device is refused/marked `MISSED` instead of
///   being queued silently;
/// * every outcome is written to the same announcement list both views read.
mixin MockIntercomDomain on MockArmxApi {
  final List<IntercomRecipient> _recipients = <IntercomRecipient>[
    const IntercomRecipient(
      userId: 'user-1',
      displayName: 'Living room tablet',
      role: 'viewer',
      consented: true,
      online: true,
    ),
    const IntercomRecipient(
      userId: 'user-2',
      displayName: 'Kitchen display',
      role: 'viewer',
      consented: false,
      online: true,
    ),
    const IntercomRecipient(
      userId: 'user-3',
      displayName: 'Gate panel',
      role: 'viewer',
      consented: true,
      online: false,
    ),
  ];

  final List<Announcement> _announcements = <Announcement>[];
  final Map<String, List<int>> _announcementAudio = <String, List<int>>{};
  IntercomConsent _consent = const IntercomConsent();
  int _announcementCounter = 0;

  @override
  Future<List<IntercomRecipient>> intercomRecipients() async {
    _guardKillSwitch();
    return List<IntercomRecipient>.unmodifiable(_recipients);
  }

  @override
  Future<IntercomConsent> intercomConsent() async {
    _guardKillSwitch();
    return _consent;
  }

  @override
  Future<IntercomConsent> setIntercomConsent({
    required bool enabled,
    required bool allowWhileLocked,
  }) async {
    _guardKillSwitch();
    final now = _clock.now().toUtc();
    _consent = IntercomConsent(
      enabled: enabled,
      allowWhileLocked: allowWhileLocked,
      updatedAt: now,
    );
    _emit(IntercomConsentEvent(
      receivedAt: now,
      userId: 'self',
      consented: enabled,
    ));
    _logger.d('mock: intercom consent = $enabled (locked: $allowWhileLocked)');
    return _consent;
  }

  @override
  Future<Announcement> sendAnnouncement({
    required List<int> audioBytes,
    required int durationMs,
    String targetUserId = '',
    String mimeType = 'audio/mp4',
  }) async {
    await _delay();
    _guardKillSwitch();
    if (!_consent.enabled && targetUserId.isNotEmpty) {
      // The sender must be an opted-in device too: nobody can push audio into a device
      // that has not allowed it, including the Admin's own device.
      throw const PolicyException(
        requiredTier: 'LOW',
        satisfiedTier: 'NONE',
        reason: 'This device has not opted in to voice announcements.',
      );
    }
    final now = _clock.now().toUtc();
    final id = 'ann-${(++_announcementCounter).toString().padLeft(6, '0')}';
    final matching = _recipients.where((IntercomRecipient r) => r.userId == targetUserId);
    final recipient = matching.isEmpty ? null : matching.first;
    if (recipient != null && !recipient.consented) {
      throw const PolicyException(
        requiredTier: 'LOW',
        satisfiedTier: 'NONE',
        reason: 'That device has not opted in to voice announcements.',
      );
    }
    final offline = recipient != null && !recipient.online;
    final announcement = Announcement(
      id: id,
      fromUserId: 'admin-1',
      fromName: 'Admin',
      scope: targetUserId.isEmpty ? AnnouncementScope.broadcast : AnnouncementScope.user,
      targetUserId: targetUserId,
      targetLabel: recipient?.displayName ?? 'all opted-in devices',
      audioUrl: '${config.apiBaseUrl}/v1/intercom/announcements/$id/audio',
      durationMs: durationMs,
      status: offline ? AnnouncementStatus.missed : AnnouncementStatus.delivered,
      createdAt: now,
    );
    _announcements.insert(0, announcement);
    _announcementAudio[id] = audioBytes.isEmpty ? _syntheticAudio(durationMs) : audioBytes;
    if (offline) {
      _emit(IntercomOutcomeEvent(
        receivedAt: now,
        announcementId: id,
        targetUserId: targetUserId,
        status: 'MISSED',
      ));
      _logger.d('mock: announcement $id missed (target offline)');
      return announcement;
    }
    _emit(IntercomAnnouncementEvent(
      receivedAt: now,
      announcementId: id,
      fromName: announcement.fromName,
      audioUrl: announcement.audioUrl,
      durationMs: durationMs,
      broadcast: announcement.isBroadcast,
    ));
    _logger.d('mock: announcement $id delivered to ${announcement.targetSummary}');
    return announcement;
  }

  @override
  Future<List<Announcement>> announcements({String targetUserId = ''}) async {
    _guardKillSwitch();
    final rows = targetUserId.isEmpty
        ? _announcements
        : _announcements.where((a) => a.targetUserId == targetUserId).toList();
    return List<Announcement>.unmodifiable(rows);
  }

  @override
  Future<List<int>> announcementAudio(String announcementId) async {
    await _delay();
    _guardKillSwitch();
    final audio = _announcementAudio[announcementId];
    if (audio == null) {
      throw const ApiException(
        'Unknown announcement',
        statusCode: 404,
        serverCode: 'announcement_not_found',
      );
    }
    return audio;
  }

  @override
  Future<void> reportAnnouncementOutcome({
    required String announcementId,
    required AnnouncementStatus status,
  }) async {
    await _delay();
    _guardKillSwitch();
    final index = _announcements.indexWhere((a) => a.id == announcementId);
    if (index < 0) {
      return;
    }
    final now = _clock.now().toUtc();
    final updated = _announcements[index].copyWith(
      status: status,
      deliveredAt: _announcements[index].deliveredAt ?? now,
      playedAt: status == AnnouncementStatus.played ? now : null,
    );
    _announcements[index] = updated;
    _emit(IntercomOutcomeEvent(
      receivedAt: now,
      announcementId: announcementId,
      targetUserId: updated.targetUserId,
      status: status.name.toUpperCase(),
    ));
  }

  /// Deterministic stand-in audio so playback works offline in the demo.
  ///
  /// A tiny WAV whose length follows [durationMs]; the real backend returns the Admin's
  /// recording.
  List<int> _syntheticAudio(int durationMs) {
    final frames = (22050 * (durationMs <= 0 ? 400 : durationMs) ~/ 1000).clamp(400, 220500);
    final data = <int>[];
    for (var i = 0; i < frames; i++) {
      final value = (8800 * math.sin(i / 50 * 2 * math.pi)).toInt();
      data.add(value & 0xff);
      data.add((value >> 8) & 0xff);
    }
    final header = <int>[
      ...'RIFF'.codeUnits,
      ..._le32(36 + data.length),
      ...'WAVE'.codeUnits,
      ...'fmt '.codeUnits,
      ..._le32(16),
      ..._le16(1),
      ..._le16(1),
      ..._le32(22050),
      ..._le32(44100),
      ..._le16(2),
      ..._le16(16),
      ...'data'.codeUnits,
      ..._le32(data.length),
    ];
    return <int>[...header, ...data];
  }

  static List<int> _le32(int value) => <int>[
        value & 0xff,
        (value >> 8) & 0xff,
        (value >> 16) & 0xff,
        (value >> 24) & 0xff,
      ];

  static List<int> _le16(int value) => <int>[value & 0xff, (value >> 8) & 0xff];

  /// Test/demo knob: makes the targeted device look offline so the MISSED path is visible.
  set intercomTargetOnline(bool online) {
    for (var i = 0; i < _recipients.length; i++) {
      _recipients[i] = _recipients[i].copyWith(online: online);
    }
  }

  /// Test/demo knob: pretends a device has (or has not) opted in.
  void setRecipientConsent(String userId, bool consented) {
    final index = _recipients.indexWhere((r) => r.userId == userId);
    if (index >= 0) {
      _recipients[index] = _recipients[index].copyWith(consented: consented);
    }
  }
}
