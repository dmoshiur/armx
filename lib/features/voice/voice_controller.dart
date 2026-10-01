// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/security/voice_verification_gateway.dart';
import '../../data/models/chat.dart';
import '../../data/models/preferences.dart';
import '../chat/chat_controller.dart';
import '../chat/chat_state.dart';
import 'voice_engines.dart';
import 'voice_state.dart';
import 'wake_word.dart';

/// Speech-to-text engine for the running platform (overridden in tests).
final Provider<SpeechToTextEngine> speechToTextEngineProvider =
    Provider<SpeechToTextEngine>((Ref ref) {
  final engine = VoiceEngineFactory.speechToText();
  ref.onDispose(() => unawaited(engine.dispose()));
  return engine;
});

/// Text-to-speech engine for the running platform (overridden in tests).
final Provider<SpeechSynthesisEngine> speechSynthesisEngineProvider =
    Provider<SpeechSynthesisEngine>((Ref ref) {
  final engine = VoiceEngineFactory.speechSynthesis();
  ref.onDispose(() => unawaited(engine.dispose()));
  return engine;
});

/// Wake-word adapter for the running platform (overridden in tests).
final Provider<WakeWordAdapter> wakeWordAdapterProvider = Provider<WakeWordAdapter>((Ref ref) {
  final adapter = NativeWakeWordAdapter();
  if (!adapter.isSupported) {
    return StubWakeWordAdapter();
  }
  ref.onDispose(() => unawaited(adapter.close()));
  return adapter;
});

/// On-device voice-factor probe used by the composite verification gateway.
final Provider<VoiceSampleProbe> voiceSampleProbeProvider = Provider<VoiceSampleProbe>((Ref ref) {
  return VoiceSampleProbe(
    engine: ref.watch(speechToTextEngineProvider),
    clock: ref.watch(clockProvider),
  );
});

/// Owns the voice pipeline: push-to-talk, wake-word mode, speech recognition and TTS.
///
/// Enforced here (not in the widgets):
/// * the microphone preference is a **local, default-OFF** gate that the user controls on
///   their own device, and no remote party can change it;
/// * wake-word mode always runs behind the platform's visible indicator (the Android
///   foreground-service notification) or is refused with
///   `background_listening_unsupported` — there is no hidden listening path;
/// * a voice-only sample never counts as verification (see [VoiceVerificationGateway]).
final NotifierProvider<VoiceController, VoiceState> voiceControllerProvider =
    NotifierProvider<VoiceController, VoiceState>(VoiceController.new);

/// Voice pipeline controller.
class VoiceController extends Notifier<VoiceState> {
  Timer? _wakeWindow;
  Timer? _captureWatchdog;
  StreamSubscription<WakeWordSignal>? _wakeSubscription;
  bool _disposed = false;

  /// How long a wake-word capture stays open before it is sent (or dropped).
  static const Duration wakeWordCaptureWindow = Duration(seconds: 6);

  /// Hard limit on a push-to-talk capture, so a stuck button cannot hold the mic open.
  static const Duration pushToTalkWatchdog = Duration(seconds: 30);

  @override
  VoiceState build() {
    final preferences = ref.read(appPreferencesProvider).value;
    final stt = ref.read(speechToTextEngineProvider);
    final tts = ref.read(speechSynthesisEngineProvider);
    final wake = ref.read(wakeWordAdapterProvider);

    ref.listen<AsyncValue<AppPreferences>>(appPreferencesProvider, (previous, next) {
      final value = next.value;
      if (value == null || _disposed) {
        return;
      }
      state = state.copyWith(
        microphoneEnabled: value.microphoneEnabled,
        wakeWordEnabled: value.wakeWordEnabled,
        autoSpeak: value.ttsAutoSpeak,
        localeCode: _localeOf(value.language),
      );
    });
    ref.onDispose(_teardown);
    _listenForAssistantReplies();
    scheduleMicrotask(_attachWakeWordSignals);

    return VoiceState(
      microphoneEnabled: preferences?.microphoneEnabled ?? false,
      wakeWordEnabled: preferences?.wakeWordEnabled ?? false,
      autoSpeak: preferences?.ttsAutoSpeak ?? true,
      localeCode: _localeOf(preferences?.language ?? 'system'),
      engines: VoiceEngineReport(
        sttEngineId: stt.engineId,
        sttAvailable: stt.isAvailable,
        ttsEngineId: tts.engineId,
        ttsAvailable: tts.isAvailable,
        ttsSimulated: tts.isSimulated,
        wakeWordEngineId: wake.engineId,
        wakeWordIsStub: wake.isStub,
      ),
      phase: stt.isAvailable ? VoicePhase.idle : VoicePhase.unsupported,
    );
  }

  void _teardown() {
    _disposed = true;
    _wakeWindow?.cancel();
    _captureWatchdog?.cancel();
    unawaited(_wakeSubscription?.cancel());
    unawaited(ref.read(speechToTextEngineProvider).cancelListening());
    unawaited(ref.read(speechSynthesisEngineProvider).stop());
  }

  Future<void> _attachWakeWordSignals() async {
    final adapter = ref.read(wakeWordAdapterProvider);
    if (!adapter.isSupported) {
      return;
    }
    _wakeSubscription = adapter.signals.listen((signal) {
      if (_disposed) {
        return;
      }
      switch (signal.kind) {
        case WakeWordSignalKind.detected:
          unawaited(_onWakeWordDetected());
        case WakeWordSignalKind.serviceState:
          state = state.copyWith(listeningServiceState: signal.state);
        case WakeWordSignalKind.error:
          state = state.copyWith(
            phase: VoicePhase.error,
            errorCode: signal.errorCode ?? 'wake_word_engine_error',
            wakeWordEnabled: false,
          );
      }
    });
  }

  // ---- Privacy switches ----------------------------------------------------

  /// Turns the in-app microphone gate on or off. Off cancels any capture and disarms the
  /// wake word: the microphone is then never opened, by any feature.
  Future<void> setMicrophoneEnabled(bool enabled) async {
    await ref.read(preferencesRepositoryProvider).setMicrophoneEnabled(enabled);
    state = state.copyWith(microphoneEnabled: enabled, clearError: true);
    if (!enabled) {
      await cancelCapture();
      await setWakeWordEnabled(false);
    }
  }

  /// Enables or disables automatic playback of assistant replies.
  Future<void> setAutoSpeak(bool enabled) async {
    await ref.read(preferencesRepositoryProvider).setTtsAutoSpeak(enabled);
    state = state.copyWith(autoSpeak: enabled);
    if (!enabled) {
      await stopSpeaking();
    }
  }

  /// Switches the recognition/playback language (`en` / `bn`).
  void setLocaleCode(String localeCode) {
    state = state.copyWith(localeCode: localeCode);
  }

  /// Dismisses the current error banner.
  void clearError() => state = state.copyWith(clearError: true, phase: VoicePhase.idle);

  // ---- Push-to-talk --------------------------------------------------------

  /// Opens the microphone for a push-to-talk capture.
  ///
  /// Returns false (with [VoiceState.errorCode] set) when the mic is switched off, the
  /// permission is missing, or the platform has no recognizer.
  Future<bool> startPushToTalk() async {
    if (!state.microphoneEnabled) {
      state = state.copyWith(errorCode: 'microphone_switch_off', phase: VoicePhase.error);
      return false;
    }
    if (state.isCapturing) {
      return false;
    }
    final engine = ref.read(speechToTextEngineProvider);
    if (!engine.isAvailable) {
      state = state.copyWith(errorCode: 'stt_unavailable', phase: VoicePhase.unsupported);
      return false;
    }

    state = state.copyWith(
      phase: VoicePhase.arming,
      mode: VoiceInputMode.pushToTalk,
      clearError: true,
      partialTranscript: '',
      transcript: '',
      captureStartedAt: ref.read(clockProvider).now().toUtc(),
    );

    final ready = await engine.initialize(
      localeCode: state.localeCode,
      onError: (code) {
        if (!_disposed) {
          state = state.copyWith(phase: VoicePhase.error, errorCode: code);
        }
      },
    );
    if (!ready) {
      state = state.copyWith(errorCode: 'stt_unavailable', phase: VoicePhase.error);
      return false;
    }

    await engine.startListening(
      localeCode: state.localeCode,
      onResult: (words, isFinal) {
        if (_disposed) {
          return;
        }
        state = isFinal
            ? state.copyWith(transcript: words, partialTranscript: '')
            : state.copyWith(partialTranscript: words);
      },
      onLevel: (level) {
        if (!_disposed) {
          state = state.copyWith(level: level.clamp(0.0, 1.0));
        }
      },
    );
    if (_disposed) {
      return false;
    }
    state = state.copyWith(phase: VoicePhase.listening);
    _captureWatchdog?.cancel();
    _captureWatchdog = Timer(pushToTalkWatchdog, () {
      unawaited(stopPushToTalk(sendToAssistant: true));
    });
    return true;
  }

  /// Closes the microphone and returns the final transcript.
  ///
  /// With [sendToAssistant] the transcript is handed to the chat controller, which is what
  /// makes "hold to talk" behave exactly like typing the same sentence.
  Future<String> stopPushToTalk({bool sendToAssistant = false}) async {
    if (state.phase != VoicePhase.listening && state.phase != VoicePhase.arming) {
      return state.transcript;
    }
    _captureWatchdog?.cancel();
    state = state.copyWith(phase: VoicePhase.transcribing);
    final engine = ref.read(speechToTextEngineProvider);
    final finalText = await engine.stopListening();
    if (_disposed) {
      return finalText;
    }
    final text = finalText.trim().isEmpty ? state.displayTranscript.trim() : finalText.trim();
    state = state.copyWith(
      transcript: text,
      partialTranscript: '',
      level: 0,
      clearCaptureStart: true,
      phase: VoicePhase.idle,
    );
    if (sendToAssistant && text.isNotEmpty) {
      await _sendToAssistant(text);
    }
    return text;
  }

  /// Abandons the current capture without sending anything.
  Future<void> cancelCapture() async {
    if (!state.isCapturing) {
      return;
    }
    _captureWatchdog?.cancel();
    await ref.read(speechToTextEngineProvider).cancelListening();
    if (!_disposed) {
      state = state.copyWith(
        phase: VoicePhase.idle,
        partialTranscript: '',
        level: 0,
        clearCaptureStart: true,
      );
    }
  }

  Future<void> _sendToAssistant(String text) async {
    state = state.copyWith(phase: VoicePhase.thinking);
    try {
      await ref.read(chatControllerProvider.notifier).send(text);
    } on AppException catch (error) {
      state = state.copyWith(phase: VoicePhase.error, errorCode: error.code);
      return;
    }
    if (!_disposed) {
      state = state.copyWith(phase: VoicePhase.idle);
    }
  }

  // ---- Wake-word mode ------------------------------------------------------

  /// Arms or disarms wake-word listening.
  ///
  /// Arming starts the platform's *visible* background listener. On platforms without one
  /// (desktop/web) this returns false and sets `background_listening_unsupported`; the UI
  /// offers the global hotkey instead of pretending to listen.
  Future<bool> setWakeWordEnabled(bool enabled) async {
    if (enabled && !state.microphoneEnabled) {
      state = state.copyWith(errorCode: 'microphone_switch_off', phase: VoicePhase.error);
      return false;
    }
    final adapter = ref.read(wakeWordAdapterProvider);
    if (enabled && !adapter.isSupported) {
      state = state.copyWith(
        errorCode: 'background_listening_unsupported',
        phase: VoicePhase.unsupported,
      );
      return false;
    }

    await ref.read(preferencesRepositoryProvider).setWakeWordEnabled(enabled);
    if (!enabled) {
      await adapter.stop();
      state = state.copyWith(
        wakeWordEnabled: false,
        listeningServiceState: 'stopped',
        clearError: true,
        phase: VoicePhase.idle,
      );
      return true;
    }

    final preferences = ref.read(appPreferencesProvider).value;
    final signal = await adapter.start(
      phrase: preferences?.wakeWordPhrase ?? 'Armex',
      sensitivity: preferences?.wakeWordSensitivity ?? 0.6,
      localeCode: state.localeCode,
    );
    if (signal.kind == WakeWordSignalKind.error) {
      state = state.copyWith(
        errorCode: signal.errorCode ?? 'wake_word_engine_error',
        phase: VoicePhase.error,
        wakeWordEnabled: false,
      );
      return false;
    }
    state = state.copyWith(
      wakeWordEnabled: true,
      listeningServiceState: signal.state.isEmpty ? 'running' : signal.state,
      clearError: true,
      phase: VoicePhase.idle,
      engines: state.engines.copyWith(wakeWordIsStub: adapter.isStub),
    );
    return true;
  }

  /// Fires a wake word without audio.
  ///
  /// Only meaningful while the no-audio stub is attached; the UI shows the button **only**
  /// then, as a demo aid, and the caption says the detector is a stub. A real adapter
  /// ignores this call, so this can never become a hidden trigger.
  void simulateWakeWord() {
    final adapter = ref.read(wakeWordAdapterProvider);
    if (!adapter.isStub) {
      return;
    }
    unawaited(_onWakeWordDetected());
  }

  Future<void> _onWakeWordDetected() async {
    if (_disposed || state.isCapturing) {
      return;
    }
    if (!state.microphoneEnabled) {
      return;
    }
    final started = await startPushToTalk();
    if (!started) {
      return;
    }
    state = state.copyWith(mode: VoiceInputMode.wakeWord);
    _wakeWindow?.cancel();
    _wakeWindow = Timer(wakeWordCaptureWindow, () {
      unawaited(stopPushToTalk(sendToAssistant: true));
    });
  }

  // ---- Speech playback -----------------------------------------------------

  /// Speaks [text] through the TTS engine.
  Future<void> speak(String text) async {
    final engine = ref.read(speechSynthesisEngineProvider);
    if (text.trim().isEmpty || !engine.isAvailable) {
      return;
    }
    await engine.stop();
    await engine.configure(localeCode: state.localeCode);
    if (_disposed) {
      return;
    }
    state = state.copyWith(phase: VoicePhase.speaking, lastSpoken: text, clearError: true);
    await engine.speak(text);
    if (!_disposed) {
      state = state.copyWith(phase: VoicePhase.idle);
    }
  }

  /// Stops playback immediately.
  Future<void> stopSpeaking() async {
    await ref.read(speechSynthesisEngineProvider).stop();
    if (!_disposed && state.phase == VoicePhase.speaking) {
      state = state.copyWith(phase: VoicePhase.idle);
    }
  }

  /// Speaks a finished assistant reply when auto-speak is on.
  ///
  /// The voice layer watches the conversation instead of the conversation calling the
  /// voice layer: that keeps the dependency one-way (voice → chat) and means *any* reply
  /// source — typed, push-to-talk, wake word, a desktop hotkey popup — is spoken with the
  /// same rule.
  Future<void> speakAssistantReply(String text) async {
    if (!state.autoSpeak) {
      return;
    }
    await speak(text);
  }

  /// Watches the transcript for a newly completed assistant message.
  void _listenForAssistantReplies() {
    ref.listen<ChatState>(chatControllerProvider, (previous, next) {
      if (_disposed || !state.autoSpeak || next.killed || next.isStreaming) {
        return;
      }
      for (final message in next.messages.reversed) {
        if (message.role != ChatRole.assistant ||
            message.status != ChatMessageStatus.sent) {
          continue;
        }
        if (message.id == _lastSpokenMessageId) {
          return;
        }
        _lastSpokenMessageId = message.id;
        unawaited(speakAssistantReply(_speakableText(message.text)));
        return;
      }
    });
  }

  /// Strips the markdown the transcript renders so TTS reads words, not punctuation.
  static String _speakableText(String text) => text
      .replaceAll(RegExp(r'```[^`]*```', dotAll: true), ' ')
      .replaceAll(RegExp(r'[#*_>`|]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _lastSpokenMessageId = '';

  static String _localeOf(String language) => language == 'bn' ? 'bn' : 'en';
}
