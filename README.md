<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# A.R.M.X AI — Flutter frontend

The client for A.R.M.X AI: a voice-first, bilingual (English / Bengali) assistant for a home
and a small estate, with three roles (Admin, VIP, User) and one codebase that runs on a phone,
a tablet, an Android device with a floating assistant bubble, and the web from 320 px to
2560 px.

**This repository is the frontend only.** It talks to an existing FastAPI service over HTTPS
and WSS; it does not contain a backend, and it never reports a result it did not receive. See
[`docs/contracts.md`](docs/contracts.md) for the client's half of the agreement.

---

## Quick start

```bash
flutter pub get
flutter gen-l10n                       # writes lib/l10n/generated/ (not committed)
flutter run                            # runs against the built-in mock backend
```

The mock backend is the default: the app boots, signs in and every screen works with no server
present. Point it at a real service with build-time configuration only:

```bash
flutter run \
  --dart-define=ARMX_API_BASE_URL=https://armx.example:8443 \
  --dart-define=ARMX_WS_URL=wss://armx.example:8443/ws \
  --dart-define=ARMX_USE_MOCK_BACKEND=false \
  --dart-define=ARMX_ENVIRONMENT=production
```

Mock credentials (fixtures, not secrets): `mohi@thamjj13.top` / `ArmxDemo#2026` (admin),
`rafi@example.com` / `Member#2026` (user).

### Configuration

| `--dart-define` | Default | Meaning |
| --- | --- | --- |
| `ARMX_API_BASE_URL` | `https://armx.local:8443` | REST base URL. Must be HTTPS outside a debug mock build, or the app refuses to start. |
| `ARMX_WS_URL` | base URL, scheme swapped, `/ws` appended | Socket URL. |
| `ARMX_USE_MOCK_BACKEND` | `true` | `false` switches to `RestArmxApi`. |
| `ARMX_ENVIRONMENT` | `development` | Shown in Settings → Diagnostics. |
| `ARMX_BUILD_LABEL` | empty | Optional build tag shown in About. |

**There are no secrets in this repository, and there is nowhere to put one.** `AppConfig` has
five fields, none of which can hold a token, a key or a password; `assert_config`-style checks
in `test/unit/core/config/app_config_test.dart` fail if a sixth field appears, and
`tool/static_checks.py` fails the build on a hardcoded secret pattern or a cleartext URL in
`lib/`. Tokens live in `flutter_secure_storage` (Keychain / EncryptedSharedPreferences) and are
never logged, never put in a URL, and never written to `SharedPreferences`.

---

## What is in the app

Fourteen screens, all responsive, all bilingual:

| Screen | Route | Notes |
| --- | --- | --- |
| Splash / bootstrap | `/` | loads preferences, restores the session, reports a failure instead of guessing |
| Sign in | `/login` | email + password, Google (only when configured), verification gate |
| Sign up | `/signup` | strong-password rules, verification email |
| Forgot / reset password | `/forgot-password`, `/reset-password` | `armx://reset-password?token=…` deep link; expired and invalid links are distinct states |
| Verify email | `/verify-email` | `armx://verify-email?token=…` |
| Assistant | `/assistant` | text + push-to-talk, wake-word state, streaming replies, tool-call cards with approve/deny |
| Floating bubble | — | Android overlay, draggable, own isolate, permission explainer at `/overlay-permission` |
| Smart home | `/smart-home`, `/smart-home/:id` | room grid, connectivity, manual fallback, risk-tiered commands |
| Alarms | `/alarms`, `/alarms/:id` | per-device targets, cross-device ring and acknowledge, snooze, repeat |
| Linked devices | `/linked-devices` | QR and code pairing, list, unlink gated by the owner's password |
| Guest greeter | `/guest-greeter`, `/guest-greeter/enroll` | camera preview, always-visible camera-on indicator, one-tap kill switch, separate consent |
| Web builder | `/web-builder` | prompt → diff preview → confirm naming the exact repo → deploy → live URL |
| Messaging personality | `/messaging` | per-contact tone, auto-send vs draft-only |
| Admin | `/admin`, `/admin/audit`, `/admin/tools` | user table, audit log, tool toggles, kill switch |
| Settings | `/settings/…` | language, theme, notifications, permissions overview, sessions with revoke, design system, diagnostics, about |

### Roles

Authorisation is a route guard, not a hidden button. Signing in as a User and typing an admin
URL redirects; it does not render a read-only imitation of the admin screen. The same holds in
the other direction: a signed-in admin visiting `/login` is sent to the home screen.

---

## Architecture

```
lib/
├── main.dart                 validates config, installs it, runs the app; overlayMain() lives here
├── app.dart                  MaterialApp.router, theme/locale binding, overlay event handling
├── core/
│   ├── breakpoints.dart      the only place a width becomes a layout decision
│   ├── theme/                palette, type scale, one AppTheme
│   ├── config/               AppConfig: five fields, no secrets
│   ├── network/              ApiClient (dio), WebSocketClient, TokenStore
│   ├── router/               routes, guards, the screen registry
│   ├── confirm/              the confirmation policy (what needs friction, and how much)
│   ├── security/             risk tiers
│   ├── widgets/              the ten shared components every screen is built from
│   ├── l10n/, utils/, preferences/, errors/, providers.dart
├── data/
│   ├── models/               plain models with explicit, tested fromJson
│   └── api/                  ArmxApi, RestArmxApi, mock/
└── features/<feature>/
    ├── application/          a controller (Riverpod Notifier) per feature
    └── presentation/         pages and the widgets only that feature uses
```

Decisions with their reasoning: [`docs/decisions/`](docs/decisions) — the API boundary, the
responsive rules, the palette and contrast, and the risk/confirmation policy. The phase-by-phase
build report, including what is still mocked, is [`docs/phases.md`](docs/phases.md).

### The rules that are enforced rather than requested

* **No layout branch on the platform.** `Platform.is*` fails the build inside `lib/`.
* **Width decides.** `< 600` compact (bottom navigation), `600–1024` medium (collapsible rail),
  `≥ 1024` expanded (persistent sidebar, optional secondary panel). Content is capped at 1200 dp
  and centred; grids grow columns, not card sizes.
* **No fixed root widths.** `Expanded` / `Flexible` / `FractionallySizedBox` / `ConstrainedBox`
  only; anything oversized scrolls inside its own box rather than widening the page.
* **No screen hardcodes a colour or a font size.** Read `ArmxColors.of(context)` and the
  `TextTheme`; the palette and the type scale are asserted in tests.
* **Colour is never the only signal.** Every status has words next to its colour.
* **`start`/`end`, never `left`/`right`.**
* **Touch targets ≥ 48 dp on compact**, with hover and focus states on medium and expanded.
* **Fail closed.** An unknown risk tier is HIGH, an unknown deployment status is `pending`, an
  unknown account status is `disabled`, an unknown socket frame is dropped.
* **Pending is not success.** A device command in flight renders as pending; a deployment is
  live only when the backend says so.

---

## Localization

`lib/l10n/app_en.arb` and `app_bn.arb` hold the same keys — currently **669 each** — and
`flutter gen-l10n` generates `AppLocalizations`. Bengali is a first-class language: the app is
fully usable with Bengali selected, and a missing Bengali string that fell back to English would
fail `tool/static_checks.py` (which compares keys *and* placeholders, and rejects an identical
EN/BN value unless the key is on the deliberate list of brand names and platform-copied strings).

```bash
python3 tool/l10n_add.py authNewKey "English text" "বাংলা লেখা"   # adds to both, keeps order
python3 tool/l10n_gen.py                                          # reports key count and drift
flutter gen-l10n
```

Bengali runs longer than English, so screens reflow rather than relying on truncation; text
scaling is honoured and clamped to 0.9–1.6.

---

## Verification

```bash
python3 tool/static_checks.py        # structure, imports, l10n, API/model references
python3 tool/prune_imports.py        # removes imports nothing uses
flutter analyze
flutter test --coverage
python3 tool/coverage_gate.py --threshold 70 --require-prefix lib/core
flutter test integration_test        # needs a device or a Linux desktop
```

`tool/static_checks.py` runs with no SDK and no network. It checks licence headers, balanced
brackets, that every relative import resolves, that every `l10n.<key>` exists in both locales,
that no secret or cleartext URL is in `lib/`, that no platform layout branch or code-generation
`part` directive crept in — and, more unusually, that every API method, model member, enum value
and provider name referenced anywhere in `lib/`, `test/` or `integration_test/` actually exists.
It has a self-test of its own parsers, because a heuristic standing in for `flutter analyze` can
rot into something that always passes.

Tests: unit tests for the core (breakpoints, routes and roles, risk tiers, the confirmation
policy, config, typography, palette contrast, validators), every model parser including its
fail-closed fallbacks, and the mock backend judged by what it *refuses*; widget tests for each
shared component at 360×800, 800×1280 and 1440×900; the confirmation dialog's rules (verbatim
action and target, no "OK", safe default focus, typed phrase); and integration tests for the two
flows the specification names — LOW risk runs with no dialog, HIGH risk asks **before any backend
call** and cancelling sends nothing — plus a responsive smoke run over 320–2560 dp.

CI ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs the static checks, `flutter
analyze`, the test suite with the coverage floor, a release web build and a debug APK on every
push and pull request, and the integration suite on `main` and on demand.

---

## Platform notes

* **Android** — `applicationId top.thamjj13.armx`, `minSdk 24`, deep links `armx://reset-password`
  and `armx://verify-email`, `allowBackup="false"`, `usesCleartextTraffic="false"`. The floating
  bubble needs the `SYSTEM_ALERT_WINDOW` permission, which the app explains before asking for and
  which is used only while the user has the bubble switched on.
* **Web** — no service worker caches a token; the app is a normal HTTPS client and the layout is
  checked from 320 px to 2560 px.
* **Biometrics** — `local_auth` returns a yes/no **on the device**. No biometric data is read,
  stored or transmitted, and nothing about the result is sent to the backend beyond the action
  the user asked for.

---

## Known gaps

Listed honestly at the end of [`docs/phases.md`](docs/phases.md). In short: this tree was
authored without a Flutter SDK available, so it is verified by `tool/static_checks.py` and by the
tests' content rather than by a compiler; `lib/l10n/generated/` must be produced by
`flutter gen-l10n`; the golden baselines in `test/golden/goldens/` must be generated once on a
machine with the SDK; and the `flutter_overlay_window` 0.5.0 named arguments must be re-checked
against the resolved package on the first real build.

---

© 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.
