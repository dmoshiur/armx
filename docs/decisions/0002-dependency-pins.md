<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# Decision 0002 — dependency pins

Status: accepted (Step 1). Every runtime dependency in `pubspec.yaml` is pinned to an exact
version (`1.2.3`, never `^1.2.3`) so that a clone, CI run and release build resolve the same
graph. Bumping a pin is a reviewed change.

## Why exact pins

* Reproducible release builds — the APK/desktop bundles that were tested are the ones shipped.
* Plugin breakage is loud and intentional: `flutter pub get` fails instead of silently
  pulling a new major version of a camera/ML plugin.
* The app targets Flutter **3.47.5 / Dart 3.13.4** (stable, 2026-09-18). Floors are
  `sdk: >=3.12.0 <4.0.0` and `flutter: >=3.44.0` because `flutter_riverpod 3.4.3` and
  `camera 0.12.1` both require Dart `^3.12.0` / Flutter `>=3.44.0`.

## Substitutions (and why)

| Requested / expected | Actually used | Reason |
| --- | --- | --- |
| `package:crypto` | `cryptography 2.9.0` | `package:crypto` has no Ed25519 signing API. `cryptography` provides Ed25519, SHA-256 and constant-time helpers, with a pure-Dart fallback when the platform has no native implementation. |
| MediaPipe hands | `google_mlkit_pose_detection 0.14.1` | There is no maintained Flutter MediaPipe-hands plugin. Palm gestures are derived from pose hand landmarks (wrist/thumb/index/pinky), which the ML Kit plugin exposes on Android. |
| `package:pedometer` / custom step plugin | `flutter_activity_recognition 4.0.0` | One plugin for `STILL / WALKING / RUNNING / IN_VEHICLE / ON_BICYCLE`, which is exactly what the WHEN/THEN rule engine consumes. |
| `sqlite3_flutter_libs` (direct) | via `drift_flutter 0.3.1` | `drift_flutter` already wires SQLite + path resolution per platform (Android, Windows, Linux, macOS). Adding the native lib directly duplicated the version constraint. |
| `package_info_plus` | `core/config/app_info.dart` | The version/credit strings are constants in one file, so no plugin, no platform channel, and no risk of a test reading the wrong bundle version. Bump `AppInfo` together with `pubspec.yaml`. |
| `flutter_markdown` | `core/widgets/sanitized_markdown.dart` | Assistant output is untrusted text. The third-party renderer would interpret links/images/HTML for us. We render a deliberate subset (headings, bold, italic, inline code, bullets, quotes, fenced code) and turn links into visible, inert text. |
| `wake word: picovoice_porcupine / openWakeWord` | in-app `WakeWordEngine` interface with a stub default | The porcupine plugin needs a licensed AccessKey (a secret) and the openWakeWord bindings are not published on pub.dev. Step 4 ships the interface plus the stub; wiring a real engine means adding one plugin and one class — see `docs/run.md`. |

## Version highlights worth remembering

* `riverpod_generator 4.0.9` pairs with `riverpod_annotation 4.0.7`; generated providers are
  **non-const** (`final appRouter = ...`), so `@Riverpod(keepAlive: true)` outputs are `final`.
* `freezed 4.0.2` requires `freezed_annotation 3.1.0` and `json_serializable 6.14.1`.
* `intl 0.20.3` is the version `flutter_localizations` pins on Flutter 3.47 — do not bump it
  alone or `flutter pub get` will fail with a conflicting constraint.
* `google_mlkit_*`, `camera` and `local_auth` are Android/iOS-first. Desktop builds still
  compile and run; the platform-capability layer degrades those screens to an explanatory
  state instead of crashing.

## Code generation

`build_runner` generates `*.freezed.dart` / `*.g.dart`, and `flutter gen-l10n` generates
`lib/l10n/generated/`. Neither is committed. Run:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```
