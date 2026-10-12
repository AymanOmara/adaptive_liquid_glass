Open items, highest priority first. Done items are dropped; history is in git
and CHANGELOG.md.

1- native menu open latency: not reproduced (re-measured 2026-10-12, iOS
  26.4 simulator, debug, components demo Period picker, 4 opens per run).
  Worst frame on opening 70-170 ms, once 371 ms; the shader path is as slow
  or slower there (100-270 ms frames), and the native view is created in
  under 1 ms. The earlier 0.5-0.7 s stall was simulator/debug noise. Only
  to do if a device shows lag: measure in profile on hardware.

2- Android options (requested 2026-10-09):
  - iOS look on Android (~1 h, later): already wired. Components choose by
    render mode, not platform, and `initialize(mode: shader)` loads the
    shaders on Android; `LiquidGlassThemeData(defaultMode:
    GlassRenderMode.shader)` should give the iOS glass app-wide. To do: run
    the gallery and components demo in shader mode on an emulator, fix what
    breaks, document with caveats:
    - shader needs Impeller; on GLES `isShaderFilterSupported` may be false
      (falls back to a plain blur)
    - shader speed on mid-range phones
    - still Android: Roboto not SF, scroll physics, back gesture, haptics
      (making those iOS-like is a separate, bigger job)
  - custom Android widget: the code side is easy (each of ~33 components
    has one point where it picks the Material widget); the API is the work.
    - option 1: done (`GlassAdaptive`, 2026-10-10)
    - option 2, on request only (several days): typed builders per
      component (e.g. tab bar gets items, selected index, tap callback);
      ~33 parameter classes of public API to freeze at 1.0. Tab bar and
      navigation bar first if asked for
  - then: example app toggle for both; README Android section + Known
    limitations (re-check every entry is still true); CHANGELOG

3- release readiness: 0.1.0 shipped 2026-10-08. 1.0 only after:
  - usability pass: audit the 94 barrel exports for what should be public
    (e.g. GlassForeground helpers, refactor-backlog P3-6), simplest
    defaults, naming review (1.0 freezes names; renames after cost
    deprecation cycles)
  - item 6 "measure later" components measured vs SwiftUI
  - fidelity items 4 and 5 at a plateau (59/75 today)
  - API unchanged for a release or two

4- fidelity, regular/tinted photo scenes (item 8 history in
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

5- fidelity, clear glass edges (group 4 history in fidelity-status.md):
  shipped postJacobianMax (clear 1.15) + clear lens/frost/rim refit.
  - remaining: clear-rect28-photo light/dark (0.970/0.969, dE 2.04),
    clear capsule/rect16/rect28 text light+dark (SSIM 0.958-0.964, the
    edge band over sharp text; SSIM on text lines is a phase match)

6- components shipped with estimated, unmeasured geometry (measure vs
  SwiftUI): GlassLabel, GlassLink/GlassShareLink, GlassColorPicker sheet,
  GlassRefresh, GlassSearchable, GlassDatePicker wheel/time, GlassWheelPicker,
  full-screen cover close button and drag thresholds, context menu (synthetic
  touches cannot open SwiftUI's), springs and press animations of the newer
  components.

7- tab bar vs native iOS 26 (details: docs/superpowers/notes/tabbar-todo.md)
  Bar-region mean |diff| native/shader: white 1.24/1.35, photo 1.93/5.14,
  dark 1.23/1.60, dark photo 2.27/3.95, badge 1.65/1.77, searchtab
  1.47/1.56, accessory 2.04/2.44
  Done 2026-10-09: lens size (press, tap, drag, idle pill within ~1 pt);
  tapped lens travel, lift (7.0 pt peak) and late pill fade-in; labels
  beside the search tab (searchLabelShift).
  Open (small), measured 2026-10-09 against SwiftUI TabView (tabbardark):
  - tap brightness (2026-10-13, tabbar_motion.py's brightness line,
    medians): native 0-10 4.4 -> 4.0 (veil shaded, nativeLensShade);
    shader 5.2 -> 3.7 (10-60 2.3 -> 2.1): tabs magnified on their own
    spring (1.14 on a tap, was 1.18-1.20 at once), thin grey rim in dark,
    tapHold 165 ms + tapLift 0.93 (lens height per frame within ~0.5 pt
    of iOS's), content bend -0.4. Left: magnification while crossing
    Music 1.14 vs iOS's 1.02-1.09; iOS's motion blur on the tabs; the
    native lens's blue halo (UIKit glass refracting the tinted copy)
  - tap timing: closed 2026-10-13. Shader lens first shows at frame 2-5
    (iOS 3-6), centre track +1.1 frames (median of 8 takes, spread
    +0.4..+3.1); native 2-7, -1.3 (-0.3..-1.6). Below what onset-aligned
    debug-build takes resolve (the same code reads +3.5 or -1.2 between
    batches); before the lens fix shader read +3.5 (-1.0..+9.8)
  - tapped lens at its end: 47 pt wide on its last visible frame (was 35;
    iOS 51)
  - selected pill over black: 54 grey levels against iOS's 50-51
  - press brightness: frames 0-10 mean |diff| ~4.5
  - drag brightness: mean |diff| ~3-4 (mid-drag within +-4)
  - icons beside the search tab ~0.4 pt right of iOS's on Music/Settings
    (Home matches); plain-bar labels +0.4 px, Home +1.1-1.3 px
  - glyph shapes: CupertinoIcons stand-ins vs SF Symbols (house, gear)
  Hard:
  - retune the shader-mode glass over photos (5.14 light, 3.95 dark): the
    biggest visible gap left
  - selected blue shifting with the colours behind it, as native's does
  Features (see also 9):
  - tabBarMinimizeBehavior: the bar shrinking to its selected tab on scroll
  - sidebarAdaptable: the tab bar becoming a sidebar on wide screens

8- match the flutter shader with the native navigation bar

9- more SwiftUI components (docs/superpowers/notes/component-gap.md):
  keyboard toolbar, tabBarMinimizeBehavior, sidebarAdaptable, zoom
  transitions, TipKit tips; then re-check the gap list for anything new.
  Candidate from app use (2026-10-10): a sliver pinned under the nav bar
  (the app's PinnedBelowBarSliver). Kept app-side for now: sticky bottom
  action bar, stage tab strip with counts.

10- refactor backlog P3 items (docs/superpowers/notes/refactor-backlog.md),
  opportunistic (P3-1 constants split only).
