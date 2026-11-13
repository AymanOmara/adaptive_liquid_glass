# iOS 26 component gap analysis

Branch `docs/component-gap`, Oct 2026; refreshed Nov 2026. Inventory taken from
`lib/adaptive_liquid_glass.dart` (64 exported files) read against the iOS 26
SwiftUI/UIKit control and container catalogue. No code changed.

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
| Palette | `.pickerStyle(.palette)` | **no** | low | M | verify: macOS-only in SwiftUI; iOS 26 status unclear |
| Date compact | `.datePickerStyle(.compact)` | **yes** — `GlassDatePicker` | med | — | capsule → glass calendar popover |
| Date graphical | `.datePickerStyle(.graphical)` | **yes** — `GlassDatePicker(style: graphical)`, `GlassCalendar` exported | med | — | inline calendar, `showWeekNumbers`; geometry estimated |
| Date wheel | `.datePickerStyle(.wheel)` | **yes** — `GlassDatePicker(style: wheel)`, `GlassDateWheel` | med | — | columns on one surface; geometry estimated, not measured |
| Time / range | `hourAndMinute`, `DateRange` graph | **partial** — `pickerMode: time` / `dateAndTime` | med | S | time capsule → wheel popover; no range selection |

### Text & search

| component | SwiftUI API | we have? | common | effort | notes |
|---|---|---|---|---|---|
| TextField | `TextField` | **yes** — `GlassTextField` | high | — | prefix/suffix, clear, error, autofill |
| SecureField | `SecureField` | **yes** — `GlassTextField.password` | med | — | eye reveal |
| TextEditor | `TextEditor` | **partial** — `GlassTextField` multiline | med | S | multiline field exists; no dedicated scrollable editor with inset glass chrome |
| Searchable | `.searchable` + scopes/suggestions | **yes** — `GlassSearchable` + `GlassSearchController` | high | — | Cancel spring, suggestion platter, scopes, `navigationBar`/`bottom` placement; geometry estimated, not measured |
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
| Menu | `Menu` pull-down | **partial** — `GlassMenuButton` | high | M | flat items only; no sections/submenus/`primaryAction` (in progress, see §3); glide via `GlassMenuController` |
| Context menu | `.contextMenu` | **partial** — `GlassContextMenu` | med | M | works (lifted preview + glass menu) but "not measured against SwiftUI" per doc comment |
| Popover | `.popover` | **yes** — `showGlassPopover` / `GlassPopoverAnchor` | med | — | iPhone bubble, no arrow, undimmed; verify: iOS 26 popover-on-iPhone behavior we should re-measure |
| Alert | `.alert` | **yes** — `showGlassAlert` | high | — | |
| Confirmation dialog | `.confirmationDialog` | **yes** — `showGlassConfirmationDialog` | high | — | tap-outside = cancel |
| Action sheet | UIKit `UIAlertController` action sheet | **yes** — `showGlassActionSheet` | med | — | |
| Sheet + detents | `.sheet` + `.presentationDetents` | **yes** — `showGlassSheet` / `GlassSheetDetent` | high | — | medium/large/fraction/height, grabber |
| Full-screen cover | `.fullScreenCover` | **yes** — `showGlassFullScreenCover` | med | — | done (`GlassFullScreenCoverHandle`, drag configuration) |
| Inspector | `Inspector` (iOS 17+) | **no** | low | L | trailing detail pane; iPad-pattern mostly |
| Glass effect container | `GlassEffectContainer` | **yes** — `GlassGroup` | high | — | spacing merge, shared backdrop |
| Glass union | `glassEffectUnion` | **yes** — `LiquidGlass.unionId` | med | — | per-member |
| Glass morph | `glassEffectID` | **yes** — `LiquidGlass.glassId` | med | — | hero morph inside group |

### Navigation & layout

| component | SwiftUI API | we have? | common | effort | notes |
|---|---|---|---|---|---|
| Inline nav bar | `NavigationStack` bar | **yes** — `GlassNavigationBar` | high | — | leading auto-back, merged actions |
| Large title | large title + collapse | **yes** — `SliverGlassNavigationBar` | high | — | scroll fade-in, pull stretch |
| Bar items | `ToolbarItem` in nav bar | **partial** — `GlassNavigationBar.actions` | high | M | we merge actions into one capsule; separate pills (`ToolbarItemGroup`, `sharedBackgroundVisibility`) in progress, see §3 |
| Bottom toolbar/bottom bar | `.toolbar` bottom bar | **yes** — `GlassToolbar` | med | — | floating capsules, spacers, no top placement |
| safeAreaBar | `.safeAreaBar` (verify) | **partial** — `GlassScaffold` bar slots | low | S | scaffold covers nav/tab/toolbar/accessory; no generic modifier |
| Bottom accessory | `.tabBarBottomAccessory` (verify name) | **yes** — `GlassBottomAccessory` | med | — | Music mini-player pattern |
| Tab bar | `TabView` tab bar | **yes** — `GlassTabBar` | high | — | lens press, drag, badges, search tab |
| Sidebar adaptable | `TabView` `.sidebarAdaptable` | **yes** — `GlassTabBarStyle.sidebarAdaptable` (via `GlassScaffold`) | med | — | done; `GlassTabSidebar` is internal |
| Tab bar minimize | `.tabBarMinimizeBehavior` | **yes** — `GlassTabBar.minimizeBehavior` / `GlassTabBarMinimizeBehavior` | med | — | done |
| Page style | `TabView` `.page` style | **partial** — `GlassPageControl` + `PageView` | med | S | dots exist; no page container wiring |
| Zoom transition | `matchedTransitionSource` / `navigationTransition(.zoom)` | **yes** — `pushGlassZoom`, `GlassZoomSource` | med | — | done |
| List insetGrouped | `.listStyle(.insetGrouped)` | **yes** — `GlassListSection` | high | — | platter, separators, header/footer, `glass:` variant |
| List plain | `.listStyle(.plain)` | **partial** — plain `ListView` | med | S | no glass separators/swipe integration tuned for plain |
| List sidebar | `.listStyle(.sidebar)` | **no** | low | L | tied to sidebarAdaptable |
| Section | `Section` headers/footers | **yes** — `GlassListSection` header/footer | high | — | list context only |
| Form | `Form` | **partial** — `GlassListSection` composition | high | S | rows compose well; no dedicated form container (keyboard avoidance, grouped sections API) |
| DisclosureGroup | `DisclosureGroup` | **yes** — `GlassDisclosureGroup` | high | — | done |
| Swipe actions | `.swipeActions` | **yes** — `GlassSwipeActions` | high | — | leading+trailing, full swipe, rubber-band |
| Pull to refresh | `.refreshable` | **yes** — `GlassRefresh`, `SliverGlassRefresh` | high | — | done |
| GroupBox | `GroupBox` | **partial** — `GlassListSection(glass:)` | low | S | labelled glass platter covers most uses |
| Scroll edge effects | `scrollEdgeEffectStyle` (verify name) | **partial** — `GlassScrollEdgeStyle` | high | M | uniform + progressive; progressive needs Impeller, no blur on native path |
| Scroll indicators | `.scrollIndicators` | **no** | low | S | thin overlay indicator; Flutter default usually fine |

## 3. Remaining gaps (ranked)

Refreshed 2026-11-09 against `lib/adaptive_liquid_glass.dart`. Done since the
Oct 2026 pass, with public API: `GlassLabel`, `GlassLink`/`GlassShareLink`,
`GlassGauge`, `GlassColorPicker`, `GlassWheelPicker`, `GlassPickerStyle`
(`menu`/`inline`/`navigationLink`), `GlassEmptyState`,
`showGlassFullScreenCover`, `GlassDisclosureGroup`, `GlassRefresh` /
`SliverGlassRefresh`, `GlassTabBar.minimizeBehavior` and
`GlassTabBarStyle.sidebarAdaptable`, `GlassKeyboardToolbar`, `pushGlassZoom`,
and TipKit tips (`GlassTipView`, `GlassPopoverTip`, `GlassTipController`).
Also done earlier: `GlassSearchable`, `GlassDatePicker` styles, `PhotosPicker`.

Next, ranked:

1. **Menu sections / submenus / `primaryAction`** — M, high. *In progress in another session.* `GlassMenuButton` is flat items only.
2. **Separate nav-bar pills** (`ToolbarItemGroup`, `sharedBackgroundVisibility`) — M, high. *In progress in another session.* Actions currently merge into one capsule.
3. **`navigationSubtitle`** — S, med.
4. ~~**`glassEffectTransition`**~~ — done: `GlassTransition` (`matchedGeometry`, `materialize`, `identity`) on `LiquidGlass(transition:)` / `.glassEffect`.
5. **`ControlGroup`** — S, low-med.
6. **Scroll edge `hard` / `hidden`** — S, med. `GlassScrollEdgeStyle` has only `uniform` and `progressive`.
7. **`NavigationSplitView`** — L, med (iPad pattern).

Other open rows in the tables above: `List sidebar`, `Inspector`, `Palette`
picker, `Form` container, plain-list glass separators, `Scroll indicators`.
