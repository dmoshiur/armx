<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# 0003 — The specified palette, plus the tokens it needs to be readable

**Status:** accepted · **Applies to:** `lib/core/theme/colors.dart`, `lib/core/theme/app_theme.dart`,
`lib/core/theme/typography.dart`, `test/unit/core/theme/contrast_test.dart`

## Context

The specification fixes nine hex values and the type scale, and separately requires a 4.5:1
minimum contrast ratio for body text in **both** themes. Those two requirements are not
compatible as written: `muted #5B6475` measures 3.16:1 on `ink #0B1220`, and `accent #5B8CFF`,
`accent2 #8B5CF6`, `danger #E2554E` and `success #3FBF82` all clear 4.5:1 on the dark
background but not on `fog #F4F6FB` or white.

## Decision

1. **The nine specified values are constants, exactly as given, and are asserted in a test.**
   `ArmxPalette.ink`, `navy`, `accent`, `accent2`, `fog`, `line`, `muted`, `danger`, `success`
   are byte-for-byte the specified colours.
2. **The dark theme uses the specified values for surfaces.** Backgrounds are `ink`, cards and
   panels are `navy` with `navyRaised #16224A` for a raised step, borders are `line` at the
   specified value (and at a lower alpha where a hairline is wanted).
3. **Derived tokens exist only where contrast demands them, and each one is documented next to
   the value it came from:**
   * `mutedDark #7C8598` — the same hue as `muted`, lifted until it clears AA on `ink`
     (the specified `muted` remains the secondary text colour on light surfaces).
   * `accentText #2E5FD9`, `accent2Text #6D28D9`, `successText #1F7A4E`, `dangerText #C0392F`
     — the specified hues darkened for light surfaces.
   * `warning #F2B441` / `warningText #8A5A08` — the specification names no warning colour, but
     the MEDIUM risk tier needs one, so a hue is introduced rather than reusing `danger`
     (which would make "needs a confirmation" look like "has failed").
   * `dangerFill #C0392F` — a white 14 px label clears AA on it; the exact `danger` value stays
     the colour of kill-switch borders, glows, dots and icons.
   * `accent2OnDark #A78BFA` — the secondary hue lifted for text on a dark surface.
4. **Colour is never the only signal.** Every status carries a word (`ArmxStatusDot` requires a
   label; `ArmxBadge` shows text; the confirmation dialog prints the risk tier as `LOW`,
   `MEDIUM` or `HIGH`), and role tags say `ADMIN`/`VIP`/`USER` rather than relying on a tint.
5. **`accent` and `accent2` are never combined on one element.** They are distinct tones for
   distinct meanings — primary action versus secondary highlight — and the theme keeps them in
   separate roles (see `ArmxColors`).
6. **Nothing outside the theme file holds a hex value.** A screen reads `ArmxColors.of(context)`
   or the `TextTheme`; the checker's structural rules and the widget tests (which pump the
   production theme rather than a bare `ThemeData()`) are what keep that true.
7. **Both themes are asserted, not described.** `contrast_test.dart` computes the WCAG ratio for
   every foreground/background pair the app actually uses — 11 pairs in dark, 9 in light — and
   fails below 4.5:1. Settings → Design system shows the same numbers, computed live, so the
   claim is visible in the product rather than only in a test.

## Consequences

* The palette a designer sees on the dark theme is exactly the specified one; the light theme
  and secondary text are the places where readability won over literalism, and each is a named,
  justified token.
* Changing a token to something prettier fails a test with the ratio in the failure message.
* Two extra colour names (`warning`, `navyRaised`) exist that the specification did not name —
  a visible, reviewable addition rather than a silent one.

## Alternatives considered

* **Use `muted` as specified on dark and accept 3.2:1** — would fail the specification's own
  accessibility requirement, and secondary text is metadata the user is expected to read.
* **Lighten the surfaces so `muted` passes on dark** — changes `ink`/`navy`, which are
  specified exactly.
* **One theme with an opacity trick** — `muted` at 70 % opacity measures worse, not better.

## Follow-up

The two derived values worth a designer's eye are `mutedDark` and `warning`: both were chosen to
meet a ratio, not to match a swatch. Every other token traces to a specified hex.
