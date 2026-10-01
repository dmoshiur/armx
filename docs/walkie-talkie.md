<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# The walkie-talkie: Admin voice announcements

Written to be read aloud at the science fair. Everything below is what the code actually
does, in the order it happens.

## What it is

The Admin or Owner can press a button and speak to one device, or to every device that said
yes. The receiving device plays a chime, shows who is speaking with a live waveform, plays
the recording, and then puts it away. It rides on the WebSocket A.R.M.X already uses for the
assistant, so nothing new is left running in the background.

## The three rules (these are not negotiable)

### Rule 1 — one-time opt-in, and it starts OFF

A device never plays Admin audio until the person holding it turns on **"Allow voice
announcements from Admin/Owner"** in their own Settings. That is the whole permission. There
is no remote enable: the Admin cannot switch it on for someone, the server cannot switch it
on for someone, and a fresh install is silent until the owner speaks up.

Underneath the main switch there is a second, narrower switch — **"Allow while phone is
locked"** — which is also OFF by default. It does not widen the first permission; it only
decides whether playback is allowed on a locked screen.

Turning it off takes effect immediately, on that device only, and needs nobody's approval.

### Rule 2 — every playback is audible AND visible

When an announcement arrives on a device that said yes:

1. a **distinct chime** plays first, so the sound is never mistaken for the assistant;
2. an **overlay** appears with the Admin's name, the words "is speaking", and a live
   waveform;
3. the recording plays;
4. the overlay dismisses itself.

The overlay has two one-tap buttons: **`Mute this once`** (stops the audio, keeps the notice
and the log entry) and **`Turn off announcements`** (revokes consent on the spot).

The overlay is shown **even when the phone is silenced** — Do Not Disturb, silent switch,
focus mode. What is skipped in that case is only the *sound*. A user is never left with a
device that quietly spoke to them with nothing on screen, and never with a screen that spoke
to them with nothing audible. (Detecting the OS focus mode is a documented follow-up: today
the app always attempts the chime once consent exists, and never overrides a system volume
setting.)

### Rule 3 — mutual visibility

Whatever the Admin panel shows about a user, that user sees about themselves in **My
Activity**. Not a summary — the same rows, the same timestamps, the same delivery status.
There is exactly one audit table behind both screens, so the two views cannot drift: a row
the Admin can see for you is a row you can see about yourself. Nothing is logged about a user
that they cannot see. The Admin's CSV export is labelled *"Visible to this user in their own
Activity screen"* for exactly that reason.

If any change would break rules 1–3, the change is refused and flagged instead of being
worked around.

## What the Admin sees

The **Talk** screen lists **only the devices that turned announcements on**. A device that
has not opted in is not shown as a greyed-out row with a disabled button — it is simply
absent, because a disabled send button would still imply the Admin may aim at that person.
The screen says why: *"Nobody has turned voice announcements on yet. They must switch it on
themselves — you cannot enable it for them."*

Then: pick one device, or flip **broadcast**, and hold the button to talk. Release to send.

Delivery status comes back from the device itself:

| Status | Meaning |
| --- | --- |
| `Delivered` | Pushed to the device; the chime and the overlay are up. |
| `Played` | Playback finished. |
| `Missed (offline)` | The device was offline. **It is not silently queued for later.** |
| `Revoked` | The user turned announcements off before it arrived. |

## What a user sees

* Settings → **Voice announcements**: the opt-in, the locked-screen sub-toggle, the three
  rules, and a big **Turn off** button.
* **My Activity**: every announcement sent to this device, newest first, with the same status
  the Admin sees. Read-only. The Admin's view is the same data with a filter and a CSV button.
* The overlay, while an announcement is playing.

## What this feature is NOT (explicit non-goals)

* No two-way listening. The Admin speaks; the device does not stream back.
* No camera, file, message or location access through this feature.
* No remote enabling of consent, by anyone, ever.
* No messaging the user's personal contacts.

## Where the code lives

| Piece | File |
| --- | --- |
| Consent + rules | `lib/features/intercom/intercom_state.dart` (`AnnouncementPolicy`) |
| Consent screen | `lib/features/intercom/intercom_consent_page.dart` |
| Incoming overlay | `lib/features/intercom/announcement_overlay.dart` |
| Admin Talk screen | `lib/features/intercom/admin_talk_page.dart` |
| Shared log (both views) | `lib/features/intercom/intercom_activity_page.dart` + `lib/data/repositories/announcement_repository.dart` |
| Controller (chime → overlay → play → log) | `lib/features/intercom/intercom_controller.dart` |
| Recorder / player | `lib/core/services/intercom_audio.dart` (+ `_native.dart`) |
| Wire frames | `lib/data/api/ws_events_intercom.dart` (`intercom.announcement`, `intercom.outcome`, `intercom.consent`) |
| Mock backend | `lib/data/api/mock/mock_intercom_domain.dart` |
| Feature flag | `PreferenceKeys.intercomEnabled` — "Voice announcements from Admin/Owner" in Settings |

## Tests that keep the rules honest

* **Consent state machine** — `test/unit/features/intercom/intercom_policy_test.dart`:
  default OFF, sub-toggle cannot widen the main consent, revoke is immediate.
* **Backend rules** — `test/unit/features/intercom/mock_intercom_test.dart`: a send to a
  non-consented device is refused, an offline device is `MISSED` (never queued), outcomes
  land on the same rows both views read.
* **DND handling** — the policy test asserts audio is skipped while the overlay is still
  required.
* **Mutual-log consistency** — `test/unit/features/intercom/announcement_log_test.dart` and
  `test/widget/intercom/intercom_activity_page_test.dart`: one table, two readers, identical
  rows.
* **Widget** — `intercom_consent_page_test.dart`, `announcement_overlay_test.dart`
  (muted and unmuted), `admin_talk_page_test.dart` (opted-in vs not listed at all).
