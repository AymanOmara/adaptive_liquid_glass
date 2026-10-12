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
- [x] Press/drag motion: frame by frame against SwiftUI's `TabView` (below).

| Scene | Native (round 2 → 3) | Shader (round 2 → 3) |
|---|---|---|
| White page | 1.24 → 1.24 | 1.35 → 1.35 |
| Photo | 1.93 (flips to 4.00) → 1.93 stable | 5.14 → 5.14 |
| Dark | 1.23 → 1.23 | 1.60 → 1.60 |
| Dark photo | 2.27 → 2.27 | 3.95 → 3.95 |
| Badge | 1.65 → 1.65 | 1.77 → 1.77 |
| Search tab | 1.97 → 1.97 | 2.33 → 2.06 |
| Accessory | 4.48 → 2.04 | 4.73 → 2.44 |

### Press, tap and drag, frame by frame

`tool/fidelity/record_tabbar_motion.sh <run> [press tap drag]` records `-controls tabbardark` and `-twin tabbardark -mode native|shader` with the app's lossless `-dump` (now available to every scene), 60 fps, after one unrecorded warm-up gesture; `tool/fidelity/tabbar_motion.py <run>` tracks per frame the bar's edges, the lens (centre, width, overhang above the bar) and the selected tint, and fits SwiftUI springs to the lens's travel and the bar's growth. Gestures from Home: press = hold Music 0.8 s, tap = quick tap on Settings, drag = Home to Settings in 0.8 s.

What iOS 26.4 does, and what changed (`TabBarMetrics`, `GlassTabBar`):

| | SwiftUI `TabView` | Before (Kept-fitted) | Now |
|---|---|---|---|
| Bar growth, held | 7.0 pt a side, peak 7.7 at frame 10–14; spring ≈ 0.32 / 0.59 | 9.3, no overshoot, tied to the lens | `growX` 7.0, own spring `grow` 0.32 / 0.6: peak 8.0, fit 0.32–0.34 / 0.52 |
| Bar on a quick tap | does not grow | grew 6.3 pt | frozen at touch-up: 0.0 |
| Bar after release | shrinks once the lens settles, 8 frames, 0.7-pt undershoot | shrank with the lens, 6 frames | shrinks from the settle, ~7 frames, 0.7-pt undershoot |
| Lean while dragging | ~1.15 pt over 172 pt | `growLean` 0.0237 (bar 9.7–10.7 at the drag start) | 0.0067 (7.7–8.3, iOS 7.7) |
| Lens travel to a pressed tab | spring 0.35 / 0.88–0.97 (rms 0.3 pt) | 0.22 / 0.85 (fit 0.16–0.20) | `travel` 0.355 / 0.9 (fit 0.352–0.356 / 0.90) |
| Lens while travelling | pops up at once: 6 pt over the bar by frame 6, 7.3 at frame 8 | grew with `press`, held down by the wobble: not over the bar until frame 12 | `pop` 0.25 / 0.7, no wobble unless dragged: 4.0–4.7 by frame 6–8 |
| Held lens on arrival | settles into the pill (gone frames 14–20), lifts again (full by frame 32) | stayed up | settles, `relift` 100 ms, lifts with `press` (up from frame 26, full by 32) |
| Quick tap on another tab | that tab is never tinted under the travelling lens | tinted for one frame | not tinted until the lens settles |

Per frame, press (ref | ours shader, run `newa`; frame 0 = first changed frame; bar left edge / lens centre, overhang, pt):

| Frame | 4 | 6 | 8 | 10 | 12 | 20 | 28 | 32 | 48 | 52 | 56 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| iOS bar | 59.7 | 58.0 | 56.7 | 56.3 | 56.3 | 57.0 | 57.0 | 57.0 | 57.0 | 59.7 | 63.3 |
| ours bar (before) | 60.7 | 58.7 | 57.0 | 55.7 | 55.0 | 54.7 | 54.7 | 54.7 | 58.7 | 64.0 | 64.0 |
| ours bar (now) | 58.7 | 57.0 | 56.3 | 56.0 | 56.0 | 57.0 | 57.0 | 57.0 | 58.0 | 62.3 | 64.3 |
| iOS lens | 149 / 3.0 | 167 / 6.0 | 180 / 6.3 | 189 / 4.7 | 194 / 2.3 | — | 202 / 5.3 | 202 / 6.0 | 201 / 4.7 | — | — |
| ours lens (before) | — | — | — | — | 202 / 2.3 | 201 / 5.7 | 201 / 6.3 | 201 / 6.3 | 201 / 1.3 | — | — |
| ours lens (now) | 155 / 2.3 | 171 / 4.0 | 183 / 4.7 | 191 / 4.7 | 196 / 2.3 | — | 201 / 3.3 | 201 / 4.7 | 201 / 2.3 | — | — |

Tap brightness (2026-10-12, runs `tapb0*` before, `tapx1*` after; `tabbar_motion.py` now prints each take's mean |diff| against the reference over frames 0-10 and 10-60, onsets aligned). Native mode's travelling lens was the gap: UIKit's clear glass veils black at about 40 grey levels (lens over the bar 38-47, over the page 38-47), while iOS's lens, once the finger lifts, shows the bar through it (33 falling to the bar's 19, page 19 falling to 3). At matched lens positions our lens region was +10 levels brighter (|diff| 15). The native lens is now tinted black at `nativeLensShade` 0.5 × (1 − the bar's light), dark mode only: held and dragged lenses (light 1–2) are untouched, a tap's fades in as the light goes. Lens region at matched positions: signed +10 → 0, |diff| 15 → 8.5.

| Native, mean \|diff\| | Before (4 takes / 2 for press, drag) | After (5 / 2) |
|---|---|---|
| Tap, frames 0-10 | 4.6–5.2 (mean 4.9) | 3.5–4.4 (mean 4.0) |
| Tap, frames 10-60 | 1.9–2.1 | 1.7–2.7 (mean 2.0) |
| Press, 0-10 / 10-60 | 7.7–8.6 / 8.2–8.6 | 7.4–7.8 / 7.7–7.9 |
| Drag, 0-10 / 10-60 | 6.1–6.7 / 8.9 | 6.7–6.8 / 8.6–9.8 |

The shader lens (unchanged) is already within ~1 level of iOS's at matched positions; its tap 0-10 (4.1–5.7) is the tinted glyphs under the lens, bent and placed unlike iOS's. Timing: shifting ours a frame later lowers native tap 0-10 by ~0.15 only (3.95 → 3.79), below the take-to-take spread, so the springs stay. The static scenes are untouched (the lens is drawn only while up).

Tapped lens look (2026-10-13; side-by-side sheets of a clean take, iOS | native | shader, before `sbs1b` and after `v2d2`). Before, in shader mode the tabs under the lens jumped to 1.18–1.20× at once (iOS: 1.02–1.09× while crossing Music, 1.14× on arrival, 1.22× held), the rim was a bright teal ring (155 grey levels, teal; iOS: about 83, neutral), the tinted Settings gear smeared into a blue crescent at the lens's end, and the lens stood up 1–2 frames early and settled 1–2 frames early. Changes: the magnification has its own spring from touch-down (`TabBarMetrics.magnify` 0.35 / 1.0, heading for `tapMagnify` 0.65 of the extra after a quick tap's touch-up) instead of following the lens's size; `tabLensDark` rim `rimMix` 0.85 → 0.46, `rimTint` 0.2 → 0 (peak now 83, neutral); `tabLensContentStrength` −0.8 → −0.4; `tapHold` 130 → 165 ms with the travelling lens heading for `tapLift` 0.93 from touch-up.

Lens per frame, tap (centre x / overhang pt; iOS take `v2c2`/`sbs1b`, ours shader `v2d2`):

| | 175–180 | 194–198 | 212–215 | 240–242 | 251–261 | 267–273 | 276–280 |
|---|---|---|---|---|---|---|---|
| iOS | 2.3–2.7 | 4.3 | 5.7–6.0 | 7.0 | 5.7–6.7 | 3.0–4.3 | 1.7–2.0 |
| shader before | 6.0 | 7.0 | 7.0 | 6.3 | 5.3 | 2.3 | 1.0 (272) |
| shader now | 2.3 | 4.0 | 5.3 | 6.7 | 6.7 | 4.7–5.7 | 1.7–3.0 |

Mean |diff| medians (takes): shader tap 0-10 5.2 (8) → 3.7 (4), 10-60 2.3 → 2.1; native tap 0-10 4.05 (5) → 3.97 (4); shader press 6.3 / 7.3 (2) → 5.9 / 5.7 (3); shader drag 6.6 / 8.6 → 5.6 / 7.6; native drag 6.7 / 8.9 → 7.0 / 9.1 (within the spread). Native press 0-10 reads 8.1–10.4 against 7.4–8.6 before, but in those takes the native lens appears 5–9 frames after the onset (debug stalls: 3–7 repeated frames in frames 0–14); nothing in these changes reaches the native lens's timing. Nearly every take on this host (load ~14) has repeated frames, so medians, not single takes. Left: magnification while crossing Music (1.14 vs 1.02–1.09), iOS's horizontal motion blur on the tabs, iOS's slightly wider settling pill at frame 20, and the native lens's blue halo.

Tap timing (2026-10-13): per take, the first frame the lens shows (30 pt wide or more) and the frame offset that maps our lens-centre track onto iOS's (iOS's frame at which it reaches each of our centres, minus ours; + = ours early). Before the tapped-lens fix (8 takes): shader first frame 0–1 vs iOS 2–5, offset median +3.5 (−1.0..+9.8); native 0–3, +0.9. After (`v2b*`, `v2d*`, 8 takes): shader 2–5 vs iOS 3–6, +1.1 (+0.4..+3.1); native 2–7, −1.3 (−0.3..−1.6). The same native code read +3.5 in one batch and −1.2 in another, so a frame is below what these debug-build, onset-aligned takes resolve; nothing is left to change here. The lens's x spring (`travel`) was never ahead: the old lead was the lens popping up early, fixed by the tap's lift and hold.

Measurement limits: the example is a debug (JIT) build, and on a loaded host its first frames after a touch can stall (a spring then jumps 2–3 frames, and fits give response ≈ 0.05); about half the takes of the shader path show it, so read the fits of clean takes (`newa`). The drag's lens lag (mean centre over frames 20–50: iOS 207–215 pt, native 204–212, shader 189–228) varies more between takes than between renderers; `follow` is unchanged. Open: the lens over a tap is wider than iOS's (81 vs 65 pt where it overhangs) and peaks lower on a press (4.7 vs 6.0–7.3 pt).

## Hard

- [ ] Selected tint vibrancy: iOS's selected blue shifts with the backdrop (0,80,237 over the photo); ours is flat.
- [ ] Shader mode over the photo (5.14): bar glass blur/refraction/tone vs UIKit's bar material; needs a tab-bar-specific fit like `tool/fidelity` does for shapes.
- [ ] Dark photo, shader mode (3.95): same fit, dark variant.
