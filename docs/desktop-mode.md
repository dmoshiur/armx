<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# Desktop background + hotkey mode

Windows, macOS and Linux. Delivery step: **desktop background mode**.

## The one rule that shapes everything

A.R.M.X auto-starts at login and runs quietly in the background, **but it never becomes an
invisible process**. The tray / menu-bar icon is always on screen and always carries
`Open A.R.M.X`, `Pause listening`, `KILL-SWITCH`, `Settings` and `Quit`.

"Runs in the background without being shown manually" means *no manual launch* — it does
**not** mean *invisible with no off-switch*. A background app with no tray icon is
indistinguishable from malware: Windows SmartScreen quarantines it, Gatekeeper flags it, and
antivirus suites remove it. The visible tray icon is the price of being allowed to start at
login, and it is also what makes the feature honest: the user can always see that A.R.M.X is
running and can always stop it.

## What is wired

| Capability | Implementation | Notes |
| --- | --- | --- |
| Tray icon | `tray_manager 0.5.3` via `core/platform/desktop_shell_native.dart` | Classic `package:tray_manager/tray_manager.dart` API. `assets/tray/tray_<state>[_dark]_{32,64}.png` — the bright variant is used on a dark taskbar, the `_dark` variant on a light one; macOS renders the icon as a template. |
| Tray states | `TrayVisualState.{idle, listening, thinking, muted, killed}` | Icon colour follows the brand tokens: cyan = idle/listening, violet = thinking, amber = muted, red = kill-switch. |
| Tray tooltip | `DesktopController._tooltip()` | State + `voice unavailable — use hotkey` when no mic + `connected`/`offline`. |
| Global hotkey | `hotkey_manager 0.2.3` | Defaults `Ctrl+Alt+Space` (Windows), `⌘+Shift+Space` (macOS), `Ctrl+Alt+A` (Linux). Rebinding lives in Settings and re-registers on start. |
| Popup window | `window_manager 0.5.2` | Frameless, always-on-top, 440×640, positioned near the cursor/tray icon. Reuses the orb, transcript and tool-approval cards. |
| Autostart at login | `launch_at_startup 0.5.1` | Windows registry `Run` key / Startup shortcut, macOS `SMAppService` login item, Linux `~/.config/autostart/*.desktop` (XDG). Toggle-able, **default ON**. |
| Device probe | `RecordDeviceAvailabilityService` | Audio inputs + video devices at startup and every 5 s; drives the tooltip, the typed-input fallback and the readiness rows. |
| Single instance | `core/platform/single_instance.dart` | Exclusive `File.lockSync()` + a loopback port written into the lock file. A second launch sends `activate` and exits. |
| Minimize to tray | `window_manager` `onWindowClose` + `setPreventClose(true)` | Close hides; it never quits. Only the tray `Quit` row exits, with a confirmation while listening. |

## Per-OS mechanics and the honest gaps

| Platform | Autostart | Tray | Hotkey | Extra setup |
| --- | --- | --- | --- | --- |
| Windows 10/11 | `Run` key / Startup shortcut | `tray_manager` | `hotkey_manager` | none |
| macOS (Intel + Apple Silicon) | `SMAppService` login item (visible in System Settings → General → Login Items) | menu-bar icon | `hotkey_manager` (keyUp events are macOS-only) | add the `launch_at_startup` MethodChannel to `macos/Runner/MainFlutterWindow.swift`, add the LaunchAtLogin SPM package and a run-script phase; add `NSMicrophoneUsageDescription` and the audio-input entitlement for the intercom |
| Ubuntu GNOME / KDE | `~/.config/autostart/armx_ai.desktop` (XDG) | AppIndicator extension required on GNOME (`sudo apt install gnome-shell-extension-appindicator`) | `keybinder-3.0` required: `sudo apt-get install keybinder-3.0` | none |

**Parity gaps stated explicitly** (these are platform limitations, not shortcuts):

1. **Linux tray click reporting.** `tray_manager 0.7.0` (GitHub only) rewrites the tray on
   `nativeapi` and **stops reporting tray clicks on Linux**. This delivery therefore pins
   `0.5.3` and keeps the classic API; the 0.7.0 migration is future work.
2. **Linux hotkeys need a system package.** `hotkey_manager` binds through `keybinder-3.0`
   on Linux. Without it `register()` fails, the tray still works, and the readiness screen
   shows "Not registered — combination in use" with a fix link. There is no pure-Dart
   fallback for a system-wide hotkey on X11/Wayland.
3. **`record` has no permission API on Windows/Linux.** The parity matrix of `record 7.1.1`
   reports `hasPermission()` as unsupported there, so `RecordDeviceAvailabilityService`
   treats "no inputs found" as `missing` and cannot distinguish "denied" from "unplugged".
   Linux additionally needs `parecord`, `pactl` and `ffmpeg` on `PATH`.
4. **Camera enumeration has no Linux implementation** in this delivery
   (`availableCameras()` throws on Linux), which maps to `DeviceAvailability.unsupported`.
   Face verification is unavailable on Linux: MEDIUM/HIGH actions fall back to the system
   biometric plus a typed passphrase. A HIGH-tier verification is **never** silently
   downgraded — it either completes with an equivalent-or-stronger factor or it fails.
5. **OS "do not disturb" is not detected yet.** `SilenceProbe` is `AlwaysAudibleProbe`:
   the intercom assumes audio is allowed once the device has consented. Detecting the
   platform focus mode (Windows Focus Assist, macOS Focus, GNOME/KDE notification settings)
   is per-OS work tracked as a follow-up; until then the intercom overlay is always shown
   and the chime is always attempted.
6. **The popup is one window.** The tray icon and the popup share the single Flutter window
   of this build (single-window popup mode). A second, independent native window would need
   `desktop_multi_window`; that is out of scope for this delivery and is called out here
   rather than faked.

## Startup order (contract)

1. **Single instance first.** If another A.R.M.X owns the lock file, this process sends
   `activate` and exits — a hotkey press can never leave a second invisible copy running.
2. **Tray.** Nothing else registers until the tray is live.
3. **Hotkey + autostart**, re-registered from the persisted preference.
4. **Device probe**, which decides typed-input mode.

`lib/features/desktop/desktop_bootstrap.dart` is the only place that sequence lives.

## Kill-switch parity

The tray `KILL-SWITCH` row behaves exactly like the mobile one: **no biometric**, stops
listening, closes the WebSocket, turns the tray icon red. Releasing it is only possible from
the open app window — a stray tray click can never re-arm a stopped assistant.

## Manual test matrix

Run each row on a clean install (no prior `%APPDATA%\armx_ai`, no `~/Library/Application
Support/armx_ai`, no `~/.local/share/armx_ai`).

### Windows 10 and Windows 11

| # | Check | Expected |
| --- | --- | --- |
| W1 | Launch A.R.M.X, sign in, close the window | The process stays in the tray; the icon is visible. |
| W2 | Right-click the tray icon | `Open A.R.M.X`, `Talk now`, `Pause 15 min`/`1 hour`/`4 hours`, `Background readiness`, `KILL-SWITCH`, `Settings`, `Quit`. |
| W3 | Press `Ctrl+Alt+Space` | The popup appears near the cursor and starts listening. |
| W4 | Press `Ctrl+Alt+Space` again | The popup hides; the tray icon returns to idle. |
| W5 | Rebind to `Ctrl+Alt+F7` in Settings | The new combination works; after a restart it is still the new one. |
| W6 | Bind a combination another app owns | "Already in use by another app. Pick another combination." and the old binding keeps working. |
| W7 | Sign out, sign back in | A.R.M.X starts by itself and the tray icon appears. |
| W8 | Toggle "Launch A.R.M.X at login" off, reboot | It does not start; the tray icon is absent; the toggle is still off. |
| W9 | Unplug the microphone | The tooltip says `voice unavailable — use hotkey`; the hotkey opens the popup in typed-input mode. |
| W10 | Replug the microphone | Within 5 s the tooltip returns to the normal state. |
| W11 | Tray `KILL-SWITCH` | Icon turns red, listening stops, the socket closes. |
| W12 | Tray `KILL-SWITCH` again | Refused ("open the A.R.M.X window to release"). |
| W13 | Open the window and release | Icon returns to cyan; listening resumes. |
| W14 | Launch a second copy while one runs | The second copy focuses the first popup and exits; Task Manager shows one process. |
| W15 | Tray `Quit` while listening | A confirmation appears; confirming exits, cancelling keeps it running. |
| W16 | Settings → Background readiness | Autostart / tray / hotkey / microphone / camera rows, each with a status pill and a fix link. |
| W17 | SmartScreen / Defender on a fresh install | No quarantine: the app is signed by the owner's certificate and always shows a tray icon. |

### macOS (Intel and Apple Silicon)

| # | Check | Expected |
| --- | --- | --- |
| M1 | Close the window | The app stays in the menu bar (dock icon may hide). |
| M2 | Menu-bar icon | Light/dark variants swap with the system appearance. |
| M3 | `⌘+Shift+Space` | Popup + listening, including while the wake word is paused. |
| M4 | System Settings → General → Login Items | A.R.M.X is listed; toggling the in-app switch removes it. |
| M5 | Reboot | A.R.M.X starts and the menu-bar icon appears. |
| M6 | Rebind in Settings | Persists across restarts; conflicts are reported. |
| M7 | Microphone permission denied | `permission denied` in readiness; typed-input mode; face verification falls back to Touch ID + typed passphrase. |
| M8 | Kill-switch engage/release | Same as W11–W13. |
| M9 | Second launch | Focuses the first, exits. |
| M10 | Gatekeeper | No "damaged app" dialog: the login item is registered through `SMAppService` and the app shows a menu-bar icon. |

### Ubuntu (GNOME and KDE)

| # | Check | Expected |
| --- | --- | --- |
| L1 | `sudo apt-get install keybinder-3.0 gnome-shell-extension-appindicator` | Installed before the first launch. |
| L2 | Tray icon | Visible in the GNOME top bar / KDE system tray. |
| L3 | `Ctrl+Alt+A` | Popup + listening. |
| L4 | Without `keybinder-3.0` | The tray works; readiness shows the hotkey row red with a fix link; nothing crashes. |
| L5 | `~/.config/autostart/armx_ai.desktop` | Written when the toggle is on, removed when off. |
| L6 | Sign out and back in | A.R.M.X starts; the tray icon appears. |
| L7 | Camera | Readiness shows `unsupported`; face verification degrades to the system biometric + typed passphrase; HIGH-tier actions are never silently downgraded. |
| L8 | `parecord`/`pactl`/`ffmpeg` missing | Recording reports "no microphone"; the intercom's hold-to-talk is disabled with a clear message. |
| L9 | Kill-switch + second launch + quit | Same as W11–W15. |

### All platforms

| # | Check | Expected |
| --- | --- | --- |
| A0 | Open `/desktop-popup` in a desktop build | The popup card renders standalone: orb, transcript, composer, `Dismiss (Esc)`. Useful for exercising typed-input mode without a tray icon. |
| A1 | `flutter analyze` | Zero issues. |
| A2 | Unit tests | Hotkey conflict, device-availability fallback, tray state machine, autostart persistence, consent state machine, DND handling, mutual-log consistency. |
| A3 | Widget tests | Consent screen, overlay muted/unmuted, admin talk screen opted-in vs not. |
