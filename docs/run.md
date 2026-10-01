<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# Running A.R.M.X AI

The client runs **fully offline against the in-app mock backend** by default. No FastAPI
server, ESP32 node or unlock agent is required to exercise every screen and test.

## 1. Prerequisites

| Tool | Version |
| --- | --- |
| Flutter | 3.47.5 (stable) |
| Dart | 3.13.4 |
| Android SDK | API 34+ for the Android target |
| Desktop | Visual Studio 2022 (Windows) / `clang`, `ninja-build`, `libgtk-3-dev` (Linux) |

```bash
flutter --version          # expect 3.47.5 / Dart 3.13.4
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # freezed/json/drift/riverpod
flutter gen-l10n                                           # lib/l10n/generated/
```

Generated files (`*.freezed.dart`, `*.g.dart`, `lib/l10n/generated/`) are **not** committed;
`flutter analyze` fails until the two commands above have run once.

## 2. Run

```bash
# Mock backend, development environment (defaults, no dart-defines needed)
flutter run

# Bengali-first smoke check
flutter run --dart-define=APP_ENV=development --dart-define=USE_MOCK=true

# Point at a real server later (TLS only; cleartext is rejected in release builds)
flutter run --dart-define=APP_ENV=staging \
            --dart-define=USE_MOCK=false \
            --dart-define=API_BASE_URL=https://api.armx.example
```

Desktop targets:

```bash
flutter run -d windows
flutter run -d linux
```

## 3. Compile-time configuration (`--dart-define`)

| Define | Default | Meaning |
| --- | --- | --- |
| `APP_ENV` | `development` | `development`, `staging` or `production`. Only `production` enforces the strict TLS/pinning rules. |
| `USE_MOCK` | `true` | Uses the deterministic in-memory backend. Set to `false` once a server exists. |
| `API_BASE_URL` | `https://api.armx.local` | REST base URL. |
| `WS_URL` | derived (`wss://…/ws`) | Explicit socket URL; otherwise derived from `API_BASE_URL`. |
| `LOG_LEVEL` | `info` | `trace`, `debug`, `info`, `warning`, `error`, `off`. |
| `CERT_PINS` | empty | Comma-separated SHA-256 SPKI pins for the certificate-pinning hook. Empty = pinning disabled (development only). |
| `MOCK_LATENCY_MS` | `120` | Simulated round-trip latency so loading states are visible. |
| `WAKE_WORD_ENGINE` | `stub` | Reserved configuration; Android currently selects the native no-audio stub regardless of this define (see below). |
| `FACE_MATCH_THRESHOLD` | `0.72` | Cosine-similarity threshold for a face match (clamped to 0.10–0.99). |
| `TELEMETRY` | `false` | Opt-in only. Never includes biometrics or tokens. |

**No secret is ever committed.** Anything sensitive (device key, tokens, certificate pins for
a private deployment) is supplied at build time through `--dart-define-from-file` or the CI
secret store, and stored at rest in `flutter_secure_storage`.

## 4. Wake word

Android wake-word engines implement the native `WakeWordEngine` contract in
`android/app/src/main/kotlin/top/thamjj13/armx/voice/`. The foreground service owns the
engine lifecycle. Its factory currently selects `StubWakeWordEngine`, which never opens the
microphone and never emits a wake event; Android background voice capture is therefore not
active yet. No push-to-talk/STT voice flow is present in this checkout either; use text chat.

To register a real adapter, implement `WakeWordEngine` and change the factory only after the
deployment has selected an engine, model, licensing, and privacy review. The stub currently
remains selected regardless of the reserved `WAKE_WORD_ENGINE` Dart define; that define is
not read by the native service. The boundary and privacy requirements are in
[`assistant-mode.md`](assistant-mode.md) and [`wake-word-adapters.md`](wake-word-adapters.md).

Porcupine requires a licensed AccessKey; openWakeWord requires an ONNX/TFLite runtime and a
model trained for "Armex". Neither engine package, runtime, key, nor model is bundled here.

## 5. Tests

```bash
flutter analyze                              # must be warning-free
flutter test                                 # unit + widget + golden
flutter test --coverage                      # writes coverage/lcov_coverage.info

# 70 % line coverage gate over core/ and data/ only
lcov --remove coverage/lcov_coverage.info 'lib/features/*' -o coverage/core_data.info
genhtml coverage/core_data.info -o coverage/html

flutter test integration_test                 # step 2: pair → approve → login → resume locked → unlock → dashboard
```

Step-2 suites live in `test/unit/features/auth/` (PIN store, auto-lock policy, rate
limiter, session refresh, pairing machine), `test/unit/data/auth_interceptor_test.dart`,
`test/widget/auth/` (pairing, login, lock) and `test/golden/auth_golden_test.dart`.

Step-3 suites live in `test/unit/features/chat/chat_controller_test.dart` (streaming,
LOW/MEDIUM/HIGH approvals, kill-switch, failed-send retry, transcript persistence) and
`test/widget/chat/chat_page_test.dart` (empty state, streamed reply + approval cards,
denial, kill-switch banner, Bengali rendering).

Goldens are regenerated deliberately, never automatically:

```bash
flutter test --update-goldens test/golden
```

Run that once before the first `flutter test` run on a fresh checkout: the step-2
baselines (`login_*`, `pairing_*`, `lock_*`) are generated that way and reviewed by eye.

## 6. Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| `Target of URI doesn't exist: 'app_localizations.dart'` | Run `flutter gen-l10n` (or `flutter pub get`, which triggers it because `generate: true`). |
| `part 'x.freezed.dart'` missing | Run `dart run build_runner build --delete-conflicting-outputs`. |
| Every request fails with a network error | `MockBackendControl.offline` is switched on (Diagnostics screen) or `USE_MOCK=false` with no server. |
| Vision screen shows "model missing" | Drop `face_embedding.tflite` into `assets/models/` — see that folder's README. |
| Wake word never fires | Expected: the native service still uses `StubWakeWordEngine`, which opens no microphone. Wire and review a real adapter before enabling capture. |
| `flutter test` golden failures after a theme tweak | Re-run with `--update-goldens` **after** confirming the visual change is intentional. |

## 7. Security checklist for a build

1. `APP_ENV=production` (TLS enforced, cleartext rejected, certificate pinning active).
2. `flutter build apk --obfuscate --split-debug-info=build/symbols` (or the desktop equivalent).
3. Confirm no screenshot of a sensitive screen: `ScreenSecurity` is enabled on unlock,
   vision, pairing and settings screens while they show secrets.
4. Confirm the Diagnostics screen shows redacted logs only (`LogRedactor`).
