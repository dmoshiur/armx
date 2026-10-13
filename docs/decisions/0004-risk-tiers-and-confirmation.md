<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# 0004 — Risk tiers decide the friction, and the client may only add it

**Status:** accepted · **Applies to:** `lib/core/security/risk_tier.dart`,
`lib/core/confirm/confirm_policy.dart`, `lib/core/widgets/armx_confirm_dialog.dart`,
`lib/features/assistant`, `lib/features/smarthome`, `lib/features/web_builder`,
`lib/features/admin`

## Context

Some actions in this app are irreversible or security-sensitive: unlocking a front door,
publishing a site to a repository, engaging the kill switch, revoking every other session,
unlinking a device, deleting an enrolled guest. Some are entirely ordinary: turning on a lamp,
acknowledging an alarm, switching the greeter camera **off**. Treating everything the same
either makes the ordinary annoying or the dangerous cheap.

## Decision

1. **Three tiers, and only three.** `RiskTier.low` runs immediately. `RiskTier.medium` needs a
   confirmation. `RiskTier.high` needs a confirmation, is marked irreversible where that is
   true, and — for the actions listed below — needs a typed phrase.
2. **The server's tier is the floor, never the ceiling.** `RiskTier.fromWire` maps the backend's
   spelling (`low`/`medium`/`high`, plus `critical` → high) and treats anything unrecognised as
   **high**, so an unknown tier demands a confirmation rather than skipping one. A screen may
   raise a tier (a device the user cannot fully control, a command whose effect is broader than
   it looks) but the `SmartHomeController.command` path never lowers the declared risk.
3. **The dialog says exactly what will happen.** Every confirmation shows the action name
   (verbatim, as the backend names it — `web_deploy`, `unlock_front_door`, never a euphemism),
   the target (`thamjj13/armx-site#main`, `Front door`), every parameter the call will carry,
   the consequence in one sentence, and the risk tier as a word. The confirm button is labelled
   with the action, never "OK".
4. **A HIGH-risk dialog cannot be dismissed by habit.** The default focus is the **cancel**
   button, so pressing Enter cancels rather than confirms; the destructive button is disabled
   until the typed phrase matches (`CONFIRM`, or the backend's phrase where it supplies one).
5. **Actions that are always phrased-gated:** `web_deploy`, `kill_switch`, `revoke_sessions`
   and `unlock`. Actions that are irreversible without a phrase: `unlink_device`, `delete_guest`,
   `delete_alarm`. The policy is data (`ConfirmPolicy.requiresTypedPhrase`,
   `ConfirmPolicy.isIrreversible`) and is tested as data.
6. **Privacy-relaxing changes are confirmed; privacy-restoring ones are not.** Turning the
   greeter camera **on**, granting the overlay permission and enabling auto-send are confirmed.
   Turning the camera off, hiding the bubble and switching to draft-only are immediate — the
   switch that stops watching must never be the one that is hard to reach.
7. **Pending is a state, not a success.** After a confirmation the UI shows a pending
   indicator ("Waiting for the server to confirm…") until the backend answers; a device command
   in flight renders as pending and is never drawn as applied.
8. **Unavailable actions are disabled with a reason, never hidden.** A device the user cannot
   control, a tool an administrator disabled, a feature whose permission was refused: each
   renders disabled and says why.

## Consequences

* The confirmation policy is the single place that decides friction, so a new destructive action
  added to a screen is one entry in one set plus one call — and the absence of that call is
  visible in review.
* The acceptance test is behavioural, not visual: sign in, ask for something LOW risk and it
  happens with no dialog; ask for something HIGH risk and the dialog appears **before any
  backend call**, asserted against a recording client
  (`integration_test/app_flow_test.dart`).
* The typed phrase is a speed bump, not a security control; the security control is the
  backend's own authorisation. The tier system exists to make the user's intent explicit.

## Alternatives considered

* **A single "are you sure?" for everything** — trains people to tap yes.
* **No confirmation, with undo** — there is no undo for publishing to a repository or unlocking
  a door.
* **Trusting the client's risk assessment as the last word** — the client does not know what a
  device does; it can only decide how much friction to add.
