# Tab bar vs native iOS 26.4 — remaining work (2026-10-07)

Bar-region mean |diff| after the first round (`build/side-by-side-tabbar-*-after`):

| Scene | Native mode | Shader mode |
|---|---|---|
| White page | 1.80 | 2.59 |
| Photo | 2.33 | 5.44 |
| Dark | 1.78 | 2.16 |
| Badge | 2.07 | 2.86 |
| Search tab | 1.87 | 2.95 |

Ordered easiest first. Round 2 takes the "easy" group.

## Easy (round 2)

- [x] Count badge: 20-pt capsule, 12-pt semibold numerals, 4-pt padding, top leading corner 12.2 pt right / 18.1 pt above the icon centre; empty badge an 18-pt circle (a343b3a).
- [x] Search tab magnifier: painted (SearchGlyph) at iOS's 22.67-pt ink, 2.08-pt ring, ~3-pt round handle; ink 1207 vs 1202 px (25bafb0).
- [x] Bar shadow: shader mode paints BarShadow 8 pt below the glass, sigma 16.9, ~7 % black; profiles within 1 grey level (32105f6).
- [x] Quick-tap lens hold: re-measured on iOS 26.4 — a ~0 ms tap keeps the lens ~230 ms, settled by ~330 ms (not 0.8 s). `TabBarMetrics.tapHold` 200 ms from touch-down; ours gone at ~320 ms (was ~60 ms). Reduce Motion and presses past tapHold release at once.
- [x] Re-measured ink and pill (subpixel, ink-weighted centroids, pill chord on ink-free rows, px @3x):
  - Pill was 0.9 px short (filled bars 1.6 px) on its trailing edge; slot spacing 0.45 pt/slot too wide beside the search tab. Now `pillExtra` 7.98 with `itemWidth` 86.0 (bar width unchanged), `pillExtraFilled` 10.1: pill edges within 0.15 px in all scenes, icon spacing within 0.5 px.
  - Labels sat 1–2.2 px towards the end: the label box is now whole points wide (`IntrinsicWidth(stepWidth: 1)`, as UIKit sizes labels) with the text at its start; tabbar/accessory label offsets ≤ 0.8 / 1.3 px. Beside the search tab iOS sets labels ~1 pt differently relative to their icons (pixel rounding we do not model): Music/Settings there 1.6–1.8 px left.
  - Icons sat ~1.2 px high: `iconDrop` ⅓ pt. Remaining icon offsets are glyph differences (CupertinoIcons vs SF Symbols; the searchtab scene's native gear is a different symbol).

Bar-region mean |diff| after round 2 (`build/side-by-side-tabbar2-*-after`):

| Scene | Native mode | Shader mode |
|---|---|---|
| White page | 1.24 | 1.35 |
| Photo | 1.93 (unstable: labels flip) | 5.14 |
| Dark | 1.23 | 1.60 |
| Dark photo | 2.27 | 3.95 |
| Badge | 1.65 | 1.77 |
| Search tab | 1.97 | 2.33 |
| Accessory | 4.48 | 4.73 |

## Medium (round 3)

How it is measured: `-controls <scene>` (SwiftUI) vs `-twin <scene> -mode native|shader`, `simctl io screenshot` after 3 s, mean |diff| over the bottom 360 px rows (y ≥ 2262 @3x, the round-2 crop), simulator iPhone 17 Pro / iOS 26.4. Re-taken captures: an occasional launch is caught mid-transition (|diff| > 10); such outliers are re-shot.

Starting point (after merging the g13 refit, which greyed the shader bar): shader 4.32 / 4.77 / 3.35 / 7.24 / 4.62 / 6.03 / 10.57 for the seven scenes below. Restoring the bar's fitted tone (identity tone knots, pre-refit fill drop and tint; search circle in the bar's material with its shadow) brought them back to the round-2 values (photo 4.77 → 5.14, the one scene the refit had helped).

- [x] Unselected labels flipping to white over the photo (native mode). Cause: the photo's mean luminance under the bar is 0.438, inside the ±0.08 hysteresis band around 0.5. The first brightness sample decided: taken before the photo decoded (white page) the labels stayed dark; taken after, 0.438 < 0.5 flipped them white and the hysteresis held that (1 launch in 6). The first sample now starts from the brightness the labels already show (`GlassGroup._sample`), so near-grey backdrops keep the appearance's labels, as iOS does (dark in light mode, light in dark mode). 10/10 launches dark.
- [x] Accessory scene: largest contributors were the accessory row (text and glyphs 17 px / 3–10 px off, labels 85 % black vs SwiftUI's black) and, in shader mode, the accessory's glass (243 vs UIKit's 253: it took the g13 tone, not the bar's material). Now the accessory is drawn with `withTabBarGlass`, its content takes the primary label colour, and the twin lays out its CupertinoIcons stand-ins at the SF Symbols' frame widths (music.note 14.33 pt, play.fill 13.33, from the reference ink). Library changes alone: native 4.48 → 4.57 (black glyphs, still misplaced), shader 6.55 → 4.97; with the twin layout 2.04 / 2.44. What is left is glyph shape (house, gearshape vs CupertinoIcons: ~0.76 + 0.22 of it) and icons ~2 px high.
- [ ] Press/drag motion: see below.

| Scene | Native (round 2 → 3) | Shader (round 2 → 3) |
|---|---|---|
| White page | 1.24 → 1.24 | 1.35 → 1.35 |
| Photo | 1.93 (flips to 4.00) → 1.93 stable | 5.14 → 5.14 |
| Dark | 1.23 → 1.23 | 1.60 → 1.60 |
| Dark photo | 2.27 → 2.27 | 3.95 → 3.95 |
| Badge | 1.65 → 1.65 | 1.77 → 1.77 |
| Search tab | 1.97 → 1.97 | 2.33 → 2.06 |
| Accessory | 4.48 → 2.04 | 4.73 → 2.44 |

## Hard

- [ ] Selected tint vibrancy: iOS's selected blue shifts with the backdrop (0,80,237 over the photo); ours is flat.
- [ ] Shader mode over the photo (5.14): bar glass blur/refraction/tone vs UIKit's bar material; needs a tab-bar-specific fit like `tool/fidelity` does for shapes.
- [ ] Dark photo, shader mode (3.95): same fit, dark variant.
