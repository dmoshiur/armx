<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# Voice pipeline (step 4)

Push-to-talk, wake-word mode, speech recognition and text-to-speech — English and Bengali —
plus the voice half of the verification stack.

## What is wired

| Piece | Where | Notes |
| --- | --- | --- |
| Speech-to-text | `features/voice/voice_engines.dart` (`PluginSpeechToTextEngine`) | `speech_to_text 7.5.0`; `en_US` / `bn_BD`; on-device recognition, partial results, level stream |
| Text-to-speech | same file (`PluginSpeechSynthesisEngine`) | `flutter_tts 4.2.5`; `en-US` / `bn-BD`; `awaitSpeakCompletion` |
| Simulated pair | same file (`SimulatedSpeechToTextEngine`, `SimulatedSpeechSynthesisEngine`) | Used where the platform has no engine (Linux/web) and in tests. **Captures no audio** and is labelled `simulated` in the UI |
| Push-to-talk | `features/voice/voice_controller.dart` + `widgets/voice_widgets.dart` | Raw pointer events (no long-press delay), 30 s watchdog, release-to-send |
| Wake word | `features/voice/wake_word.dart` | `NativeWakeWordAdapter` (Android foreground service) / `StubWakeWordAdapter`; detector adapter point documented below |
| Spoken replies | voice controller, `_listenForAssistantReplies` | Watches the transcript for a finished assistant message; one-way dependency (voice → chat) |
| Voice factor | `core/security/voice_verification_gateway.dart` | Challenge phrase + minimum duration; **voice-only evidence** |
| Verification composition | `core/security/composite_verification_gateway.dart` | Face + voice (+ system biometric) merged for `RiskPolicy` |
| Screen | `features/voice/voice_page.dart` | Route `/settings/voice`, reachable from Settings → Voice and the chat composer's microphone button |

## Rules this feature must not break

1. **Voice alone is never sufficient.** `VoiceVerificationGateway` adds exactly one factor
   (`voice`), and `RiskPolicy` refuses voice-only evidence for *every* tier — including LOW,
   where the spec's "face OR voice" reads as a conflict with "voice alone is never trusted".
   `test/unit/core/security/voice_verification_test.dart` pins this down (RULE 1 test).
2. **The microphone is a local gate, default OFF.** `VoiceState.microphoneEnabled` mirrors
   `PreferenceKeys.microphoneEnabled`; with it off, push-to-talk refuses
   (`microphone_switch_off`), wake word cannot be armed, and disabling it cancels a running
   capture.
3. **Background listening is visible.** Wake-word mode on Android runs behind the
   foreground-service notification with `Pause` / `Stop` / `KILL-SWITCH` actions. On
   platforms without that service the mode is refused with
   `background_listening_unsupported` — the app never falls back to a hidden listener.
4. **No audio leaves the device.** Only a transcript (for dictation) or a pass/fail plus a
   match ratio (for the voice factor) crosses the engine boundary. Nothing is uploaded.
5. **Engine honesty.** Every screen that can use the microphone names the attached engine
   and marks simulated/stub engines as such.

## The wake-word adapter point

```
Android:  ArmxListenService (foreground, persistent notification)
             └── voice/WakeWordEngine  ← real detector goes here (porcupine / openWakeWord / ONNX)
                   └── ArmxListenEventBus → EventChannel → NativeWakeWordAdapter → VoiceController
Dart/desktop: StubWakeWordAdapter (never listens; the desktop wake path is the global hotkey)
```

A production detector must:

* call `Listener.onWakeWordDetected()` **only** after a local match;
* never persist or forward raw PCM (no audio, no transcript, no telemetry);
* release the microphone in `pause()` and `close()`.

Until such a detector is bundled, the native engine reports `isAvailable = false`, the
service still shows its notification while armed, and the voice screen says plainly that no
audio is captured (rule 7 + rule 3 of the product spec).

## Verification today

* `test/unit/features/voice/voice_state_test.dart` — state/orb contract, copyWith semantics.
* `test/unit/features/voice/voice_controller_test.dart` — microphone gate, partial
  transcripts, release-to-send into the chat, wake-word refusals, stub simulation, TTS,
  cancel-on-disable.
* `test/unit/core/security/voice_verification_test.dart` — challenge matching, minimum
  duration, `voiceNotHeard`/`voiceTooShort`, voice-only evidence, RULE 1 regression.
* `test/widget/voice/voice_page_test.dart` — privacy copy, localized refusal, engine rows,
  verification notice.

The Android foreground service, the Quick Settings tile and the real detector still need a
physical-device pass: see the matrix in [`assistant-mode.md`](assistant-mode.md).
