<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# Assistant mode — deliveries 1 and 2

**Status:** Android foreground-service bridge, notification, lifecycle controls, and a
no-audio `WakeWordEngine` stub are present. The real detector, popup, voice interaction
role, readiness screen, desktop tray, and full test matrix are not implemented yet.

## What exists now

* `ArmxListenService` is a non-exported Android foreground service declared with
  `foregroundServiceType="microphone"`.
* The ongoing, low-importance notification offers **Talk**, **Pause/Resume listening**, and
  **KILL-SWITCH**. At this stage, **Talk opens the full app**; it is not a popup yet. The
  native kill action stops this service and persists the red/killed state; it does not close
  an app/backend WebSocket, which remains for the later kill-switch wiring delivery.
* Android persists the service phase and uses `START_STICKY` to recover from an ordinary
  system process reclaim. A user force-stop cannot be restarted by the app.
* `ArmxListeningService` exposes the Flutter bridge and Settings shows the live service
  phase. The MethodChannel methods are `status`, `start`, `pause`, `resume`, `stop`, and
  `killSwitch`. EventChannel types are `status`, `error`, and `wakeWordDetected`; the default
  stub never emits a wake event.
* Android `WakeWordEngine` is a newly added lifecycle contract; the service factory selects
  `StubWakeWordEngine`, which never opens audio. A real engine would vibrate and emit a
  payload-free wake event after detection. Popup routing and STT remain later work.
* The app requests microphone and notification permissions while the app UI is visible.
  Notification text follows the app's English/Bengali locale supplied at service start. The
  manifest comments document the permissions included in this phase.

## Important behavior and privacy boundary

The foreground service still has **no active wake-word detector**: its default stub does
not open the microphone, record audio, save audio, or transmit audio. `wakeWordEngineReady`
remains `false`, and the notification and in-app status say this explicitly. The Kotlin
interface and adapter guidance exist, but a real engine/model/runtime has not been selected
or integrated; see [`wake-word-adapters.md`](wake-word-adapters.md).

Start the service from the visible app. Android 14+ requires a microphone foreground service
and blocks starting one from an ordinary background context. Android 12+ may show the system
microphone privacy indicator once microphone capture is added; the app does not attempt to
hide it. There is no `BOOT_COMPLETED` receiver. After reboot, open A.R.M.X and start the
service again; this is explained in the Settings card. Android's keyguard is not modified.

The service is Android-only in this phase. Desktop background listening is explicitly
unavailable until the desktop delivery.

## Platform/build assumptions and verification

The repository did not contain an Android host project, `PROJECT_SPEC.md`, or the
`WakeWordEngine` interface referenced by the larger prompt (the repository README still has
voice as a future step). Delivery 2 therefore adds only a small native lifecycle contract
and safe no-audio stub; it does not claim compatibility with an absent voice API. The
Android host uses the repository's `top.thamjj13.armx` application ID and pins AGP 8.11.1,
Kotlin Gradle plugin 2.2.20, and Gradle 8.14.3 as a compatibility baseline for the README's
Flutter 3.47.5 toolchain. The Gradle 8.14.3 wrapper scripts and JAR are included from the
upstream release (Apache-2.0 licensed). The sandbox has no Flutter, Dart, Java, or Android SDK, so
Dart analysis, Android compilation, `./gradlew lint`, and device behavior could not be
verified; Gradle may also need to download its pinned distribution on first run.

No real Android device, notification permission prompt, process reclaim, OEM behavior, or
Android 14+ foreground-service start was exercised. Do not treat the presence of this
skeleton as proof of hardware or Play policy approval.
