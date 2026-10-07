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

## Medium

- [ ] Native mode over the photo: unselected labels sometimes flip to white (backdrop brightness sampling in `lib/src/foreground` / `lib/src/group`; iOS keeps them dark).
- [ ] Accessory scene: 4.48 native / 4.73 shader after round 2 (5.06 / 6.21 after round 1).
- [ ] Press/drag motion: frame-by-frame comparison of lens growth, stretch and release vs native (fixed-rate recordings).

## Hard

- [ ] Selected tint vibrancy: iOS's selected blue shifts with the backdrop (0,80,237 over the photo); ours is flat.
- [ ] Shader mode over the photo (5.44): bar glass blur/refraction/tone vs UIKit's bar material; needs a tab-bar-specific fit like `tool/fidelity` does for shapes.
- [ ] Dark photo, shader mode (4.50): same fit, dark variant.
