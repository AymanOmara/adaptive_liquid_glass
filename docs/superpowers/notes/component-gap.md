# iOS 26 component gap analysis

Originally drafted in Oct 2026 and refreshed in Nov 2026. The inventory is based
on `lib/adaptive_liquid_glass.dart` and the iOS 26 SwiftUI/UIKit control and
container catalogue; this note also records the implementations, simulator
captures and measurements completed during the refresh.

Legend — have: **yes** / **partial** / **no** (+ our class). Common: how often
the component appears in typical apps. Effort: **S** (≤ a focused day),
**M** (multi-day), **L** (multi-week / new subsystem). "verify" = unsure the
API exists exactly as named in iOS 26.

## 1. What we export today

Grouped from `lib/adaptive_liquid_glass.dart`; `lib/testing.dart` is a second
entrypoint (fidelity constants, not stable API).

- **Core/effect**: `LiquidGlass` (+ `.glassEffect()` extension), `GlassGroup`,
  `Glass`, `GlassVariant`, `GlassShape`, `GlassRenderMode`,
  `GlassBackdropSource`, `GlassForeground`, `AdaptiveLiquidGlass`,
  `LiquidGlassTheme`, `LiquidGlassThemeData`, `GlassSystemColors`.
- **Button**: `GlassButton` (+ `.icon`), `GlassButtonStyle`, `GlassButtonRole`,
  `GlassButtonShape`, `GlassControlSize`, `GlassControlSizeScope`, `GlassChip`.
- **Controls**: `GlassToggle`, `GlassSlider`, `GlassRangeSlider`, `GlassSegmentedControl`,
  `GlassSegment`, `GlassStepper`, `GlassDatePicker` (compact only).
- **Picker/menu**: `GlassPicker` (menu only), `GlassPickerItem`,
  `GlassMenuButton`, `GlassMenuItem`, `GlassMenuController`, `GlassContextMenu`.
- **Overlays**: `showGlassAlert`, `showGlassConfirmationDialog`,
  `GlassDialogAction`, `showGlassActionSheet`, `showGlassSheet`, `GlassSheet`,
  `GlassSheetDetent`, `showGlassPopover`, `GlassPopoverAnchor`,
  `showGlassToast`, `GlassToastAction`, `GlassToastHandle`.
- **Navigation/scaffold**: `GlassNavigationBar`, `SliverGlassNavigationBar`,
  `GlassScrollEdgeStyle`, `GlassBackButton`, `GlassScaffold`,
  `GlassBottomAccessory`, `GlassTabBar`, `GlassTabBarItem`.
- **Toolbar/text/search**: `GlassToolbar`, `GlassToolbarSpacer`,
  `GlassSearchField`, `GlassTextField` (+ `.password`).
- **List**: `GlassListSection`, `GlassListTile`.
- **Feedback**: `GlassProgressIndicator`, `GlassProgressStyle`, `GlassBadge`
  (+ `.count`), `GlassPageControl` (UIKit UIPageControl), `GlassSwipeActions`,
  `GlassSwipeAction`.

## 2. Gap table

### Buttons

| component | SwiftUI API | we have? | common | effort | notes |
|---|---|---|---|---|---|
| Glass button | `.buttonStyle(.glass)` | **yes** — `GlassButton` | high | — | variants/roles/sizes/shapes complete |
| Prominent glass | `.buttonStyle(.glassProminent)` | **yes** — `GlassButton(style: .glassProminent)` | high | — | tint + role aware |
| Bordered / borderless / plain | `.bordered`, `.borderedProminent`, `.borderless`, `.plain` | **yes** — `GlassButton(style: .bordered / .borderedProminent / .borderless / .plain)` | med | — | no glass; role + disabled aware; fills, disabled colours, held highlights and visual release measured 2026-10-30; default-size geometry measured; pointer onset measured/improved 149→49 ms in debug (native ≈15 ms); hardware latency unmeasured |
| Button role | `.destructive` / `.cancel` | **yes** — `GlassButtonRole` | high | — | |
| Control size | `.controlSize(_:)` | **yes** — `GlassControlSize` + `GlassControlSizeScope` | med | — | `mini`→small, `extraLarge`→large collapse |
| Label | `Label(_:systemImage:)` | **yes** — `GlassLabel` | high | — | done; `GlassLabelLayout`, vibrant label styling |
| Link | `Link(destination:)` | **yes** — `GlassLink` | med | — | done |
| Share link | `ShareLink(item:)` | **yes** — `GlassShareLink` | med | — | done |
| PhotosPicker | `PhotosPicker` (PhotosUI) | yes | low | L | `GlassPhotosPicker` / `pickGlassPhotos`: PHPicker on iOS, Photo Picker on Android, files copied to temp |
| Keyboard toolbar | `ToolbarItem(placement: .keyboard)` | **yes** — `GlassKeyboardToolbar` | med | — | done 2026-11-08: measured (`-controls keyboardtoolbar`): 48 pt capsules on the keyboard top, 16 pt side insets; Material: full-width surface bar |
| ToolbarSpacer | `ToolbarSpacer(.flexible)` | **yes** — `GlassToolbarSpacer` | med | — | bottom toolbar only |

### Controls

| component | SwiftUI API | we have? | common | effort | notes |
|---|---|---|---|---|---|
| Toggle | `Toggle` | **yes** — `GlassToggle` | high | — | tap + drag thumb |
| Slider | `Slider` | **yes** — `GlassSlider` | high | — | filled track, divisions+haptics; `axis: Axis.vertical`; range/two-thumb as `GlassRangeSlider` |
| Stepper | `Stepper` | **yes** — `GlassStepper` | med | — | configurable `step`; no custom increment/decrement builders |
| Gauge | `Gauge` | **yes** — `GlassGauge` (`GlassGaugeStyle`) | med | — | done |
| ColorPicker | `ColorPicker` | **yes** — `GlassColorPicker` | med | — | done |

### Pickers

| component | SwiftUI API | we have? | common | effort | notes |
|---|---|---|---|---|---|
| Menu picker | `.pickerStyle(.menu)` | **yes** — `GlassPicker` | high | — | checkmark menu, accent value |
| Segmented | `.pickerStyle(.segmented)` | **yes** — `GlassSegmentedControl` | high | — | standalone widget, not a `GlassPicker` style; UX parity already good |
| Wheel | `.pickerStyle(.wheel)` | **yes** — `GlassWheelPicker` | med | — | done |
| Inline | `.pickerStyle(.inline)` | **yes** — `GlassPickerStyle.inline` | med | — | done |
| NavigationLink | `.pickerStyle(.navigationLink)` | **yes** — `GlassPickerStyle.navigationLink` | med | — | done |
| Palette | `.pickerStyle(.palette)` | **yes** — `GlassPickerStyle.palette` | low | — | done (63b3518) |
| Date compact | `.datePickerStyle(.compact)` | **yes** — `GlassDatePicker` | med | — | capsule → glass calendar popover |
| Date graphical | `.datePickerStyle(.graphical)` | **yes** — `GlassDatePicker(style: graphical)`, `GlassCalendar` exported | med | — | inline calendar, `showWeekNumbers`; inline geometry measured (`-controls calendargraphical`, `calendargraphicaltime`: fills its width, 44-pt rows/circles, tinted selection, time row); week-number gutter uses a package-defined width (the recorded native graphical picker has no gutter) |
| Date wheel | `.datePickerStyle(.wheel)` | **yes** — `GlassDatePicker(style: wheel)`, `GlassDateWheel` | med | — | selection band and column label alignment measured on iOS 26.4 (see `controls.json` → `date_wheel` and `date_wheel_time`); native drag trials recorded in §4 measurements |
| Time / range | `hourAndMinute`, `DateRange` graph | **yes** — `pickerMode: time` / `dateAndTime`, `GlassDateRangePicker` | med | — | range picker done (63b3518) |

### Text & search

| component | SwiftUI API | we have? | common | effort | notes |
|---|---|---|---|---|---|
| TextField | `TextField` | **yes** — `GlassTextField` | high | — | prefix/suffix, clear, error, autofill |
| SecureField | `SecureField` | **yes** — `GlassTextField.password` | med | — | eye reveal |
| TextEditor | `TextEditor` | **yes** — `GlassTextEditor` | med | — | done (71a59a3) |
| Searchable | `.searchable` + scopes/suggestions | **yes** — `GlassSearchable` + `GlassSearchController` | high | — | Cancel spring, suggestion platter, scopes, `navigationBar`/`bottom` placement; measured (`SearchMetrics`: `-controls search`, `searchactive`, `searchmotion`, `searchscopes*`, `searchdrawer*`; `controls.json` → `search`, `searchable`, `search_scopes`, `search_suggestions`, `search_drawer`) |
| Tab search | `Tab(role: .search)` | **yes** — `GlassTabBar.onSearch` | med | — | circle lens tab |
| Text input on glass | `GlassForeground` vibrant labels | **yes** — `GlassForeground` | high | — | brightness-sampled label colors |

### Feedback & status

| component | SwiftUI API | we have? | common | effort | notes |
|---|---|---|---|---|---|
| ProgressView | `ProgressView` linear/circular | **yes** — `GlassProgressIndicator` | high | — | both styles, determinate + indeterminate |
| Badge | `.badge(_:)` | **yes** — `GlassBadge` (+ `GlassTabBarItem.badge`) | med | — | count caps at 99+, dot |
| Empty/error state | `ContentUnavailableView` | **yes** — `GlassEmptyState` | high | — | done |
| TipKit | `Tip` / `.popoverTip` | **yes** — `GlassTipView`, `GlassPopoverTip`, `GlassTipController` | low | — | done; show-once via controller (app persists); no rules/events engine |
| Toast | no SwiftUI API | **yes** — `showGlassToast` (beyond SwiftUI) | med | — | swipe-dismiss, queue, actions |
| Page control | UIKit `UIPageControl` | **yes** — `GlassPageControl` | med | — | tap halves, scrub, haptics |

### Menus & overlays

| component | SwiftUI API | we have? | common | effort | notes |
|---|---|---|---|---|---|
| Menu | `Menu` pull-down | **yes** — `GlassMenuButton` + `GlassMenuItem.section` / `.submenu`, `primaryAction` | high | — | done (5c545cd); submenus use the iOS 26 recede presentation; `GlassMenuItem.picker` supports a palette swatch row |
| Context menu | `.contextMenu` | **yes** — `GlassContextMenu` | med | — | measured against UIKit (`ContextMenuMetrics`: lift, shadow, 250-pt menu, safe-area clamp, springs); oversized preview scaling and menu overlap implemented; fresh tall-preview pair in §4 |
| Popover | `.popover` | **yes** — `showGlassPopover` / `GlassPopoverAnchor` | med | — | iPhone bubble, no arrow, undimmed; rechecked on iOS 26.4 in §4 |
| Alert | `.alert` | **yes** — `showGlassAlert` | high | — | |
| Confirmation dialog | `.confirmationDialog` | **yes** — `showGlassConfirmationDialog` | high | — | tap-outside = cancel |
| Action sheet | UIKit `UIAlertController` action sheet | **yes** — `showGlassActionSheet` | med | — | |
| Sheet + detents | `.sheet` + `.presentationDetents` | **yes** — `showGlassSheet` / `GlassSheetDetent` | high | — | medium/large/fraction/height, grabber |
| Full-screen cover | `.fullScreenCover` | **yes** — `showGlassFullScreenCover` | med | — | done (`GlassFullScreenCoverHandle`, drag configuration) |
| Inspector | `Inspector` (iOS 17+) | **yes** — `GlassInspector` | low | — | done (3213048) |
| Glass effect container | `GlassEffectContainer` | **yes** — `GlassGroup` | high | — | spacing merge, shared backdrop |
| Glass union | `glassEffectUnion` | **yes** — `LiquidGlass.unionId` | med | — | per-member |
| Glass morph | `glassEffectID` | **yes** — `LiquidGlass.glassId` | med | — | hero morph inside group |

### Navigation & layout

| component | SwiftUI API | we have? | common | effort | notes |
|---|---|---|---|---|---|
| Inline nav bar | `NavigationStack` bar | **yes** — `GlassNavigationBar` | high | — | leading auto-back, merged actions |
| Large title | large title + collapse | **yes** — `SliverGlassNavigationBar` | high | — | scroll fade-in, pull stretch |
| Bar items | `ToolbarItem` in nav bar | **yes** — `GlassBarItem`, separate trailing pills | high | — | done (9c180ce); lone trailing item is a 44-pt circle |
| Bottom toolbar/bottom bar | `.toolbar` bottom bar | **yes** — `GlassToolbar` | med | — | floating capsules, spacers, no top placement |
| safeAreaBar | `.safeAreaBar` | **yes** — `GlassSafeAreaBar` | low | — | done (3213048) |
| Bottom accessory | `.tabBarBottomAccessory` (verify name) | **yes** — `GlassBottomAccessory` | med | — | Music mini-player pattern |
| Tab bar | `TabView` tab bar | **yes** — `GlassTabBar` | high | — | lens press, drag, badges, search tab |
| Sidebar adaptable | `TabView` `.sidebarAdaptable` | **yes** — `GlassTabBarStyle.sidebarAdaptable` (via `GlassScaffold`) | med | — | done; `GlassTabSidebar` is internal |
| Tab bar minimize | `.tabBarMinimizeBehavior` | **yes** — `GlassTabBar.minimizeBehavior` / `GlassTabBarMinimizeBehavior` | med | — | done |
| Page style | `TabView` `.page` style | **yes** — `GlassPageView` + `GlassPageControl` | med | — | done (3213048) |
| Zoom transition | `matchedTransitionSource` / `navigationTransition(.zoom)` | **yes** — `pushGlassZoom`, `GlassZoomSource` | med | — | done |
| List insetGrouped | `.listStyle(.insetGrouped)` | **yes** — `GlassListSection` | high | — | platter, separators, header/footer, `glass:` variant |
| List plain | `.listStyle(.plain)` | **yes** — `GlassPlainList`, `GlassPlainListSection` | med | — | measured inset hairlines (16/56 pt), sticky headers, swipe rows, Material path; swipe-open pair in §4 |
| List sidebar | `.listStyle(.sidebar)` | **yes** — `GlassSidebarList` | low | L | iPhone rows compared with SwiftUI; regular rows inside `GlassSplitView` use the measured 320-pt sidebar width; iPhone light and dark compared; fresh expanded iPad pair in §4 |
| Section | `Section` headers/footers | **yes** — `GlassListSection` header/footer | high | — | list context only |
| Form | `Form` | **yes** — `GlassForm` | high | — | done (2839880) |
| DisclosureGroup | `DisclosureGroup` | **yes** — `GlassDisclosureGroup` | high | — | done |
| Swipe actions | `.swipeActions` | **yes** — `GlassSwipeActions` | high | — | leading+trailing, full swipe, rubber-band |
| Pull to refresh | `.refreshable` | **yes** — `GlassRefresh`, `SliverGlassRefresh` | high | — | done |
| GroupBox | `GroupBox` | **yes** — `GlassGroupBox` | low | — | done (2839880) |
| Scroll edge effects | `scrollEdgeEffectStyle` | **yes** — `GlassScrollEdgeStyle` (`uniform`, `progressive`, `hard`, `hidden`) | high | — | `hard`/`hidden` done (748e0c1); progressive needs Impeller |
| Scroll indicators | `.scrollIndicators` | **yes** — `GlassScrollIndicators` / `GlassScrollIndicatorVisibility` | low | — | implemented (71a59a3); iOS 26.4 geometry, minimum length, edge insets, color, hold and fade measured in §4; measured fade hold is ~1.02–1.05 s (`hold_seconds_bounds` in each `summary.json`), and `timeToFade` is set to 1033 ms, inside those bounds |

## 3. Previously ranked gaps — completed

Refreshed 2026-11-13. Every row below has an implementation in this checkout.

| # | gap | public API | status |
|---|---|---|---|
| 1 | Menu sections / submenus / `primaryAction` | `GlassMenuItem.section`, `.submenu`, `GlassMenuButton.primaryAction` | done (5c545cd) |
| 2 | Separate nav-bar pills | `GlassBarItem` | done (9c180ce) |
| 3 | `navigationSubtitle` | nav-bar subtitle | done (748e0c1); screenshots in §4 |
| 4 | `glassEffectTransition` | `GlassTransition` (`matchedGeometry`, `materialize`, `identity`) | done (b1ecfd0 + 43e9eed); visible and hidden comparison captures in §4 |
| 5 | `ControlGroup` | `GlassControlGroup` | done (27d5b95); 4 tests passed; showcase captures in §4 show the same scene (`-twin gapcontrolgroup`); outside a bar it now draws SwiftUI's standalone capsule: 32 pt high, `systemFill` grey, white glyphs (measured from gap-controlgroup-swiftui.png). Remaining: SwiftUI items hug their glyph (about glyph + 22.4 pt), Flutter uses a fixed 34.33 pt per item, so the chevron pair is ~4 pt narrower and B/I/U ~9 pt wider |
| 6 | Scroll edge `hard` / `hidden` | `GlassScrollEdgeStyle.hard` / `.hidden` | done (748e0c1, with 3); scrolled comparison captures in §4. The hard edge's tint is 0.91 opacity and its blur sigma 4 pt, both fitted to gap-edge-hard-swiftui.png: the rows under the edge keep 8.2–8.5% of their ink in Flutter (shader mode) against 8.7–9.0% in SwiftUI. The native path still draws no blur, on purpose (platform-view flicker); the 0.91 tint hides most content there anyway |
| 7 | `NavigationSplitView` | `GlassSplitView`, `GlassSplitViewColumn`, `GlassSplitViewVisibility`, `GlassSplitViewController` | done (064cb32); analyze clean (deprecation infos only), 6 tests passed on the original implementation; refreshed iPad captures in §4. New `GlassSplitViewSidebarButton`: a 26-pt `sidebar.left` glyph, ink 25×19.5 pt as SwiftUI's (was 15.5×12). The detail now sits `TabSidebarMetrics.splitDetailTopInset` (8.33 pt) lower, so its bar title centres 31.0 pt down against SwiftUI's 31.5 (was 22.5). Remaining: the detail body text centres 8 pt higher than SwiftUI's (618.75 vs 626.75 pt); the body's top inset is 54.7 pt and SwiftUI's is about 70 pt, and the cause is not yet isolated |

Also built in parallel (rows updated above): `GlassInspector`,
`GlassSafeAreaBar`, `GlassPageView` (3213048); `GlassPickerStyle.palette`,
`GlassDateRangePicker` (63b3518); `GlassForm`, `GlassGroupBox` (2839880);
`GlassTextEditor`, `GlassScrollIndicators` (71a59a3).


## 4. Visuals (iOS Simulator)

Captured on iOS 26.4 with iPhone 17 Pro and iPad 26.4 simulators; files are in
`docs/superpowers/notes/images/`. Paired captures use the same appearance;
all are full-resolution device captures. Exceptions are noted per row.

| component | image |
|---|---|
| GlassInspector | ![](images/native-inspector-iphone.png) ([video](images/native-inspector-toggle-iphone.mp4)) |
| GlassSafeAreaBar | ![](images/native-safeareabar-iphone.png) |
| GlassPageView | ![](images/native-pagestyle-iphone.png) |
| Picker palette | ![](images/picker-palettestandalone-swiftui.png) ![](images/picker-palettemenu-open-swiftui.png) |
| GlassForm | ![](images/listform-native-form.png) |
| GlassGroupBox | ![](images/listform-native-groupbox.png) |
| Plain list | ![](images/listform-native-plain.png) |
| List sidebar | ![](images/listform-native-sidebar.png) ![](images/listform-twin-sidebar.png) (native, `GlassSidebarList`) |
| Nav subtitle (large) — Flutter / SwiftUI | ![](images/gap-subtitle-flutter.png) ![](images/gap-subtitle-swiftui.png) |
| Navigation split view (iPad) — Flutter / SwiftUI | ![](images/gap-split-flutter.png) ![](images/gap-split-swiftui.png) |
| Sidebar list (dark, Flutter / SwiftUI) | ![](images/gap-sidebar-dark-flutter.png) ![](images/listform-native-sidebardark.png) |
| Hard scroll edge (Flutter `-mode shader` / SwiftUI) | ![](images/gap-edge-hard-flutter.png) ![](images/gap-edge-hard-swiftui.png) |
| Hidden scroll edge (Flutter / SwiftUI) | ![](images/gap-edge-hidden-flutter.png) ![](images/gap-edge-hidden-swiftui.png) |
| Glass transition, visible (Flutter / SwiftUI) | ![](images/gap-transition-flutter.png) ![](images/gap-transition-swiftui.png) |
| Glass transition, hidden (Flutter / SwiftUI) | ![](images/gap-transition-hidden-flutter.png) ![](images/gap-transition-hidden-swiftui.png) |
| Control group (Flutter / SwiftUI) — same scene; item widths differ slightly | ![](images/gap-controlgroup-flutter.png) ![](images/gap-controlgroup-swiftui.png) |
| Sidebar split, iPad light (Flutter / SwiftUI) | ![](images/sidebar-ipad-flutter.png) ![](images/sidebar-ipad-swiftui.png) |
| Sidebar split, iPad dark (Flutter / SwiftUI) | ![](images/sidebar-ipad-dark-flutter.png) ![](images/sidebar-ipad-dark-swiftui.png) |
| Photo navbar pills, light (Flutter / SwiftUI) | ![](images/navbar-pills-photo-flutter.png) ![](images/navbar-pills-photo-swiftui.png) |
| Photo navbar pills, dark (Flutter / SwiftUI) | ![](images/navbar-pills-photo-dark-flutter.png) ![](images/navbar-pills-photo-dark-swiftui.png) |
| Open palette menu, light (Flutter / SwiftUI) | ![](images/palette-menu-open-flutter.png) ![](images/palette-menu-open-swiftui.png) |
| Open palette menu, dark (Flutter / SwiftUI) | ![](images/palette-menu-open-dark-flutter.png) ![](images/palette-menu-open-dark-swiftui.png) |
| Plain list, swipe open (Flutter / SwiftUI) | ![](images/plain-swipe-open-flutter.png) ![](images/plain-swipe-open-swiftui.png) |
| iPhone popover (Flutter / SwiftUI) | ![](images/popover-iphone-flutter.png) ![](images/popover-iphone-swiftui.png) |
| Context menu, standard and tall (Flutter / UIKit) | [captures and measurements](context-menu-parity.md) |
| Scroll indicators, trace light / dark (SwiftUI) | ![](images/scrollindicatorstrace.png) ![](images/scrollindicatorstracedark.png) |
| Scroll indicators, long content / bottom edge (SwiftUI) | ![](images/scrollindicatorslong.png) ![](images/scrollindicators-bottom-swiftui.png) |
| Date wheel, hit-trial baseline (SwiftUI) | ![](images/date-wheel-hit-baseline-swiftui.png) |

The capture target reads `-twin` scenes through the example launch channel.
Use the commands below for the SwiftUI references and the corresponding
`-twin` launch argument for Flutter. `gap_capture.dart` supports `controlgroup`,
`transition`, `split`, and `sidebarsplit` twins. The hard and hidden edge pages use
`-twin hard` and `-twin hidden`.

| Comparison | SwiftUI launch arguments | Flutter launch environment |
|---|---|---|
| Hard scroll edge | `-controls gapedgehard` | `-twin hard` |
| Hidden scroll edge | `-controls gapedgehidden` | `-twin hidden` |
| Glass transition | `-controls gaptransition` | `-twin transition` |
| Control group | `-controls gapcontrolgroup` | `-twin controlgroup` |
| Split view | `-controls gapsplit` | `-twin split` |
| Sidebar split view (iPad) | `-listform sidebarsplit` / `sidebarsplitdark` | `-twin sidebarsplit` / `sidebarsplitdark` |

For scroll edge, drag the content under the bar before taking the
screenshot. For split view, use an iPad and capture the sidebar expanded.

For palette menus and photo-background navbar pills, use the main example
target. Pair `-controls palettemenu` or `palettemenudark` with the same
`-twin` scene and open the menu on both sides. Pair `-controls navbarpills`
and `navbarpillsdark` with their corresponding `-twin` scenes. The saved
flat-gray navbar captures match within one 8-bit RGB level at the capsule
center in both appearances. Photo-background and open-palette comparisons
are shown in §4. Centered menu placement is available on `GlassMenuButton`,
and the palette twin uses it to keep the open menu within the viewport. The
iPad light split/sidebar captures show tint and backdrop differences between
the native and Flutter rendering paths. The iPad dark pair shows the same
tint and backdrop differences.

For wheel and scroll-indicator measurements, launch `-controls datewheeldump`
or `timewheeldump`,
`scrollindicatorstrace`, `scrollindicatorstracedark` or
`scrollindicatorslong`. The bottom-edge trace has no scene of its own: its
folder, `measurements/ios-26.4/scrollindicatorsbottom/`, records
`"scene": "scrollindicatorstrace"` in `run.json`, i.e. the trace scene
dragged to the content end. The app writes the scene name to
`tmp/measurement-scene`, the view frames to `tmp/viewdump.json`, and the
indicator trace to `tmp/indicator-trace` after 20 seconds. Use
`xcrun simctl get_app_container <device> <bundle-id> data` to locate
that directory. Raw traces, view dumps, frame-bracketed summaries and wheel
trial dumps are in `measurements/ios-26.4/`. On iPhone 17 Pro, the vertical
indicator measures 3 pt wide with a 3 pt trailing inset. Its top inset is 3 pt
below the 62 pt safe-area origin, and its bottom inset is 3 pt at the content
end. Its length is 237.67 pt for 60 rows and reaches the 36 pt minimum for
2,000 rows. The light and dark colors match `0x59000000` and `0x80FFFFFF`.
Across light, dark, long-content and bottom-edge traces, the fade begins
1.017–1.050 s (`hold_seconds_bounds`) after the final dragging/deceleration frame and lasts
0.217–0.250 s to opacity 0.001. Date-wheel drag trials place the first date
column boundary between x=204 (column 0) and x=230 pt (column 1) — no trial
falls in between — and the second at x=258 pt and the time-wheel transitions at
x=169 and x=224 pt. Trial starting points on each side and changed UIKit
components are recorded in `datewheel/hit-trials.json`.
