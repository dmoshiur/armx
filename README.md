<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# A.R.M.X AI

**A**utomated **R**esource **M**anagement e**X**tension — the owner's control surface for a
privately hosted home/estate assistant.

* Owner: **Md. Moshiur Rahman Mohi**
* Brand: **THAMJJ13.TOP**
* Targets: **Android** (primary), **Windows** and **Linux** desktop
* Toolchain: Flutter **3.47.5** / Dart **3.13.4**, Material 3, dark-first

> Frontend only. There is no backend in this repository: the app runs against a
> deterministic in-app mock backend (`USE_MOCK=true` by default) so every screen, flow and
> test works today. `docs/api.md` is the contract the real server must implement.

---

## Status

| Step | Scope | State |
| --- | --- | --- |
| 1 | Setup, theme, router, l10n, skeleton, mock backend | ✅ delivered |
| 2 | Auth, pairing, app lock | ✅ delivered |
| 3 | Chat + WebSocket + tool approval cards | ✅ delivered |
| 4 | Voice (push-to-talk, wake word, TTS) | |
| 5 | Dashboard + devices | |
| 6 | Admin, kill-switch, audit | |
| 7 | Vision (face enrolment, palm gesture) | |
| 8 | Activity + WHEN/THEN rules | |
| 9 | Unlock client | |
| 10 | Settings polish, full test suite, release docs | |

Step 1 ships the design system, the five-tab shell, the routing table, English + Bengali
localization, the security core (`RiskPolicy`, evidence, secure storage), the data layer
(models, Drift schema, preferences) and a mock backend that behaves like the real one —
including a working kill-switch and streaming assistant.

Steps 2–3 add pairing, sign-in, the LOW-tier app-lock gate, and the assistant conversation
tab: a streaming transcript over the WebSocket event contract, tool approval cards that
enforce the risk tiers (LOW runs immediately, MEDIUM/HIGH require an explicit decision
after on-device verification), reconnect with exponential backoff, and an offline transcript
cache. See [`docs/step-3-report.md`](docs/step-3-report.md).

### Background assistant add-on

Deliveries 1–2 add the Android foreground-service shell, persistent notification actions,
live status controls, and a native no-audio wake-word stub/adapter contract. The real
wake-word detector is **not connected yet**; this phase does not access or capture microphone
audio. See [`docs/assistant-mode.md`](docs/assistant-mode.md) for Android start restrictions,
privacy behavior, and verification limits.

## Quick start

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run                    # mock backend, EN; add --dart-define=… per docs/run.md
```

See **`docs/run.md`** for every `--dart-define`, the wake-word wiring, the coverage gate and a
troubleshooting table.

## Architecture

```
lib/
  main.dart, app.dart          entry point, MaterialApp.router, theme + locale binding
  core/
    config/    compile-time configuration, product constants (no secrets in code)
    errors/    sealed AppException hierarchy + error mapping
    logging/   redacting logger + in-memory ring buffer for Diagnostics
    l10n/      BuildContext extensions over the generated ARB bindings
    router/    go_router graph: bootstrap → 5-tab shell + pushed flows
    security/  RiskPolicy, 60 s evidence window, secure storage, screen guard
    theme/     palette, typography, motion, effects, ThemeData (dark/light)
    utils/     clock, hex, validators, JSON readers, platform capabilities
    widgets/   glass panels, orb, risk chips, status pills, controls, states
  data/
    api/       ArmxApi contract, WebSocket codec, deterministic mock backend
    db/        Drift database + tables (offline cache, prefs, outbox)
    models/    freezed/json_serializable models for every wire object
    repositories/  app preferences (theme, language, thresholds), chat transcript cache
  features/    auth, chat, voice, dashboard, devices, vision, activity, unlock, admin, settings, shell
  l10n/        app_en.arb, app_bn.arb
assets/fonts/  Inter + JetBrains Mono (bundled, no network fonts)
docs/          run.md, api.md, decisions/
test/          unit, widget, golden, support harness
integration_test/  pair → chat → approve → kill-switch
```

## Risk rules

`RiskPolicy` is the single authority and is unit-tested (`test/unit/core/security/`):

| Tier | Requirements | Typical actions |
| --- | --- | --- |
| LOW | face **or** voice | status reads, scene previews |
| MEDIUM | face **and** voice | relay toggles, scenes, rule edits |
| HIGH | face **and** voice **and** system biometric/PIN | unlock, gate, destructive commands |

Non-negotiable details: **voice alone is never trusted** (fail-closed, even for LOW), a **2D
face match is medium trust**, every verification result **expires after 60 s**, and escalating
the tier **forces re-verification** instead of reusing older evidence.

## Security model

* **No secrets in code.** Everything sensitive arrives through `--dart-define` or the
  platform keyring; tokens live only in `flutter_secure_storage`.
* **TLS only**, cleartext rejected in release builds, with a certificate-pinning hook.
* **Biometrics never leave the device.** Face embeddings and voice prints are encrypted at
  rest; the only artefact sent over the network is a signed, single-use, 60-second,
  scoped `owner_verified` assertion.
* **KILL-SWITCH** is reachable everywhere, engages on a 1-second long press, requires **no**
  biometric, calls the API, closes the WebSocket and keeps the UI red until re-enabled.
* **Screenshots are blocked** on sensitive screens (`ScreenSecurity`), and logs are redacted
  before they reach the buffer, the console or Diagnostics.
* **Assistant and tool text is untrusted**: it is rendered as plain/sanitized text, and links
  are displayed inert rather than opened.

## Design system

Tokens (dark-first, light counterpart for every value): `#0B1020` background, `#141B33`
panel, `#1B2444` raised panel, `#263056` border, `#22D3EE` cyan, `#8B5CF6` violet, `#E5E9F5`
text, `#93A0C0` muted, `#F59E0B` amber (MEDIUM), `#34D399` green (LOW/ok), `#F87171` red
(HIGH/danger).

Signature widgets: the animated assistant orb (idle/listening/thinking/speaking/locked),
risk-tier chips, status pills, glass panels and the `A.R.M.X` wordmark with cyan `AI`.
Reduced-motion is honoured, every interactive element is ≥ 48 dp, and all colours come from
the theme extension — never a literal (see `Settings → Design system`).

## Tests

```bash
flutter analyze          # zero warnings required
flutter test             # unit + widget + golden
flutter test --coverage  # ≥ 70 % line coverage on lib/core/ and lib/data/
```

The offline mock backend is what makes this possible without a server or hardware.

## Legal

Proprietary. Copyright (c) 2026 **Md. Moshiur Rahman Mohi** / **THAMJJ13.TOP**.
All Rights Reserved. Bundled fonts are used under the SIL Open Font License
(`assets/fonts/OFL-*.txt`).

**A.R.M.X AI by THAMJJ13.TOP - Md. Moshiur Rahman Mohi. All Rights Reserved.**
