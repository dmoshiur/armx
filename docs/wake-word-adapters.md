<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# Wake-word engine adapters

## Current implementation

`WakeWordEngine` is a native Kotlin lifecycle contract used by `ArmxListenService`. The
factory currently returns `StubWakeWordEngine`. The stub reports unavailable, starts no
worker, opens no audio device, and emits no wake event. Therefore, a foreground service can
be active while **wake-word listening itself remains inactive**. The native status exposes
`wakeWordEngineReady=false` for the stub.

No third-party engine dependency, license key, model, or downloaded asset is included.

## Adapter boundary

A reviewed adapter must implement `start(listener)`, `pause()`, `resume()`, and `close()`.
It may notify `Listener.onWakeWordDetected()` only after an on-device match, and may send
only a stable, non-sensitive error code to `Listener.onError()`. Audio bytes, transcripts,
model inputs, and vendor exception text must not cross that callback boundary.

An adapter that captures microphone PCM must:

* start only after the app has microphone permission and `ArmxListenService` is foreground;
* run inference on-device and keep pre-wake audio in memory only;
* never persist, log, upload, or forward pre-wake audio;
* stop capture immediately on pause, service stop, permission loss, or close; and
* release its audio buffers and native handles in `close()`.

The service acknowledges a successful event with a brief vibration and emits a
`wakeWordDetected` EventChannel event with no audio or transcript payload. Popup routing and
STT are not connected yet; they belong to later deliveries.

## Deployment choices (not implemented)

* **Porcupine:** requires a deployment-owned licensed SDK/access key and a compatible
  `Armex` keyword model. No product API signatures or license terms are assumed here.
* **openWakeWord:** needs a supported Android inference/runtime integration and a model
  trained or converted for the `Armex` phrase. The Python project alone is not an Android
  runtime, so this repository does not claim an Android adapter exists.

Neither choice can be enabled by changing `WAKE_WORD_ENGINE` today: Android currently uses
`WakeWordEngineFactory`'s stub unconditionally. Implement and review an adapter, model
provenance, supported Android ABIs, licensing, thermal/battery cost, sensitivity mapping,
and privacy behavior before changing the factory.
