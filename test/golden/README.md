<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# Golden baselines

`armx_golden_test.dart` renders every shared component — and the confirmation dialog — in
both themes at 360×800, 800×1280 and 1440×900, and compares the result against a PNG in
`goldens/`.

## Why the baselines are not committed

A golden image is a picture of a machine: fonts, rasteriser and platform all change the
pixels. A baseline generated on a machine without the bundled Inter and JetBrains Mono assets
renders every text run in a fallback font, and every later comparison then fails with a diff
nobody can resolve. So the baselines are generated once, by a person, on a machine with the
Flutter SDK and this repository's assets:

```bash
flutter pub get
flutter gen-l10n
flutter test --update-goldens test/golden
git add test/golden/goldens
```

`test/golden/goldens/` is what the suite looks for. Until it exists, the golden tests skip
themselves with the command above as the reason — a skip that says what to do, rather than a
green tick that means nothing.

## What to do when a golden diff appears

1. Look at the diff image in `test/golden/failures/`. A real change to a component should be
   obvious: a new state, a spacing change, a token change.
2. If the change is intended, regenerate and commit the baseline **in the same pull request as
   the component change**, so the diff is reviewed alongside the code that caused it.
3. If the change is not intended, the golden test has just caught a visual regression — fix
   the component rather than the baseline.
