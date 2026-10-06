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

- [ ] Count badge: 20 pt on iOS vs our 18.7 (`badge_metrics.dart`); check font size/weight and the dot too.
- [ ] Search tab magnifier: ~22 pt and bolder on iOS vs our 26-pt-font glyph at ~20 pt of ink.
- [ ] Bar shadow: native sits lower; ours has no y-offset (tab-bar-only shadow, not the shared shader).
- [ ] Quick-tap lens hold: iOS keeps the lens ~0.8–0.9 s after a quick tap, ours ~0.2 s (tab bar motion constant).
- [ ] Re-measure icon/label ink per tab in all scenes and re-check pill size, now that colours are exact.

## Medium

- [ ] Native mode over the photo: unselected labels sometimes flip to white (backdrop brightness sampling in `lib/src/foreground` / `lib/src/group`; iOS keeps them dark).
- [ ] Accessory scene: 5.06 native / 6.21 shader (only measured after round 1).
- [ ] Press/drag motion: frame-by-frame comparison of lens growth, stretch and release vs native (fixed-rate recordings).

## Hard

- [ ] Selected tint vibrancy: iOS's selected blue shifts with the backdrop (0,80,237 over the photo); ours is flat.
- [ ] Shader mode over the photo (5.44): bar glass blur/refraction/tone vs UIKit's bar material; needs a tab-bar-specific fit like `tool/fidelity` does for shapes.
- [ ] Dark photo, shader mode (4.50): same fit, dark variant.
