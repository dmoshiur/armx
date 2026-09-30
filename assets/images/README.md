<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# Image assets

Intentionally empty.

The whole visual identity is drawn at runtime with `CustomPainter`s and gradients
(`lib/core/widgets/ambient_background.dart`, `armx_orb.dart`, `armx_wordmark.dart`), so the
app has **zero raster assets** and therefore no bitmap variants to maintain for
Android/Windows/Linux and light/dark.

Keep this directory in the bundle: launcher icons, the adaptive-icon foreground and the
splash artwork for release builds belong here. Recommended sizes when you add them:

| File | Purpose | Size |
| --- | --- | --- |
| `app_icon.png` | legacy launcher icon fallback | 512 × 512 |
| `app_icon_foreground.png` | Android adaptive icon foreground (safe zone 66 %) | 432 × 432 |
| `splash.png` | optional splash artwork on top of the orb animation | 768 × 768 |
