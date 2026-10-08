# iOS 26 component gap analysis

Branch `docs/component-gap`, Oct 2026. Inventory taken from
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
- **Controls**: `GlassToggle`, `GlassSlider`, `GlassSegmentedControl`,
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
| Bordered / borderless / plain | `.bordered`, `.borderless`, `.plain` | **no** | med | S | iOS 26 defaults most bars to glass; plain styles only matter for dense content rows |
| Button role | `.destructive` / `.cancel` | **yes** — `GlassButtonRole` | high | — | |
| Control size | `.controlSize(_:)` | **yes** — `GlassControlSize` + `GlassControlSizeScope` | med | — | `mini`→small, `extraLarge`→large collapse |
| Label | `Label(_:systemImage:)` | **partial** — `GlassListTile` leading / `GlassButton.icon` | high | S | no standalone icon+title text widget with vibrant label styling (`GlassLabelStyle` is internal) |
| Link | `Link(destination:)` | **no** | med | S | url_launcher wrapper in glass capsule |
| Share link | `ShareLink(item:)` | **no** | med | S | native share sheet via `share_plus`; glass pill trigger |
| PhotosPicker | `PhotosPicker` (PhotosUI) | **no** | low | L | needs platform plugin + asset transfer |
| Keyboard toolbar | `ToolbarItem(placement: .keyboard)` | **no** | med | M | glass accessory bar above keyboard (done/next); measure vs iOS 26 quick-type bar glass |
| ToolbarSpacer | `ToolbarSpacer(.flexible)` | **yes** — `GlassToolbarSpacer` | med | — | bottom toolbar only |

### Controls

| component | SwiftUI API | we have? | common | effort | notes |
|---|---|---|---|---|---|
| Toggle | `Toggle` | **yes** — `GlassToggle` | high | — | tap + drag thumb |
| Slider | `Slider` | **yes** — `GlassSlider` | high | — | filled track, divisions+haptics; no vertical, no range/two-thumb |
| Stepper | `Stepper` | **yes** — `GlassStepper` | med | — | configurable `step`; no custom increment/decrement builders |
| Gauge | `Gauge` | **no** | med | S | start with linear + accessoryCircular styles |
| ColorPicker | `ColorPicker` | **no** | med | S | HSV wheel + hex/rgb rows in glass sheet; measure vs iOS 26 picker sheet |

### Pickers

| component | SwiftUI API | we have? | common | effort | notes |
|---|---|---|---|---|---|
| Menu picker | `.pickerStyle(.menu)` | **yes** — `GlassPicker` | high | — | checkmark menu, accent value |
| Segmented | `.pickerStyle(.segmented)` | **partial** — `GlassSegmentedControl` | high | S | standalone widget, not a `GlassPicker` style; UX parity already good |
| Wheel | `.pickerStyle(.wheel)` | **no** | med | M | `CupertinoPicker` under glass + selection lens |
| Inline | `.pickerStyle(.inline)` | **no** | med | S | compose from `GlassListTile` + value + chevron |
| NavigationLink | `.pickerStyle(.navigationLink)` | **no** | med | S | same row composition, pushes detail list |
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
| Empty/error state | `ContentUnavailableView` | **no** | high | S | icon/title/description/actions; very common |
| TipKit | `Tip` / `.popoverTip` | **no** | low | M | verify: liquid-glass restyle of tips in 26; needs persistence + rules plumbing |
| Toast | no SwiftUI API | **yes** — `showGlassToast` (beyond SwiftUI) | med | — | swipe-dismiss, queue, actions |
| Page control | UIKit `UIPageControl` | **yes** — `GlassPageControl` | med | — | tap halves, scrub, haptics |

### Menus & overlays

| component | SwiftUI API | we have? | common | effort | notes |
|---|---|---|---|---|---|
| Menu | `Menu` pull-down | **yes** — `GlassMenuButton` | high | — | flat items only; no submenus/sections; glide via `GlassMenuController` |
| Context menu | `.contextMenu` | **partial** — `GlassContextMenu` | med | M | works (lifted preview + glass menu) but "not measured against SwiftUI" per doc comment |
| Popover | `.popover` | **yes** — `showGlassPopover` / `GlassPopoverAnchor` | med | — | iPhone bubble, no arrow, undimmed; verify: iOS 26 popover-on-iPhone behavior we should re-measure |
| Alert | `.alert` | **yes** — `showGlassAlert` | high | — | |
| Confirmation dialog | `.confirmationDialog` | **yes** — `showGlassConfirmationDialog` | high | — | tap-outside = cancel |
| Action sheet | UIKit `UIAlertController` action sheet | **yes** — `showGlassActionSheet` | med | — | |
| Sheet + detents | `.sheet` + `.presentationDetents` | **yes** — `showGlassSheet` / `GlassSheetDetent` | high | — | medium/large/fraction/height, grabber |
| Full-screen cover | `.fullScreenCover` | **no** | med | S | edge-to-edge modal, no detents, optional drag-dismiss |
| Inspector | `Inspector` (iOS 17+) | **no** | low | L | trailing detail pane; iPad-pattern mostly |
| Glass effect container | `GlassEffectContainer` | **yes** — `GlassGroup` | high | — | spacing merge, shared backdrop |
| Glass union | `glassEffectUnion` | **yes** — `LiquidGlass.unionId` | med | — | per-member |
| Glass morph | `glassEffectID` | **yes** — `LiquidGlass.glassId` | med | — | hero morph inside group |

### Navigation & layout

| component | SwiftUI API | we have? | common | effort | notes |
|---|---|---|---|---|---|
| Inline nav bar | `NavigationStack` bar | **yes** — `GlassNavigationBar` | high | — | leading auto-back, merged actions |
| Large title | large title + collapse | **yes** — `SliverGlassNavigationBar` | high | — | scroll fade-in, pull stretch |
| Bar items | `ToolbarItem` in nav bar | **partial** — `GlassNavigationBar.actions` | high | M | we merge actions into one capsule; verify iOS 26 separate pills vs shared capsule per placement |
| Bottom toolbar/bottom bar | `.toolbar` bottom bar | **yes** — `GlassToolbar` | med | — | floating capsules, spacers, no top placement |
| safeAreaBar | `.safeAreaBar` (verify) | **partial** — `GlassScaffold` bar slots | low | S | scaffold covers nav/tab/toolbar/accessory; no generic modifier |
| Bottom accessory | `.tabBarBottomAccessory` (verify name) | **yes** — `GlassBottomAccessory` | med | — | Music mini-player pattern |
| Tab bar | `TabView` tab bar | **yes** — `GlassTabBar` | high | — | lens press, drag, badges, search tab |
| Sidebar adaptable | `TabView` `.sidebarAdaptable` | **no** | med | L | sidebar + tab bar + search in one adaptive container |
| Tab bar minimize | `.tabBarMinimizeBehavior` (verify) | **no** | med | M | scroll-linked shrink to lens |
| Page style | `TabView` `.page` style | **partial** — `GlassPageControl` + `PageView` | med | S | dots exist; no page container wiring |
| Zoom transition | `matchedTransitionSource` / `navigationTransition(.zoom)` | **no** | med | L | hero zoom into detail; Flutter route hero work |
| List insetGrouped | `.listStyle(.insetGrouped)` | **yes** — `GlassListSection` | high | — | platter, separators, header/footer, `glass:` variant |
| List plain | `.listStyle(.plain)` | **partial** — plain `ListView` | med | S | no glass separators/swipe integration tuned for plain |
| List sidebar | `.listStyle(.sidebar)` | **no** | low | L | tied to sidebarAdaptable |
| Section | `Section` headers/footers | **yes** — `GlassListSection` header/footer | high | — | list context only |
| Form | `Form` | **partial** — `GlassListSection` composition | high | S | rows compose well; no dedicated form container (keyboard avoidance, grouped sections API) |
| DisclosureGroup | `DisclosureGroup` | **no** | high | S | expandable rows in settings lists |
| Swipe actions | `.swipeActions` | **yes** — `GlassSwipeActions` | high | — | leading+trailing, full swipe, rubber-band |
| Pull to refresh | `.refreshable` | **no** | high | M | glass spinner, threshold, haptic |
| GroupBox | `GroupBox` | **partial** — `GlassListSection(glass:)` | low | S | labelled glass platter covers most uses |
| Scroll edge effects | `scrollEdgeEffectStyle` (verify name) | **partial** — `GlassScrollEdgeStyle` | high | M | uniform + progressive; progressive needs Impeller, no blur on native path |
| Scroll indicators | `.scrollIndicators` | **no** | low | S | thin overlay indicator; Flutter default usually fine |

## 3. Build next (top 8, value ÷ effort)

1. **GlassDisclosureGroup** — *S, high value.* `GlassDisclosureGroup({label, content, isExpanded, onExpansionChanged})` wrapping `GlassListTile`; rotating chevron, section-height spring (matching our sheet/segment springs). Material: `ExpansionTile`. Measure against Settings.app grouped disclosure and SwiftUI `DisclosureGroup` spring curve.
2. **showGlassRefresh / .refreshable** — *M, high value.* Sliver + box wrapper: overscroll drives a glass `GlassProgressIndicator(circular)` that morphs from arrow to spinner at threshold, haptic on trigger, `onRefresh` Future. Material: `RefreshIndicator` underneath. Measure against iOS 26 Mail refresh: trigger distance, spinner scale/blur, snap-back.
3. **GlassSearchable presentation** — *M, high value.* `GlassScaffold.searchable(field | controller)` — field expands into nav-bar slot with Cancel, suggestion rows on glass, optional scopes as chips. Material: `SearchAnchor`. Measure against iOS 26 `searchable`: field collapse/expand spring, cancel button placement, suggestion row metrics.
4. **GlassEmptyState** (ContentUnavailableView) — *S, high value.* `GlassEmptyState({icon, title, description, actions})` centered on optional glass platter; actions row of `GlassButton`s. Material: `Card`-free plain column. Measure against SwiftUI `ContentUnavailableView` label spacing and_actions layout.
5. **showGlassFullScreenCover** — *S, med-high value.* `showGlassFullScreenCover(context, builder)` — opaque edge-to-edge route, status-bar aware, optional drag-to-dismiss from top, glass close `GlassBackButton`. Material: `Dialog.fullscreen`. Measure against `.fullScreenCover` transition timing.
6. **GlassGauge** — *S, med value.* `GlassGauge({value, minValue, maxValue, label, currentValueLabel, tint})` with `linear` and `circular` styles on a glass capsule track. Material: styled `LinearProgressIndicator`/custom. Measure against SwiftUI `Gauge(.accessoryCircular)` ring thickness, label placement.
7. ~~**GlassDatePicker upgrades**~~ — done (styles, modes, `GlassCalendar`/`GlassDateWheel` exported; wheel and time geometry estimated, not measured). *M, med value.* Export internal `GlassCalendar` as standalone graphical picker; add `.hourAndMinute` time rows and wheel variant reusing the new `GlassWheelPicker`. Material: `showDatePicker`/`showTimePicker`. Measure against iOS 26 compact→graphical popover and wheel picker perspective.
8. **GlassWheelPicker** — *M, med value.* `GlassWheelPicker<T>({items, selected, onChanged, itemExtent})` — `CupertinoPicker` in a glass capsule with a clear-glass selection lens band and haptics; also serves as `GlassPicker(wheel)` style. Material: dialog wheel fallback. Measure against iOS wheel picker: row perspective, lens blur depth, haptic cadence.

Honorable mentions (next after the 8): keyboard toolbar (M), `GlassShareLink` (S),
picker `.inline`/`.navigationLink` row compositions (S), nav-bar separate
action pills (verify first), `tabBarMinimizeBehavior` (M), sidebarAdaptable (L),
zoom transitions (L), TipKit tips (M), `GlassColorPicker` (S), `PhotosPicker` (L).
