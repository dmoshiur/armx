// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/foundation.dart';

/// Lifecycle of one voice interaction.
///
/// The orb on the chat tab and the voice screen both render straight from this value, so
/// there is exactly one source of truth for "what is the microphone doing right now".
enum VoicePhase {
  /// No capture, no playback.
  idle,

  /// A capture is being started (permission prompt, engine warm-up).
  arming,

  /// The microphone is open and the transcript is still growing.
  listening,

  /// The microphone is closed; the final transcript is being resolved.
  transcribing,

  /// The assistant is producing a reply.
  thinking,

  /// Text-to-speech is playing a reply.
  speaking,

  /// The last attempt failed ([VoiceState.errorCode] says how).
  error,

  /// This platform has no speech engine (documented, not a failure).
  unsupported,
}

/// How the current or last capture was started.
enum VoiceInputMode {
  /// Nothing captured yet.
  none,

  /// Press-and-hold on the microphone button.
  pushToTalk,

  /// The wake word started the capture.
  wakeWord,
}

/// What speech engines this build actually has.
///
/// [isSimulated] is surfaced in the UI whenever it is true: a simulated engine captures no
/// audio at all, so the user is never misled into thinking a microphone is live.
@immutable
class VoiceEngineReport {
  /// Creates an engine report.
  const VoiceEngineReport({
    this.sttEngineId = 'none',
    this.sttAvailable = false,
    this.sttSimulated = false,
    this.ttsEngineId = 'none',
    this.ttsAvailable = false,
    this.ttsSimulated = false,
    this.wakeWordEngineId = 'stub',
    this.wakeWordIsStub = true,
  });

  /// Identifier of the speech-to-text engine (diagnostics only).
  final String sttEngineId;

  /// Whether a real speech-to-text engine is present.
  final bool sttAvailable;

  /// Whether recognition is simulated (no microphone audio is captured).
  final bool sttSimulated;

  /// Identifier of the text-to-speech engine (diagnostics only).
  final String ttsEngineId;

  /// Whether a text-to-speech engine is present.
  final bool ttsAvailable;

  /// Whether playback is simulated (no audio is produced).
  final bool ttsSimulated;

  /// Identifier of the wake-word engine reported by the native host.
  final String wakeWordEngineId;

  /// Whether the wake-word engine is the no-audio stub.
  ///
  /// True means **A.R.M.X does not listen in the background**. The Android foreground
  /// service is still started (with its persistent notification) because the wake-word
  /// adapter contract lives there, but no audio is opened. The UI must say so.
  final bool wakeWordIsStub;

  /// Whether a real wake-word detector is attached.
  bool get wakeWordAvailable => !wakeWordIsStub;

  /// Copy with overrides.
  VoiceEngineReport copyWith({
    String? sttEngineId,
    bool? sttAvailable,
    bool? sttSimulated,
    String? ttsEngineId,
    bool? ttsAvailable,
    bool? ttsSimulated,
    String? wakeWordEngineId,
    bool? wakeWordIsStub,
  }) =>
      VoiceEngineReport(
        sttEngineId: sttEngineId ?? this.sttEngineId,
        sttAvailable: sttAvailable ?? this.sttAvailable,
        sttSimulated: sttSimulated ?? this.sttSimulated,
        ttsEngineId: ttsEngineId ?? this.ttsEngineId,
        ttsAvailable: ttsAvailable ?? this.ttsAvailable,
        ttsSimulated: ttsSimulated ?? this.ttsSimulated,
        wakeWordEngineId: wakeWordEngineId ?? this.wakeWordEngineId,
        wakeWordIsStub: wakeWordIsStub ?? this.wakeWordIsStub,
      );

  @override
  bool operator ==(Object other) =>
      other is VoiceEngineReport &&
      other.sttEngineId == sttEngineId &&
      other.sttAvailable == sttAvailable &&
      other.sttSimulated == sttSimulated &&
      other.ttsEngineId == ttsEngineId &&
      other.ttsAvailable == ttsAvailable &&
      other.ttsSimulated == ttsSimulated &&
      other.wakeWordEngineId == wakeWordEngineId &&
      other.wakeWordIsStub == wakeWordIsStub;

  @override
  int get hashCode => Object.hash(
        sttEngineId,
        sttAvailable,
        sttSimulated,
        ttsEngineId,
        ttsAvailable,
        ttsSimulated,
        wakeWordEngineId,
        wakeWordIsStub,
      );
}

/// Immutable snapshot of the voice pipeline.
@immutable
class VoiceState {
  /// Creates a voice state.
  const VoiceState({
    this.phase = VoicePhase.idle,
    this.mode = VoiceInputMode.none,
    this.transcript = '',
    this.partialTranscript = '',
    this.errorCode,
    this.localeCode = 'en',
    this.microphoneEnabled = false,
    this.wakeWordEnabled = false,
    this.listeningServiceState = 'stopped',
    this.level = 0,
    this.engines = const VoiceEngineReport(),
    this.lastSpoken = '',
    this.autoSpeak = true,
    this.captureStartedAt,
  });

  /// Current phase.
  final VoicePhase phase;

  /// How the last capture was started.
  final VoiceInputMode mode;

  /// Final transcript of the last capture (empty while listening).
  final String transcript;

  /// Growing transcript while [VoicePhase.listening].
  final String partialTranscript;

  /// Stable, non-sensitive error code (`microphone_permission_required`, …).
  final String? errorCode;

  /// Active language (`en` or `bn`).
  final String localeCode;

  /// The user's in-app microphone switch (default OFF; a privacy gate, not an OS grant).
  final bool microphoneEnabled;

  /// Whether wake-word mode is armed.
  final bool wakeWordEnabled;

  /// Phase reported by the Android foreground service (`stopped`, `running`, `paused`, …).
  final String listeningServiceState;

  /// Input level 0.0–1.0 while listening, for the level meter. No audio is retained.
  final double level;

  /// Which engines are attached.
  final VoiceEngineReport engines;

  /// Text most recently handed to text-to-speech.
  final String lastSpoken;

  /// Whether assistant replies are spoken automatically.
  final bool autoSpeak;

  /// When the current capture opened (used for the minimum-sample-duration rule).
  final DateTime? captureStartedAt;

  /// Transcript to display: the partial one wins while listening.
  String get displayTranscript =>
      partialTranscript.isNotEmpty ? partialTranscript : transcript;

  /// Whether a capture is in progress or being resolved.
  bool get isCapturing =>
      phase == VoicePhase.arming ||
      phase == VoicePhase.listening ||
      phase == VoicePhase.transcribing;

  /// Whether the assistant is producing or playing a reply.
  bool get isResponding => phase == VoicePhase.thinking || phase == VoicePhase.speaking;

  /// Orb state that matches the current phase (single mapping, used by every screen).
  String get orbPhaseName => switch (phase) {
        VoicePhase.arming || VoicePhase.listening || VoicePhase.transcribing => 'listening',
        VoicePhase.thinking => 'thinking',
        VoicePhase.speaking => 'speaking',
        VoicePhase.error || VoicePhase.unsupported => 'locked',
        VoicePhase.idle => 'idle',
      };

  /// Copy with overrides. [clearError] / [clearCaptureStart] remove nullable fields.
  VoiceState copyWith({
    VoicePhase? phase,
    VoiceInputMode? mode,
    String? transcript,
    String? partialTranscript,
    String? errorCode,
    bool clearError = false,
    String? localeCode,
    bool? microphoneEnabled,
    bool? wakeWordEnabled,
    String? listeningServiceState,
    double? level,
    VoiceEngineReport? engines,
    String? lastSpoken,
    bool? autoSpeak,
    DateTime? captureStartedAt,
    bool clearCaptureStart = false,
  }) =>
      VoiceState(
        phase: phase ?? this.phase,
        mode: mode ?? this.mode,
        transcript: transcript ?? this.transcript,
        partialTranscript: partialTranscript ?? this.partialTranscript,
        errorCode: clearError ? null : (errorCode ?? this.errorCode),
        localeCode: localeCode ?? this.localeCode,
        microphoneEnabled: microphoneEnabled ?? this.microphoneEnabled,
        wakeWordEnabled: wakeWordEnabled ?? this.wakeWordEnabled,
        listeningServiceState: listeningServiceState ?? this.listeningServiceState,
        level: level ?? this.level,
        engines: engines ?? this.engines,
        lastSpoken: lastSpoken ?? this.lastSpoken,
        autoSpeak: autoSpeak ?? this.autoSpeak,
        captureStartedAt:
            clearCaptureStart ? null : (captureStartedAt ?? this.captureStartedAt),
      );
}
