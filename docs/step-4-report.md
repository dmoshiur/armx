<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# Delivery report — desktop background mode + walkie-talkie intercom

Branch `arena/01a0f4ff-armx`. Both features sit on top of the step-3 conversation layer and
ship together in one PR.

---

## A. Desktop background + hotkey mode

### The non-negotiable principle

A.R.M.X auto-starts at login and runs quietly in the background, **and it always shows a
visible tray / menu-bar icon** with `Open A.R.M.X`, `Talk now`, `Pause listening`,
`Background readiness`, `KILL-SWITCH`, `Settings` and `Quit`. "Not shown manually" is
implemented as *no manual launch needed* — never as *invisible with no off-switch*, which is
the pattern SmartScreen, Gatekeeper and antivirus suites quarantine. The tray icon is
registered **before** the hotkey and before autostart, so a background A.R.M.X is never
un-closeable or invisible.

### Files

| File | Lines | What it owns |
| --- | --- | --- |
| `lib/core/platform/desktop_shell.dart` | 380 | `TrayVisualState`, `TrayMenuItem`, `HotkeyDescriptor` (+ `storageKey`, `fromString`, `fromJson`, `defaultFor`), `DesktopShellCallbacks`, `DesktopShell`, `NoopDesktopShell` |
| `lib/core/platform/desktop_shell_native.dart` | 350 | `tray_manager` / `hotkey_manager` / `window_manager` adapter, tray bridge, single-window popup mode, USB HID key mapping |
| `lib/core/platform/autostart_service.dart` | 98 | `AutostartService`, `LaunchAtStartupService` (Windows Run key, macOS `SMAppService`, Linux XDG), `NoopAutostartService` |
| `lib/core/platform/device_availability.dart` | 240 | `DeviceAvailability`, `DeviceStatus`, `RecordDeviceAvailabilityService` (5 s polling), `NoopDeviceAvailabilityService`, `deviceAvailabilityLabel()` |
| `lib/core/platform/single_instance.dart` | 121 | `SingleInstanceGuard` (exclusive `File.lockSync` + loopback port), secondary sends `activate` and exits, degrades to primary on any FS error |
| `lib/features/desktop/desktop_state.dart` | 240 | `HotkeyStatus`, `ReadinessItem`, `DesktopIssue`, `DesktopState` (`visualState`, `readiness`, `isReady`, `voiceUnavailable`) |
| `lib/features/desktop/desktop_controller.dart` | 470 | `TrayCommand`, `DesktopController` — tray, hotkey, autostart, popup, kill-switch, device probe, localized tray labels |
| `lib/features/desktop/desktop_bootstrap.dart` | 96 | Startup order: single instance → tray → hotkey + autostart → device probe |
| `lib/features/desktop/desktop_menu_labels.dart` | 45 | Resolves tray labels from the stored locale (a native menu cannot read a `BuildContext`) |
| `lib/features/desktop/widgets/hotkey_field.dart` | 198 | `HotkeyRecorderField` — live capture, requires a modifier, commits only after a successful registration, shows the conflict message |
| `lib/features/desktop/widgets/background_readiness_page.dart` | 185 | Readiness checklist with a status pill and a fix action per row, plus the hotkey rebinder |
| `lib/features/desktop/popup/desktop_popup_page.dart` | 220 | Frameless popup: orb, transcript, tool-approval cards, composer, Esc / click-outside dismiss, typed-input mode |
| `assets/tray/*` | 20 files | `tray_<state>[_dark]_{32,64}.png` for idle / listening / thinking / muted / killed |
| `docs/desktop-mode.md` | 148 | Per-OS mechanics, parity gaps, startup contract, and the manual test matrix (W1–W17, M1–M10, L1–L9, A0–A3) |

### Requirement → where it lives

1. **Autostart per OS, toggle-able, default ON** — `LaunchAtStartupService` + the
   `armx.desktop.autostart` preference (defaults to `true`) + the Settings toggle.
2. **Tray with state icons and the specified menu** — `NativeDesktopShell.updateTray` +
   `DesktopController._menu()`; tooltip carries state, the `voice unavailable — use hotkey`
   hint and `connected`/`offline`.
3. **Global hotkey with per-OS defaults, rebinding, conflict detection, persistence** —
   `HotkeyDescriptor.defaultFor` (`Ctrl+Alt+Space` / `⌘+Shift+Space` / `Ctrl+Alt+A`),
   `HotkeyRecorderField`, `DesktopController.rebindHotkey` (persists `ctrl+alt+f7` and
   re-registers on start).
4. **Device enumeration + honest fallbacks** — `RecordDeviceAvailabilityService`; no mic →
   wake word disabled, tooltip hint, popup opens in typed-input mode; no camera → typed
   passphrase + system biometric. A HIGH-tier verification is never silently downgraded.
5. **Frameless always-on-top popup** — `NativeDesktopShell.showPopup/hidePopup` +
   `DesktopPopupPage` (reuses the orb, transcript and tool-approval cards).
6. **Background readiness checklist** — `BackgroundReadinessPage`.
7. **Tray kill-switch identical to mobile** — engages without a biometric, stops listening,
   closes the socket, red icon; releasing is only possible from the open window.
8. **Close → minimize to tray, explicit Quit with confirmation, single instance** —
   `minimizeToTray()`, `TrayCommand.quit`, `SingleInstanceGuard`.
9. **Tests + docs** — see below.

### Stated parity gaps (not faked)

| Gap | Handling |
| --- | --- |
| `tray_manager 0.7.0` stops reporting tray clicks on Linux | Pinned `0.5.3` with the classic API; migration deferred and documented |
| Linux system-wide hotkeys need `keybinder-3.0` | Tray keeps working; readiness shows the hotkey row red with a fix link |
| `record` has no permission API on Windows/Linux | `missing` vs `permissionDenied` cannot be distinguished there; documented |
| No camera enumeration on Linux | `unsupported`; face verification degrades to system biometric + typed passphrase |
| OS do-not-disturb is not detected | `SilenceProbe` is `AlwaysAudibleProbe`; follow-up documented in both docs |
| The popup shares the single Flutter window | Documented; a second native window would need `desktop_multi_window` |
| Popup anchors to the window, not the cursor | `window_manager` exposes no cursor query; a per-OS native read is a documented follow-up |

---

## B. Walkie-talkie voice intercom

### Files

| File | Lines | What it owns |
| --- | --- | --- |
| `lib/data/models/announcement.dart` | 135 | `AnnouncementStatus`, `AnnouncementScope`, `Announcement`, `IntercomRecipient`, `IntercomConsent` |
| `lib/data/db/tables.dart` (+1 table) | 45 | `AnnouncementsCache` — the one audit table both views read |
| `lib/data/db/armx_database.dart` (+ methods) | 40 | `schemaVersion` 1 → 2 with an `onUpgrade` that creates only the new table; `announcements()`, `upsertAnnouncement()`, `markAnnouncementPlayed()`, `clearAnnouncements()`, and `wipeCaches()` clears it too |
| `lib/data/repositories/announcement_repository.dart` | 90 | Local copy of the log; the user view and the admin view read the same rows |
| `lib/data/api/ws_events_intercom.dart` | 111 | `intercom.announcement`, `intercom.outcome`, `intercom.consent` |
| `lib/data/api/mock/mock_intercom_domain.dart` | 250 | Mock backend: consent, recipients, upload, log, outcome, plus `intercomTargetOnline` / `setRecipientConsent` test knobs |
| `lib/core/services/intercom_audio.dart` | 107 | `IntercomClip`, `IntercomAudio`, `SilentIntercomAudio` |
| `lib/core/services/intercom_audio_native.dart` | 160 | `RecordIntercomAudio` on `record 7.1.1` + `audioplayers 6.6.0`; amplitude via `onAmplitudeChanged` with a synthetic fallback |
| `lib/features/intercom/intercom_state.dart` | 160 | `OverlayPhase`, `TalkPhase`, `IntercomState`, `AnnouncementPolicy` (the three rules as pure functions) |
| `lib/features/intercom/intercom_controller.dart` | 370 | Consent, push-to-talk, incoming handling (chime → overlay → play → log), CSV export |
| `lib/features/intercom/intercom_consent_page.dart` | 148 | The one-time opt-in screen |
| `lib/features/intercom/announcement_overlay.dart` | 210 | Live waveform overlay with `Mute this once` / `Turn off announcements` |
| `lib/features/intercom/admin_talk_page.dart` | 320 | Admin "Talk": only opted-in devices, hold-to-talk, broadcast, delivery status, CSV |
| `lib/features/intercom/intercom_activity_page.dart` | 135 | The mutual log, read-only, exportable |
| `assets/audio/intercom_chime.wav` | 22 KB | 0.5 s, 22.05 kHz mono 16-bit, 880 → 1320 Hz two-tone chime |
| `docs/walkie-talkie.md` | 124 | Written to be read aloud at the science fair |

### The three rules, and where they are enforced

1. **One-time opt-in, default OFF.** `IntercomConsent` defaults to `false`; the only writer is
   `IntercomController.setConsent`, driven by the consent screen. The mock backend refuses a
   send to (or from) a non-consented device with a `PolicyException`, so the rule holds even
   if a UI path is missed. The locked-screen sub-toggle is a separate, narrower permission
   that cannot widen the main one.
2. **Every playback audible + visible.** `_handleIncoming` always chimes (when allowed) and
   always shows the overlay with the speaker's name and a live waveform; `Mute this once`
   stops the audio but keeps the notice and the log entry; `Turn off announcements` revokes
   consent immediately from the overlay. Audio is never forced over a system silence setting.
3. **Mutual visibility.** One table (`AnnouncementsCache`), two readers. The receiving device
   writes the row the moment the frame arrives, and the same status is reported back so the
   Admin's row and the user's row stay identical. The CSV export is labelled *"Visible to
   this user in their own Activity screen"*.

The feature sits behind the `enableAdminIntercom` flag (`PreferenceKeys.intercomEnabled`,
exposed as "Voice announcements from Admin/Owner" in Settings) and the Talk screen refuses to
render anything until it is on.

---

## Tests

| File | Covers |
| --- | --- |
| `test/unit/core/platform/desktop_shell_test.dart` | Platform defaults, JSON + compact round-trips, corrupted preference fallback, modifier normalisation, refused registration keeps the previous binding, `NoopDesktopShell` recording |
| `test/unit/core/platform/device_availability_test.dart` | Device-availability fallback logic (missing mic, refused permission, missing/unsupported camera, unknown, both missing) |
| `test/unit/core/platform/single_instance_test.dart` | Primary lock, secondary signals and exits, stale and corrupted lock files, release and take-over |
| `test/unit/features/desktop/desktop_state_test.dart` | Tray state machine (killed > muted > listening > idle, expiry), readiness rows and fix actions |
| `test/unit/features/desktop/desktop_controller_test.dart` | Real controller with `NoopDesktopShell`: hotkey conflict + rebind, typed-input fallback, pause expiry, tray kill-switch parity, autostart round-trip, popup open/close, minimize-to-tray |
| `test/unit/features/desktop/autostart_persistence_test.dart` | Autostart default ON, persistence across a "restart", reactivity, corrupted hotkey fallback, intercom consent default OFF, `resetAll` |
| `test/unit/features/intercom/intercom_policy_test.dart` | Consent state machine, DND handling, targeting rules, `copyWith` |
| `test/unit/features/intercom/mock_intercom_test.dart` | Backend rules: consent OFF by default, non-consented send refused, offline → `MISSED` (never queued), shared log, outcome updates, kill-switch parity |
| `test/unit/features/intercom/announcement_log_test.dart` | Mutual-log consistency at the storage layer |
| `test/widget/intercom/intercom_consent_page_test.dart` | Consent screen: default OFF, opt-in, sub-toggle, the three rules |
| `test/widget/intercom/announcement_overlay_test.dart` | Overlay muted / unmuted, chime + speaker + waveform, auto-dismiss + `PLAYED` |
| `test/widget/intercom/admin_talk_page_test.dart` | Opted-in vs not listed at all, empty state, feature flag gate, broadcast |
| `test/widget/intercom/intercom_activity_page_test.dart` | Both views read the same rows, export label, missed announcements shown |

---

## Deviations and open items

* **No Flutter SDK in the authoring sandbox.** `flutter analyze`, `flutter test`,
  `build_runner` and `flutter gen-l10n` could not be executed here. Everything was written
  against the pinned package APIs and the repo's own widget signatures, and mechanically
  audited (brace/paren balance, relative-import resolution, `l10n.*` key existence, ≤ 100
  char lines, trailing newline, copyright headers). The first CI run must confirm:
  ```bash
  flutter pub get
  dart run build_runner build --delete-conflicting-outputs
  flutter gen-l10n
  flutter analyze
  flutter test
  ```
* **macOS `launch_at_startup` wiring is native work, not Dart.** The MethodChannel in
  `macos/Runner/MainFlutterWindow.swift`, the LaunchAtLogin SPM package and the run-script
  phase are listed in `docs/desktop-mode.md` and must be applied in Xcode; the Dart side is
  complete.
* **`SilenceProbe` is `AlwaysAudibleProbe`.** OS focus-mode detection is per-OS follow-up.
* **Tray labels are English in the controller** unless the bootstrap has resolved them from
  the stored locale (it does, via `DesktopMenuLabels.forLocale`); the English fallback keeps
  tests and mobile builds working.
* **New dependencies** (`tray_manager`, `hotkey_manager`, `window_manager`,
  `launch_at_startup`, `record`, `audioplayers`) are pinned exactly and recorded in
  `docs/decisions/0002-dependency-pins.md`. `flutter pub get` must be run to regenerate
  `pubspec.lock` (which is not committed).
* **Generated files are not committed**, per the repo convention: `*.freezed.dart`,
  `*.g.dart` and `lib/l10n/generated/` come from `build_runner` / `gen-l10n`.
