## 0.1.0-dev.8

- Add light and dark iOS example screenshots to the pub.dev package gallery.
- Remove the private repository link from package metadata.

## 0.1.0-dev.7

* New components (Material 3 counterparts on Android):
  - `GlassTextField`, with `GlassTextField.password`.
  - `showGlassToast`, with `GlassToastAction` and `GlassToastHandle`.
  - `GlassListSection` and `GlassListTile`: iOS 26's inset-grouped list,
    measured against SwiftUI on iOS 26.4.
  - `showGlassActionSheet`: iOS 26's confirmation dialog, measured.
  - `GlassChip`, `GlassBadge`, `GlassPageControl` and
    `GlassProgressIndicator` (geometry estimated, not yet measured).
* `AdaptiveLiquidGlass.initialize()` preloads the shaders before the first
  frame.
* `GlassMenuController` drives slide-to-select from an outer gesture
  (`glideTo`, `endGlide`, `cancelGlide`).
* `GlassScrollEdgeStyle.progressive` on the navigation bars: an opt-in
  graduated blur under the bar. The default is unchanged.
* Rounded rectangles use a continuous (iOS-style) corner
  (`GlassConstants.cornerZone`).
* Interactive glass stretches toward a finger dragged past its edge, and
  shows a focus ring under keyboard focus.
* `GlassTabBar` re-measured against SwiftUI's `TabView`: selected and
  unselected colours, pill, icon and label sizes, and the bar's glass.
* Accessibility: one screen-reader node per control; explicit labels
  replace the visible text; `semanticLabel` on `GlassPicker`,
  `GlassMenuItem`, `showGlassPopover` and `GlassSearchField`; tapping
  outside a menu or picker is announced as "Dismiss".
* Fixes:
  - Glass and the text on it now follow one brightness (the theme's),
    including inside dialogs, sheets, popovers, menus and toasts. Behaviour
    change: a `MaterialApp` with no dark theme now gets light glass on a
    dark system.
  - `GlassTabBar`: the pill no longer stops on a different tab from the
    selected tint when `selectedIndex` does not change, and the held lens
    no longer draws black on the native path.
  - `GlassToggle` returns to `value` when the parent rejects a change.
  - The tab bar's search button had no screen-reader tap action; disabled
    stepper halves still offered one.
* Includes code adapted from liquid_glass_widgets (MIT); see
  `THIRD_PARTY_NOTICES`.

## 0.1.0-dev.6

* Fix: on iOS 26 (native glass), content no longer flickers as it scrolls
  under the navigation bar. The scroll edge keeps its fade but drops its
  blur there, since Flutter cannot blur UIKit views in place.
* Fix: labels on glass no longer flip between light and dark while content
  scrolls past. A flip now needs the backdrop to move clearly past middle
  grey, on two samples in a row.

## 0.1.0-dev.5

* New components, each measured against SwiftUI on iOS 26.4:
  - `showGlassAlert` and `showGlassConfirmationDialog`, with
    `GlassDialogAction`.
  - `showGlassPopover` and `GlassPopoverAnchor`.
  - `GlassPicker` (menu style).
  - `GlassStepper`.
  - `GlassDatePicker`, the compact style with a glass calendar.
  - `GlassContextMenu`.
  - `GlassTabBar.onSearch`, iOS 26's search tab.
* `showGlassSheet` takes `detents` (`GlassSheetDetent.medium`, `.large`,
  `.fraction`, `.height`):
  - It drags between detents and dismisses on a drag or fling down.
  - At `large` it is edge to edge and opaque, with the screen's corners.
  - It is its own route now, so it needs no Material ancestor.
  - Breaking: `isScrollControlled` is removed; use `detents`.
* The earlier components were re-measured against SwiftUI:
  - The segmented control is 32 pt and the slider thumb 37 pt.
  - The toolbar is 48 pt, 28 pt from the screen's edges.
  - The menu opens over its button, with icons at the start.
  - Swipe actions use SwiftUI's compact and stacked layouts.
  - Toggle, slider, segmented control and stepper colours are measured, in
    light and dark.
* `GlassSystemColors`: iOS 26's red, blue, orange and green.
* Fixes:
  - Glass labels on a light page inside `GlassScaffold` were white.
  - A grey band appeared on the tab bar next to an accessory.
  - The menu button's glass drew over its open menu.
  - Material's letter spacing leaked into glass text; iOS tracking is now
    applied.
  - Text in glass routes fell back to Flutter's debug style (underlines).
  - Components threw without Cupertino localizations.
  - With an accessory, the tab bar widens to the accessory's width, as on
    iOS.
* Tooling: `tool/reference/capture_components.sh`,
  `measure_components.py` and `compare_components.py` score every
  component against SwiftUI per path.

* `GlassScaffold`: an iOS 26 screen in one widget. The navigation bar sits
  on top, the tab bar or toolbar floats at the bottom with an optional
  `GlassBottomAccessory`, and the body runs under the bars, padded clear
  of them.
* `GlassToolbar` and `GlassToolbarSpacer`: the floating bottom toolbar.
* `GlassToggle`, `GlassSlider` and `GlassSegmentedControl`: their thumbs
  turn into clear glass lenses while pressed.
* `showGlassSheet` and `GlassSheet`: a floating glass sheet.
* `GlassMenuButton` and `GlassMenuItem`: a glass pull-down menu.
* `GlassSearchField`: a glass search capsule.
* `GlassSwipeActions` and `GlassSwipeAction`: list swipe actions with
  tinted glass capsules, a full swipe and a haptic.
* `GlassTabBar`: a selection haptic as the dragged lens reaches each tab
  (`enableFeedback`).
* Internal: one class per file, and fixed colours moved to `GlassColors`.
  The public API is unchanged.

## 0.1.0-dev.4

* `GlassTabBar`, matched frame by frame to iOS 26.4's tab bar (Kept):
  - The lens is shader glass. It bends the page and bar behind it outward
    into its rim (a dark, colour-split band along its long sides), and
    draws the tinted tabs over that in their own pass
    (`tab_lens_content.frag`): pulled inward towards the lens's round
    ends, softly blurred, keeping their colour. Teal-cyan rim, no white
    wash; tabs under it are magnified about their own centres.
  - The bar is shader glass fitted to UIKit's bar (flat fill, even 1 pt
    rim, lighter frost). It lights up around a held lens and evenly while
    the lens is dragged, fading after release.
  - The lens follows the finger with a continuous spring (no stutter) and
    trails it as iOS's does; tapping a far tab sends it across and
    settles it on arrival. The selected tint no longer flickers.
  - An explicit `mode:` still wins.
* `GlassVariantConstants`: `lensVertical` (bend mostly where the outline
  faces up or down), `rimTint` and `rimHue` (a tinted rim). All default to
  off.
* `GlassButton` / `GlassButton.icon`: SwiftUI's glass and prominent button
  styles, destructive and cancel roles, control sizes, border shapes,
  disabled and loading states; Material 3 buttons on Android. Sizes
  measured from SwiftUI (`tool/reference/controls.json`).
* `GlassBackButton`, `GlassNavigationBar` (inline title) and
  `SliverGlassNavigationBar` (collapsing large title): iOS 26's navigation
  bar, measured from SwiftUI; `AppBar` / `SliverAppBar.large` on Android.

## 0.1.0-dev.3

* `glassEffect(onPressed: ...)`: a glass button in one line, same as
  `LiquidGlass.onPressed`.
* `GlassTabBar` and `GlassTabBarItem`: iOS 26's floating tab bar. The
  selected tab sits on a pill; pressing turns it into a clear glass lens
  that overhangs the bar and magnifies the tabs under it, dragging slides
  it between tabs, and letting go springs it to the nearest tab (sizes and
  timing measured from iOS 26.4). Works in every render mode, follows the
  reading direction and Reduce Motion, and exposes each tab as a selectable
  button to assistive tech.
* Tabs shrink evenly to fit the width the bar is given (`itemWidth` is
  now the maximum), so five tabs fit a phone.
* Tab bar motion measured frame by frame against iOS 26.4's own tab bar:
  pill 7.55 wider than the 86.15 tab spacing; the lens (114 × 74) grows on
  a 0.38 s spring, trails the finger on a 0.3 s spring at 1.06× its offset
  from the bar's centre, wobbles in height with its acceleration, and
  settles back with a squash on a 0.36 s spring; the bar grows towards the
  lens; tabs under it magnify 1.21 × 1.10. The tabs now lie beneath the
  lens glass, so it refracts them at its rim.
* `GlassTabBarItem.activeIcon` (the selected tab's icon) and `.badge` (a
  count or short text in a red capsule, a dot when empty; read with the
  tab by assistive tech).
* On the Material path (Android by default) the bar is a Material 3
  `NavigationBar` in the same floating capsule, with ripple and badges.

## 0.1.0-dev.2


### Task 17d — noise floor, tone LUT, hard target met

- Certified fidelity: 46/75 scenes pass (SSIM ≥ 0.97, ΔE ≤ 2.0), median
  SSIM 0.9828 / ΔE 1.09, min SSIM 0.9532, 0 scenes below 0.95 (75 in-set;
  held-out 48-scene set 18/48, min 0.9470).
- Tone LUT: piecewise-linear 9-knot input→output curve per variant set,
  measured from grey flats (covers below the 0.15 code floor); small dark
  shapes gain a `toneLift`.
- Clear glass: lens max-min grid (`lensSizeRef`/`lensStrength`), rim mix,
  post-blur share; regular dark: anisotropic frost (`blurAspectPower`).
- Noise floors: SwiftUI-vs-SwiftUI repeat floor is exactly zero
  (bit-deterministic simulator); SwiftUI-vs-UIKit cross-API floor
  committed; `compare.py --floor` adds report-only within-noise verdicts.


* Native glass is SwiftUI's own: native mode hosts a `GlassEffectContainer`
  with a `.glassEffect` view per member (was UIKit `UIGlassEffect`), so it
  matches SwiftUI pixel for pixel, follows `MediaQuery.platformBrightness`
  like the shader path (and re-themes when it changes at runtime), draws
  circles as circles and supports `unionId`.
* **Breaking:** native glass is the default on iOS 26+; `auto` picks it from
  the first frame (the iOS version is read synchronously at startup).
  `LiquidGlassThemeData.nativeEnabled` is removed; use `mode:` or
  `defaultMode: GlassRenderMode.shader` to opt out.

* `Widget.glassEffect(glass:, shape:, glassId:, unionId:, padding:)`: one-line
  glass, mirroring SwiftUI's `.glassEffect(_:in:)`.
* `LiquidGlass.padding`: insets the child inside the glass (directional).
* `LiquidGlass.adaptiveForeground` (default `true`): text and icons on glass
  take a readable label colour (the Material on-colour on Android); explicit
  colours still win.
* `LiquidGlass.onPressed`: glass as a button, with button semantics, focus,
  Enter/Space activation and interactive glass unless the glass opts out
  with `interactive(false)`.
* `Glass` remembers an explicit `interactive(false)`, so it no longer equals
  the plain preset.
* `LiquidGlass.precache()` is optional: shader glass draws as a blur until
  the shader loads, then switches in place.
* Android and the other non-shader paths no longer load the shader.
* `concentricRadius` is no longer exported.
* Android is declared as a supported platform (a Dart-only plugin entry).

* **Breaking:** `GlassMotionConstants.pressScale` is replaced by
  `pressGrowthArea` and `pressScaleMax`: a pressed shape grows by about the
  same area whatever its size (`sqrt(1 + pressGrowthArea / (w·h))`, capped),
  as SwiftUI does, so small shapes grow more than large ones.
* Press-in and release use separate springs (`releaseResponse`,
  `releaseDamping`); press, release and morph springs, press stretch and
  glow radius are refitted to lossless SwiftUI recordings.
* Shader fidelity: every reference scene is at SSIM ≥ 0.95 against SwiftUI
  (minimum 0.9532, median 0.983, median ΔE 1.09), with a per-variant tone
  curve, anisotropic frost, a wide frost tail and a refitted clear lens.
* Example: an Android host, a dark theme for the gallery, and motion-scene
  harness entries (`-motion`, `-dump`); harness entries default to the
  shader unless `-mode native` is passed.

## 0.1.0-dev.1

* First development release: `LiquidGlass`, `GlassGroup`, `Glass`,
  `GlassShape`, `LiquidGlassTheme`, `GlassBackdropSource` and
  `GlassForeground`; shader glass fitted to SwiftUI on iOS, Apple's native
  glass on iOS 26+ (opt-in), Material 3 on Android.
