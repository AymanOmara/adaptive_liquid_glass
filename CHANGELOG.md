## Unreleased

- `showGlassDateRangePicker` returns a `DateTimeRange?`: on the glass path
  the `showGlassDatePicker` sheet with a range calendar (first tap the
  start, second the end, a tap before the start begins again; blue end
  circles and a lighter band wrapping per week row; Done disabled until
  both ends are picked), on Material `showDateRangePicker`. The calendar
  is public as `GlassCalendar.range`; in-range days read as selected.

## 0.2.2 (2026-10-15)

- `LiquidGlassThemeData.supportLiquidGlassOnAndroid` (default false): one
  switch for the iOS look on Android. `auto` then draws the shader glass
  there (the frosted blur where `ImageFilter.isShaderFilterSupported` is
  false) instead of Material 3; iOS and other platforms are unchanged, and
  a widget's `mode:` or a non-`auto` `defaultMode` still wins.
  `AdaptiveLiquidGlass.initialize(supportLiquidGlassOnAndroid: true)`
  preloads the shaders; without it they load on first use (a plain blur
  for the first frame or two). `androidShaderBudget` applies. The example
  app has an "iOS glass" toggle on Android (`--dart-define=ANDROID_GLASS=true`).
- Android, `GlassRenderMode.shader`: all shader glass of a route draws
  through one shared layer (one backdrop capture, one blur per stratum of
  overlapping glass, up to 24 shapes per pass), with each group's content
  composited after its glass. Under Impeller each shader backdrop costs
  about 110-200 MB of GPU memory whatever its size, and the example
  Gallery (10+ groups) reached 1.1-3.9 GB and was killed by lmkd; it now
  peaks about 0.9 GB over idle with every group shader glass. Limits:
  non-glass content painted after a group and overlapping its glass draws
  beneath it, groups of one stratum share the largest blur, clips around
  glass are rectangular, and menus draw their glass group by group. iOS, Material and native glass are
  unchanged.
- `GlassTabBar` over shader glass: the vibrant labels, tint and selected
  pill no longer vanish when a scroll view or a route transition moves the
  bar. The vibrancy shader finds the glyphs at the screen position of the
  last paint, and moving the bar did not repaint them; the blend now
  repaints (with the same glyph image) when an enclosing scroll position
  or the route animates. This, not the shared layer, was why vibrancy
  looked broken there: on the shared layer it is now on, and the bar
  matches the per-group path (mean difference 0.0 over the bar on the
  vibrancy probe and over a photo, 0.07 on the Gallery's two bars after
  scrolling). Cost: about 100 MB more host graphics memory on average
  over the emulator Gallery run (peaks within run-to-run noise).
- `LiquidGlassThemeData.androidShaderBudget` (new; default null = no cap)
  caps the shader glass groups drawn group by group on Android (outside
  the shared layer); the rest draw the frosted blur fallback.
- Android (Impeller, OpenGL ES): fixed a raster-thread crash at launch
  with a shader-mode `GlassTabBar`. Its vibrant labels rasterise a glyph
  image (`toImageSync`), and a snapshot taken before the first frame
  reaches the screen makes Impeller build a throwaway surface, which
  crashes on GLES (Flutter 3.47). The labels now stay flat until the first
  frame is rasterised, and the `GlassBackdropSource` luminance sampler
  skips its readback until then and while the app is in the background.
- Measured against SwiftUI / UIKit on iOS 26.4 (TODO item 6):
  - `GlassRefresh`: the refresh starts under the finger once the list is
    pulled 173 pt (or the finger travels 315 pt past the top), as
    `.refreshable` does; it armed at 65 pt and fired on release. The
    spinner is 30 pt with no glass disk behind it and does not scale; its
    spokes fade in with the pull (was a 36-pt disk and a 20-pt spinner).
    `SliverGlassRefresh` uses the same 173-pt threshold.
  - `GlassRefresh` gives a scrollable that inherits bouncing physics
    UIScrollView's rubber band under the pull: for 50-300 pt of finger
    travel the content moves 36-165 pt (UIKit 40-168; was 25-133). New
    `GlassRefreshScrollPhysics` for scrollables that set their own physics
    and for `SliverGlassRefresh`. Clamping platforms keep theirs.
  - The refresh spinner's dark-mode spokes are measured: #888893 (was an
    estimated #AEAEB2), the head spoke matching UIKit's on black exactly.
  - `GlassSearchable`: the close button's reveal is fitted to SwiftUI's
    (three recordings, rms 1.95 pt): the field narrows over the first 13%
    of the spring (was 50%), the button grows from 0.32 (0.28) on a
    0.53 / 0.69 spring (was the sheet's 0.4 / 0.86) and overshoots
    slightly before settling. Its hide is fitted too (three recordings,
    rms 1.85 pt): the row jumps to the idle insets at once, the button
    fades within ~4 frames and the field springs over its room on a
    0.26 / 0.56 spring, ~7 pt past its rest and back (was the reveal's
    spring run backwards; 23 pt rms from SwiftUI's curve, now 5).
  - `GlassColorPicker`'s sheet is laid out as UIColorPickerViewController:
    600 pt, floating, no grabber; the row's label as title and a close
    button; a Grid / Spectrum / Sliders segmented control; red, green and
    blue capsule sliders with value fields and an sRGB hex field; an
    opacity slider with its percentage; the current colour under a
    separator. New `slidersLabel` and `closeLabel`; `hexLabel` defaults
    to 'sRGB Hex Color #'. `GlassColorPickerPanel` gains `title`,
    `onClose` and per-channel labels.
  - `GlassColorPicker`'s sheet, second pass against
    UIColorPickerViewController: it floats 8 pt in from the screen's
    sides (was 4.7), so the grid is 296 pt as UIKit's (was ~303); the
    segmented control is 30.67 pt (was 32). New: the saved colours row
    (29-pt circles 46.07 apart and a "+" that saves the current colour; a
    tap picks one, a long press removes it), kept in memory and shared
    between pickers, or the app's own through `savedColors` /
    `onSavedColorsChanged`; UIKit's Spectrum map (hue down the page,
    white to hue to black across it, its measured curves; was a
    saturation-value square and hue bar, mean |diff| 100 -> 1.1 of 255);
    an eyedropper that hides the sheet, shows a loupe over the app and
    picks the pixel under it (`supportsEyedropper`, `eyedropperLabel`;
    the app's own drawing only). New labels `savedColorLabel`,
    `addColorLabel`.
- Sheets: every partial detent floats 8 pt in from the screen's sides,
  whatever its height, as SwiftUI's `.height(300)` to `.height(765)` do
  (measured); only a detent within ~31 pt of large runs edge to edge.
  Taller detents used to widen toward the edges past the medium height.
- `GlassSegmentedControl`: `trackHeight` (default SwiftUI's 32); the
  track is iOS's translucent tertiary fill, so it shows on grey surfaces
  such as the colour sheet (same colour as before over white and black).

- Usability pass ahead of 1.0 (audit in
  `docs/superpowers/notes/usability-audit.md`):
  - `AdaptiveLiquidGlass.initialize()` initialises the Flutter binding
    itself; `main()` no longer needs `WidgetsFlutterBinding.ensureInitialized()`.
  - `tint` is the accent colour's name on every control, as SwiftUI's
    `.tint`: `GlassToggle`, `GlassSlider` and `GlassRangeSlider` (was
    `activeColor`), `GlassProgressIndicator` and `GlassPicker` (was
    `color`), `GlassChip` and `GlassTabBar` (was `selectedColor`). The old
    names still work, deprecated until 1.0.
  - `LiquidGlass.precache()` is deprecated: `AdaptiveLiquidGlass.initialize()`
    is the one setup call (pass `mode: GlassRenderMode.shader` to preload
    off iOS too).
  - `GlassMenuButton`'s `icon` and `semanticLabel` default to the ellipsis
    "More" button; `showGlassAlert`'s `actions` default to one OK button
    (localised), as SwiftUI's `.alert`.
  - No longer exported: `DatePickerMetrics`, `DatePickerWheelMetrics` and
    `WheelPickerMetrics`, the measured constants the widgets use (no public
    API takes them), and `pressableGlass`, a helper documented as internal.
  - README: Getting started is one import, one optional setup call and one
    example; the "Which widget?" table gains the components it missed
    (`GlassLabel`, `GlassLink`, `GlassShareLink`, `GlassColorPicker`,
    `GlassRefresh`, `SliverGlassRefresh`, `GlassSymbol`).

- Photos picker: picked videos report their upright `width` and `height`
  and a new `GlassPickedPhoto.duration` (both platforms); Android photo
  sizes now account for EXIF rotation.
- `GlassPhotosPicker` and `pickGlassPhotos` take `maxWidth`, `maxHeight`
  and `imageQuality` to downscale or re-encode photos, and
  `compatibleFormat` for JPEG instead of HEIC (and, on iOS, H.264 instead
  of HEVC videos). Defaults keep the original files.
- Photos picker `compatibleFormat` now transcodes HEVC videos to H.264
  on Android too (platform `MediaCodec`/`MediaMuxer`, no new dependency;
  audio copied, rotation kept). A video whose conversion fails (either
  platform) arrives unconverted with the new
  `GlassPickedPhoto.conversionFailed` set, instead of silently.
- `pickGlassPhotos` returns `GlassPickedPhotos`, still a
  `List<GlassPickedPhoto>`, with `droppedCount`: items chosen beyond
  `maxSelection` in the Android document-picker fallback, which cannot
  enforce the limit. `GlassPhotosPicker.onPicked` receives it too.
- `clearGlassPickedPhotos()` deletes the picker's copies (the
  `adaptive_liquid_glass_picker` folder in the temporary or cache
  directory).
- `GlassRefresh`: the content stays held down by the spinner's room
  while `onRefresh` runs, as SwiftUI's `.refreshable` holds its list, and
  returns on the measured snap-back spring once it completes. The release
  eases into the hold on a spring fitted to iOS (response 0.30, damping
  1.43) instead of bouncing to the top; content scrolled into while
  refreshing carries the spinner up with it. Against SwiftUI on iOS 26.4:
  hold 60.0 vs 60.3 pt, spinner centre 30 pt below the list's top inset
  (90.5 vs 92 pt on screen), snap-back fit 0.445 / 0.79 vs 0.486 / 0.76.
- `GlassRefresh.edgeOffset`: where the indicator's room starts; defaults
  to the top media padding, as `UIRefreshControl` sits below the scroll
  view's top inset (it sat at the very top, under a status or nav bar).
- README: dropped the known limitation that shader-drawn tab labels
  (vibrancy) sample the backdrop upside down on Android's OpenGL ES
  backend. Checked on an Android emulator (Impeller, OpenGL ES, Flutter
  3.47): each label pixel follows the glass right behind it; the shader
  flips only on engines before 3.46, like the glass shader. A test now
  keeps every backdrop shader on that guard.
- `example/lib/vibrancy_flip_probe.dart`: the tab bar over a red page
  with a blue band behind the labels, to check the orientation by eye.
- Internal: one class per file across `lib/` (private helpers as `part`
  files), colour literals and stray `CupertinoColors` uses routed through
  `GlassColors` (convention documented there), and the frozen
  `GlassConstants.standard` data in its own file. No behaviour or public
  API change.
- `showGlassSheet`: `isScrollControlled` (Material; null derives it as
  before), `enableDrag` (apart from `isDismissible`'s barrier tap) and
  `maxHeightFactor`, which caps the whole sheet, grabber and inset
  included.
- `showGlassAlert`: `content`, `icon`, `barrierDismissible` (null keeps
  each path's default) and `actionOrder` (`GlassAlertActionOrder`).
- `GlassDialogAction.subtitle`: a secondary second line on alerts,
  confirmation dialogs and action sheets, read with the label. Each glass
  dialog button is now its own semantics node.
- `GlassMenuItem.color` tints an item's label and icon on both paths; a
  disabled or destructive item keeps its own colour.
- `GlassButton.foregroundColor` sets the label and icon colour on every
  path and style; a disabled button keeps its dimmed look.
- `GlassButton.cornerRadius` sets a `GlassButtonShape.roundedRect`
  button's radius on both paths (other shapes ignore it).
- `GlassChip.subtitle`: secondary text after the label (a count, say),
  read with it; the chip stays 32 pt tall.
- `LiquidGlass.minSize`: the glass grows to at least this size with its
  child centred (a 44 pt circle around a 16 pt icon, no padding sums).
- `GlassListSection.backgroundColor` and `separatorColor` replace the
  platter and hairline colours (the card and dividers on Material).
- `GlassTabBar.labelMaxTextScale` caps the tab labels' text scale (the
  floating bar still pins it at 1 by default).

- `showGlassDatePicker(context:, ...)` returns a `Future<DateTime?>`: a
  glass sheet with the calendar (picking a day confirms) or the wheels (a
  checkmark confirms); dismissing returns null. On Material it is
  `showDatePicker`.
- `firstDayOfWeek` on `GlassCalendar`, `GlassDatePicker` and
  `showGlassDatePicker` (0 = Sunday to 6 = Saturday; null follows the
  locale). On Material the locale decides.
- `GlassNavigationBar.materialBuilder`: return your own
  `PreferredSizeWidget` on the Material path (it receives the default
  `AppBar`); its `preferredSize` sizes the `Scaffold` / `GlassScaffold`
  slot. The Material bar is now tested to take every `AppBarTheme` style.
- `GlassAdaptive.pathOf(context)` and `GlassAdaptive.usesGlass(context)`
  tell function-style code which path the package would render
  (`GlassEffectivePath`), using the same resolver as every widget.
- `GlassSwipeActions.groupTag`: opening a row closes only open rows with
  the same tag; `GlassSwipeActions.closeGroup(tag)`. `closeAll()` closes
  every group.
- Fixed: `GlassEmptyState`'s title and description keep the app's font
  family on the glass path.

- `GlassBatch`: ungrouped glass below it (chips, list rows, sheet
  content) shares one native iOS 26 view instead of one each; on the
  simulator 29 chips need 1 view instead of 29 (first show 0.3 s instead
  of 1.6-2.2 s, debug). Glass a shared view would draw differently (over
  painted or overlapping content, partly clipped, rotated, in an overlay
  or another scroll view) keeps its own view.
- `LiquidGlassThemeData.batchImplicitGroups` (default false): `GlassSheet`
  content and `GlassScaffold` bodies batch their ungrouped glass
  automatically, and native `GlassGroup`s take more than 16 members.
  Scrolled content needs its own `GlassBatch`.

## 0.2.1 (2026-10-14)

- Debug builds print a one-time warning when more than 8 native glass
  views are alive at once: a `LiquidGlass` outside any `GlassGroup` hosts
  its own native view on iOS 26. The README says to wrap repeated glass in
  one `GlassGroup`.

## 0.2.0 (2026-10-14)

- `GlassTabBar`, native mode: SwiftUI draws the selected pill inside the
  glass, shifting it by a fixed amount as iOS does, so a photo keeps its
  colour beneath (pill error vs SwiftUI's `TabView`: plain 17 / 33 -> 0,
  photo 8.7 / 10.4 -> 5.6 / 3.4, light / dark). The lens leads the finger
  and its tap travel by UIKit's frame of latency (drag centre 199 -> 208
  pt, iOS 208; tap error 18.5 -> 5.3 pt), stays mounted so a press shows
  it on iOS's frame, darkens its overhang past the bar, shows the bar's
  edge 3.3 pt in as iOS's squeezes it, and rims bright in dark mode
  (held-lens error 2.51 / 6.52 -> 2.01 / 4.70).
- `GlassTabBar`, shader mode: the dark lens's overhang stays near black
  (it read blue); the light lens's shadow is soft beside it; the held lens
  shows the bar's edge 3.3 pt in, as iOS's (held-lens error 3.52 / 5.64
  -> 2.46 / 5.17). The bar's glass follows iOS's tone over photos and
  text (ambient lift), the light lens fringes in rainbow colours, and the
  lens refracts only the bar (no page text in its bands).
- README: `GlassTabBar` recorded beside SwiftUI's `TabView`.
- `package:adaptive_liquid_glass/glass_testing.dart`: `GlassTesting.setUp`
  pins the platform, iOS version and fallbacks for an app's widget tests
  and stops the shaders loading; `GlassTesting.reset` restores the
  defaults. README: Testing your app.
- `GlassSwipeActions` matches SwiftUI's motion, measured frame by frame
  (`tool/fidelity/record_swipe_motion.sh`): actions grow in place as the
  row uncovers them, trailing a fast drag; past rest the inner ones keep
  to the row and fade while the outermost stretches, and past the
  full-swipe point (now 0.62 of the width) a fast swipe takes the row,
  while a slow pull there only opens it. Actions bounce slightly as they
  reach full size. Rows from 90 pt get 50-pt circles centred with their
  labels. The platter fades on its own clock (no grey dip in light
  mode), the row's spring no longer overshoots, and compact capsules are
  SwiftUI's width.
- `GlassSwipeAction.destructive`: red by default; its full swipe hides
  the row, collapses it, then runs `onPressed`.
- Material path: `GlassNavigationBar` is as tall as the app's
  `AppBarTheme.toolbarHeight` in a `Scaffold` or `GlassScaffold` (it was
  squeezed to the glass bar's 46.33).
- Glass routes (sheets, popovers, dialogs, full-screen covers, context
  menus) put a transparent `Material` under their content, so a
  `ListTile` or `TextField` works there.
- `GlassSheetDetent.contentHeight(h)`: the sheet's content is exactly `h`
  tall; the grabber and bottom inset are added on top.
- Material path: tinted glass keeps the tint as given instead of a pastel
  `primaryContainer` seeded from it, with black or white labels for
  contrast; tinted prominent buttons label for contrast too.
- Swipe actions: `GlassSwipeAction.confirm` asks before the action runs
  (false closes the row and skips it); `GlassSwipeActions.fullSwipeThreshold`
  sets the full-swipe point (0.6 of the width by default);
  `GlassSwipeActions.closeAll()` closes the open row.
- `showGlassToast(replace: true)`: the new toast takes over at once; the
  shown one leaves and those waiting are dropped (on the Material path,
  the messenger's snackbars are cleared).
- `GlassTextField.password`: the Material eye button reads its show /
  hide label to assistive tech (it was a tooltip only), and the glass
  one reports its enabled state, so both paths read the same.
- Material `GlassChip`s are 32 tall, as the glass chip: compact, without
  the padded tap target.
- `GlassSegmentedControl.height`: the control is this tall on both
  paths; the Material `SegmentedButton` is compact without the padded
  tap target, so a fixed-extent header fits either.
- Segmented control labels, toasts and glass pages keep the inherited
  font family (an app's custom font) instead of falling back to the
  default.
- Every animated control (toggle, slider, segmented control, refresh,
  tab bar and sidebar, progress, toast, swipe actions, search, sheet,
  full-screen cover) creates its animation controllers in `initState`;
  a lazy one first read in `dispose` threw on Flutter before 3.47.
- `GlassSegmentedControl`: a pick the parent rejects (keeps `selected`)
  springs the thumb back to the selected segment.
- `GlassActivityIndicator.semanticLabel` defaults to none, not the
  English 'Loading'; pass a label in the app's language.
- Shader glass on Android (`GlassRenderMode.shader`, Impeller on OpenGL
  ES): glass sampled the backdrop upside down and drew flat grey away
  from the screen's middle. `liquid_glass.frag` and
  `tab_lens_content.frag` now flip only on engines that still store GLES
  targets bottom-up, as `progressive_blur.frag` does.
- Glass navigation bars (`GlassNavigationBar`, `SliverGlassNavigationBar`)
  set the status bar glyphs to match the page (dark on light), as iOS's
  do; on Android they kept the previous route's style.
- README: the iOS look on Android, and its known limitations.
- `GlassButtonStyle` gains SwiftUI's styles without glass: `bordered`
  (grey fill, or the tint at 15% / 20% dark, accent label),
  `borderedProminent` (solid accent fill, white label), `borderless`
  (accent label) and `plain` (primary label colour). They support
  `GlassButton.icon`, roles (destructive is red), sizes, shapes, loading,
  and iOS's grey disabled state, and dim while pressed. On Android they
  map to `FilledButton.tonal`, `FilledButton` and `TextButton`. Fills and
  press dimming are estimated, not measured.
- `GlassTabBar` over shader glass: untinted labels are vibrant, as iOS
  26.4's (each glyph pixel takes the hue of the glass behind it and a
  lightness fitted per pixel; `tab_vibrancy.frag`); the selected tint
  follows the glass by half, and the selected pill darkens the glass
  more where it is darker, as iOS's do.
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
- New: `GlassPhotosPicker`, SwiftUI's `PhotosPicker`: a glass trigger that
  opens the system photo picker (`PHPickerViewController` on iOS, the
  Android Photo Picker or document picker on Android) with
  `maxSelection` and a `GlassPhotosPickerFilter` (images, videos, any).
  `pickGlassPhotos()` opens it from any trigger. Picks arrive as
  `GlassPickedPhoto` local copies (path, video flag, MIME type, image
  size). No new dependencies and no permissions.
- Android: the package now ships a small Kotlin plugin
  (`AdaptiveLiquidGlassPlugin`) that only hosts the photo picker; the
  Material 3 path stays pure Dart.
- Motion measured against SwiftUI on iOS 26.4: `GlassDisclosureGroup`
  springs with response 0.29 (was 0.35, damping 1.0); `GlassRefresh`
  snaps back with 0.47 / 0.77 (was 0.35 / 0.8); `GlassColorPicker`'s grid
  ring swaps at once (was a 150 ms fade). New
  `tool/fidelity/record_component_motion.sh` and `component_motion.py`.
- Measured against SwiftUI (iOS 26.4) and pinned in the reference tests:
  `GlassLabel` gap 6 -> 12; `GlassWheelPicker` rows 21 -> 22 pt (band,
  width and row height confirmed); date wheel band 32 -> 30.67;
  `GlassSearchable` active field 12 pt from the sides and 12 above the
  keyboard (was 16/8), idle 28 from the sides and bottom, and Cancel is now
  iOS 26's 48-pt glass xmark circle 12 pt from the field; the full-screen
  cover's close button is a 44-pt circle flush with the safe area (was the
  30-pt regular icon button); the colour row swatch has iOS's hue ring
  (3.33 pt) and 1.67-pt gap. Links and the time capsule already matched.
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
