Open items, highest priority first. Done items are dropped; history is in git
and CHANGELOG.md.

1- components demo bugs seen on the simulator (2026-10-08, dark,
  PLAIN_BACKGROUND=true, example/lib/components_demo.dart):
  - GlassPicker (Period row) menu renders UNDER the bottom accessory ("Now
    Playing") and the tab bar: "Day" / "Month" show through them. Open the
    menu on the root overlay above GlassBottomAccessory / GlassTabBar.
  - GlassSearchable with navigationBar placement draws the search field in
    the status-bar area, over the Dynamic Island. Respect the top safe-area
    inset.
  - GlassTabBar lens while DRAGGING shows refracted fragments of the
    accessory above it ("Now Playing" text) plus colour fringing along the
    lens's top edge; gone once the drag settles. Lens samples outside the
    bar's rect: clamp the lens backdrop to the bar bounds, or exclude
    GlassBottomAccessory from the lens backdrop. The fringe is RGB-split
    (per-channel displacement at the lens edge) and the "Settings" label
    smears at the bottom-right edge; native shows neither. Frames:
    build/tabbar-drag-leak-1.png, -2.png.

2- release readiness: 0.1.0 shipped 2026-10-08. 1.0 only after:
  - usability pass: audit the 94 barrel exports for what should be public
    (e.g. GlassForeground helpers, refactor-backlog P3-6), simplest
    defaults, naming review (1.0 freezes names; renames after cost
    deprecation cycles)
  - item 5 "measure later" components measured vs SwiftUI
  - fidelity items 3 and 4 at a plateau (59/75 today)
  - API unchanged for a release or two

3- fidelity, regular/tinted photo scenes (item 8 history in
  docs/superpowers/notes/fidelity-status.md): device 59/75,
  build/fidelity/g8-3, min SSIM 0.9525. Luma-keyed tone LUT shipped; linear
  light, vibrancy, gated ambient, union sizing, clear sharp edge measured
  and rejected (gemini-fidelity-answer.md).
  - regular rect photo-dark (deltaE ~3.4), photo-light (~2.6)
  - regular capsule photo-dark (SSIM 0.9525), tinted capsule photo/gradient
    light (deltaE 2.3)
  - round 4 question drafted, not yet asked (Gemini web/CLI blocked
    2026-10-08): docs/superpowers/notes/gemini-fidelity-question-r4.md
  - untried in full: linear-light refit of all fill/tone keys (> 2 h LS);
    clear sharp edge needs a sharp-backdrop texture in the shader

4- fidelity, clear glass edges (group 4 history in fidelity-status.md):
  shipped postJacobianMax (clear 1.15) + clear lens/frost/rim refit.
  - remaining: clear-rect28-photo light/dark (0.970/0.969, dE 2.04),
    clear capsule/rect16/rect28 text light+dark (SSIM 0.958-0.964, the
    edge band over sharp text; SSIM on text lines is a phase match)

5- components shipped with estimated, unmeasured geometry (measure vs
  SwiftUI): GlassLabel, GlassLink/GlassShareLink, GlassColorPicker sheet,
  GlassRefresh, GlassSearchable, GlassDatePicker wheel/time, GlassWheelPicker,
  full-screen cover close button and drag thresholds, context menu (synthetic
  touches cannot open SwiftUI's), springs and press animations of the newer
  components.
  Not done: arrow->spinner morph on refresh; Material searchable keeps
  scopes always visible.

6- tab bar vs native iOS 26 (details: docs/superpowers/notes/tabbar-todo.md)
  Bar-region mean |diff| native/shader: white 1.24/1.35, photo 1.93/5.14,
  dark 1.23/1.60, dark photo 2.27/3.95, badge 1.65/1.77, searchtab
  1.97/2.06, accessory 2.04/2.44
  Open: label offsets beside the search tab (~1 pt, UIKit pixel rounding);
  tap lens wider than iOS's, press lens peaks lower; drag lag unresolved
  (debug-build stalls)
  Hard:
  - selected blue shifting with the colours behind it, as native's does
  - retune the shader-mode glass over photos (5.14 light, 3.95 dark)

7- match the flutter shader with the native navigation bar

8- more SwiftUI components (docs/superpowers/notes/component-gap.md):
  keyboard toolbar, tabBarMinimizeBehavior, sidebarAdaptable, zoom
  transitions, TipKit tips; then re-check the gap list for anything new.

9- refactor backlog P3 items (docs/superpowers/notes/refactor-backlog.md),
  opportunistic; optional rename of 8 files whose name differs from their
  class (git log 699c4ab..6bd738c).
