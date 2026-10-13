<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# Backend contracts the frontend depends on

This document is the frontend's side of the agreement with the FastAPI service. It exists so a
backend change can be checked against what the client actually needs, and so the mock
(`lib/data/api/mock`) can be kept honest.

Everything here is implemented once, in `ArmxApi` (`lib/data/api/armx_api.dart`) and
`RestArmxApi`. No screen talks to the network directly.

## Transport

| | |
| --- | --- |
| REST base URL | `ARMX_API_BASE_URL` (`--dart-define`), HTTPS only outside a debug mock build |
| Socket URL | `ARMX_WS_URL`, defaulting to the base URL with the scheme swapped and `/ws` appended |
| Auth | `Authorization: Bearer <access token>`; the socket sends `{"type":"auth","token":…}` as its first frame |
| Content | JSON, `snake_case` keys |
| Timeouts | connect 10 s, request 30 s (from `AppConfig`) |
| Uploads | none from the client; camera and microphone audio never leave the device unencrypted and are not uploaded by this build |

## Errors

Errors arrive as an HTTP status plus `{"message": …, "code": …}`. The client maps them onto one
sealed `AppException` hierarchy, and those subtypes are what the UI switches on:

| Status / condition | Exception | What the UI does |
| --- | --- | --- |
| 401 `invalid_credentials` | `UnauthorizedException` | shows the sign-in failure, never says which field was wrong |
| 401 `email_not_verified` | `UnauthorizedException` | sends the user to the verification screen |
| 401 `refresh_rejected` | `UnauthorizedException` (`refreshRejected`) | signs out and redirects to sign-in with `?next=` |
| 403 | `ForbiddenException` | shows the reason; no retry offered |
| 404 | `NotFoundException` | shows the missing target |
| 409 | `ConflictException` | shows the current state, offers a reload |
| 422 / field errors | `ValidationException` (with `fieldErrors`) | attaches messages to the offending fields |
| 429 | `RateLimitedException` (`retryAfter`) | counts down before offering a retry |
| 5xx | `ServerException` | offers a retry, keeps the last good state on screen |
| Never valid JSON | `MalformedResponseException` | reports a malformed response rather than showing half of it |
| Policy refusal | `PolicyException` (with `reason`) | explains the refusal; it is not an error to retry |
| Missing capability | `CapabilityException` (with `capability`) | names what the device or account cannot do |
| Timeout / no route | `TimeoutException` / `NetworkException` | offline notice plus a manual fallback where one exists |

## Session lifecycle

1. `POST /auth/login` or `POST /auth/google` → `{access_token, refresh_token, expires_in, user}`.
   Tokens go to `flutter_secure_storage` (Keychain / EncryptedSharedPreferences) — never to
   `SharedPreferences`, never to a log, never to a URL.
2. The client refreshes on a 401 by calling `POST /auth/refresh` once per failure burst. A
   refresh that is itself rejected moves the session to `sessionExpired`, which the router turns
   into a redirect to sign-in carrying `?next=` so the user returns where they were.
3. `POST /auth/logout` revokes the current session; `DELETE /sessions/{id}` revokes another.
   Revoking the current session from the list is refused client-side *and* must be refused by
   the backend.
4. The socket opens after sign-in and closes on sign-out. It is never opened for a signed-out
   account, and a reconnect re-sends the auth frame rather than trusting the previous one.

## Socket frames (server → client)

`RestArmxApi` maps these onto `AssistantEvent`s; an unrecognised frame is dropped rather than
guessed at.

| `type` | Payload | Effect |
| --- | --- | --- |
| `assistant.token` | `message_id`, `text`, `done` | appends/continues a streaming reply |
| `assistant.tool_call` | the tool call object | adds a tool-call card in `awaitingDecision` |
| `assistant.tool_status` | `tool_call_id`, `status`, `message` | moves the card to running/succeeded/denied/failed |
| `device.state` | the device object | updates the device in place, and any open detail view |
| `admin.kill_switch` | the kill-switch object | shows the estate-wide banner to every signed-in client |

Client → server frames are the REST calls (`POST /assistant/messages`,
`POST /assistant/tool_calls/{id}/decision`); the socket is a push channel only, so a dropped
connection cannot lose a user's message.

## Endpoints the client calls

Grouped as they are in `ArmxApi`:

* **Auth** — `auth/login`, `auth/signup`, `auth/google`, `auth/verify`, `auth/resend`,
  `auth/password/request`, `auth/password/reset`, `auth/password/token`, `auth/refresh`,
  `auth/logout`, `me`, `sessions`, `sessions/{id}` (DELETE).
* **Assistant** — `assistant/messages` (POST), `assistant/tool_calls/{id}/decision`,
  `assistant/transcript?conversation_id=`.
* **Smart home** — `rooms`, `devices`, `devices/{id}/commands` (POST, carrying the command, its
  parameters and the client's `declared_risk`).
* **Alarms** — `alarms`, `alarms/{id}` (PUT/DELETE), `alarms/{id}/test`, `alarms/{id}/ack`.
* **Linked devices** — `linked_devices`, `pairing` (POST/DELETE), `pairing/approve`,
  `linked_devices/{id}` (DELETE, requiring the owner's own password).
* **Guest greeter** — `greeter`, `greeter/camera`, `guests`, `guests/{id}` (DELETE),
  `greeter/events`.
* **Web builder** — `web_builder/drafts` (POST), `web_builder/deployments` (POST/GET).
* **Messaging** — `contacts`, `tones`, `tones/{id}` (PUT), `contacts/{id}` (PATCH).
* **Admin** — `admin/users`, `admin/users/{id}` (PATCH), `admin/audit`, `admin/tools`,
  `admin/tools/{id}` (PATCH), `admin/kill_switch` (GET/POST).

## What the client will not do

* It will not retry a POST that may have had an effect without the user asking.
* It will not apply a device command locally before the backend confirms it.
* It will not render a deployment as live without a `live_url`.
* It will not send biometric data anywhere; `local_auth` returns a yes/no on the device and
  nothing else leaves it.
* It will not read, store or transmit a secret: there is no field for one, and the config
  summary is asserted to contain none.
