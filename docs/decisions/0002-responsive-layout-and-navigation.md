<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# 0002 — Width decides the layout; the platform never does

**Status:** accepted · **Applies to:** `lib/core/breakpoints.dart`, `lib/core/utils/responsive.dart`,
`lib/features/shell`, every page

## Context

The same codebase runs on a 320 px browser window, a phone, a tablet, a 2560 px monitor and a
resizable desktop window. The classic mistake is to branch on the platform — `Platform.isAndroid
? bottomNav : rail` — which is wrong the moment a phone is rotated, a tablet is split-screened,
or a desktop window is dragged narrow. It also makes the layout untestable without a fleet of
devices.

## Decision

1. **Breakpoints on available width only.** `Breakpoint.fromWidth` returns `compact` (< 600),
   `medium` (600–1024) or `expanded` (≥ 1024). `compactMax`/`mediumMax` are named constants, so
   the boundaries are asserted in `test/unit/core/breakpoints_test.dart` rather than implied.
2. **`Platform.is*` is banned in `lib/`.** The checker fails the build on any occurrence outside
   a comment; there is no escape hatch, because every legitimate use (permissions, path
   separators) belongs behind a plugin call, not a layout branch.
3. **Navigation follows the breakpoint.** Compact shows a bottom bar; medium shows a
   collapsible `NavigationRail`; expanded shows a persistent sidebar with an optional secondary
   panel. The same destinations and the same route names are used at all three sizes, so a
   deep link and a tap land in the same place.
4. **No fixed root widths.** Content is laid out with `Expanded`/`Flexible`, `FractionallySizedBox`
   and `ConstrainedBox`; the page body is capped at `Breakpoint.maxContentWidth` (1200 dp) and
   centred, so a 2560 px monitor shows a readable column with air around it instead of a
   stretched form. Grids use `SliverGridDelegateWithMaxCrossAxisExtent`, so a room grid gains
   columns instead of growing cards.
5. **Touch targets and pointer affordances.** Compact keeps every interactive element at least
   48 dp tall (`Insets.minTouchTarget`, asserted in the widget tests); medium and expanded add
   hover and focus states for a mouse and a keyboard.
6. **Text scaling is respected, then bounded.** The app honours `MediaQuery.textScaler` and
   clamps it to 0.9–1.6 so a 2× setting cannot clip a label into unreadability. Bengali runs
   longer than English, so layouts reflow rather than relying on the clamp.
7. **Start/end, never left/right.** No padding, alignment or icon is mirrored by hand; the
   framework's directionality does it, which is also what makes an RTL locale safe.

## Consequences

* A layout bug found at one width can be reproduced in a test at that width: the reference
  sizes (360×800, 800×1280, 1440×900) are constants in `test/support`, and
  `integration_test/responsive_smoke_test.dart` additionally walks 320, 600, 1024 and 2560.
* Rotation, window resizing and split screen need no code: they change the width, and the width
  already decides everything.
* The 1200 dp cap is a product decision, not a technical limit: it is what keeps a form
  readable and a table scannable on a large display.

## Alternatives considered

* **`responsive_framework` / `flutter_screenutil`** — extra dependencies to do what two
  constants and a `LayoutBuilder` do, and they tend to encourage fixed pixel scaling.
* **Separate phone and tablet widget trees** — two of everything to maintain, and the wrong one
  is always on screen after a rotation.
* **An `adaptive` package keyed on device type** — device type is not the question. Available
  width is.
