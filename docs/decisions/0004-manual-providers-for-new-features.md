<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# Decision 0004 — hand-written providers and models for steps 4–10

Status: accepted (steps 4–10).

## Context

Steps 1–3 (and the desktop/walkie-talkie add-ons) use `@riverpod` + `freezed` +
`json_serializable`, with the generated files produced by `build_runner` and **not
committed** (`analysis_options.yaml` excludes them; `docs/run.md` requires a codegen pass
before the first analyze).

Deliveries 4–10 were authored without a Dart toolchain (see decision 0003), so generator
output could not be produced or inspected here. Writing new annotated code would mean
committing source whose generated half nobody has ever seen, and every new
`part 'x.g.dart'` is an unresolved-URI error until someone runs the generator.

## Decision

New code introduced in steps 4–10:

* declares providers with the **manual Riverpod API** — `Provider`, `FutureProvider`,
  `StreamProvider`, `NotifierProvider`, `AsyncNotifierProvider` — instead of the
  `@riverpod` annotation;
* declares state/model classes **by hand** (`class VoiceState { … copyWith … }`) instead of
  `freezed`, and hand-writes `fromJson`/`toJson` where the object is on the wire, matching
  the existing hand-written `WsEvent` hierarchy;
* reuses the step-1..3 generated models (`ArmxDevice`, `ToolCall`, `AutomationRule`,
  `UnlockTarget`, …) unchanged.

`tool/static_checks.py` enforces this: a file that did not exist at the branch point may not
declare a `part '*.g.dart'` / `part '*.freezed.dart'`.

Existing annotated code keeps working exactly as before — nothing is migrated.

## Consequences

* The new tree under `lib/features/{voice,vision,dashboard,devices,admin,activity,unlock}`
  plus `lib/core/security/*` additions is analysable **without** a generator pass; the
  pre-existing tree still needs `dart run build_runner build` as before.
* Style is slightly mixed (annotation in steps 1–3, manual in 4–10). When the team wants one
  style, migrating a manual provider back to `@riverpod` is a mechanical, per-file change
  with no behavioural difference; the reverse migration is what this decision avoids.
* Hand-written equality means value classes implement `==`/`hashCode` explicitly where the
  UI depends on it (state classes used in `ref.watch` comparisons).
