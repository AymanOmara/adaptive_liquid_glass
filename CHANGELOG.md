## Unreleased

- `GlassButtonStyle` gains SwiftUI's styles without glass: `bordered`
  (grey fill, or the tint at 15% / 20% dark, accent label),
  `borderedProminent` (solid accent fill, white label), `borderless`
  (accent label) and `plain` (primary label colour). They support
  `GlassButton.icon`, roles (destructive is red), sizes, shapes, loading,
  and iOS's grey disabled state, and dim while pressed. On Android they
  map to `FilledButton.tonal`, `FilledButton` and `TextButton`. Fills and
  press dimming are estimated, not measured.
- New `GlassTabBar.style` (`GlassTabBarStyle.sidebarAdaptable`): on an
  iPad the bar floats at the top as text tabs with a sidebar button and an
  overlay sidebar, as iOS 26.4's `.sidebarAdaptable` (measured on iPad Pro
  11-inch; top bar within ~3.5 mean levels, open sidebar ~0.5).
- `GlassScaffold`: with the tab bar minimized, the bottom accessory moves
  beside the circle, as iOS 26.4 does.
- New `GlassTabBar.minimizeBehavior` (`GlassTabBarMinimizeBehavior`):
  `.onScrollDown` shrinks the bar into a 48 pt circle holding the
  selected tab after ~75 pt of scrolling down, and expands it within
  ~15 pt of the top or on a tap, as iOS 26.4's `TabView` does (measured).
  Default `.automatic` (never on iPhone) keeps today's bar.
- `GlassScaffold`: a scrolling body fades into the page colour behind the
  tab bar, iOS 26's scroll edge under a tab bar (text ink within ~10
  levels of SwiftUI's).
- New `GlassTabBarItem.symbol(name, fallback:, label:)` and `GlassSymbol`:
  SF Symbols drawn by iOS at run time (never bundled), in the icon
  colour, at `TabView`'s size (18 pt, medium, large scale) and position;
  the fallback `IconData` elsewhere. Against SwiftUI's `TabView` (white
  page, idle): icon region |diff| 4.8 -> 0.8, bar 1.2 -> 0.5.
- `GlassTabBar`: a held lens is 2.7 pt narrower (iOS's outline, within
  1 px), and on arriving at a held tab it settles to its resting size
  and lifts again without vanishing (it went invisible for ~6 frames),
  as iOS 26's does.
- `GlassTabBar` (light, native): the lens is tinted to iOS's grey (247
  over the white bar, was 255) and casts a soft shadow below it, as
  SwiftUI's `TabView` lens does.
- `GlassTabBar` (light, shader): the lens is light-grey glass with a soft
  shadow below it and a neutral rim, as iOS 26's (was near-invisible with
  a teal rim). New `GlassVariantConstants.shadowOffsetY` moves a shadow
  down. Against SwiftUI's `TabView` (tabbar_light.py, 0-10 / 10-60): tap
  5.9 / 1.4 -> 5.2 / 1.3, press 4.2 / 3.5 -> 5.2 / 2.4, drag 5.0 / 8.1 ->
  5.0 / 5.4.
- `GlassTabBar`: the dragged lens follows the finger faster (spring
  response 0.25, was 0.35), keeping within ~3 pt of iOS 26's lens
  instead of ~12 pt behind.
- `GlassTabBar` (dark): the shader lens rim splits colour by side (cool
  left, warm right) as iOS's does; the lens keeps black at 3 and the
  resting bar at 20 under it; a drag keeps the held light ~300 ms before
  softening it. Lens fill error per frame vs SwiftUI's `TabView`
  (tabbar_fill.py, max): drag native 11 -> 4.5, shader 7.3 -> 5.8;
  press shader overhang 8 -> 3.
- `GlassTabBar`: the tabs grow with the bar around a held or dragged
  lens, as iOS 26's do (Home and Settings move out about 4 pt). Against
  SwiftUI's `TabView` (dark, frames 0-10 / 10-60): press shader 6.2 /
  5.8 -> 5.1 / 4.4, native 7.6 / 6.3 -> 6.3 / 4.2; drag shader 5.6 / 7.6
  -> 4.6 / 5.2, native 6.6 / 7.7 -> 6.3 / 6.3.
- `GlassTabBar`, native mode: the bar now lights up around a held or
  dragged lens as iOS's does (the glow shader mode already drew), and in
  dark mode the dragged lens is dimmed a little. Against SwiftUI's
  `TabView`: drag mean |diff| 7.0 / 9.1 -> 6.4 / 8.2 (frames 0-10 /
  10-60), press 10-60 7.6 -> 6.3. The native lens no longer smears the
  tinted tabs under it into a blue halo.
- `GlassTabBar`: a quick tap's travelling lens looks closer to iOS 26's.
  The tabs under it magnify on their own spring from touch-down
  (`TabBarMetrics.magnify`), up to about 1.14 for a tap instead of 1.2
  at once. The lens stays up a little longer (`tapHold` 130 -> 165 ms)
  and lifts a little less (`tapLift`), so its height follows iOS's frame
  by frame. In shader mode, dark, the lens rim is a thin neutral grey
  (about 83 grey levels, as iOS's) instead of a bright teal ring, and the
  tinted tabs bend less at the lens's ends. Shader tap frames 0-10 mean
  |diff| against SwiftUI's `TabView`: 5.2 -> 3.7.
- `GlassSlider`: `axis: Axis.vertical` stands it up, minimum at the
  bottom, as a rotated SwiftUI `Slider` (Control Center style); the
  thumb, press growth, divisions, haptics and semantics follow
  (VoiceOver's increase moves it up). Material: a turned `Slider`.
- New `GlassRangeSlider`: two glass thumbs choosing a `RangeValues`, the
  track filled between them. SwiftUI has no range slider; geometry and
  colours follow its single slider. Thumbs never cross, a touch takes
  the nearest one (on overlapping thumbs the drag direction picks),
  `divisions` snap with haptics, each thumb is its own semantics slider,
  and `axis` makes it vertical. Material: `RangeSlider`.
- `GlassTabBar`, native mode, dark: a quick tap's travelling lens no
  longer shows a grey veil. UIKit's clear glass lifted black to about 40
  grey levels under the lens; it is now shaded as the bar's light fades,
  as iOS's lens lets the bar show through (tap frames 0-10 mean |diff|
  against SwiftUI's `TabView` 4.9 -> 4.0; held and dragged lenses keep
  their look).
- Accessibility: high contrast (`MediaQuery.highContrastOf`) now draws
  the shader and degraded glass as a solid surface, as Reduce
  Transparency does, so text over glass keeps its contrast. Native iOS 26
  glass follows Increase Contrast itself; Material is unchanged.
- Accessibility: `GlassToggle` draws iOS's "I" and "O" marks on its track
  when On/Off Labels is on (`MediaQuery.onOffSwitchLabelsOf`).
- Shader glass: the touch glow is about 6× fainter, matching SwiftUI's
  (measured luma lift 0.027 light / 0.041 dark, SwiftUI 0.012–0.019 /
  0.041–0.066; it was 0.175 / 0.238).
- `GlassRefresh` / `SliverGlassRefresh`: pulling reveals the spinner's
  spokes one by one, as `UIRefreshControl` does, instead of filling a
  ring that then jumps to the spinner. `color` now tints the spinner.
- `GlassRefresh`: no tiny disk is left over the content after a refresh
  (the snap-back now ends at exactly 0).
- Accessibility: large text (Dynamic Type / `MediaQuery.textScaler`) no
  longer overflows or cuts text off. Buttons, chips, links, pickers, the
  compact date picker, text and search fields, menus, alerts, action
  sheets and toasts grow and wrap (alerts stack their buttons at the
  accessibility sizes and scroll); fixed-height chrome (the floating tab
  bar, the inline navigation title, segmented controls, wheels, badges and
  accessory gauges) keeps its default text size, as iOS's. Nothing changes
  at the default text size.

## 0.1.9 (2026-10-11)

- Tab bar: `GlassTabBarItem.spacer()`, an empty slot (e.g. under a
  floating action centred over the bar) with no tap target and no
  accessibility node, on both paths. A press released over it leaves the
  lens on the selected tab.
- Fix: `GlassBackButton`'s chevron now mirrors in right-to-left layouts.
- Fix: Material `GlassMenuButton` draws destructive items in the theme's
  error colour.
- Fix: `GlassMenuAnchor` no longer creates its animation controller in
  `dispose()` when the menu was never opened (threw "Looking up a
  deactivated widget's ancestor is unsafe" in debug before Flutter 3.47).
- Depends on `cupertino_icons`, so the icons the package draws render
  without the app adding it.

## 0.1.8 (2026-10-10)

- Sheets: `showGlassSheet` and `GlassSheet` take an optional `cornerRadius`
  and `grabberSize` (defaults stay iOS 26's 38 and 34.67 x 5). On the
  Material path `cornerRadius` rounds the bottom sheet's top corners.
- Tab bar: `GlassTabBarItem.custom(iconWidget:, activeIconWidget:)` for
  SVG or image icons, drawn in the bar's icon size and colour. Breaking:
  `GlassTabBarItem.icon` is now nullable (null for custom items).
- `AdaptiveLiquidGlass.reduceTransparency`: overrides the system's Reduce
  Transparency (null follows it). `true` draws every glass widget as its
  opaque fallback, native glass included, on any platform, to test those
  fallbacks or back an in-app setting.
- `GlassFloatingActionButton` and `.extended(label:)`: a real Material 3
  `FloatingActionButton` on the Material path, a large prominent glass
  button (circle, or capsule with the label) elsewhere.
- `GlassScaffold.floatingActionButton`: floats at the end, 16 above the
  bottom bars (or the safe area); the body keeps its padding.
- `GlassAdaptive(glass:, material: (context) => ...)`: your own widget on
  the Material path, the glass one elsewhere; follows the render mode, so
  app code never checks the platform.
- Material `GlassSearchable`: scopes show only while search is active, as
  on iOS (in the open search view, then under the bar while a query
  remains); they were always visible.
- `GlassScaffold.hideBottomBarsWithKeyboard` (default true): the tab bar,
  toolbar, accessory and floating action button step aside while the
  keyboard is open, instead of riding up onto it; they stay while focus
  is inside them. `GlassScaffold` is now a `StatefulWidget`.
- Tab bar: `materialStyle: GlassMaterialTabBarStyle.edgeToEdge` draws
  Material 3's full-width `NavigationBar` on the Material path, safe area
  inside; `GlassScaffold` drops its gap and pads the body to match.
  `onSearch` becomes a last destination there.
- `GlassLargeTitleScrollView`: a `SliverGlassNavigationBar` over a body
  that scrolls itself (a `ListView`, a paged list). A list in
  `SliverFillRemaining` took every drag, so the large title never
  collapsed.
- Fix: the Material tab bar's floating capsule no longer grows by the
  status bar's height (NavigationBar padded itself by the top inset).

## 0.1.7 (2026-10-09)

- pub.dev metadata: a searchable description, topics `glassmorphism`,
  `ios` and `widget`, and a `repository` link.
- README: links the Medium write-up on how the glass was measured.

## 0.1.6 (2026-10-09)

- pub.dev's Example tab shows the quick start (`example/example.md`);
  0.1.5 still showed the test harness's `example/lib/main.dart`.

## 0.1.5 (2026-10-09)

- Example: `example/lib/quick_start.dart`, a small app with the main
  widgets, replaces the Flutter template on pub.dev's Example tab
  (`example/README.md`); the README's quick start links to it.
- README: Known limitations list the tab bar gaps, the components with
  unmeasured geometry and the picker menu's first-tap issue.

## 0.1.4 (2026-10-09)

- `GlassTabBar` motion, measured frame by frame against SwiftUI's
  `TabView` (iOS 26.4):
  - The lens is the same size as iOS's on press, tap and drag (within
    ~1 pt), and the idle pill matches.
  - A tapped lens travels at iOS's speed (a selection change no longer
    restarts it as a faster slide), lifts 7.0 pt as iOS's does, and the
    new pill fades in late, as on iOS.
  - The bar's light and glow on press and drag, and the first frames'
    brightness, follow iOS's.
  - The lens no longer bends page text or the bottom accessory.
  - Labels beside the search tab sit where iOS sets them.
- `GlassSearchable` in the navigation bar clears the status bar.
- A centred `GlassMenuAnchor` menu (picker) stays on screen near the edges.
- README: a tab bar demo GIF.

## 0.1.3 (2026-10-08)

- README: fidelity numbers from the latest device run (59/75 strict
  passes, median ΔE 1.19) and the install snippet points at the current
  version.

## 0.1.2 (2026-10-08)

- Internal: nine `lib/src` files renamed to match the class they hold;
  the shader test seam moved onto `GlassProgram`. No public API change
  (code importing `src/` paths directly must update them).

## 0.1.1 (2026-10-08)

- README: demo GIF and dark-mode component screenshots, served from GitHub
  so they render on pub.dev.

## 0.1.0 (2026-10-08)

First stable release. The 0.1.0-dev.x series is folded in below.

- `GlassEmptyState` sits where SwiftUI's `ContentUnavailableView` does
  (measured; it was 2.5-10 pt low): a fitted bottom inset, and a taller
  icon gap for `.search`.
- `GlassButton`'s glass label is opaque black over light content, as
  SwiftUI's `.glass` button draws it (measured; it read 38,38,38).
- `showGlassFullScreenCover`:
  - The slide's timing and curves are fitted from a screen recording of
    SwiftUI's `.fullScreenCover` (440 ms in, 406 ms out, within 0.6% of
    the screen's height RMS; were estimated).
  - `dragToDismiss`: drag the cover down to close it, like a sheet (a
    quarter of its height or a 700 pt/s fling; springs back otherwise;
    a semantics dismiss action; `PopScope` respected). Off by default,
    as SwiftUI's cover has none.
  - `showsCloseButton` (+ `closeButtonSemanticLabel`): a glass xmark
    circle top-trailing; a Material close icon on Android.
* `GlassPicker.style` (`GlassPickerStyle`): `inline` rows with a checkmark
  for a `GlassListSection`, and `navigationLink`, a row with the current
  choice and a chevron that pushes a page of the choices (like SwiftUI's
  `.pickerStyle(.inline)` / `.navigationLink`). Material 3 counterparts.
* `GlassLabel`: SwiftUI's `Label(_:systemImage:)`, an icon and title
  with vibrant label colours on glass (`GlassLabelLayout` picks the parts
  shown; geometry estimated). `GlassLabelStyle` is now public.
* `GlassLink` and `GlassShareLink`: glass triggers for SwiftUI's `Link` and
  `ShareLink`. Callbacks only (`onOpen(Uri)`, `onShare`); the app wires its
  URL launcher or share plugin.
* `GlassColorPicker`: iOS 26's `ColorPicker` row (label and swatch) opening
  a glass sheet with a preset grid, a spectrum square and hue bar, an
  opacity slider and a hex field; a Material 3 list tile and bottom sheet
  on Android. Geometry estimated, not yet measured.
* `GlassSearchable`: iOS 26's `.searchable` presentation around
  `GlassSearchField` — Cancel button with a spring, suggestion rows on a
  glass platter, scopes as a `GlassSegmentedControl`, `navigationBar` or
  `bottom` placement, driven by `GlassSearchController`. Material:
  `SearchAnchor`. Geometry estimated, not measured.
* `GlassRefresh` and `SliverGlassRefresh`: iOS 26's pull to refresh
  (SwiftUI `.refreshable`) with a glass spinner, haptic on trigger and a
  spring snap-back; `RefreshIndicator` on Android. Geometry estimated, not
  yet measured.
* `GlassDatePicker.style` (`GlassDatePickerStyle`): `graphical` renders the
  calendar inline (`GlassCalendar` is now public, with `showWeekNumbers`),
  `wheel` renders day/month/year columns on one glass surface
  (`GlassDateWheel`). `GlassDatePicker.pickerMode` (`GlassDatePickerMode`):
  `time` is an hour:minute capsule opening a wheel time picker (12/24-hour
  per `MediaQuery.alwaysUse24HourFormat` or `use24HourFormat`,
  `minuteInterval` respected); `dateAndTime` shows both capsules.
  Material: `CalendarDatePicker`, `showTimePicker`. Wheel geometry
  estimated, not yet measured.

## 0.1.0-dev.10

* `Glass` presets: `Glass.frosted`, `Glass.crystal`, `Glass.smoke`,
  `Glass.accent` and `Glass.tinted(color)`, all composed from the existing
  material API.
* `GlassActivityIndicator`: iOS's spinner as a standalone widget
  (`CircularProgressIndicator` on the Material path).
* `GlassWheelPicker`: SwiftUI's `.pickerStyle(.wheel)` in a glass surface
  with a clear-glass selection band and haptics (`ListWheelScrollView` on
  the Material path).

## 0.1.0-dev.9

- Add light and dark screenshots with plain backgrounds to the pub.dev gallery.
- Keep photo-background screenshots as additional glass-effect examples.

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
