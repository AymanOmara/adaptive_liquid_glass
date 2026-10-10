Open items, highest priority first. Done items are dropped; history is in git
and CHANGELOG.md.

1- bugs. Components demo, seen on the simulator (2026-10-08, dark,
  PLAIN_BACKGROUND=true, example/lib/components_demo.dart):
  - Period picker: the first tap after launch/restart does not open the
    menu; the second does (seen twice, 2026-10-08).
  - Large titles do not collapse when the list sits in
    `SliverFillRemaining` (reported from app use 2026-10-10: Directory,
    Services and other paged lists).

2- API gaps from real app use (reported 2026-10-10, v0.1.7), quick wins
  first:
  - extended FAB: an optional label on the floating button; on Android use
    a real M3 FloatingActionButton(.extended), not IconButton.filled
    (material_glass_button.dart ~111)
  - Android tab bar: an edge-to-edge option (plain M3 NavigationBar with
    safe-area padding) beside today's floating capsule
    (glass_tab_bar.dart _materialBar ~740)

3- Android options (requested 2026-10-09):
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
    - option 1, now (~1 h): a generic switch, e.g. `GlassAdaptive(glass:
      ..., material: (context) => MyAndroidWidget())`, following the
      render mode so app code never checks the platform; wraps anything
    - option 2, on request only (several days): typed builders per
      component (e.g. tab bar gets items, selected index, tap callback);
      ~33 parameter classes of public API to freeze at 1.0. Tab bar and
      navigation bar first if asked for
  - then: example app toggle for both; README Android section + Known
    limitations (re-check every entry is still true); CHANGELOG

4- release readiness: 0.1.0 shipped 2026-10-08. 1.0 only after:
  - usability pass: audit the 94 barrel exports for what should be public
    (e.g. GlassForeground helpers, refactor-backlog P3-6), simplest
    defaults, naming review (1.0 freezes names; renames after cost
    deprecation cycles)
  - item 7 "measure later" components measured vs SwiftUI
  - fidelity items 5 and 6 at a plateau (59/75 today)
  - API unchanged for a release or two

5- fidelity, regular/tinted photo scenes (item 8 history in
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

6- fidelity, clear glass edges (group 4 history in fidelity-status.md):
  shipped postJacobianMax (clear 1.15) + clear lens/frost/rim refit.
  - remaining: clear-rect28-photo light/dark (0.970/0.969, dE 2.04),
    clear capsule/rect16/rect28 text light+dark (SSIM 0.958-0.964, the
    edge band over sharp text; SSIM on text lines is a phase match)

7- components shipped with estimated, unmeasured geometry (measure vs
  SwiftUI): GlassLabel, GlassLink/GlassShareLink, GlassColorPicker sheet,
  GlassRefresh, GlassSearchable, GlassDatePicker wheel/time, GlassWheelPicker,
  full-screen cover close button and drag thresholds, context menu (synthetic
  touches cannot open SwiftUI's), springs and press animations of the newer
  components.
  Not done: arrow->spinner morph on refresh; Material searchable keeps
  scopes always visible.

8- tab bar vs native iOS 26 (details: docs/superpowers/notes/tabbar-todo.md)
  Bar-region mean |diff| native/shader: white 1.24/1.35, photo 1.93/5.14,
  dark 1.23/1.60, dark photo 2.27/3.95, badge 1.65/1.77, searchtab
  1.47/1.56, accessory 2.04/2.44
  Done 2026-10-09: lens size (press, tap, drag, idle pill within ~1 pt);
  tapped lens travel, lift (7.0 pt peak) and late pill fade-in; labels
  beside the search tab (searchLabelShift).
  Open (small), measured 2026-10-09 against SwiftUI TabView (tabbardark):
  - tap brightness: frames 0-10 mean |diff| ~7 levels (10-60: 2.4). The
    icons and labels magnified under the travelling lens come out brighter
    and in other places than iOS's (e.g. Music's icon top white under our
    lens, Settings' glyph appearing later); mean +3.3 brighter early
  - tap timing: our lens shows ~1 frame before iOS's (frame 1-2 vs 3-4)
    and stays ~1 frame ahead throughout
  - tapped lens at its end narrows faster than iOS's (35 vs 51 pt wide on
    its last visible frame)
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
  Features (see also 10):
  - tabBarMinimizeBehavior: the bar shrinking to its selected tab on scroll
  - sidebarAdaptable: the tab bar becoming a sidebar on wide screens

9- match the flutter shader with the native navigation bar

10- more SwiftUI components (docs/superpowers/notes/component-gap.md):
  keyboard toolbar, tabBarMinimizeBehavior, sidebarAdaptable, zoom
  transitions, TipKit tips; then re-check the gap list for anything new.
  Candidate from app use (2026-10-10): a sliver pinned under the nav bar
  (the app's PinnedBelowBarSliver). Kept app-side for now: sticky bottom
  action bar, stage tab strip with counts, hiding the tab bar with the
  keyboard.

11- refactor backlog P3 items (docs/superpowers/notes/refactor-backlog.md),
  opportunistic (P3-1 constants split only).
