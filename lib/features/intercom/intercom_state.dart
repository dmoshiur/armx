// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/foundation.dart';

import '../../data/models/announcement.dart';

/// What the receiving device is doing with an incoming announcement.
enum OverlayPhase {
  /// Nothing incoming.
  hidden,

  /// Chime is playing and the overlay is on screen.
  announcing,

  /// Audio is playing.
  speaking,

  /// The user muted this one announcement.
  mutedOnce,

  /// Playback finished / dismissed.
  done,
}

/// Recording state of the Admin's push-to-talk button.
enum TalkPhase {
  /// Idle.
  idle,

  /// Holding the button and capturing.
  recording,

  /// Uploading.
  sending,

  /// The last send finished; [lastOutcome] describes it.
  sent,
}

/// Immutable snapshot of the intercom feature.
@immutable
class IntercomState {
  /// Creates the intercom state.
  const IntercomState({
    this.enabled = false,
    this.consent = const IntercomConsent(),
    this.recipients = const <IntercomRecipient>[],
    this.log = const <Announcement>[],
    this.talk = TalkPhase.idle,
    this.overlay = OverlayPhase.hidden,
    this.level = 0,
    this.lastOutcome,
    this.error,
  });

  /// The `enableAdminIntercom` feature flag (off by default).
  final bool enabled;

  /// This device's consent (rule 1: OFF by default).
  final IntercomConsent consent;

  /// Devices the Admin may target.
  final List<IntercomRecipient> recipients;

  /// The shared announcement log (same rows the Admin sees).
  final List<Announcement> log;

  /// Admin push-to-talk state.
  final TalkPhase talk;

  /// Incoming-announcement overlay state (rule 2).
  final OverlayPhase overlay;

  /// Live microphone level 0.0–1.0 for the waveform.
  final double level;

  /// Human readable result of the last send (`delivered`, `missed`, …).
  final String? lastOutcome;

  /// Localized-agnostic error code from the last failure.
  final String? error;

  /// True when an announcement may play out loud.
  ///
  /// False when the device has not consented, or when the OS is silencing alerts — in the
  /// latter case the overlay still shows, only the sound is skipped.
  bool audioAllowed(bool silenced) => consent.enabled && !silenced;

  /// Devices the Admin can actually send to.
  List<IntercomRecipient> get targetable =>
      recipients.where((IntercomRecipient r) => r.isTargetable).toList(growable: false);

  /// True when the Admin should see "no opted-in devices".
  bool get hasNoTargets => targetable.isEmpty;

  static const Object _clear = Object();

  IntercomState copyWith({
    bool? enabled,
    IntercomConsent? consent,
    List<IntercomRecipient>? recipients,
    List<Announcement>? log,
    TalkPhase? talk,
    OverlayPhase? overlay,
    double? level,
    Object? lastOutcome = _clear,
    Object? error = _clear,
  }) =>
      IntercomState(
        enabled: enabled ?? this.enabled,
        consent: consent ?? this.consent,
        recipients: recipients ?? this.recipients,
        log: log ?? this.log,
        talk: talk ?? this.talk,
        overlay: overlay ?? this.overlay,
        level: level ?? this.level,
        lastOutcome: lastOutcome == _clear ? this.lastOutcome : lastOutcome as String?,
        error: error == _clear ? this.error : error as String?,
      );
}

/// Why an announcement could not be shown as an alert.
enum SilenceReason {
  /// The OS is in Do Not Disturb / silent mode.
  systemSilenced,

  /// The device has not consented at all.
  notConsented,
}

/// Decides what an incoming announcement may do.
///
/// Pure function of (consent, OS silence) so the rule is unit-testable and identical on
/// every platform.
class AnnouncementPolicy {
  /// Private constructor for a static-only helper.
  const AnnouncementPolicy._();

  /// True when the chime and the voice may be played.
  static bool mayPlay(IntercomConsent consent, bool systemSilenced) =>
      consent.enabled && !systemSilenced;

  /// True when the full-screen overlay must still be shown (rule 2: never silent+invisible).
  static bool mustShowOverlay(IntercomConsent consent) => consent.enabled;

  /// Why audio is skipped, or `null` when it may play.
  static SilenceReason? skipReason(IntercomConsent consent, bool systemSilenced) {
    if (!consent.enabled) {
      return SilenceReason.notConsented;
    }
    if (systemSilenced) {
      return SilenceReason.systemSilenced;
    }
    return null;
  }
}
