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
| `WAKE_WORD_ENGINE` | `stub` | `stub` (no audio) or a registered engine id (see below). |
| `FACE_MATCH_THRESHOLD` | `0.72` | Cosine-similarity threshold for a face match (clamped to 0.10–0.99). |
| `TELEMETRY` | `false` | Opt-in only. Never includes biometrics or tokens. |

**No secret is ever committed.** Anything sensitive (device key, tokens, certificate pins for
a private deployment) is supplied at build time through `--dart-define-from-file` or the CI
secret store, and stored at rest in `flutter_secure_storage`.

## 4. Wake word

Wake-word detection sits behind `WakeWordEngine` (`features/voice/`). The default `stub`
engine never opens the microphone and reports `unavailable`, so push-to-talk is the only
audio path until an engine is registered. To wire a real one:

1. add the plugin (for example `picovoice_porcupine` or an openWakeWord FFI binding);
2. implement `WakeWordEngine` with the engine id you pass to `WAKE_WORD_ENGINE`;
3. register it in the voice feature's engine list.

Porcupine needs a licensed AccessKey and openWakeWord needs an ONNX/TFLite model plus the
"Armex" wake phrase trained — both are deployment decisions, which is why neither is in the
dependency list.

## 5. Tests

```bash
flutter analyze                              # must be warning-free
flutter test                                 # unit + widget + golden
flutter test --coverage                      # writes coverage/lcov_coverage.info

# 70 % line coverage gate over core/ and data/ only
lcov --remove coverage/lcov_coverage.info 'lib/features/*' -o coverage/core_data.info
genhtml coverage/core_data.info -o coverage/html

flutter test integration_test                 # pair → chat → approve → kill-switch
```

Goldens are regenerated deliberately, never automatically:

```bash
flutter test --update-goldens test/golden
```

## 6. Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| `Target of URI doesn't exist: 'app_localizations.dart'` | Run `flutter gen-l10n` (or `flutter pub get`, which triggers it because `generate: true`). |
| `part 'x.freezed.dart'` missing | Run `dart run build_runner build --delete-conflicting-outputs`. |
| Every request fails with a network error | `MockBackendControl.offline` is switched on (Diagnostics screen) or `USE_MOCK=false` with no server. |
| Vision screen shows "model missing" | Drop `face_embedding.tflite` into `assets/models/` — see that folder's README. |
| Wake word never fires | Expected with `WAKE_WORD_ENGINE=stub`; use push-to-talk or wire an engine. |
| `flutter test` golden failures after a theme tweak | Re-run with `--update-goldens` **after** confirming the visual change is intentional. |

## 7. Security checklist for a build

1. `APP_ENV=production` (TLS enforced, cleartext rejected, certificate pinning active).
2. `flutter build apk --obfuscate --split-debug-info=build/symbols` (or the desktop equivalent).
3. Confirm no screenshot of a sensitive screen: `ScreenSecurity` is enabled on unlock,
   vision, pairing and settings screens while they show secrets.
4. Confirm the Diagnostics screen shows redacted logs only (`LogRedactor`).
