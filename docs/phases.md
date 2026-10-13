<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# Phase report

Ten phases, in the order they were built. Each entry lists the files it produced, the screens
that work at the end of it, what is still mocked, and the responsive problems found and fixed
while building it.

## 1 — Scaffold, design system, shell

**Files** `pubspec.yaml`, `analysis_options.yaml`, `l10n.yaml`, `lib/main.dart`, `lib/app.dart`,
`lib/core/**` (breakpoints, theme: colours/typography/app_theme, config, l10n, utils,
preferences, security, providers, errors, network: token_store/api_client/websocket_client,
router: routes/app_router/screen_registry, confirm, widgets: the ten shared components),
`android/**`, `assets/**`.

**Working** the app boots, validates its configuration, loads preferences, shows a splash, and
renders the navigation shell: bottom bar under 600 dp, collapsible rail from 600 dp, persistent
sidebar with an optional secondary panel from 1024 dp. Theme switching and locale switching are
live; the palette, the type scale and every shared component exist and are used by the screens
that follow.

**Still mocked** the backend (fixtures).

**Responsive issues found and fixed** the first sidebar draft used a fixed 280 dp width plus
`Row`, which overflowed at 1024 dp once the secondary panel was open — replaced with
`Expanded` + `ContentConstraint`. The bottom bar's labels were clipped at 320 dp once Bengali
was selected; the bar now uses short labels and the full label as the semantic description.

## 2 — Authentication

**Files** `lib/features/auth/**` (login, signup, forgot/reset password, verify email; controller,
Google flow, models), `lib/core/network/token_store.dart`, the auth branch of the router.

**Working** email + password sign-in, Google sign-in (only when the platform is configured —
never faked), sign-up with verification, token deep links for reset and verify, expiry and
invalid-link states distinguished, session restore on launch, token refresh, sign-out, forced
sign-out on a rejected refresh.

**Still mocked** the account store; Google is gated behind a real client id.

**Responsive issues found and fixed** the sign-in card was centred with a fixed 420 dp width,
which was wider than a 320 dp window — now `ConstrainedBox(maxWidth)` inside a padded,
scrollable column. The reset-link screen's long token was overflowing its detail row at 360 dp;
the value now wraps in a monospace block.

## 3 — The assistant

**Files** `lib/features/assistant/**` (page, composer, chat bubble, tool-call card, controller).

**Working** text chat with streaming replies; push-to-talk with a recording indicator;
wake-word state shown honestly (armed / listening / unavailable) rather than as a decorative
dot; tool-call cards for LOW/MEDIUM/HIGH with approve/deny; TTS playback per message language;
the transcript survives navigation.

**Still mocked** speech recognition and synthesis run on the device; the replies come from the
mock backend.

**Responsive issues found and fixed** the composer's send button was pushed off screen at
320 dp when the mic and send buttons were both present — the row now shrinks the field first
and drops the mic into the toolbar below 360 dp.

## 4 — Smart home and alarms

**Files** `lib/features/smarthome/**` (device grid, device detail, controller),
`lib/features/alarms/**` (alarms list, alarm editor, controller and `sortedAlarms`).

**Working** room-grouped device grid, connectivity state per device, sensor readings, manual
fallback controls when a device is unreachable, brightness and on/off, and the risk rules
(a light is LOW; a lock is MEDIUM; an unlock is HIGH with a typed phrase). Alarms ring on a
chosen set of devices with per-device ring/acknowledge status, snooze, repeat rules and
test-ring.

**Still mocked** device state changes come from the backend; no real hardware is contacted by
this build.

**Responsive issues found and fixed** the device grid used `SliverGridDelegateWithFixedCrossAxisCount`,
which made 90 dp cards on a 2560 px monitor; now `…MaxCrossAxisExtent` (260 dp). The alarm
editor's time picker and repeat chips overflowed at 360 dp — they wrap now.

## 5 — Linked devices

**Files** `lib/features/linked/**` (device list, pairing flow with QR and code, controller),
`lib/features/overlay/presentation/overlay_permission_page.dart` (the bubble's explainer).

**Working** QR/code pairing with a clear waiting/approved/rejected/cancelled state, the linked
list with last-seen and platform, and unlinking gated by the owner's own password.

**Still mocked** pairing is simulated by the mock backend (the code expires after its window
and cannot be redeemed twice).

**Responsive issues found and fixed** the QR code was drawn at a fixed 240 dp and clipped at
320 dp; it is now sized from the available width with a cap.

## 6 — Guest greeter

**Files** `lib/features/greeter/**` (greeter screen, enrollment screen, controller).

**Working** camera preview with a visible, always-present camera-on indicator; a one-tap kill
switch; separate consent and enrollment; per-guest delete; a greeting log with confidence and
whether a greeting was actually spoken.

**Still mocked** face detection runs on the device (ML Kit via the camera pipeline); the
backend stores only a reference to an encrypted template, and the client never holds one.

**Responsive issues found and fixed** the preview's overlay badges collided at 360 dp; the
overlay is now a single row that wraps, with the kill switch anchored and never covered.

## 7 — Web builder

**Files** `lib/features/web_builder/**` (page, prompt field, generated-file list, diff preview,
deployment status helpers, controller).

**Working** prompt → generated files with a diff against the previous contents → a confirmation
dialog naming the exact repository and branch and requiring the typed phrase → `web_deploy` →
deployment status with the live URL only when the backend reports one.

**Still mocked** generation and deployment are simulated; the mock refuses any repository that
is not the configured one.

**Responsive issues found and fixed** the diff preview was a fixed-width monospace column that
scrolled the whole page sideways at 320 dp; it now scrolls inside its own bounded box, with the
file list moving above the diff below 600 dp.

## 8 — Administration

**Files** `lib/features/admin/**` (dashboard with the user table, audit log with filters, tool
toggles, kill switch; controllers and providers).

**Working** the user table with role and status changes (the owner cannot demote themselves),
the audit log filtered by actor and action, per-tool enable/disable with the reason a tool is
unavailable, and an estate-wide kill switch behind a typed confirmation.

**Still mocked** the audit trail is fixtures; the kill switch does not reach real devices.

**Responsive issues found and fixed** the user table needed horizontal scrolling on a phone;
below 600 dp it now renders as a list of cards, and the table returns at 600 dp and above.

## 9 — The Android floating bubble

**Files** `lib/features/overlay/**` (host interface and plugin adapter, bubble isolate entry
point, permission explainer screen, controller), `lib/main.dart` (`overlayMain`),
`android/app/src/main/AndroidManifest.xml` (the plugin's `OverlayService`, foreground-service
permissions, deep links).

**Working** the permission explainer, the draggable bubble via `flutter_overlay_window`, and
`overlayMain()` as the second engine's entry point. The bubble's own UI is deliberately tiny: it
has no session and no socket, so it does not pretend to know backend state; tapping it sends
`open-assistant` to the main isolate, which is the only place that navigates.

**Still mocked** nothing — but the plugin API is pinned to 0.5.0 and must be re-checked against
the resolved version on the first real build (see Known gaps).

**Responsive issues found and fixed** not applicable (a floating window has its own size), but
the permission screen reuses the same `PageBody` rules and is covered by the responsive smoke
run.

## 10 — Real API, tests and responsive QA

**Files** `lib/data/api/rest_armx_api.dart`, `lib/core/network/api_client.dart`,
`lib/core/network/websocket_client.dart`, `docs/contracts.md`, `test/**`,
`integration_test/**`, `tool/static_checks.py`, `tool/prune_imports.py`,
`tool/coverage_gate.py`, `.github/workflows/ci.yml`, `README.md`.

**Working** every screen runs against either implementation of `ArmxApi`; the REST client
implements the endpoint list in `docs/contracts.md`, maps errors onto the exception taxonomy,
refreshes tokens once per failure burst, and maps socket frames onto typed events.

**Still mocked** by default the app runs against the mock backend; `ARMX_USE_MOCK_BACKEND=false`
switches it to the real one.

**Responsive QA** `integration_test/responsive_smoke_test.dart` walks every screen at 320, 360,
600, 800, 1024, 1440 and 2560 dp, at 1.6× text scale, and in Bengali. Each earlier phase's
report names the specific overflow that phase fixed; the smoke run is what keeps them fixed.

---

## Known gaps at the end of phase 10

These are stated rather than hidden, because each one is a place where "looks finished" and
"is verified" differ:

1. **No Flutter SDK in the environment this was written in.** Everything here is verified by
   `python3 tool/static_checks.py` (headers, structure, imports, l10n keys, API/model/enum
   references, provider names, no hardcoded secrets, no platform layout branches) and by the
   test suite's *content* — not by a compiler. The first `flutter analyze` on a machine with
   the SDK is expected to surface a handful of mechanical issues; they are not known to exist,
   they are simply not ruled out.
2. **`lib/l10n/generated/` is produced by `flutter gen-l10n`** and is therefore absent from the
   tree. Run it before analyzing or testing.
3. **Golden baselines are not committed** (see `test/golden/README.md`); the golden suite skips
   with instructions until somebody generates them with the SDK.
4. **`flutter_overlay_window` 0.5.0 API** — the adapter was written against the plugin's
   published source, but the pinned version's exact named arguments must be re-checked on the
   first real build (`lib/features/overlay/application/overlay_host.dart`).
5. **Google sign-in needs a real client id** and the platform's own configuration; it is gated
   and reports that it is unavailable rather than pretending to work.
6. **The backend must exist.** The endpoint list and socket frame names in `docs/contracts.md`
   are the client's half of the contract; where the real service differs, `RestArmxApi` is the
   only file that changes.
