# Usability audit (2026-10-14, before 1.0)

TODO item 3: what the barrel exports, which defaults are missing, which
names disagree, and where a common task takes more than one widget. Done in
this pass is marked **done**; the rest are 1.0 candidates, each with the
reason it was not done now. Rule for this pass: additive only, old names
kept as `@Deprecated` aliases, no behaviour or fidelity change.

## Exports

`lib/adaptive_liquid_glass.dart` had 108 export directives; 105 now
(plus `RangeValues` from Flutter). `lib/testing.dart` is a second library
(`GlassConstants`, motion and variant constants) and is not counted.

### Core public: what most apps use

`LiquidGlass`, `GlassEffect` (`.glassEffect`), `Glass`, `GlassShape`,
`GlassGroup`, `AdaptiveLiquidGlass`, `GlassButton`, `GlassButtonRole`,
`GlassButtonStyle`, `GlassFloatingActionButton`, `GlassBackButton`,
`GlassScaffold`, `GlassNavigationBar`, `SliverGlassNavigationBar`,
`GlassTabBar`, `GlassTabBarItem`, `GlassToolbar`, `GlassToolbarSpacer`,
`GlassToggle`, `GlassSlider`, `GlassSegmentedControl`, `GlassSegment`,
`GlassStepper`, `GlassPicker`, `GlassPickerItem`, `GlassDatePicker`,
`GlassMenuButton`, `GlassMenuItem`, `GlassContextMenu`, `showGlassAlert`,
`showGlassConfirmationDialog`, `showGlassActionSheet`, `GlassDialogAction`,
`showGlassSheet`, `GlassSheetDetent`, `showGlassToast`, `GlassToastAction`,
`GlassTextField`, `GlassSearchField`, `GlassSearchable`,
`GlassSearchSuggestion`, `GlassListSection`, `GlassListTile`, `GlassChip`,
`GlassBadge`, `GlassProgressIndicator`, `GlassActivityIndicator`,
`GlassEmptyState`, `GlassRefresh`.

### Advanced: public, less common

- Theming and paths: `LiquidGlassTheme`, `LiquidGlassThemeData`,
  `GlassRenderMode`, `GlassAdaptive`, `GlassVariant` (type of
  `Glass.variant`), `GlassSystemColors`.
- Options of core widgets: `GlassButtonShape`, `GlassControlSize`,
  `GlassControlSizeScope`, `GlassDatePickerMode`, `GlassDatePickerStyle`,
  `GlassPickerStyle`, `GlassProgressStyle`, `GlassGaugeStyle`,
  `GlassLabelLayout`, `GlassScrollEdgeStyle`, `GlassSearchablePlacement`,
  `GlassMaterialTabBarStyle`, `GlassTabBarStyle`,
  `GlassTabBarMinimizeBehavior`, `GlassPhotosPickerFilter`.
- Handles and controllers returned or taken by core API:
  `GlassToastHandle`, `GlassFullScreenCoverHandle`, `GlassMenuController`,
  `GlassSearchController`.
- Less common components: `GlassRangeSlider`, `GlassWheelPicker`,
  `GlassDateWheel`, `GlassCalendar`, `GlassPopoverAnchor`,
  `showGlassPopover`, `showGlassFullScreenCover`, `GlassSheet`,
  `GlassDisclosureGroup`, `GlassGauge`, `GlassPageControl`, `GlassLabel`,
  `GlassLink`, `GlassShareLink`, `GlassColorPicker`, `GlassPhotosPicker`,
  `GlassPickedPhoto`, `pickGlassPhotos`, `clearGlassPickedPhotos`,
  `GlassSwipeActions`, `GlassSwipeAction`, `GlassSymbol`,
  `GlassLargeTitleScrollView`, `GlassBottomAccessory`,
  `SliverGlassRefresh`.
- Label colour helpers: `GlassBackdropSource`, `GlassForeground` (kept on
  purpose, refactor-backlog P3-6).

### Should be internal

- **done**: `DatePickerMetrics`, `DatePickerWheelMetrics`,
  `WheelPickerMetrics` (measured constants; no public API takes them, not
  in README or example; `MenuMetrics` and the rest were never exported),
  and `pressableGlass` (documented "Internal.", leaked by the unfiltered
  `glass.dart` export).
- 1.0 candidates, not hidden now because each class documents standalone
  use with its own example, so an app may use it:
  - `GlassRefreshIndicator`: "rarely built directly"; the refresh widgets
    build it.
  - `GlassSearchSuggestionRow`, `SearchCancelButton`: the pieces
    `GlassSearchable` draws.
  - `GlassLabelStyle`: the colouring `GlassForeground` applies; only
    useful with `GlassForeground.labelColorOf`.
- 1.0 decision: `LiquidGlassThemeData(constants:)` takes `GlassConstants`,
  which only `testing.dart` exports. Either the parameter moves to the
  testing library or the type joins the main one.

## Required parameters that could have defaults

- **done** `GlassMenuButton.icon` and `semanticLabel`: default to
  `CupertinoIcons.ellipsis` and 'More' (SwiftUI's usual "More" menu; the
  package already defaults other labels in English).
- **done** `showGlassAlert(actions:)`: defaults to one OK button with the
  localised `okButtonLabel`, as SwiftUI's `.alert` adds OK when it has no
  actions.
- 1.0 candidate: `firstDate` / `lastDate` on `GlassDatePicker`,
  `GlassDateWheel`, `GlassCalendar` (SwiftUI's `DatePicker` needs no
  range). Not done: the `.dateAndTime` wheel builds one row per day of the
  range eagerly, so a wide default (1900-2100, ~73k rows) would be slow;
  the wheel needs lazy rows first.
- Kept required, deliberately: `GlassColorPicker.label` (SwiftUI's
  `ColorPicker` has a title too), `GlassLink.onOpen` /
  `GlassShareLink.onShare` (the package opens no URL or share sheet),
  `GlassButton.onPressed` (required-nullable, Flutter's convention).

## Names that disagree

- **done** accent colour: `tint` on every control, as SwiftUI's `.tint`.
  Was `activeColor` (`GlassToggle`, `GlassSlider`, `GlassRangeSlider`),
  `color` (`GlassProgressIndicator`, `GlassPicker`), `selectedColor`
  (`GlassChip`, `GlassTabBar`); `tint` already on `GlassButton`, FAB,
  links, photos picker and `GlassGauge`. Old names are deprecated aliases
  (constructor parameter and getter) until 1.0. `color` stays where the
  widget is one colour (`GlassActivityIndicator`, `GlassRefresh`,
  `GlassBadge`, `GlassLabel`), with `textColor` and `indicatorColor` for
  second colours.
- **done** setup: `LiquidGlass.precache()` deprecated for
  `AdaptiveLiquidGlass.initialize()`, the one setup call.
- 1.0 candidate, selection value: `value` (`GlassToggle`, `GlassSlider`,
  `GlassStepper`, `GlassDatePicker`, `GlassDateWheel`, `GlassColorPicker`,
  `GlassGauge`, `GlassProgressIndicator`) vs `selected`
  (`GlassSegmentedControl`, `GlassPicker`, `GlassWheelPicker`,
  `GlassCalendar`). Proposal: `value` / `onChanged` on all four
  (`GlassCalendar` also has `onSelected`); keep `selectedIndex`
  (`GlassTabBar`, as `NavigationBar`) and `currentPage` (`GlassPageControl`,
  as `PageView`). Not done: `selected` is required on generic widgets; an
  alias makes both names optional, and with a nullable `T` a missing value
  would only be caught at run time.
- 1.0 candidate, `onSelected` means four things: `VoidCallback`
  (`GlassMenuItem`, `GlassSearchSuggestion`), `ValueChanged<bool>`
  (`GlassChip`, as `FilterChip`), `ValueChanged<int>` (`GlassTabBar`),
  `ValueChanged<DateTime>` (`GlassCalendar`). Proposal:
  `GlassMenuItem.onPressed` (as `MenuItemButton`). Not done: required
  non-null today; an alias would make it optional and a null item a new
  state. `GlassListTile.onTap` stays (as `ListTile`).
- 1.0 candidate: `showGlassToast(context, ...)` takes `context`
  positionally; every other `show*` takes `context:` named. A parameter
  cannot be both, so this needs the 1.0 break.
- 1.0 decision: `Glass.frosted` and `Glass.crystal` are aliases of
  `regular` and `clear`; two names for one material double what 1.0
  freezes.
- Consistent already: `glass:` is the `Glass` of a surface everywhere,
  `style:` a layout enum, `mode:` the render path, `semanticLabel:` the
  accessible name. Odd one out: `GlassWheelPicker.surface` (bool), fine as
  is.

## Tasks that take more than one widget or boilerplate

- **done** setup: `WidgetsFlutterBinding.ensureInitialized()` before
  `initialize()` is gone; `initialize()` does it.
- 1.0 candidate, iOS look on Android: `initialize(mode: shader)` and the
  theme's `defaultMode: shader` must agree, two places for one choice.
  Not done: making `initialize(mode:)` set the app-wide mode changes what
  an existing call does (an app may preload for one subtree only).
- Candidate (new widget): a tabbed app is `GlassScaffold(tabBar:)` plus
  index state plus an `IndexedStack` of bodies; a `GlassTabView` (SwiftUI's
  `TabView`) keeping each tab's state would make it one widget.
- `GlassScaffold` body content must read `MediaQuery.paddingOf` below the
  scaffold (a `Builder`, see `example/lib/quick_start.dart`) to clear the
  floating bars, as `Scaffold(extendBody: true)` does. Worth a README line
  or a `GlassScaffold` padding helper.
- Repeated glass (chips, rows) needs one `GlassGroup` around it or each
  hosts its own native view on iOS 26; documented, with a debug warning.
- README "A group of buttons" builds circular buttons from `LiquidGlass`
  (shape, padding, onPressed, icon); `GlassButton.icon` does the same with
  an accessible label. Kept, as the section teaches `LiquidGlass`.

## The 5-minute path

Before: add the dependency; read "Quick start" (Install, Setup, One line,
Group, Theming, Android: six subsections before a runnable app);
`main()` with `WidgetsFlutterBinding.ensureInitialized()` and
`initialize()`; `.glassEffect(...)` as the first widget; for a real screen,
open `example/lib/quick_start.dart`. The "Which widget?" table missed
`GlassLabel`, `GlassLink`, `GlassShareLink`, `GlassColorPicker`,
`GlassRefresh`, `SliverGlassRefresh` and `GlassSymbol`.

After (**done**): "Getting started" is the dependency and one runnable
snippet: one import, one optional `initialize()`, a `GlassButton` opening
`showGlassAlert` with its default OK. The table lists every component.
