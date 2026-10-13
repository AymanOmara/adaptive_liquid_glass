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
  Still scenes, whole-crop mean |diff| native/shader (2026-10-13, with
  GlassTabBarItem.symbol): white 0.33/0.45, dark 0.34/0.71, photo
  1.30/4.54, dark photo 1.60/3.28, searchtab 0.71/0.81, accessory
  1.66/1.43 (were 1.24/1.35, 1.23/1.60, 1.93/5.14, 2.27/3.95, 1.47/1.56,
  2.04/2.44). Done 2026-10-13: SF Symbols at run time (icon region 4.8 ->
  0.8), light lens (grey glass + shadow, shader and native), held lens
  size, arrival dip, drag follow, selected pill (53 vs iOS 53).
  Open:
  - vibrancy: done over shader glass (tab_vibrancy.frag): untinted
    glyph |diff| over the photo 12.4 -> 8.7 light, 11.2 -> 10.1 dark; the
    selected tint 24.4 -> 16.2 light, 22.4 -> 12.6 dark. Native mode keeps
    flat colours (Flutter cannot see UIKit glass)
  - lens fringe: iOS's bands at the lens top/bottom carry a rainbow fringe
    warm on one end, cool on the other; our dispersion is symmetric
    (stronger dispersion / lensVertical / normal radius tried, held-lens
    SSIM 0.810 -> 0.80-0.81, reverted)
  - motion blur of moving tabs (needs a velocity blur in
    tab_lens_content.frag)
  - native mode's lens is UIKit glass: it cannot bend the bar's edges or
    darken only its overhang (the shader cannot see native glass)
  - motion is measured in debug builds (profile is not available on the
    simulator): onset timing within +-2 frames of iOS, below take noise
  Features (see also 9):

8- match the flutter shader with the native navigation bar

9- more SwiftUI components (docs/superpowers/notes/component-gap.md):
  keyboard toolbar, zoom
  transitions, TipKit tips; then re-check the gap list for anything new.
  Candidate from app use (2026-10-10): a sliver pinned under the nav bar
  (the app's PinnedBelowBarSliver). Kept app-side for now: sticky bottom
  action bar, stage tab strip with counts.

10- refactor backlog P3 items (docs/superpowers/notes/refactor-backlog.md),
  opportunistic (P3-1 constants split only).

11- new SwiftUI components (2026-10-13), merged to main
  (bordered/borderedProminent/borderless/plain buttons, vertical GlassSlider,
  GlassRangeSlider, GlassPhotosPicker; 1081 tests pass). Open:
  - open the photo picker for real on an iOS simulator and an Android
    emulator (only unit tests with a mocked channel and the builds ran)
  - SwiftPM build of the iOS plugin (only CocoaPods was built)
  - measure the bordered fill, press dim and disabled colours vs SwiftUI
