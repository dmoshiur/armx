<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# Verification — what "done" means here, and how to reproduce it

Two layers: an **offline layer** that runs anywhere (including an environment without the
Flutter SDK) and the **canonical layer** that needs the pinned toolchain. Steps 4–10 were
authored in an environment where only the offline layer could run — see
[`decisions/0003-verification-without-sdk.md`](decisions/0003-verification-without-sdk.md).

## 1. Offline layer (always runnable)

```bash
python3 tool/static_checks.py         # headers, imports, ARB parity, secrets, brackets
python3 tool/l10n_add.py keys.json    # add EN+BN keys atomically (authoring helper)
```

Exit code 0 means: every new file carries the licence header, every import target exists,
EN and BN carry exactly the same localization keys with identical placeholders, no cleartext
URL or hardcoded secret was introduced, and no new file depends on `build_runner` output
(decision 0004).

## 2. Canonical layer (needs Flutter 3.47.5 / Dart 3.13.4)

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter analyze                                   # must be warning-free
flutter test                                      # unit + widget + golden
flutter test --coverage
lcov --remove coverage/lcov_coverage.info 'lib/features/*' -o coverage/core_data.info
python3 tool/coverage_gate.py coverage/core_data.info 70   # core/ + data/ ≥ 70 %
flutter test integration_test                     # needs a device/emulator/display
```

`tool/coverage_gate.py` is the same gate CI enforces; the threshold matches
`docs/run.md` (70 % lines over `core/` and `data/`).

## 3. What each step report claims

| Claim | Evidence |
| --- | --- |
| "code written and wired" | file list + `git show --stat` of the step commit |
| "static checks pass" | `python3 tool/static_checks.py` output in the step report |
| "analyze clean / tests pass" | **CI** (`.github/workflows/ci.yml`) — not claimed from the authoring sandbox |
| "coverage" | CI artifact `coverage-core-data`; local `tool/coverage_gate.py` |
| "rule not weakened" | the relevant test file(s) + a pointer to the enforcing code |

## 4. Manual checks that no automated layer covers

* Android foreground service, Quick Settings tile, VoiceInteractionService and the popup
  activity: install on a physical device and follow the matrix in
  [`assistant-mode.md`](assistant-mode.md).
* Camera / ML Kit / TFLite: needs hardware; the demo path is explicitly labelled "simulated"
  in the UI when no model binary is bundled (`assets/models/README.md`).
* Desktop tray, global hotkey and autostart: matrix in [`desktop-mode.md`](desktop-mode.md).
* Walkie-talkie audible + visible playback, and the two-sided log: matrix in
  [`walkie-talkie.md`](walkie-talkie.md).
* Unlock against a real Windows/Linux agent: needs a paired agent; the token format is
  pinned by `docs/api.md` § `POST /unlock/request` and by the signer tests.
