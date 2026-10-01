// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../data/api/ws_events.dart';
import '../../data/models/announcement.dart';
import 'intercom_state.dart';

part 'intercom_controller.g.dart';

/// Owns the Admin/Owner voice intercom: consent, push-to-talk, the incoming overlay and
/// the shared activity log.
///
/// The three safety rules are enforced here rather than in the widgets:
/// 1. consent is a local preference that starts OFF and is only ever written by the person
///    holding the device ([setConsent]);
/// 2. an incoming announcement always chimes + shows the overlay when consented, and only
///    skips *audio* when the OS is silencing alerts ([AnnouncementPolicy]);
/// 3. every announcement is written to the one log table that both the user's "My
///    Activity" screen and the Admin's per-user view read.
@Riverpod(keepAlive: true)
class IntercomController extends _$IntercomController {
  StreamSubscription<double>? _levelSubscription;
  StreamSubscription<WsEvent>? _eventSubscription;
  final Map<String, String> _audioFiles = <String, String>{};
  bool _disposed = false;

  @override
  IntercomState build() {
    final preferences = ref.watch(appPreferencesProvider).value;
    final enabled = preferences?.intercomEnabled ?? false;
    ref.onDispose(_disposeResources);

    final initialState = IntercomState(
      enabled: enabled,
      consent: IntercomConsent(
        enabled: preferences?.intercomConsent ?? false,
        allowWhileLocked: preferences?.intercomConsentLocked ?? false,
      ),
    );
    scheduleMicrotask(() => unawaited(_load()));
    return initialState;
  }

  Future<void> _load() async {
    final repository = ref.read(announcementRepositoryProvider);
    final audio = ref.read(intercomAudioProvider);
    final log = await repository.recent();
    if (_disposed) {
      return;
    }
    state = state.copyWith(log: log);
    _levelSubscription = audio.amplitude.listen((double level) {
      if (!_disposed) {
        state = state.copyWith(level: level);
      }
    });
    _eventSubscription = ref.read(armxApiProvider).events().listen(_onEvent);
    if (state.enabled) {
      await _refreshRecipients();
    }
  }

  void _disposeResources() {
    _disposed = true;
    _levelSubscription?.cancel();
    _eventSubscription?.cancel();
    unawaited(ref.read(intercomAudioProvider).dispose());
  }

  // ---- Feature flag --------------------------------------------------------

  /// Turns the whole feature on or off (the science-fair demo switch).
  Future<void> setEnabled(bool enabled) async {
    await ref.read(preferencesRepositoryProvider).setIntercomEnabled(enabled);
    state = state.copyWith(enabled: enabled, error: null);
    if (enabled) {
      await _refreshRecipients();
    }
  }

  // ---- Consent (rule 1) ----------------------------------------------------

  /// Sets this device's consent. Local, instant, revocable without anyone's approval.
  Future<void> setConsent({required bool enabled, required bool allowWhileLocked}) async {
    final repository = ref.read(preferencesRepositoryProvider);
    await repository.setIntercomConsent(enabled);
    await repository.setIntercomConsentLocked(allowWhileLocked);
    state = state.copyWith(
      consent: IntercomConsent(enabled: enabled, allowWhileLocked: allowWhileLocked),
    );
    try {
      await ref.read(armxApiProvider).setIntercomConsent(
            enabled: enabled,
            allowWhileLocked: allowWhileLocked,
          );
    } on Object catch (_) {
      // Offline: the local decision stands, the server catches up on the next sync.
    }
    if (enabled) {
      await _refreshRecipients();
    }
  }

  // ---- Admin side ----------------------------------------------------------

  Future<void> _refreshRecipients() async {
    try {
      final recipients = await ref.read(armxApiProvider).intercomRecipients();
      if (!_disposed) {
        state = state.copyWith(recipients: recipients);
      }
    } on Object catch (_) {
      // Keep the last known list; the readiness row reports the failure.
    }
  }

  /// Starts capturing. Returns false when there is no usable microphone.
  Future<bool> startTalking() async {
    final audio = ref.read(intercomAudioProvider);
    if (!await audio.hasMicrophone) {
      state = state.copyWith(error: 'no microphone');
      return false;
    }
    await audio.startRecording();
    state = state.copyWith(talk: TalkPhase.recording, error: null, lastOutcome: null);
    return true;
  }

  /// Stops capturing and uploads the clip to [targetUserId] (empty = broadcast).
  Future<void> stopTalkingAndSend({String targetUserId = ''}) async {
    final audio = ref.read(intercomAudioProvider);
    final clip = await audio.stopRecording();
    if (clip.isEmpty) {
      state = state.copyWith(talk: TalkPhase.idle, error: 'empty recording');
      return;
    }
    state = state.copyWith(talk: TalkPhase.sending);
    try {
      final announcement = await ref.read(armxApiProvider).sendAnnouncement(
            audioBytes: clip.bytes,
            durationMs: clip.durationMs,
            targetUserId: targetUserId,
            mimeType: clip.mimeType,
          );
      await ref.read(announcementRepositoryProvider).save(announcement);
      await _refreshLog();
      state = state.copyWith(
        talk: TalkPhase.sent,
        lastOutcome: announcement.status.name,
        error: null,
      );
    } on AppException catch (error) {
      state = state.copyWith(talk: TalkPhase.idle, error: error.code);
    } on Object catch (_) {
      state = state.copyWith(talk: TalkPhase.idle, error: 'send failed');
    }
  }

  /// Abandons the current capture.
  Future<void> cancelTalking() async {
    await ref.read(intercomAudioProvider).cancelRecording();
    state = state.copyWith(talk: TalkPhase.idle);
  }

  // ---- Receiving side (rule 2) --------------------------------------------

  void _onEvent(WsEvent event) {
    if (_disposed) {
      return;
    }
    switch (event) {
      case IntercomAnnouncementEvent event:
        unawaited(_handleIncoming(event));
      case IntercomOutcomeEvent event:
        unawaited(_handleOutcome(event));
      case IntercomConsentEvent event:
        unawaited(_handleConsentMirror(event));
      default:
        break;
    }
  }

  Future<void> _handleIncoming(IntercomAnnouncementEvent event) async {
    if (!state.consent.enabled) {
      // Not consented: nothing is shown, nothing is played, nothing is queued silently.
      return;
    }
    final silenced = await ref.read(silenceProbeProvider).isSilenced;
    if (_disposed) {
      return;
    }
    final repository = ref.read(announcementRepositoryProvider);
    final audio = ref.read(intercomAudioProvider);

    // Rule 3: write the row the moment it arrives, so the user's own Activity screen shows
    // the same announcement the Admin's panel shows — before it is even played.
    await repository.save(Announcement(
      id: event.announcementId,
      fromUserId: 'admin-1',
      fromName: event.fromName,
      scope: event.broadcast ? AnnouncementScope.broadcast : AnnouncementScope.user,
      targetUserId: 'self',
      targetLabel: 'this device',
      durationMs: event.durationMs,
      status: AnnouncementStatus.delivered,
      createdAt: DateTime.now().toUtc(),
    ));
    await _refreshLog();

    state = state.copyWith(overlay: OverlayPhase.announcing);
    if (AnnouncementPolicy.mayPlay(state.consent, silenced)) {
      await audio.playChime();
    }
    final path = await _downloadAudio(event.announcementId, event.audioUrl);
    if (_disposed) {
      return;
    }
    if (path == null) {
      state = state.copyWith(overlay: OverlayPhase.done, error: 'audio unavailable');
      return;
    }
    if (!AnnouncementPolicy.mayPlay(state.consent, silenced)) {
      // OS silence or a revoked consent mid-flight: overlay only, no audio override.
      state = state.copyWith(overlay: OverlayPhase.done);
      await _report(event.announcementId, AnnouncementStatus.delivered);
      return;
    }
    state = state.copyWith(overlay: OverlayPhase.speaking);
    await audio.playFile(path);
    if (_disposed) {
      return;
    }
    await _report(event.announcementId, AnnouncementStatus.played);
    await repository.markPlayed(event.announcementId, DateTime.now().toUtc());
    await _refreshLog();
    if (!_disposed) {
      state = state.copyWith(overlay: OverlayPhase.done);
    }
  }

  Future<String?> _downloadAudio(String announcementId, String url) async {
    final cached = _audioFiles[announcementId];
    if (cached != null && File(cached).existsSync()) {
      return cached;
    }
    try {
      final bytes = await ref.read(armxApiProvider).announcementAudio(announcementId);
      // No `path_provider` dependency: the clip is a disposable cache entry, so the OS
      // temp directory is enough and keeps the dependency list honest.
      final directory = Directory('${Directory.systemTemp.path}/armx_intercom');
      await directory.create(recursive: true);
      final path = '${directory.path}/$announcementId.wav';
      await File(path).writeAsBytes(bytes, flush: true);
      _audioFiles[announcementId] = path;
      await ref.read(announcementRepositoryProvider).setAudioPath(announcementId, path);
      return path;
    } on Object catch (_) {
      return null;
    }
  }

  /// "Mute this once": stops the audio but keeps the overlay and the log entry.
  Future<void> muteOnce() async {
    await ref.read(intercomAudioProvider).stopPlayback();
    state = state.copyWith(overlay: OverlayPhase.mutedOnce);
  }

  /// "Turn off announcements" straight from the overlay (instant, local).
  Future<void> turnOffFromOverlay() async {
    await ref.read(intercomAudioProvider).stopPlayback();
    await setConsent(enabled: false, allowWhileLocked: false);
    state = state.copyWith(overlay: OverlayPhase.hidden);
  }

  /// Dismisses the overlay after playback.
  void dismissOverlay() {
    state = state.copyWith(overlay: OverlayPhase.hidden);
  }

  Future<void> _handleOutcome(IntercomOutcomeEvent event) async {
    final status = switch (event.status) {
      'DELIVERED' => AnnouncementStatus.delivered,
      'PLAYED' => AnnouncementStatus.played,
      'MISSED' => AnnouncementStatus.missed,
      'REVOKED' => AnnouncementStatus.revoked,
      _ => AnnouncementStatus.queued,
    };
    final existing = state.log.where((Announcement a) => a.id == event.announcementId);
    if (existing.isNotEmpty) {
      await ref.read(announcementRepositoryProvider).save(existing.first.copyWith(status: status));
    }
    await _refreshLog();
  }

  Future<void> _handleConsentMirror(IntercomConsentEvent event) async {
    // Only mirrors *this* device's own change back into the recipient list.
    if (event.userId != 'self') {
      return;
    }
    await _refreshRecipients();
  }

  Future<void> _report(String announcementId, AnnouncementStatus status) async {
    try {
      await ref.read(armxApiProvider).reportAnnouncementOutcome(
            announcementId: announcementId,
            status: status,
          );
    } on Object catch (_) {
      // Offline: the local log keeps the row, the server syncs later.
    }
  }

  // ---- Shared log (rule 3) -------------------------------------------------

  Future<void> _refreshLog() async {
    final log = await ref.read(announcementRepositoryProvider).recent();
    if (!_disposed) {
      state = state.copyWith(log: log);
    }
  }

  /// Reloads the log from the backend and merges it with the local cache.
  Future<void> refreshLog() async {
    try {
      final remote = await ref.read(armxApiProvider).announcements();
      final repository = ref.read(announcementRepositoryProvider);
      for (final announcement in remote) {
        await repository.save(announcement);
      }
    } on Object catch (_) {
      // Offline: show whatever is cached.
    }
    await _refreshLog();
  }

  /// Exports the log as CSV for the science-fair demo (Admin view).
  String exportCsv({String targetUserId = ''}) {
    final buffer = StringBuffer()
      ..writeln('id,from,scope,target,status,at,played_at');
    for (final announcement in state.log) {
      if (targetUserId.isNotEmpty && announcement.targetUserId != targetUserId) {
        continue;
      }
      buffer
        ..write(announcement.id)
        ..write(',')
        ..write(announcement.fromName)
        ..write(',')
        ..write(announcement.scope.name)
        ..write(',')
        ..write(announcement.targetLabel.replaceAll(',', ' '))
        ..write(',')
        ..write(announcement.status.name)
        ..write(',')
        ..write(announcement.createdAt.toIso8601String())
        ..write(',')
        ..write(announcement.playedAt?.toIso8601String() ?? '')
        ..writeln();
    }
    return buffer.toString();
  }

  /// Clears the local log copy (the backend keeps the audit trail).
  Future<void> clearLocalLog() async {
    await ref.read(announcementRepositoryProvider).clear();
    state = state.copyWith(log: const <Announcement>[]);
  }

  /// Re-reads the recipient list (used by the Admin screen's refresh).
  Future<void> refreshRecipients() => _refreshRecipients();
}
