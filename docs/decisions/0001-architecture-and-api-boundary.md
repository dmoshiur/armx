<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# 0001 — One interface, two implementations, and a frontend that never invents a result

**Status:** accepted · **Applies to:** `lib/core/network`, `lib/data/api`, `lib/data/api/mock`,
every controller in `lib/features/*/application`

## Context

The client is a Flutter frontend for an existing FastAPI backend that it does not own. During
development the backend is not always reachable — a phone on a train, a laptop without a VPN,
a colleague who only needs to see a screen. The tempting shortcut is to scatter
`if (kDebugMode) return _fakeDevices;` through the UI, and every project that does it ends up
shipping a screen that shows a green tick for a request that was never sent.

## Decision

1. **One interface.** Every backend interaction is a method on `ArmxApi`
   (`lib/data/api/armx_api.dart`). No widget, controller or repository constructs an HTTP
   client, and none of them knows whether the implementation in front of it talks to a server.
2. **Two implementations, chosen once, at the provider.**
   * `RestArmxApi` — dio over HTTPS and a `WebSocketClient` for server-pushed events.
   * `MockArmxApi` — an in-process state machine with fixed fixtures, selected only when
     `AppConfig.useMockBackend` is true (`--dart-define=ARMX_USE_MOCK_BACKEND=true`).
3. **The mock behaves like a backend, not like a demo.** It refuses what a real one refuses:
   a wrong password fails, an unverified address reports `email_not_verified`, a HIGH-risk tool
   call stops at `awaitingDecision` until a decision arrives, a deployment is `pending` before
   it is `live`, a non-admin cannot read the admin surface, and unlinking a device checks the
   owner's password. `test/unit/data/api/mock_api_test.dart` asserts exactly that list.
4. **Nothing renders a result it did not receive.** A device command is `pending` until the
   backend confirms (or the device reports in). A deployment without a `live_url` is not live.
   A tool call without a status is not a success. Failure text comes from the exception, and
   the last good state is kept on error rather than replaced by a guess.
5. **One place decides what the client may say.** `AppConfig` carries the base URL, the socket
   URL, the environment label and the mock flag — and nothing else. It has no field that could
   hold a token, a key or a password, and `describe()` (rendered in Settings → Diagnostics)
   prints exactly those five keys. `test/unit/core/config/app_config_test.dart` fails if a
   sixth appears.
6. **Cleartext is a build error, not a warning.** `AppConfig.httpsBaseUrl` throws when the base
   URL is `http://` and the build is not a debug mock build, so a misconfigured release fails
   before `runApp`.

## Consequences

* Swapping the backend for a different one means writing one new class, not touching a screen.
* The suite runs with no network and no server: `flutter test` is enough, which is why the
  coverage gate in CI can be meaningful.
* Every fixture lives in one file (`mock_fixtures.dart`) and is reused by tests, so a fixture
  that drifts from what the UI expects fails a test rather than surprising a demo audience.
* The mock is extra code to keep honest. The mitigation is that its refusals are tested
  explicitly — the mock is judged by what it *won't* do.

## Alternatives considered

* **`http` package instead of dio** — dio's interceptors, cancellation tokens and typed
  timeouts are what the auth-refresh and retry rules need; the alternative was re-implementing
  them.
* **Repository classes per feature wrapping the API** — rejected as ceremony: the API interface
  is already the seam, and a second layer would only add places for state to hide.
* **`freezed`/`json_serializable`** — the project is codegen-free by choice (see the checker
  rule that forbids `part '*.g.dart'`): models are plain classes with explicit, testable
  `fromJson`, including the deliberate fail-closed fallbacks.
