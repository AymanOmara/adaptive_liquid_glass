# adaptive_liquid_glass — Phase 2a: GlassButton and the navigation bar

Status: approved design (2026-10-05). Follows Phase 1 (core material) and
`GlassTabBar`.

## 1. Intent

Ship the two components every iOS 26 screen uses after the tab bar: a glass
button with SwiftUI's full button vocabulary, and the top navigation bar
(inline title, and a large title that collapses on scroll). Same promise as
the rest of the package: one API, SwiftUI's look on iOS, Material 3 on
Android, no platform branching in app code.

### What the user decided

- Toolbar scope: the **top navigation bar** only (bottom toolbar later).
- Title: **large title with collapse**, plus the inline-title bar.
- Button: the **full SwiftUI set** — `glass` and `glassProminent` styles,
  roles, five control sizes, border shapes, disabled and loading states.
- Nav bar shape: **approach A, a sliver pair** — `GlassNavigationBar` (box,
  for `Scaffold.appBar`) and `SliverGlassNavigationBar` (large title, in a
  `CustomScrollView`).

### Success criteria

1. `GlassButton` covers every style × role × size × shape × state below, on
   the shader, native and Material paths, with tests on each.
2. Button metrics (height, padding, font, icon size, corner radius per
   size and shape) are measured from SwiftUI on the reference simulator
   (iPhone 17 Pro, iOS 26.4) and recorded next to the constants.
3. The large title collapses into the inline title with SwiftUI's scroll
   offsets (measured) and stretches on over-scroll.
4. On Android both bars are stock Material 3 (`AppBar`,
   `SliverAppBar.large`) and buttons are stock M3 buttons.
5. RTL: back chevron mirrors, actions sit at the end, large title at the
   start. Semantics: header for the title, buttons for actions.

## 2. Public API

### GlassButton

```dart
GlassButton(
  onPressed: save,                    // null = disabled
  style: GlassButtonStyle.glass,      // .glass | .glassProminent
  role: GlassButtonRole.none,         // .none | .destructive | .cancel
  size: GlassControlSize.regular,     // .mini | .small | .regular | .large | .extraLarge
  shape: GlassButtonShape.automatic,  // .automatic | .capsule | .circle | .roundedRect
  loading: false,
  tint: null,                         // prominent fill; default accent colour
  mode: null,                         // GlassRenderMode override
  child: const Text('Save'),
)

GlassButton.icon(
  icon: Icons.share,                  // IconData
  label: null,                        // optional Widget beside the icon
  onPressed: share,
  // same style / role / size / shape / loading / tint / mode
)
```

- `automatic` shape: circle for icon-only, capsule otherwise (SwiftUI's
  `.automatic` for glass buttons).
- `roundedRect` uses `GlassShape.rect(r)` with `r` measured per size.
- `GlassButton` is built on `LiquidGlass` (shape, glass, padding,
  `onPressed`), so it joins an enclosing `GlassGroup`, morphs with
  `glassId` (exposed as `glassId`), and inherits mode resolution,
  Reduce Transparency/Motion and press visuals. No new rendering code.

### Styles and roles

| | `glass` | `glassProminent` |
|---|---|---|
| none | `Glass.regular.interactive()`, readable label colour | `Glass.regular.tint(tint ?? accent).interactive()`, white label |
| destructive | label `systemRed` | tint `systemRed` |
| cancel | label semibold | label semibold |

Accent = `CupertinoTheme.primaryColor`.

### States

- **Disabled** (`onPressed == null`): content at 50 % opacity, glass not
  interactive, semantics `button + enabled:false` (unlike bare
  `LiquidGlass`, a `GlassButton` is always a button).
- **Loading**: a `CupertinoActivityIndicator` sized to the label's line
  height replaces the content inside an invisible copy of it (no layout
  shift); taps ignored; semantics label gains ", loading"
  (localisable via a `loadingLabel` parameter, default `'loading'`).

### GlassBackButton

Circular glass chevron (`CupertinoIcons.chevron_back`, mirrored in RTL by
the icon itself), `GlassButton.icon` at the bar's size. Default
`onPressed`: `Navigator.maybePop`. Semantics label: `MaterialLocalizations`
/ `CupertinoLocalizations` "Back" when available, else `'Back'`.

### GlassNavigationBar (inline)

```dart
GlassNavigationBar(
  title: const Text('Inbox'),
  leading: null,            // default: GlassBackButton when the route can pop
  automaticallyImplyLeading: true,
  actions: [GlassButton.icon(...), GlassButton.icon(...)],
  mode: null,
)
```

`implements PreferredSizeWidget` (height measured; ~ 54 + top safe area).
Use with `Scaffold(extendBodyBehindAppBar: true)` so content scrolls under
it, as on iOS 26.

### SliverGlassNavigationBar (large title)

```dart
CustomScrollView(slivers: [
  SliverGlassNavigationBar(
    largeTitle: const Text('Inbox'),
    title: null,            // inline title; defaults to largeTitle's text
    leading: null,
    actions: [...],
  ),
  SliverList(...),
])
```

## 3. Layout and behaviour (iOS paths)

- **No bar background.** iOS 26 bars are transparent; only the controls
  are glass. A **scroll edge effect** — a top gradient of the page
  background (from `CupertinoTheme.scaffoldBackgroundColor`) fading to
  transparent, ~ the bar's height — keeps the title readable over
  content. Shown only when content is under the bar (scroll offset > 0).
- **Leading**: back button (circle). **Trailing**: `actions` inside one
  `GlassGroup(spacing: <gap>)` with a shared `unionId`, so they draw as one
  capsule (iOS's grouped bar buttons). A single action is a circle.
- **Inline title**: centred, 17 pt semibold, plain text (not on glass),
  `Semantics(header: true)`.
- **Large title** (sliver): 34 pt bold, leading-aligned below the bar.
  As the page scrolls the large title scrolls up under the bar; when its
  baseline passes under the bar the inline title fades in (measured
  offset and fade distance). Over-scroll (pull down) scales the large
  title up from its leading edge, as iOS does. Implemented as a pinned
  `SliverPersistentHeader` with a custom delegate (min = bar height,
  max = bar + large-title height).
- **Metrics** (bar height, button size and gaps, title fonts, collapse
  offsets) are measured from a SwiftUI reference screen in the example's
  SwiftUI renderer (`NavigationStack` + `.toolbar` +
  `.navigationTitle(...)` with `.large` and `.inline` display modes).

## 4. Material path (Android by default)

| Package | Material 3 |
|---|---|
| `GlassButton` glass | `FilledButton.tonal` |
| `GlassButton` glassProminent | `FilledButton` (`tint` → `backgroundColor`) |
| icon-only | `IconButton.filledTonal` / `IconButton.filled` |
| destructive | `error` / `onError` colours |
| cancel | `TextButton` |
| sizes | mini 32, small 36, regular 40, large 48, extraLarge 56 dp heights |
| loading | `CircularProgressIndicator` (strokeWidth 2) in place of content |
| `GlassNavigationBar` | `AppBar` (actions as `IconButton`s, `BackButton`) |
| `SliverGlassNavigationBar` | `SliverAppBar.large` |
| `GlassBackButton` | `BackButton` |

Mode resolution is the existing `resolveGlassMode`; the components pick the
Material widgets when it resolves to `material`.

## 5. Files

```
lib/src/button/glass_button.dart          GlassButton, enums
lib/src/button/glass_button_metrics.dart        measured per-size metrics
lib/src/button/material_button.dart       Material mapping
lib/src/navigation/glass_back_button.dart
lib/src/navigation/glass_navigation_bar.dart
lib/src/navigation/sliver_glass_navigation_bar.dart
lib/src/navigation/nav_bar_metrics.dart
lib/src/navigation/glass_scroll_edge.dart       scroll edge effect
test/button/…, test/navigation/…
example/ios/Runner/…                       SwiftUI reference screens
```

Barrel exports the public types only.

## 6. Testing

- Widget tests per style × role × size × state on `ios` (shader) and
  `android` (Material) variants; native-path build smoke test.
- Semantics: button, enabled/disabled, loading label, header title.
- Nav bar: back button appears only when the route can pop; actions merge
  into one group; RTL placement; scroll drives the inline-title fade and
  the large-title collapse; over-scroll stretch.
- Simulator check on iOS 18.1 (shader) and iOS 26.4 (native) via the
  example gallery; metrics recorded against the SwiftUI reference.

## 7. Non-goals

- Bottom toolbar, search field in the bar, menus from bar buttons (later
  phases).
- `GlassNavigationScaffold` (could wrap this later).
- Matching SwiftUI's nav bar push/pop transition.

## 8. Risks

- Native glass buttons inside a scrolling header: platform views in a
  pinned sliver must track scroll every frame (existing scroll chain in
  `lib/src/group/scroll_chain.dart` covers enclosing scrollables; verify a
  pinned header).
- Large-title metrics depend on Dynamic Type; measure at the default size
  and scale with `MediaQuery.textScaler`.
