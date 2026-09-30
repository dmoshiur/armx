<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# A.R.M.X AI — network contract (client side)

Single source of truth for the REST/WebSocket contract the client is written against.
`MockArmxApi` implements this document exactly, so the app can be built and tested today and
switching to the real server is a matter of setting `USE_MOCK=false`.

Everything below is JSON over **TLS only** (`https` / `wss`). Requests carry
`Authorization: Bearer <access_token>` and, once paired, `X-Armx-Device-Key: <device_key>`.

## Risk tiers

| Tier | Required verification | Client behaviour |
| --- | --- | --- |
| `LOW` | face **or** voice (voice alone is never trusted — see `RiskPolicy`) | runs immediately |
| `MEDIUM` | face **and** voice, both within the 60 s trust window | tool card requires an explicit Approve |
| `HIGH` | face **and** voice **and** system biometric/PIN | tool card requires an explicit Approve **and** a fresh `owner_verified` assertion |

Unknown or missing tiers are treated as `HIGH` (fail closed). A verification result older
than 60 s is discarded, and escalating the tier forces re-verification.

## REST

> **Step 2 additions (client-side assumptions):** `GET /health`, `POST /auth/refresh`,
> `POST /auth/logout`, `POST /devices/unpair`, the `pending`/`rejected` answers of
> `POST /devices/pair` and the `423 auth_account_locked` login error were specified here
> when the auth UI was built — the original document only defined `POST /auth/login` and
> `POST /devices/pair` (approved). The backend must implement them as written below;
> `MockArmxApi` already does.

### `GET /health`

Unauthenticated liveness probe behind the "Test connection" button.

`200` → `{ "server_version": "mock-1.0.0", "requires_pairing": true, "at": "2026-09-30T11:59:00Z" }`

Unreachable hosts reject the TLS handshake or time out; the client shows the network error
verbatim (no data leaks whether any device exists).

### `POST /auth/login`

```json
{
  "username": "mohiur",
  "password": "…",
  "device_key": "mockkey_…",
  "platform": "android",
  "client_version": "0.1.0+1"
}
```

`200` →

```json
{
  "access_token": "…", "refresh_token": "…", "expires_at": "2026-09-30T12:30:00Z",
  "device_id": "device-1a2b3c4d",
  "user": {
    "id": "user-mohiur", "display_name": "Md. Moshiur Rahman Mohi",
    "email": "owner@thamjj13.top", "roles": ["owner", "admin"]
  }
}
```

Errors: `401 auth_invalid_credentials`, `403 auth_pairing_rejected`, `403 auth_device_revoked`,
`403 auth_account_locked` (account disabled after repeated failures or by an admin — the
client renders a dedicated localized message and does not offer immediate retry).

### `POST /auth/refresh`

```json
{ "refresh_token": "…" }
```

`200` → `{ "access_token": "…", "refresh_token": "…", "expires_at": "2026-09-30T12:30:00Z" }`

The refresh token is **rotated**: the old one stops working the moment a new pair is issued.
Errors: `401 auth_refresh_rejected` (unknown/expired/rotated-away token) — the client must
discard both tokens and return to the login screen.

### `POST /auth/logout`

Best effort. Requires the bearer token. `204` on success (the client deletes its local
tokens even when the server is unreachable).

### `POST /devices/pair`

Registers this device's **Ed25519 public key**. The private key never leaves the keyring.

```json
{ "public_key": "MCowBQYDK2VwAyEA…", "device_name": "Mohiur Pixel", "platform": "android" }
```

`200` (approved) → `{ "device_id": "device-…", "device_key": "mockkey_…", "site": "home",
"paired_at": "2026-09-30T11:00:00Z" }`

`202` (awaiting approval) → `{ "status": "pending", "device_id": "device-…",
"message": "Awaiting owner approval" }` — the client keeps showing the QR/fingerprint and
re-posts the same body to poll; the `device_id` stays stable while pending.

Errors: `403 auth_pairing_rejected` (the owner refused the device — the client shows the
rejected state with a retry). `public_key` is the base64 **SPKI DER** of the Ed25519 key
(12-byte prefix `302a300506032b6570032100` + the raw 32-byte key); the fingerprint shown
in the UI is SHA-256 over those exact bytes.

### `POST /devices/unpair`

```json
{ "device_id": "device-…" }
```

`204` — removes the registration server-side. Idempotent; the client also wipes its
keypair and tokens locally whether or not the call succeeded.

### `GET /devices`

`200` →

```json
[
  {
    "id": "dev-living-light", "name": "Living Room Lights", "site": "home", "kind": "LIGHT",
    "online": true, "risk_tier": "MEDIUM", "firmware": "1.4.2",
    "last_seen_at": "2026-09-30T11:59:48Z",
    "relays": [{ "id": "relay-main", "label": "Main", "state": "OFF" }],
    "sensors": [{ "id": "sensor-pir", "label": "Motion", "value": 0 }]
  }
]
```

### `POST /devices/{id}/command`

```json
{ "command": "relay-main:ON", "parameters": {}, "risk_tier": "MEDIUM" }
```

`200` → `{ "device_id": "dev-living-light", "accepted": true, "command_id": "cmd-…",
"at": "…", "message": "Applied \"relay-main:ON\"" }`

Errors: `404 device_not_found`, `409 device_offline`, `428 policy_verification_required`
(client must re-verify and retry), `423 kill_switch_active`.

### `GET /audit`

Query parameters: `from`, `to`, `risk_tier`, `outcome` (`SUCCESS|FAILURE|DENIED`), `actor`,
`search`, `limit` (default 50), `offset`. Newest entry first.

### `POST /admin/kill`

```json
{ "engaged": true, "reason": "Owner engaged the kill-switch" }
```

`200` → `{ "engaged": true, "at": "…", "actor": "owner", "sockets_closed": 1 }`

Engaging the switch **must** stop in-flight work, clear pending tool calls and close the
WebSocket; the client does the same locally, without any biometric prompt.

### `POST /admin/tools`

```json
{ "tool": "GITHUB", "enabled": false }
```

### `POST /admin/revoke`

```json
{ "device_id": "device-1a2b3c4d" }
```

### `POST /unlock/request`

```json
{
  "device_id": "pc-studio", "nonce": "8f2c…", "exp": "2026-09-30T12:00:28Z",
  "issued_at": "2026-09-30T11:59:58Z", "action": "unlock", "algorithm": "Ed25519",
  "public_key": "MCowBQYDK2VwAyEA…", "signature": "base64…",
  "assertion": {
    "token": "owner-verified-…", "scope": "owner_verified", "single_use": true,
    "iat": "2026-09-30T11:59:58Z", "exp": "2026-09-30T12:00:58Z"
  }
}
```

* `exp` may be at most **30 s** after `issued_at`; the signature covers the canonical JSON of
  `{device_id, nonce, exp, action}`.
* The optional `assertion` is the **only** verification artefact that leaves the device: a
  signed, single-use, 60-second, scoped `owner_verified` token. Face templates, palm
  geometry and voice prints are never transmitted.
* Result: `{ "status": "UNLOCKED" | "FAILED" | "EXPIRED", "request_id": "unlock-…",
  "target_id": "pc-studio", "message": "…" }`
* Errors: `400 bad_signature`, `400 token_ttl_too_long`, `409 target_offline`,
  `423 kill_switch_active`.

### `GET|POST /rules`, `DELETE /rules/{id}`, `POST /rules/dry-run`

A rule is:

```json
{
  "id": "rule-drive-focus", "name": "Driving → focus mode", "enabled": true,
  "trigger_type": "ACTIVITY_IS", "action_type": "SCENE",
  "trigger_params": { "activity": "IN_VEHICLE" },
  "action_params": { "scene_id": "scene-focus" },
  "risk_tier": "MEDIUM", "dry_run": false, "run_count": 12,
  "last_run_at": "2026-09-29T18:04:00Z"
}
```

`POST /rules/dry-run` returns
`{ "rule_id": "…", "would_fire": true, "blocked_reason": "", "steps": ["…"] }` and never
executes the action.

## WebSocket `GET /ws`

One JSON object per frame. The client ignores unknown `type` values and never throws on a
malformed frame.

| `type` | Payload | Client effect |
| --- | --- | --- |
| `assistant.token` | `message_id`, `conversation_id`, `token`, `index` | appends to the streaming bubble |
| `assistant.done` | `message_id`, `text`, `finish_reason`, `blocked` | finalises the bubble |
| `tool.request` | `call{id, tool, parameters, risk_tier, reason}` | shows the Approve/Deny card (MEDIUM/HIGH also need verification) |
| `tool.result` | `tool_call_id`, `success`, `summary` | updates the card |
| `device.state` | `device{id, online, relays[], …}` | merges into the device list |
| `system.killed` | `engaged`, `reason`, `actor` | forces the red locked state in every screen |
| `system.heartbeat` | — | keeps the connection alive |

Reconnect uses exponential backoff with jitter; the client re-authenticates with the refresh
token before resubscribing.

## Errors

Every non-2xx response uses the same envelope:

```json
{ "code": "device_offline", "message": "Device is offline", "retryable": true, "request_id": "…" }
```

The client maps `code` to `AppException` subtypes (`AuthException`, `PolicyException`,
`KillSwitchActiveException`, `NetworkException`, `ApiException`) and shows a localized
message; `message` is never rendered raw.

## MQTT (backend side only)

The app never speaks MQTT. The server bridges it to the ESP32 nodes on
`armx/{site}/{device}/cmd` and `armx/{site}/{device}/state`. Those topic names appear in tool
parameters (`mqtt.publish`) so the audit trail shows exactly what was published.
