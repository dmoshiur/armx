<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# Decision 0003 — verification tooling for deliveries finished off-SDK

Status: accepted (steps 4–10).

## Context

Deliveries 4–10 were written in an environment where the Flutter SDK could not be installed:
`pub.dev`, `storage.googleapis.com` (the SDK/release host) and every non-GitHub
package mirror are unreachable, and no Dart/Flutter toolchain is present. `flutter analyze`,
`flutter test`, `flutter build` and `dart run build_runner` therefore **cannot execute
during authoring**. The repository also does not commit generated sources
(`*.freezed.dart`, `*.g.dart`, `lib/l10n/generated/**`), so even a correct checkout only
compiles after a codegen pass.

Pretending those commands ran would be worse than saying so: the product spec rewards
honesty about limits, and a reviewer needs to know exactly which claims are verified.

## Decision

Three compensating controls, all committed:

1. **`tool/static_checks.py`** — an offline structural checker that catches the mistakes the
   Dart analyzer would otherwise catch *structurally*:
   * missing `Copyright` header on any new Dart/Kotlin/XML/Gradle file;
   * unbalanced brackets per Dart file (comment/string aware);
   * unresolved `import` / `export` / `part` targets (codegen outputs excluded);
   * unknown `l10n.<key>` references, EN/BN key parity and placeholder parity;
   * hardcoded-secret and cleartext-`http://` patterns in `lib/`;
   * new files that would introduce `part '*.g.dart'` / `part '*.freezed.dart'`
     (see decision 0004).
2. **CI** (`.github/workflows/ci.yml`) — runs the full canonical sequence
   (`pub get` → `build_runner` → `gen-l10n` → static checks → `flutter analyze` →
   `flutter test --coverage` → 70 % gate over `core/` + `data/`). One push turns the
   unverified claims into verified ones.
3. **`docs/verification.md`** — the exact local command list, plus the definition of
   "done" used in every step report of this phase.

## Consequences

* Step reports distinguish **verified here** (static checks, ARB JSON parse, git diff
  review) from **must be verified by CI/local run** (`analyze`, `test`, builds).
* Coverage numbers are *not* claimed in the step reports of steps 4–10; the gate in CI is
  the authority. `tool/coverage_gate.py` implements the same 70 % threshold locally.
* The checker is deliberately conservative: it is allowed to add notes for pre-existing
  oversize files, and it fails only on the classes of defect listed above.
