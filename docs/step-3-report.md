<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# Step 3 report — chat, WebSocket client, tool approval cards

A.R.M.X AI client · owner **Md. Moshiur Rahman Mohi** · brand **THAMJJ13.TOP** ·
Flutter 3.47.5 / Dart 3.13.4 · target Android + Windows/Linux desktop.

> **Sandbox limitation.** This container has no Flutter/Dart SDK, so `flutter analyze`,
> `flutter test` and `dart run build_runner` could not be executed here. Every cross-file
> reference was reconciled by reading the source; the open items to confirm on the first
> analyzer run are listed at the end of this document.

## 1. What this delivery adds

Step 3 turns the `PlaceholderPage` of the chat tab into the assistant conversation:

* **Streaming transcript** — `assistant.token` frames append to one bubble,
  `assistant.done` finalises it with the authoritative server text (or marks it
  `blocked` when policy suppressed the reply). A blinking-caret equivalent marks the
  live bubble; failed user messages offer an in-place retry.
* **Tool approval cards** — every `tool.request` becomes a card with the tool name,
  the assistant's reason, the read-only parameters and the risk badge:
  * **LOW** never raises a card: the client approves immediately and the server's
    `tool.result` lands as a one-line outcome;
  * **MEDIUM / HIGH** demand an explicit Approve/Deny and, before an approval is
    sent, fresh `RiskPolicy` evidence (face+voice, plus a system biometric for HIGH)
    captured through the `VerificationGateway`; HIGH additionally mints the
    single-use `owner_verified` assertion the server requires.
* **Realtime channel** — one subscription folded into state, exponential-backoff
  reconnect (250 ms → 5 s ceiling) on socket loss, `system.killed` handling that
  blocks the composer, expires pending cards and clears captured evidence.
* **Offline transcript** — user/assistant/system messages persist in the existing
  `ChatMessagesCache` Drift table and are restored on the next cold start; "clear
  chat" wipes them.
* **Localization** — 23 new keys in `app_en.arb` / `app_bn.arb` (254 keys each now).

## 2. Files

```
lib/core/security/verification_gateway.dart   NEW   gateway contract + simulated impl
lib/core/providers.dart                       EDIT  chatRepository + verificationGateway
lib/core/router/app_router.dart               EDIT  chat branch → ChatPage
lib/data/repositories/chat_repository.dart    NEW   transcript persistence (Drift)
lib/data/db/armx_database.dart                EDIT  mostRecentConversationId()
lib/data/db/tables.dart                       EDIT  wire-value doc comments
lib/data/api/mock/mock_assistant.dart         EDIT  LOW-tier scripted turn
lib/data/api/mock/mock_chat_domain.dart       EDIT  LOW calls run without a card
lib/features/chat/chat_state.dart             NEW   ChatConnection + ChatState
lib/features/chat/chat_controller.dart        NEW   ChatController (riverpod)
lib/features/chat/chat_page.dart              NEW   the chat tab
lib/features/chat/widgets/chat_bubble.dart    NEW   message bubbles / tool lines
lib/features/chat/widgets/tool_approval_card.dart NEW Approve/Deny card
lib/features/chat/widgets/chat_composer.dart  NEW   input row + send button
lib/features/chat/widgets/chat_suggestions.dart  NEW starter prompts
lib/l10n/app_en.arb, app_bn.arb               EDIT  23 chat keys each
test/unit/features/chat/chat_controller_test.dart  NEW
test/widget/chat/chat_page_test.dart               NEW
docs/api.md, docs/run.md, README.md, docs/step-3-report.md  EDIT/NEW
```

## 3. Event flow

`ChatController.build()` subscribes once to `ArmxApi.events()` and folds each frame
(the `switch` is exhaustive over the sealed `WsEvent` hierarchy; unknown/device/
heartbeat frames are deliberately ignored — they belong to steps 5/6):

| Frame | Controller effect |
| --- | --- |
| `assistant.token` | creates the streaming bubble on first token, appends afterwards |
| `assistant.done` | replaces the bubble text with the server text; `blocked` → amber bubble |
| `tool.request` | appends a tool message and registers the `ToolCall` as `pending` |
| `tool.result` | `succeeded` / `failed` (a `denied` card keeps its state); unknown id → tool line |
| `system.killed` | engaged: banner, composer off, pending cards `expired`, evidence cleared; released: composer back |
| socket `done`/`error` | connection → `reconnecting`, resubscribe with backoff |

## 4. Per-file public surface

### `lib/core/security/verification_gateway.dart` · 80 lines

- **VerificationGateway** — on-device factor capture contract (`verify({tier, reason})`).
- **SimulatedVerificationGateway** — deterministic stand-in: records exactly the factors
  `RiskPolicy` demands for the tier, all fresh at the injected clock. Replaced by the real
  face/voice/biometric pipelines in steps 4/7 by swapping one provider.

### `lib/data/repositories/chat_repository.dart` · 76 lines

- **ChatRepository** — `recent`, `save` (upsert, skips tool-role rows), `clear`,
  `mostRecentConversationId`. Mapping is a `ChatMessage.toJson()` /
  `ChatMessage.fromJson()` round-trip, so the cache stores the same wire values as the API.

### `lib/features/chat/chat_state.dart` · 87 lines

- **ChatConnection** — `live` / `reconnecting` / `offline` (app-bar pill).
- **ChatState** — messages, live tool calls, streaming id, verifying id, killed, restored,
  error; hand-written `copyWith` with the sentinel pattern used by `AuthState`.

### `lib/features/chat/chat_controller.dart` · 507 lines

- **ChatController** — `send`, `retry`, `approve`, `deny`, `clear`, `dismissError`.
  Provider: `chatControllerProvider` (keepAlive).

### `lib/features/chat/chat_page.dart` · 388 lines

- **ChatPage** — app bar (streaming subtitle, clear action, connection pill), kill/error
  banners, reversed transcript, empty state (orb + pitch + starter prompts), composer.
  Private widgets: `_Transcript`, `_MessageRow`, `_EmptyTranscript`, `_ConnectionPill`,
  `_KillBanner`, `_ErrorBanner`.

### Widgets

- **ChatBubble** (`widgets/chat_bubble.dart`, 203 lines) — user bubble, assistant bubble
  (`SanitizedMarkdown`, streaming caret, blocked note, retry), system notice, tool line.
- **ToolApprovalCard** (`widgets/tool_approval_card.dart`, 244 lines) — tier accent, tool
  name, reason, read-only parameter block, status area (verifying / running / succeeded /
  failed / denied / expired) and the Approve/Deny row.
- **ChatComposer** (`widgets/chat_composer.dart`, 120 lines) — `ArmxTextField` + 48 dp
  circular send button; disabled while killed or streaming.
- **ChatSuggestions** (`widgets/chat_suggestions.dart`, 84 lines) — four starter prompts
  covering MEDIUM, HIGH, a plain answer and the kill-switch.

## 5. Deliberate deviations, flagged

1. **`chat_controller.dart` is 507 lines** — the longest file in the repo (pages run
   350–425). It is one cohesive state machine; the socket handlers are sectioned and are
   the natural extraction point when the dashboard (step 5) and admin panel (step 6) start
   sharing the same event stream.
2. **Tool-role messages are not persisted.** An approval card is live interaction state
   (decision, verification, result), not history; a restored transcript therefore shows
   user/assistant/system bubbles and re-raises any card the server still considers pending.
3. **The composer passes the hint as `ArmxTextField`'s label** instead of adding a
   hint-only variant to the design system; the floating label behaves like a chat hint and
   keeps the field on-brand.
4. **The streaming caret is static** (no animation controller): a repeating animation in
   every streaming bubble would make `pumpAndSettle`-based golden tests (step 10) hang.
5. **The mock backend gained a LOW-tier scripted turn** (`devices.list`) and now runs LOW
   calls immediately (`tool.result` without `tool.request`), so the "no approval card" path
   is exercised offline. MEDIUM/HIGH behaviour is unchanged.
6. **Verification is simulated** (see §4). No camera, microphone or platform channel is
   touched; the gateway is the single seam the real verifiers replace.
7. **No golden baselines for the chat tab** — goldens are a step-10 deliverable
   (`docs/run.md` § 5).

## 6. Tests

`test/unit/features/chat/chat_controller_test.dart` (13 tests) — streaming and
finalisation, empty drafts, MEDIUM approval end-to-end, HIGH approval with the minted
assertion, denial, LOW auto-run, evidence reuse, kill-switch engage/release (including the
reconnect), refused send + in-place retry, refused decision, transcript restore, clear.

`test/widget/chat/chat_page_test.dart` (7 tests) — empty state, suggestion → streamed
reply → MEDIUM card → approve → executed, denial, HIGH approval, LOW tool line,
kill-switch banner + disabled composer, Bengali rendering.

Both suites use the deterministic mock with zero latencies and a fixed clock, so they run
without network, camera or microphone.

## 7. To confirm on the first analyzer run

1. `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs` and
   `flutter gen-l10n` — `chat_controller.g.dart`, `chat.freezed.dart` and
   `lib/l10n/generated/` are not committed.
2. `ChatMessage.toJson()`/`fromJson()` round-trip against the Drift cache: confirm the
   generated freezed JSON uses `risk_tier` / `tool_call_id` / `conversation_id` snake_case
   keys (per `build.yaml`) and that a `null` risk tier stays `null` rather than failing
   closed to HIGH.
3. `ChatMessagesCacheCompanion.insert(...)` with `Value<String?>(null)` for the nullable
   `riskTier` / `toolCallId` columns.
4. The exhaustive `switch` over the sealed `WsEvent` hierarchy in `_onEvent` (Dart 3
   patterns; ignored cases use binding-free patterns).
5. riverpod_generator output for `@Riverpod(keepAlive: true) class ChatController` —
   provider name `chatControllerProvider` and the `$Notifier` base with a public `ref`.
6. `pumpEventQueue(times: …)` availability on this Flutter version (used by the existing
   step-1 chat tests; the step-3 tests pump explicit durations instead).
7. Reconnect timing in widget tests: the mock closes the socket on kill-switch, so the
   backoff timer must be cancelled by `container.dispose` (it is — `ref.onDispose`).
8. `flutter analyze` (zero warnings) and `flutter test --coverage`; the ≥ 70 % gate over
   `core/` + `data/` now also covers `chat_repository.dart` and the LOW-tier mock branch.
