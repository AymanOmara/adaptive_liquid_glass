# adaptive_liquid_glass

**Flutter Liquid Glass**: iOS 26 Liquid Glass for Flutter, measured against
SwiftUI, with Material 3 counterparts on Android, behind one API. App code never branches on platform.

- **iOS 26+:** SwiftUI's own Liquid Glass, pixel-identical to a SwiftUI app.
- **Older iOS:** a fragment-shader glass tuned to SwiftUI's.
- **Android:** a Material 3 surface (colours from your `Theme`, ink ripple
  for interactive glass). No glass code runs.
- **RTL-safe:** directional insets throughout; the light angle is not
  mirrored, matching iOS.

How it was built and measured:
[I Measured Apple's Liquid Glass Against SwiftUI, Pixel by Pixel — and Brought It to Flutter](https://medium.com/@aymanomara55/i-measured-apples-liquid-glass-against-swiftui-pixel-by-pixel-and-brought-it-to-flutter-3ba425455f63)
on Medium.

<p align="center">
  <img src="https://raw.githubusercontent.com/AymanOmara/adaptive_liquid_glass/main/screenshots/demo.gif" width="300" alt="Adaptive Liquid Glass demo on iOS 26" />
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/AymanOmara/adaptive_liquid_glass/main/screenshots/tabbar.gif" width="400" alt="GlassTabBar: press, tap and drag the lens across three tabs" />
  <img src="https://raw.githubusercontent.com/AymanOmara/adaptive_liquid_glass/main/screenshots/tabbar-light.gif" width="400" alt="GlassTabBar in light mode: white glass bar with a blue tint on a white page" />
</p>

### Tab bar against SwiftUI

`GlassTabBar` recorded beside SwiftUI's own `TabView` on iOS 26.4: top row
SwiftUI, then this package in native mode, then in shader mode; light on the
left, dark on the right; press, drag and tap, aligned on the gesture's start.

<p align="center">
  <img src="https://raw.githubusercontent.com/AymanOmara/adaptive_liquid_glass/main/screenshots/tabbar-compare.gif" width="880" alt="GlassTabBar beside SwiftUI's TabView: press, drag and tap in light and dark, native and shader modes" />
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/AymanOmara/adaptive_liquid_glass/main/screenshots/tabbar-compare-slowmo.gif" width="880" alt="The same comparison at a quarter speed" />
</p>

Videos: [real time](https://github.com/AymanOmara/adaptive_liquid_glass/raw/main/screenshots/tabbar-compare.mp4),
[4x slow motion](https://github.com/AymanOmara/adaptive_liquid_glass/raw/main/screenshots/tabbar-compare-slowmo.mp4).

## Screenshots

The screenshot gallery shows the example app on iOS 26.4 in light and dark
modes. Plain backgrounds make the controls easier to inspect; photo backgrounds
show the glass effect over imagery.

<p>
  <img src="https://raw.githubusercontent.com/AymanOmara/adaptive_liquid_glass/main/screenshots/01-controls-dark.png" width="160" alt="controls" /> <img src="https://raw.githubusercontent.com/AymanOmara/adaptive_liquid_glass/main/screenshots/02-alert-toolbar-dark.png" width="160" alt="alert toolbar" /> <img src="https://raw.githubusercontent.com/AymanOmara/adaptive_liquid_glass/main/screenshots/03-sheet-dark.png" width="160" alt="sheet" /> <img src="https://raw.githubusercontent.com/AymanOmara/adaptive_liquid_glass/main/screenshots/04-pickers-fields-dark.png" width="160" alt="pickers fields" /> <img src="https://raw.githubusercontent.com/AymanOmara/adaptive_liquid_glass/main/screenshots/05-lists-chips-progress-dark.png" width="160" alt="lists chips progress" /> <img src="https://raw.githubusercontent.com/AymanOmara/adaptive_liquid_glass/main/screenshots/06-gauges-badges-empty-dark.png" width="160" alt="gauges badges empty" /> 
</p>

## Fidelity

The shipped glass constants are certified against Apple's SwiftUI
`.glassEffect` on the reference simulator (iPhone 17 Pro, iOS 26.4):

| path | result |
|---|---|
| Shader (iOS < 26, or `mode: shader`) | every scene at SSIM ≥ 0.95 (minimum 0.9525); 59/75 pass the strict bars (SSIM ≥ 0.97 and ΔE ≤ 2.0); median SSIM 0.983, median ΔE 1.19 |
| Native (iOS 26+, the default) | 75/75 at parity with SwiftUI (minimum SSIM 0.9996, maximum ΔE 0.05) |

Over 75 scenes (regular, clear and tinted glass; capsules, circles and
rounded rectangles; photo, text and gradient backgrounds; light and dark;
merged groups): **59/75 scenes pass** the official bars (SSIM ≥ 0.97,
CIEDE2000 ΔE ≤ 2.0), median SSIM 0.9830 / median ΔE 1.19, min SSIM 0.9525,
**0 scenes below SSIM 0.95** on the 75 in-set scenes (baseline
`build/fidelity/g8-3`). Model↔Flutter parity is 75/75.
The full per-scene record, diagnosis and known residuals:
`docs/superpowers/notes/fidelity-status.md`.

Press and morph motion uses SwiftUI's measured springs (press-in, release
and `.bouncy` morph) and a size-dependent press growth. To re-run, follow
`tool/fidelity/README.md`: capture both renderers with
`tool/fidelity/capture.sh build/fidelity/<run>` (setup and options
documented there), then score with
`tool/fidelity/.venv/bin/python tool/fidelity/compare.py build/fidelity/<run>`.

## Getting started

```yaml
dependencies:
  adaptive_liquid_glass: ^0.2.5
```

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  await AdaptiveLiquidGlass.initialize(); // optional: preloads the shaders
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Hello()))));
}

class Hello extends StatelessWidget {
  const Hello({super.key});

  @override
  Widget build(BuildContext context) => GlassButton(
    onPressed: () => showGlassAlert(context: context, title: 'Hello, glass'),
    child: const Text('Tap me'),
  );
}
```

That is all the setup there is: no theme and no platform checks. The
button is iOS 26 Liquid Glass on iOS and a Material 3 button on Android; the
alert is iOS 26's alert with an OK button, or an `AlertDialog`. Without
`initialize()` the shaders load on first use, and glass draws as a plain blur
for a frame or two before switching over in place.

A complete small app (navigation bar, tab bar, controls, sheet, toast) is
in [`example/lib/quick_start.dart`](example/lib/quick_start.dart); run it
with `flutter run -t lib/quick_start.dart` from `example/`. The
[Which widget?](#which-widget) table lists every component.

### One line

```dart
const Text('Hello').glassEffect(padding: const EdgeInsets.all(12));

// A glass button, also one line:
const Icon(Icons.add).glassEffect(onPressed: add);
```

`glassEffect` mirrors SwiftUI's `.glassEffect(_:in:)` and returns a
`LiquidGlass` widget. Text and icons on glass get a readable colour by
default, like SwiftUI's vibrant labels; colours you set yourself still win.

The full widget takes the same options and a few more:

```dart
LiquidGlass(
  glass: Glass.regular.tint(Colors.blue),   // default: Glass.regular
  shape: const GlassShape.rect(20),         // default: capsule
  padding: const EdgeInsetsDirectional.all(16),
  onPressed: () {},                         // makes it a button
  child: const Text('Continue'),
)
```

`Glass` has named presets when you don't want to compose one:

| Preset | Means |
|---|---|
| `Glass.regular` / `Glass.frosted` | standard frosted glass (the default) |
| `Glass.clear` / `Glass.crystal` | highly transparent, for photos and video |
| `Glass.smoke` | regular glass darkened with a smoke tint |
| `Glass.accent` | regular glass tinted iOS 26 system blue |
| `Glass.tinted(color)` | shorthand for `Glass.regular.tint(color)` |

Every preset still chains: `Glass.smoke.interactive()`.

With `onPressed` the glass is a button: it gets button semantics, takes
focus, answers Enter and Space, and its glass turns interactive (the press
stretch and light on iOS, the ripple on Android; the light is SwiftUI's,
measured: white over the whole shape plus a glow under the finger, on at
the touch and held 0.33 s past the release). Pass
`Glass.regular.interactive(false)` to keep the tap without the press
visuals.

### A group of buttons

Glass next to glass belongs in one `GlassGroup`, SwiftUI's
`GlassEffectContainer`. Members are drawn in one pass, sample the same
backdrop, and can blend and morph into each other.

```dart
GlassGroup(
  spacing: 16,
  child: Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 12,
    children: [
      LiquidGlass(
        shape: const GlassShape.circle(),
        padding: const EdgeInsets.all(14),
        onPressed: () {},
        child: const Icon(Icons.edit),
      ),
      LiquidGlass(
        shape: const GlassShape.circle(),
        padding: const EdgeInsets.all(14),
        onPressed: () {},
        child: const Icon(Icons.share),
      ),
    ],
  ),
)
```

Group repeated glass too. A `LiquidGlass` outside any `GlassGroup` gets a
group of its own, and on iOS 26 every group hosts its own native view, which
is costly to create. Twenty chips in a row, glass list rows or glass inside a
sheet's content each become a separate view unless one `GlassGroup` wraps
them; debug builds print a warning when more than 8 are alive at once.

To keep such glass separate but still share one native view, wrap it in a
`GlassBatch` (inside the scroll view, if it scrolls): nothing merges, the
shapes only share the view. Glass the batch could not draw as its own view
would (over a coloured or overlapping widget, partly clipped, rotated, in an
overlay) keeps its own view. `LiquidGlassThemeData(batchImplicitGroups: true)`
also places a batch in `GlassSheet` content and `GlassScaffold` bodies, and
lets a native `GlassGroup` take more than 16 members.

`spacing` is how close two shapes must be to flow together. The default, 0,
merges only shapes that touch, so a row of buttons stays a row of separate
buttons. Set it to at least the gap between them (here 12) for SwiftUI's
liquid blending.

### Theming and native mode

A `LiquidGlassTheme` is optional; without one the defaults apply.

```dart
LiquidGlassTheme(
  data: const LiquidGlassThemeData(
    defaultGlass: Glass.clear,  // glass for widgets that do not pick one
  ),
  child: MaterialApp(home: const HomePage()),
)
```

Glass and the text on it follow one brightness — the theme's (a
`MaterialApp` with no dark theme gets light glass on a dark system; set a
dark theme and the glass goes dark with it).

On iOS 26 and later, glass is SwiftUI's own Liquid Glass: each `GlassGroup`
hosts one `GlassEffectContainer` with a `.glassEffect` view per member in a
platform view behind its content, so it matches a SwiftUI app pixel for pixel
(including dark mode, tint, merging and Reduce Transparency, which SwiftUI
handles itself). There is no flag: the iOS version is read at startup, so the
first frame already uses it. Older iOS gets the shader. To force a path for
one subtree, pass `mode:` to `GlassGroup` or `LiquidGlass`
(`GlassRenderMode.auto`, `shader`, `native` or `material`); set
`defaultMode: GlassRenderMode.shader` in the theme to opt out of native glass
app-wide.

For function-style code that needs a boolean rather than a widget switch,
`GlassAdaptive.pathOf(context)` returns the `GlassEffectivePath` the
package would draw (native, shader, degraded, opaque or material) and
`GlassAdaptive.usesGlass(context)` whether it is glass, using the same
resolver as every widget.

### Android

On Android, and any platform other than iOS, `auto` renders Material 3
(on Android, see [the iOS look on Android](#the-ios-look-on-android) to opt
into the glass):

| Glass | Material 3 |
|---|---|
| `Glass.regular` | `surfaceContainerHigh`, elevation 1 |
| `Glass.clear` | `surfaceContainerLow` at 85 % opacity |
| `.tint(color)` | `primaryContainer` of `ColorScheme.fromSeed(color)` |
| `.interactive()` / `onPressed` | `InkWell` ripple |
| `GlassGroup` | layout only (no merging) |

Text and icons on the surface use its matching "on" colour (`onSurface`, or
the tint's `onPrimaryContainer`).

For a Material widget of your own, `GlassAdaptive` picks by render mode,
so app code never checks the platform:

```dart
GlassAdaptive(
  glass: GlassTabBar(items: items, selectedIndex: tab, onSelected: pick),
  material: (context) => NavigationBar(
    selectedIndex: tab,
    onDestinationSelected: pick,
    destinations: destinations,
  ),
)
```

The tab bar floats in a capsule on Android too. For Material 3's own
full-width bar, pass `materialStyle: GlassMaterialTabBarStyle.edgeToEdge`
(see [Tab bar](#tab-bar)).

The package has a small Kotlin plugin on Android for one job: the system
photo picker behind `GlassPhotosPicker` (see [Photos picker](#photos-picker)).
Everything else is drawn in Dart; it adds no Gradle dependencies and no
permissions.

#### The iOS look on Android

One switch: set `supportLiquidGlassOnAndroid` and `auto` draws the shader
glass on Android instead of Material 3. iOS is unchanged (SwiftUI's glass on
26+), other platforms keep Material, and a widget's own `mode:` still wins.

```dart
Future<void> main() async {
  // Optional: preloads the shaders, else the first frames draw a plain blur.
  await AdaptiveLiquidGlass.initialize(supportLiquidGlassOnAndroid: true);
  runApp(
    const LiquidGlassTheme(
      data: LiquidGlassThemeData(supportLiquidGlassOnAndroid: true),
      child: MaterialApp(home: HomePage()),
    ),
  );
}
```

Memory: under Impeller each shader backdrop renders full-screen offscreen
textures, about 110-200 MB of GPU memory each, so on Android all shader
glass of a route draws through one shared layer (one capture, one blur
per stratum of overlapping glass); see Known limitations. Devices
without shader support (not Impeller) get the frosted blur throughout.

`defaultMode: GlassRenderMode.shader` (with `initialize(mode:
GlassRenderMode.shader)`) forces the shader on every platform, iOS 26
included.

The example app's home page has an "iOS glass" toggle on Android; it also
takes `--dart-define=ANDROID_GLASS=true` (or `MODE=shader`, `material`) for
both the gallery and `lib/components_demo.dart`. Checked on an Android 15
emulator (Impeller, OpenGL ES): glass, sheets, dialogs, menus, popovers,
toasts, pickers, lists and the navigation bar render as on iOS. The shader
needs Impeller (Flutter's default on Android); without it the glass falls
back to a plain blur (see [Known limitations](#known-limitations)). Fonts,
scroll physics, the back gesture and haptics stay Android's.

## Which widget?

Every component is iOS 26's own on iOS and gets a Material 3 counterpart on
Android. All are in the example app's Gallery (`example/lib/gallery.dart`,
`flutter run -t lib/gallery.dart`).

| Widget / function | What it is | Material 3 on Android |
|---|---|---|
| `LiquidGlass`, `GlassEffect.glassEffect` | Glass behind any child; SwiftUI's `.glassEffect(_:in:)` | Surface (table above) |
| `Glass` | The material: `regular`, `clear`, `.tint()`, `.interactive()` | Variant mapping (table above) |
| `GlassShape` | The outline: capsule, circle, `rect(r)`, `concentric()` | Same shape as a border |
| `GlassGroup` | Neighbouring glass drawn in one pass; blends and morphs | Layout only (no merging) |
| `LiquidGlassTheme`, `LiquidGlassThemeData` | Optional app-wide defaults (`defaultGlass`, `defaultMode`, `lightAngle`, `androidShaderBudget`) | — |
| `GlassRenderMode` | Force `auto`, `shader`, `native` or `material` for a subtree | — |
| `AdaptiveLiquidGlass.initialize` | Optional: preload the shaders in `main()` | no-op |
| `AdaptiveLiquidGlass.reduceTransparency` | Override the system's Reduce Transparency (null follows it) | already opaque |
| `GlassAdaptive` | Your own widget on the Material path, the glass one elsewhere | your `material` builder |
| `GlassBackdropSource`, `GlassForeground` | Adaptive label colour over busy content | — |
| `GlassOverlayContent` | Content laid over glass from outside its group stays above it on Android's shared layer | — |
| `GlassSystemColors` | iOS 26's red, blue, orange and green | — |
| `GlassButton` (`+ .icon`), `GlassButtonRole`, `GlassButtonStyle`, `GlassButtonShape`, `GlassControlSize`, `GlassControlSizeScope` | SwiftUI's glass, prominent, bordered, borderless and plain buttons, roles, sizes, shapes, loading | `FilledButton` / `IconButton` / `TextButton` |
| `GlassFloatingActionButton` (`+ .extended`) | The screen's primary action: a large prominent glass circle, or capsule with a label | `FloatingActionButton` |
| `GlassBackButton` | Circular glass chevron that pops the route | `BackButton` |
| `GlassNavigationBar`, `SliverGlassNavigationBar`, `GlassScrollEdgeStyle` | Inline and large-title nav bars, no bar background; `scrollEdgeStyle` blurs content scrolled under | `AppBar` / `SliverAppBar.large` |
| `GlassLargeTitleScrollView` | Large-title bar over a body that scrolls itself (`ListView`, paged list), so the title still collapses | `SliverAppBar.large` in a `NestedScrollView` |
| `GlassScaffold`, `GlassBottomAccessory` | An iOS 26 screen in one widget; the Music-style mini-player slot | Same layout, Material bars |
| `GlassToolbar`, `GlassToolbarSpacer` | The floating bottom toolbar, merged capsules | Material buttons |
| `GlassTabBar`, `GlassTabBarItem`, `GlassMaterialTabBarStyle` | iOS 26's floating tab bar, draggable lens, `onSearch` tab | `NavigationBar`, floating or edge to edge |
| `GlassToggle` | iOS 26's switch, glass lens thumb | `Switch` |
| `GlassSlider` | Slider with a glass lens thumb, optional `divisions`, horizontal or vertical | `Slider` |
| `GlassRangeSlider` | Two-thumb range slider on the same track (SwiftUI has none) | `RangeSlider` |
| `GlassSegmentedControl`, `GlassSegment` | Segmented control, sliding lens | `SegmentedButton` |
| `GlassStepper` | Minus/plus capsule stepper | pair of icon buttons |
| `GlassPicker`, `GlassPickerItem` | Menu-style picker, current choice checked | `DropdownButton` |
| `GlassWheelPicker` | `.pickerStyle(.wheel)`: scrolling rows under a clear-glass selection band, haptics | `ListWheelScrollView` on a Material surface |
| `GlassDatePicker` | Compact date picker opening a glass calendar | text button + `showDatePicker` |
| `showGlassDatePicker`, `showGlassDateRangePicker`, `GlassCalendar` (`.range`) | The calendar sheet for one date or a range | `showDatePicker` / `showDateRangePicker` |
| `GlassMenuButton`, `GlassMenuItem` | Pull-down glass menu from an icon button | `MenuAnchor` |
| `GlassMenuController` | Drives a menu from an outer gesture: slide-to-select (`glideTo`) | open/close only |
| `GlassContextMenu` | Long-press lifts the child and opens the glass menu | popup menu |
| `GlassPopoverAnchor`, `showGlassPopover` | SwiftUI's iPhone popover: a glass bubble over its anchor | Material surface bubble |
| `showGlassAlert`, `GlassDialogAction` | iOS 26 alert: centred glass card, buttons side by side | `AlertDialog` |
| `showGlassConfirmationDialog` | Small glass card, actions stacked; cancel taken by a tap outside | `AlertDialog` |
| `showGlassActionSheet` | iOS 26's confirmation dialog on iPhone: stacked capsule buttons | modal bottom sheet |
| `showGlassSheet`, `GlassSheet`, `GlassSheetDetent` | Modal sheet with detents (`medium`, `large`, `fraction`, `height`) | modal bottom sheet |
| `showGlassFullScreenCover`, `GlassFullScreenCoverHandle` | `.fullScreenCover`: opaque edge-to-edge modal sliding up | full-screen `Dialog` |
| `showGlassToast`, `GlassToastAction`, `GlassToastHandle` | Glass capsule toast from the top, queued, swipe to dismiss | `SnackBar` |
| `GlassTextField` (`+ .password`) | Text field in a glass capsule; password with an eye button | `TextField` |
| `GlassSearchField` | Search capsule with magnifier and clear button | `SearchBar` |
| `GlassSearchable`, `GlassSearchController`, `GlassSearchSuggestion` | `.searchable`: field with a springing Cancel, suggestions listed in place of the content, scopes; bottom or navigation-bar placement | `SearchAnchor` |
| `GlassListSection`, `GlassListTile` | Inset-grouped list, like Settings; rows with leading/title/value/trailing | `Card` of `ListTile`s |
| `GlassDisclosureGroup` | SwiftUI's DisclosureGroup: a list row with a rotating chevron that expands its rows | `ExpansionTile` |
| `GlassEmptyState` (`+ .search`) | ContentUnavailableView: icon, title, description, actions | plain centred column |
| `GlassChip` | Capsule chip with selected state and delete button | `FilterChip` / `InputChip` |
| `GlassBadge` | Red count capsule (dot when empty) on a child's top trailing corner | `Badge` |
| `GlassActivityIndicator` | iOS's spinner on its own (`ProgressView()` with no value) | `CircularProgressIndicator` |
| `GlassPageControl` | Page dots on a glass capsule; tap and scrub | row of Material dots |
| `GlassProgressIndicator`, `GlassProgressStyle` | Linear bar on a glass track, or ring/spinner | `LinearProgressIndicator` / `CircularProgressIndicator` |
| `GlassGauge`, `GlassGaugeStyle` | SwiftUI's Gauge: linear capacity, accessoryCircular, accessoryCircularCapacity | `LinearProgressIndicator` / `CircularProgressIndicator` |
| `GlassSwipeActions`, `GlassSwipeAction` | List swipe actions: tinted capsules, full swipe, haptic | iOS layout, Material colour |
| `GlassPhotosPicker`, `pickGlassPhotos`, `GlassPickedPhoto` | SwiftUI's `PhotosPicker`: a glass trigger opening the system photo picker; items come back as local files | Material 3 button, Android Photo Picker |
| `GlassLabel` (`+ .text`) | SwiftUI's `Label`: icon and title, coloured like a vibrant label on glass | icon and text row, Material 3 sizes |
| `GlassLink`, `GlassShareLink` | SwiftUI's `Link` and `ShareLink`: glass triggers; your app opens the URL or share sheet | Material 3 button |
| `GlassColorPicker` | SwiftUI's `ColorPicker` row opening a glass sheet laid out as UIKit's: grid, spectrum and RGB/hex sliders, opacity, saved colours, eyedropper | `ListTile` and modal bottom sheet |
| `GlassRefresh`, `SliverGlassRefresh`, `GlassRefreshScrollPhysics` | `.refreshable`: pull to refresh around a scrollable, or as a sliver; UIScrollView's rubber band under the pull | `RefreshIndicator` |
| `GlassSymbol` | An SF Symbol drawn by iOS at run time (never bundled) | its `fallback` |

## Cookbook

One minimal example per component. All are in the example app's Gallery
(`example/lib/gallery.dart`) and `example/lib/components_demo.dart`
(`flutter run -t lib/components_demo.dart`).

### Glass button

```dart
const Text('Save').glassEffect(
  onPressed: save,
  padding: const EdgeInsetsDirectional.symmetric(horizontal: 24, vertical: 14),
)
```

`GlassButton` is SwiftUI's `.buttonStyle(.glass)` and `.glassProminent`,
with roles, control sizes, border shapes, and disabled and loading states:

```dart
GlassButton(onPressed: save, child: const Text('Save'))
GlassButton(
  onPressed: delete,
  role: GlassButtonRole.destructive,
  style: GlassButtonStyle.glassProminent,
  child: const Text('Delete'),
)
GlassButton.icon(onPressed: share, icon: CupertinoIcons.share, semanticLabel: 'Share')
GlassButton(onPressed: upload, loading: uploading, child: const Text('Upload'))
```

The system styles without glass are there too: `GlassButtonStyle.bordered`
(a grey fill, or the tint at low opacity, behind an accent label),
`.borderedProminent` (a solid accent fill), `.borderless` (accent text) and
`.plain` (label-coloured text). A destructive role turns them red, a null
`onPressed` greys them out, and they dim while pressed. On Android they are
`FilledButton.tonal`, `FilledButton` and `TextButton`. Their fills and press
dimming are estimated, not measured.

```dart
GlassButton(onPressed: edit, style: GlassButtonStyle.bordered, child: const Text('Edit'))
GlassButton(onPressed: more, style: GlassButtonStyle.borderless, child: const Text('Show more'))
```

Sizes are measured from SwiftUI on iOS 26.4 (iOS 26 draws mini as small and
extraLarge as large; icon-only buttons are capsules 12 pt wider than tall).
Set a default with `GlassControlSizeScope(size: GlassControlSize.small, ...)`.

`GlassFloatingActionButton` is the screen's primary action. iOS 26 has
none, so the glass path draws a large prominent glass circle, or a capsule
with `.extended`'s label. On Android it is Material 3's
`FloatingActionButton`. Put it in `GlassScaffold.floatingActionButton`
(see [Screen layout](#screen-layout)):

```dart
GlassFloatingActionButton(
  onPressed: compose,
  icon: CupertinoIcons.add,
  semanticLabel: 'New event',
)
GlassFloatingActionButton.extended(
  onPressed: compose,
  icon: CupertinoIcons.add,
  label: const Text('New event'),
)
```

`foregroundColor` sets the label and icon colour on both paths (a disabled
button keeps its dimmed look), and `cornerRadius` sets the radius of a
`GlassButtonShape.roundedRect` button.

### Card with padding

```dart
const LiquidGlass(
  shape: GlassShape.rect(24),
  padding: EdgeInsetsDirectional.all(20),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Liquid Glass', style: TextStyle(fontSize: 22)),
      Text('Text on glass picks a readable colour.'),
    ],
  ),
)
```

Nested glass with `GlassShape.concentric()` follows the card's corners, inset
by the distance between them.

`minSize` makes the glass at least that size with the child centred, so a
36-pt circle around an 18-pt icon needs no padding arithmetic.

### Morphing pair with `glassId`

Give glass an identity and it morphs in and out of its neighbours as it
appears and disappears, like `glassEffectID`:

```dart
GlassGroup(
  spacing: 20,
  child: Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 12,
    children: [
      LiquidGlass(
        glassId: 'toggle',
        shape: const GlassShape.circle(),
        padding: const EdgeInsets.all(14),
        onPressed: () => setState(() => expanded = !expanded),
        child: Icon(expanded ? Icons.close : Icons.add),
      ),
      if (expanded)
        const Icon(Icons.favorite).glassEffect(
          glassId: 'extra',
          shape: const GlassShape.circle(),
          padding: const EdgeInsets.all(14),
        ),
    ],
  ),
)
```

### Merged union

Members with the same `unionId` are drawn as one shape however far apart
they are, like `glassEffectUnion`:

```dart
GlassGroup(
  child: Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 24,
    children: [
      for (final icon in [Icons.edit, Icons.share, Icons.delete])
        Icon(icon).glassEffect(
          shape: const GlassShape.circle(),
          unionId: 'tools',
          padding: const EdgeInsets.all(12),
        ),
    ],
  ),
)
```

### Clear glass over media

`Glass.clear` is the highly transparent variant for photos and video:

```dart
Stack(
  alignment: Alignment.center,
  children: [
    Image.asset('cover.jpg'),
    const Icon(Icons.play_arrow, size: 36).glassEffect(
      glass: Glass.clear.interactive(),
      shape: const GlassShape.circle(),
      padding: const EdgeInsets.all(16),
    ),
  ],
)
```

### Tinted glass

```dart
LiquidGlass(
  glass: Glass.regular.tint(Colors.blue),
  onPressed: () {},
  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
  child: const Text('Tinted'),
)
```

### Tab bar

iOS 26's floating tab bar. Pressing turns the selected pill into a clear
glass lens that magnifies the tabs under it; dragging slides it between
tabs; letting go springs it to the nearest tab and calls `onSelected`.

```dart
Stack(
  children: [
    pages[tab],
    Positioned(
      left: 21,
      right: 21,
      bottom: 21,
      child: Center(
        child: GlassTabBar(
          items: const [
            GlassTabBarItem(icon: CupertinoIcons.clock_fill, label: 'History'),
            GlassTabBarItem(
              icon: CupertinoIcons.text_quote,
              label: 'Snippets',
              badge: '3', // '' shows a dot
            ),
            GlassTabBarItem(icon: CupertinoIcons.gear_solid, label: 'Settings'),
          ],
          selectedIndex: tab,
          onSelected: (i) => setState(() => tab = i),
        ),
      ),
    ),
  ],
)
```

Tabs sit `itemWidth` (86.0, as on iOS) apart and move closer evenly when
the bar would not fit, so five tabs fit a phone. Press, drag and release
follow iOS 26's measured springs: the lens trails the finger and wobbles with
its acceleration. The lens is drawn with the package's shader, fitted to iOS
26.4's tab lens: unfrosted, it refracts what lies just outside its edge into
a band and splits colour there. So that the lens can refract the bar, the bar
is shader glass too whenever the shader is available (pass `mode:` to force
another path). Give a tab an `activeIcon` for its selected
state. The selected tab takes `tint` (default: iOS 26's tab bar
blue, measured from SwiftUI's `TabView`); the others take glass's readable
colour. `onSearch` adds iOS 26's search tab, a glass circle beside the bar.
On Android it is a Material 3 `NavigationBar` in the same floating capsule;
`materialStyle: GlassMaterialTabBarStyle.edgeToEdge` draws Material 3's
full-width bar instead, safe area inside, with `onSearch` as a last
destination (`GlassScaffold` pads the body to match).
Each tab is a selectable button for VoiceOver and TalkBack, the order follows
the reading direction, and with Reduce Motion the pill moves without
animating.

To shrink the bar to its selected tab as the page scrolls down (SwiftUI's
`.tabBarMinimizeBehavior(.onScrollDown)`), pass
`minimizeBehavior: GlassTabBarMinimizeBehavior.onScrollDown` to a bar inside
a `GlassScaffold`. It expands again near the top of the page or when the
circle is tapped. With a bottom accessory, the accessory slides into the
bar's row beside the circle.

For SwiftUI's `.tabViewStyle(.sidebarAdaptable)`, pass
`style: GlassTabBarStyle.sidebarAdaptable`. On a regular width (an iPad,
700 pt and up) a `GlassScaffold` floats the tabs as text at the top with a
sidebar button; the sidebar lists the tabs with their icons. Phones keep
the bottom bar.

For the exact icons iOS draws, use `GlassTabBarItem.symbol` with an SF
Symbol name. iOS renders the symbol at run time (nothing is bundled), at
`TabView`'s size and position; other platforms show `fallback`.

```dart
GlassTabBarItem.symbol(
  'house.fill',
  fallback: CupertinoIcons.house_fill,
  label: 'Home',
),
```

For SVG or image icons, use `GlassTabBarItem.custom`. The bar draws the
widget inside an `IconTheme` with its icon size and colour, so widgets that
read it (`ImageIcon`, a theme-tinted SVG) follow the selection; plain images
keep their own colours.

```dart
const GlassTabBarItem.custom(
  iconWidget: ImageIcon(AssetImage('assets/home.png')),
  activeIconWidget: ImageIcon(AssetImage('assets/home_fill.png')),
  label: 'Home',
)
```

`GlassTabBarItem.icon` is null for custom items.

`labelMaxTextScale` caps how far the labels follow the system text size
(the glass bar keeps iOS's default size; Material's `NavigationBar` stops
at 1.3 on its own).

### Navigation bar

```dart
// Inline title
Scaffold(
  extendBodyBehindAppBar: true,
  appBar: GlassNavigationBar(
    title: const Text('Inbox'),
    scrollEdgeStyle: GlassScrollEdgeStyle.progressive, // optional
    actions: [GlassButton.icon(
      onPressed: share, icon: CupertinoIcons.share, semanticLabel: 'Share')],
  ),
  body: ...,
)

// Large title
CustomScrollView(slivers: [
  SliverGlassNavigationBar(largeTitle: const Text('Inbox'), actions: [...]),
  SliverList(...),
])
```

No bar background, as on iOS 26: a `GlassBackButton` when the route can
pop, the actions merged into one glass capsule, and a fade at the top once
content is under the bar. `GlassScrollEdgeStyle.progressive` is an opt-in
graduated blur under the bar (strongest at the top, easing to sharp further
down); the default `uniform` is one even blur. The large title scrolls away
with the content, the inline title fades in once it has gone, and pulling
down stretches the large title. Metrics are measured from SwiftUI's
`NavigationStack` (`tool/reference/`). On Android these are `AppBar` and
`SliverAppBar.large`.

A list in `SliverFillRemaining` takes every drag, so the large title never
collapses. When the body scrolls itself (a `ListView`, a paged list), use
`GlassLargeTitleScrollView`: scrolling the body collapses the title first.

```dart
GlassLargeTitleScrollView(
  navigationBar: const SliverGlassNavigationBar(largeTitle: Text('Inbox')),
  body: ListView.builder(itemCount: mails.length, itemBuilder: buildRow),
)
```

The body sits below the bar, not under it. Content that can be slivers
belongs in a `CustomScrollView` after the bar, so it scrolls under the glass.

`materialBuilder` replaces the Android bar: it receives the default
`AppBar` (which already follows your `AppBarTheme`) and returns any
`PreferredSizeWidget`, whose `preferredSize` sizes the `Scaffold` slot.
`SliverGlassNavigationBar.materialBuilder` does the same for the sliver
bar: it receives the default `SliverAppBar.large` and returns a sliver.

### Screen layout

```dart
GlassScaffold(
  navigationBar: const GlassNavigationBar(title: Text('Inbox')),
  tabBar: GlassTabBar(items: tabs, selectedIndex: tab, onSelected: pick),
  bottomAccessory: GlassBottomAccessory(child: nowPlaying), // optional
  floatingActionButton: GlassFloatingActionButton( // optional
    onPressed: compose,
    icon: CupertinoIcons.add,
    semanticLabel: 'Compose',
  ),
  body: ListView(children: rows),
)
```

One widget lays out an iOS 26 screen. The body runs under the bars. The
tab bar floats 21 pt above the home indicator, and an optional accessory
floats above it, like Music's mini-player. The body's `MediaQuery`
padding grows by the bars, so scroll views keep their content clear of
them. Read that padding inside the body, not with a context from above
the scaffold. The body is a `GlassBackdropSource` unless
`sampleBackdrop: false`.

A `floatingActionButton` floats at the end, 16 above the bottom bars (or
the safe area); it does not pad the body. While the keyboard is open the
tab bar, toolbar, accessory and floating button step aside, as on iOS,
instead of riding up onto it; they stay while focus is inside them. Pass
`hideBottomBarsWithKeyboard: false` to keep them above the keyboard.

### Toolbar

```dart
GlassScaffold(
  toolbar: GlassToolbar(children: [
    GlassButton.icon(onPressed: reply, icon: CupertinoIcons.reply,
        semanticLabel: 'Reply'),
    const GlassToolbarSpacer(),
    GlassButton.icon(onPressed: compose, icon: CupertinoIcons.pencil,
        semanticLabel: 'Compose'),
  ]),
  body: ...,
)
```

Neighbouring items merge into one glass capsule. A `GlassToolbarSpacer`
starts a new capsule and pushes the groups apart, like SwiftUI's
`ToolbarSpacer`.

### Toggle, slider, segmented control, stepper

```dart
GlassToggle(value: wifi, onChanged: (v) => setState(() => wifi = v))
GlassSlider(value: volume, onChanged: (v) => setState(() => volume = v))
GlassSlider(axis: Axis.vertical, value: level, onChanged: (v) => setState(() => level = v))
GlassRangeSlider(values: price, onChanged: (v) => setState(() => price = v))
GlassSegmentedControl<Period>(
  segments: const [
    GlassSegment(value: Period.day, label: Text('Day')),
    GlassSegment(value: Period.week, label: Text('Week')),
  ],
  selected: period,
  onChanged: (p) => setState(() => period = p),
)
GlassStepper(value: count, min: 0, max: 10, onChanged: (v) => setState(() => count = v))
```

As in iOS 26, each thumb turns into a clear glass lens while it is
pressed or dragged. The segmented control's lens slides between segments
with a haptic on each one.
`axis: Axis.vertical` stands a slider up with its minimum at the bottom,
as a rotated SwiftUI `Slider` (give it a height). `GlassRangeSlider` has
no SwiftUI counterpart; it follows the single slider's geometry with two
thumbs that never cross. A touch takes the nearest thumb, and on
overlapping thumbs the drag's direction picks; each thumb is its own
slider for VoiceOver. On Android it is a `RangeSlider`. All four follow the reading direction and
Reduce Motion. On Android they are `Switch`, `Slider`, `SegmentedButton`
and a pair of icon buttons.

### Text field and search field

```dart
GlassTextField(
  placeholder: 'Email',
  clearButton: true,
  onChanged: (text) => setState(() => email = text),
)

const GlassTextField.password(
  placeholder: 'Password',
  onSubmitted: logIn,
)

GlassSearchField(onChanged: (q) => setState(() => query = q))
```

The text field is a glass capsule (a rounded rect when multi-line) with an
optional `prefix` and `suffix`, a clear button, an `errorText` under the
field, and a `semanticLabel` for screen readers. `.password` obscures the
text and adds an eye button that shows and hides it. Put the search field
in a `GlassBottomAccessory` slot or a toolbar for iOS 26's bottom search.
On Android they are Material 3's `TextField` and `SearchBar`.

For SwiftUI's `.searchable` presentation wrap the screen's content (a
`GlassScaffold` body) in `GlassSearchable`: tapping the field springs a
close button out of its end, `suggestionsBuilder` rows replace the
content as a plain list (as SwiftUI's do) and `scopes` become a
`GlassSegmentedControl` at the top once a query is typed (under the
field in the navigation-bar placement). `placement` picks iPhone's floating bottom field or the
navigation-bar one; a `GlassSearchController` reads or drives the text,
activation and scope. On Android it is Material 3's `SearchAnchor`; scopes
show there only while search is active too (in the open search view, then
under the bar while a query remains).

```dart
GlassSearchable(
  controller: search,
  scopes: const ['All', 'Recent'],
  suggestionsBuilder: (context, search) => [
    for (final hit in hits(search.text))
      GlassSearchSuggestion(title: Text(hit), onSelected: () => open(hit)),
  ],
  child: const MailList(),
)
```

### List section

```dart
GlassListSection(
  header: const Text('General'),
  children: [
    GlassListTile(
      leading: const Icon(CupertinoIcons.wifi),
      title: const Text('Wi-Fi'),
      trailing: GlassToggle(value: wifi, onChanged: setWifi),
    ),
    GlassListTile(
      title: const Text('About'),
      value: 'iOS 26.4',
      chevron: true,
      onTap: openAbout,
    ),
  ],
)
```

iOS 26's inset-grouped list, measured against SwiftUI on iOS 26.4: rows on
a rounded platter with hairline separators and optional header and footer.
The platter is opaque by default, as iOS 26 Settings; pass
`glass: Glass.regular` for a Liquid Glass platter over imagery. A tile's
row highlights while pressed. On Android it is a Material 3 filled `Card`
of `ListTile`s.

`backgroundColor` and `separatorColor` replace the iOS system platter and
hairline colours (the background is ignored when `glass` is set).

### Disclosure group

```dart
GlassListSection(
  header: const Text('Settings'),
  children: [
    GlassDisclosureGroup(
      leading: const Icon(CupertinoIcons.gear),
      label: const Text('Advanced'),
      initiallyExpanded: true,
      children: const [
        GlassListTile(title: Text('Proxy'), value: 'Off'),
        GlassListTile(title: Text('DNS'), value: 'Automatic'),
      ],
    ),
  ],
)
```

A list row that expands to reveal more rows beneath it, like SwiftUI's
`DisclosureGroup`: the label row lays out as a list row whose chevron
rotates to point down while the children, indented, spring open, and it
keeps the list's press highlight. Leave the state internal with
`initiallyExpanded`, or drive it with `isExpanded` and
`onExpansionChanged`. Geometry measured against SwiftUI on iOS 26.4. On
Android it is a Material 3 `ExpansionTile`.

### Chip and badge

```dart
GlassChip(
  label: 'Whale watching',
  icon: CupertinoIcons.tag,
  selected: picked,
  onSelected: (v) => setState(() => picked = v),
  onDeleted: () => remove('Whale watching'),
)

GlassBadge.count(count: unread, child: const Icon(CupertinoIcons.mail))
```

The chip is a glass capsule with a selected state (tinted glass) and an
optional delete button; without `onSelected` it is a display-only tag. The
badge is iOS's small solid red capsule with a count (a dot when empty,
hidden at 0) on a child's top trailing corner — iOS draws badges solid,
not glass. Geometry estimated, not yet measured. On Android: `FilterChip`
/ `InputChip` and `Badge`.

`GlassChip.subtitle` shows a secondary text after the label, such as a
count, and is read with it.

### Page control and progress

```dart
GlassPageControl(
  count: 3,
  controller: pageController,
  onPageChanged: (page) => debugPrint('page $page'),
)

GlassProgressIndicator(value: downloaded)   // 0..1, null indeterminate
const GlassProgressIndicator.circular()     // a spinner
```

Tapping a half of the page control steps a page and dragging scrubs the
dots, like UIKit's interactive page control. The progress indicator is a
linear bar on a glass track, or a circular ring (iOS's activity spinner
while indeterminate); the fill defaults to system blue. Geometry
estimated, not yet measured. On Android: a row of Material dots, and
Material 3 progress indicators.

### Empty state

```dart
GlassEmptyState(
  icon: const Icon(CupertinoIcons.tray),
  title: const Text('No Mail'),
  description: const Text('New messages you receive will appear here.'),
  actions: [GlassButton(onPressed: refresh, child: const Text('Refresh'))],
)

GlassEmptyState.search(query: 'kiwi')
```

SwiftUI's `ContentUnavailableView`: a centred icon, title, description and
stacked actions where a list or a search has nothing to show. `.search`
draws the magnifying glass, "No Results for “kiwi”" and a hint, so an
empty search is one line (`searchTitle` and `searchDescription` are exposed
to localise them). Actions are small buttons unless a
`GlassControlSizeScope` above says otherwise. It draws no platter of its
own and nothing animates. Geometry measured against SwiftUI on iOS 26.4.
On Android the same column takes Material 3 typography.

### Gauge

```dart
GlassGauge(
  value: 0.62,
  label: const Text('Battery'),
  currentValueLabel: const Text('62%'),
  minimumValueLabel: const Text('0'),
  maximumValueLabel: const Text('100'),
)
GlassGauge(
  value: 21, min: 0, max: 40,
  style: GlassGaugeStyle.accessoryCircular,
  label: const Text('Temp'),
  currentValueLabel: const Text('21'),
  tint: GlassSystemColors.orange,
)
```

SwiftUI's `Gauge` in its three forms: `linearCapacity` (the default, a
capsule track filled to the value), `accessoryCircular` (an open ring with
a dot marking the value) and `accessoryCircularCapacity` (a ring filled to
the value). `tint` colours the fill (by default blue on the linear gauge
and the label colour on the rings, as SwiftUI), and the value does not
animate; SwiftUI's gauges do not either. Geometry measured against SwiftUI
on iOS 26.4. On Android it is a
Material 3 `LinearProgressIndicator` or `CircularProgressIndicator` with
the labels around it.

### Sheet

```dart
showGlassSheet<void>(
  context: context,
  detents: const [GlassSheetDetent.medium, GlassSheetDetent.large],
  builder: (context) => details,
);
```

The sheet works like SwiftUI's `presentationDetents`:
- It follows a drag between its detents, and a drag or fling below the
  lowest one dismisses it.
- At a partial detent it is floating glass, 8 pt in from the screen's
  sides at any height (measured from SwiftUI up to `.height(765)`).
- At `large` (or a detent within ~31 pt of it) it runs edge to edge, opaque, with the screen's own corners.
- `GlassSheetDetent.fraction(0.6)` and `.height(400)` make custom detents.
- `cornerRadius` and `grabberSize` change the floating sheet's corners and
  grabber (iOS 26's 38 and 34.67 x 5 by default). On Android
  `cornerRadius` rounds the bottom sheet's top corners.
- `maxHeightFactor` caps the whole sheet, grabber and inset included, at a
  fraction of the screen. `enableDrag: false` turns dragging off while
  `isDismissible` still governs a tap outside. `isScrollControlled`
  overrides the Material sheet's own choice.

### Full-screen cover

```dart
final cover = showGlassFullScreenCover<void>(
  context: context,
  builder: (context) => Column(
    children: [
      Align(
        alignment: AlignmentDirectional.topEnd,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
          child: GlassButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ),
      ),
      const Expanded(child: PlayerView()),
    ],
  ),
);
// later: cover.dismiss();
```

SwiftUI's `.fullScreenCover`: an opaque page sliding up over the whole
screen, for a video player or a photo editor. The page below neither
scales nor dims; the background runs edge to edge while the content
respects the safe area, and with Reduce Motion it cross-fades instead of
sliding. `Navigator.pop` from inside closes it, or keep the returned
`GlassFullScreenCoverHandle` (`dismiss`, and `result` completes with the
value it closed with) to close it from anywhere. Layout matches SwiftUI,
and the slide's timing is fitted from a recording of SwiftUI's cover. On
Android it is a Material 3 full-screen dialog.

Two options SwiftUI's cover lacks, both off by default:
`dragToDismiss: true` lets it be dragged down to close like a sheet, and
`showsCloseButton: true` adds a glass xmark close button top-trailing (a
Material close icon on Android).

### Menu button and controller

```dart
GlassMenuButton(
  items: [
    GlassMenuItem(label: 'Copy', icon: CupertinoIcons.doc_on_doc,
        onSelected: copy),
    GlassMenuItem(label: 'Delete', icon: CupertinoIcons.trash,
        destructive: true, onSelected: delete),
  ],
)
```

Without `icon` and `semanticLabel` it is the ellipsis "More" button. The
menu opens over the button, from its top corner, as SwiftUI's `Menu`
does; measured from SwiftUI. `GlassMenuController` drives it from an outer
gesture — iOS's slide-to-select under a long-press:

```dart
final controller = GlassMenuController();

GestureDetector(
  onLongPressStart: (_) => controller.open(),
  onLongPressMoveUpdate: (details) =>
      controller.glideTo(details.globalPosition),
  onLongPressEnd: (_) => controller.endGlide(),
  onLongPressCancel: controller.cancelGlide,
  child: const Text('Hold, then slide'),
)

GlassMenuButton(controller: controller, /* ... */)
```

On Android it is a Material 3 `MenuAnchor`; gliding is a no-op there, but
opening and closing still work.

`GlassMenuItem.color` tints a row's label and icon on both paths; disabled
and `destructive` rows keep their own colours.

### Context menu

```dart
GlassContextMenu(
  items: [GlassMenuItem(label: 'Copy', icon: CupertinoIcons.doc_on_doc,
      onSelected: copy)],
  child: photo,
)
```

A long-press lifts the item over the blurred page and opens the glass menu
beside it. Assistive tech gets the items as custom actions. On Android the
long-press opens a Material popup menu.

### Popover and picker

```dart
GlassPopoverAnchor(
  popoverBuilder: (_) => const Padding(
    padding: EdgeInsets.all(16),
    child: Text('Liquid Glass popover'),
  ),
  builder: (context, open) => GlassButton.icon(
    onPressed: open, icon: CupertinoIcons.info, semanticLabel: 'Info'),
)

GlassPicker<Period>(
  items: const [
    GlassPickerItem(value: Period.day, label: 'Day'),
    GlassPickerItem(value: Period.week, label: 'Week'),
  ],
  selected: period,
  onChanged: (p) => setState(() => period = p),
)
```

- **Popover:** the glass bubble opens over its button, and the button steps
  aside while it's open, as in SwiftUI. `showGlassPopover` anchors one to
  any widget.
- **Picker:** SwiftUI's menu style. It opens the glass menu with the
  current choice checked.

### Date picker

```dart
GlassDatePicker(
  value: date,
  firstDate: DateTime(2020),
  lastDate: DateTime(2030),
  onChanged: (d) => setState(() => date = d),
)
```

The compact style: the date in a grey capsule, opening a glass calendar
popover. Picking a day closes it. On Android, a text button opening
Material's `showDatePicker`.

`showGlassDatePicker(context: context, initialDate: ..., firstDate: ...,
lastDate: ...)` returns a `Future<DateTime?>`: a glass sheet with the
calendar (picking a day confirms) or the wheels (a checkmark confirms);
dismissing returns null. On Android it is `showDatePicker`.
`firstDayOfWeek` (0 = Sunday to 6 = Saturday) overrides the locale's week
start on the calendar; on Android the locale decides.

`showGlassDateRangePicker(context: context, initialRange: ..., firstDate:
..., lastDate: ...)` returns a `Future<DateTimeRange?>` from the same
sheet: the first tap picks the start, the second the end (a tap before the
start begins again), drawn as iOS does with blue end circles and a lighter
band between; the checkmark confirms once both ends are picked. On
Android it is `showDateRangePicker`. `GlassCalendar.range` is the
calendar on its own.

### Alert and confirmation dialog

```dart
showGlassAlert(
  context: context,
  title: 'Delete photo?',
  message: 'This photo will be deleted from all your devices.',
  actions: [
    const GlassDialogAction(label: 'Cancel', role: GlassButtonRole.cancel),
    GlassDialogAction(
      label: 'Delete',
      role: GlassButtonRole.destructive,
      onPressed: delete,
    ),
  ],
);

showGlassConfirmationDialog(
  context: context,
  title: 'Photo',
  actions: [
    GlassDialogAction(label: 'Share', onPressed: share),
    const GlassDialogAction(label: 'Cancel', role: GlassButtonRole.cancel),
  ],
);
```

The alert is a 320-pt glass card centred in the safe area, with its
buttons side by side; without `actions` it has one OK button, as SwiftUI's
`.alert` does. The confirmation dialog is a 240-pt card with its
buttons stacked. As in iOS 26, its cancel action isn't drawn: a tap
outside takes it. On Android they are `AlertDialog`s.

`showGlassAlert` also takes `content` (any widget under the message),
`icon`, `barrierDismissible` (null keeps each platform's default) and
`actionOrder` (`GlassAlertActionOrder.platform` puts Cancel where the
platform does). `GlassDialogAction.subtitle` adds a secondary second line
to a button, in alerts, confirmation dialogs and action sheets.

### Action sheet

```dart
showGlassActionSheet(
  context: context,
  title: 'Photo',
  message: 'What would you like to do with it?',
  actions: [
    GlassDialogAction(label: 'Share', onPressed: share),
    GlassDialogAction(
      label: 'Delete',
      role: GlassButtonRole.destructive,
      onPressed: delete,
    ),
  ],
  cancel: const GlassDialogAction(
    label: 'Cancel',
    role: GlassButtonRole.cancel,
  ),
);
```

iOS 26's confirmation dialog as SwiftUI draws it on iPhone, measured: a
240-pt glass card with a semibold title, a secondary message and the
actions stacked as capsule buttons. As on iOS, `cancel` is not drawn — a
tap outside takes it. On Android it is a Material 3 modal bottom sheet
with Cancel included.

### Toast

```dart
showGlassToast(
  context,
  message: 'Upload complete',
  icon: CupertinoIcons.checkmark_circle,
  action: GlassToastAction(label: 'View', onPressed: openFile),
);
```

A glass capsule slides in from the top with a spring; swipe up to dismiss,
or wait for `duration` (4 s by default; null keeps it until dismissed).
One toast shows at a time — later calls wait in a queue, and the returned
`GlassToastHandle` dismisses its toast early, shown or still waiting
(`handle.dismiss()`, `await handle.closed`). With Reduce Motion it fades
instead of sliding, and it is announced as a live region. On Android it is a
`SnackBar` through the nearest `ScaffoldMessenger`, otherwise a Material 3
snackbar-styled surface at the bottom of the screen.

### Photos picker

```dart
GlassPhotosPicker(
  label: 'Select Photos',
  maxSelection: 0, // unlimited; 1 (the default) picks one
  filter: GlassPhotosPickerFilter.any, // images (default), videos, any
  onPicked: (photos) => setState(() => _photos = photos),
)

// A custom trigger, photos at most 2048 px and JPEG instead of HEIC:
final photos = await pickGlassPhotos(
  maxSelection: 3,
  maxWidth: 2048,
  maxHeight: 2048,
  imageQuality: 85,
  compatibleFormat: true,
);
Image.file(File(photos.first.path));

// Done with the files (after an upload, or on the next launch):
await clearGlassPickedPhotos();
```

SwiftUI's `PhotosPicker(selection:maxSelectionCount:matching:)`. The
trigger is a `GlassButton` (pass `child` for your own label, or `label`
and `icon`); tapping presents the system picker. On iOS that is
`PHPickerViewController`, on Android the system Photo Picker
(`MediaStore.ACTION_PICK_IMAGES`, Android 13+ and 11-12 with the SDK
extension) or the document picker on older versions. Neither needs a
photo library or storage permission, and the package adds no
dependencies. Cancelling returns an empty list (`onPicked` is not
called).

The result is a `GlassPickedPhotos`: an ordinary `List<GlassPickedPhoto>`
that also has `droppedCount`, the items chosen beyond `maxSelection` and
left out (only the Android document-picker fallback lets that happen).

Each `GlassPickedPhoto` is a copy in the `adaptive_liquid_glass_picker`
folder of the app's temporary (iOS) or cache (Android) directory, with
`path`, `isVideo`, `mimeType`, the upright `width` and `height` (photos
and videos) and, for videos, `duration`. Items arrive in their original
format unless asked otherwise (both on `GlassPhotosPicker` and
`pickGlassPhotos`):
- `maxWidth` / `maxHeight` (pixels) scale larger photos down to fit,
  keeping the aspect ratio.
- `imageQuality` (0-100) re-encodes JPEG and HEIC photos at that quality.
- `compatibleFormat: true` turns HEIC/HEIF photos into JPEG and HEVC
  videos into H.264 `.mp4` (iOS: `AVAssetExportSession`; Android:
  `MediaCodec`, audio copied as is, rotation kept). A video that fails to
  convert (no H.264 encoder for its size, an unsupported audio track)
  arrives as HEVC with `conversionFailed: true`.

A re-encoded photo is upright and keeps its format where the platform can
write it (iOS: HEIC, JPEG, PNG; Android: JPEG, PNG), else becomes JPEG;
its metadata (EXIF, location) is dropped. GIFs are left as they are. The
app owns the copies: move what it
keeps, and call `clearGlassPickedPhotos()` to delete the folder.

### Swipe actions

```dart
GlassSwipeActions(
  key: ValueKey(item.id),
  leading: [GlassSwipeAction(icon: CupertinoIcons.pin_fill, label: 'Pin',
      color: CupertinoColors.systemOrange, onPressed: () => pin(item))],
  trailing: [GlassSwipeAction(icon: CupertinoIcons.trash, label: 'Delete',
      color: GlassSystemColors.red, onPressed: () => delete(item))],
  child: ItemRow(item),
)
```

Swiping a row aside reveals tinted glass capsules with their labels
underneath:
- The row rubber-bands past its actions and springs open or shut.
- A full swipe (`allowsFullSwipe`, the default) runs the outermost action,
  with a haptic as it passes the threshold.
- Only one row is open at a time. A scroll or a tap closes it.
- `groupTag` limits that to rows with the same tag;
  `GlassSwipeActions.closeGroup(tag)` and `closeAll()` close them from code.
- VoiceOver and TalkBack get the actions as custom actions.

### iOS 26 colours

`GlassSystemColors` holds iOS 26's red, blue, orange and green. Flutter's
`CupertinoColors` still has the iOS 18 values.

## Component fidelity

Every component is measured against its SwiftUI counterpart on the iOS
26.4 simulator, using reference scenes in
`example/ios/Runner/ControlScenes.swift`:
- `tool/reference/measure_components.py` reads the geometry and colours
  into `controls.json`, and `test/reference/` pins the Dart constants to
  it.
- A Flutter twin of each scene (`-twin <scene>`) is scored per component by
  `tool/reference/compare_components.py`, using the fidelity harness's
  measures.

Over 24 component views:

| path | pass | median SSIM | median dE |
|---|---|---|---|
| native glass | 9/24 | 0.960 | 1.11 |
| shader glass | 8/24 | 0.960 | 1.14 |

Passing views: the toggles, slider, toolbar, sheets, stepper and picker
menu. The remaining gaps:
- SF Symbols' weights against CupertinoIcons.
- UIKit's text rendering against Flutter's.
- The popover and menu glass tone.
- The calendar's first weekday, which follows the region.

`GlassChip`, `GlassBadge`, `GlassPageControl` and `GlassProgressIndicator`
are geometry-estimated, not yet measured.

## Adaptive foreground over busy content

By default the label colour follows the theme's brightness. To follow the
content actually behind the glass, wrap that content in a
`GlassBackdropSource`; each group then samples it (a small GPU readback every
250 ms) and `GlassForeground.labelColorOf(context)` switches between dark and
light labels.

```dart
Stack(
  children: [
    GlassBackdropSource(child: photoGrid),
    Align(
      alignment: AlignmentDirectional.bottomCenter,
      child: const Text('Now playing').glassEffect(),
    ),
  ],
)
```

## RTL and accessibility

- **RTL:** every component lays out by the reading direction — insets are
  directional (`EdgeInsetsDirectional`), the tab bar, segmented control,
  slider fill, list chevrons, swipe-action edges and back button all follow
  `Directionality`. The glass light angle is not mirrored, matching iOS.
- **Screen readers:** one semantics node per control; an explicit
  `semanticLabel` replaces the visible text where one exists
  (`GlassButton`, `GlassMenuButton`, `GlassMenuItem`, `GlassPicker`,
  `GlassSearchField`, `GlassTextField`, `showGlassPopover`, and others).
  Tabs, segments and rows are selectable buttons; swipe actions and context
  menus appear as custom actions; toasts are live regions; tapping outside
  a menu or picker is announced as "Dismiss".
- **Reduce Motion:** springs are dropped — the tab bar's lens and pill, the
  toggle thumb, the sheet, the toast (fades instead of sliding) and the
  progress indicator's easing all move or appear without animating.
- **Large text** (Dynamic Type / `MediaQuery.textScaler`): content grows
  and wraps — buttons, chips, fields, pickers, menus, alerts (buttons
  stacked at the accessibility sizes, scrolling when tall), action sheets
  and toasts. Fixed-height chrome keeps its default text size, as iOS's:
  the floating tab bar, the inline navigation title, segmented controls,
  wheels, badges and accessory gauges (the large title still scales).
- **Keyboard:** interactive glass takes focus and shows a focus ring;
  `onPressed` glass and buttons answer Enter and Space.
- **Reduce Transparency** (iOS) turns glass into an opaque surface, as iOS
  does (on iOS 26+ SwiftUI's glass does this itself). Set
  `AdaptiveLiquidGlass.reduceTransparency = true` to force the opaque
  fallback on any platform, native glass included (to test it, or for an
  in-app setting); `null` follows the system.
- **On/Off Labels** (iOS, `MediaQuery.onOffSwitchLabelsOf`) draws the "I"
  and "O" marks on `GlassToggle`'s track, as iOS does, so its state does not
  rest on colour alone. The Material path keeps Material 3's `Switch`.
- **Increase Contrast / high contrast** (`MediaQuery.highContrastOf`) turns
  the Flutter-drawn glass into an opaque surface, so text over it keeps its
  contrast; on iOS 26+ SwiftUI's own glass follows the setting itself, and
  Material is unchanged. Nothing to call — it follows the system. To try it
  without changing device settings, override the `MediaQuery`:

  ```dart
  MediaQuery(
    data: MediaQuery.of(context).copyWith(highContrast: true),
    child: const LiquidGlass(child: Text('Readable on a solid surface')),
  )
  ```

## Testing your app

Under `flutter test` the package's shaders do not load and the iOS
plugin is absent, so which path glass takes depends on the machine.
`GlassTesting` pins it:

```dart
import 'package:adaptive_liquid_glass/glass_testing.dart';

setUp(() => GlassTesting.setUp(iosMajorVersion: 18));
tearDown(GlassTesting.reset);

testWidgets('pays', (tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.tap(find.text('Pay'));
  // ...
}, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
```

- iOS before 26 tests the Flutter-drawn glass. iOS 26 picks native glass,
  which widget tests do not draw.
- Android (the default `platform` follows the variant) tests the
  Material path.
- `shaderSupported: false` and `reduceTransparency: true` test the
  degraded and opaque fallbacks.

## Known limitations

- **Native mode, runtime light→dark flip:** on iOS 26, 71 of 72 measured
  brightness flips at runtime match SwiftUI. One does not: a regular glass
  capsule over a photo, flipped from light to dark, keeps part of Apple's
  previous look (SSIM 0.84 against a dark launch, which matches). Apple's
  glass appears to keep state from glass drawn earlier in the process; it
  is not fixed by rebuilding the glass.
- **Native interactive glass:** Flutter keeps the touches, so SwiftUI's
  own press never runs on native glass. The package draws its growth,
  stretch and light instead, measured from SwiftUI's (on at the touch,
  held 0.33 s past the release; in-shape error over a press 1.1 light,
  1.6 dark, from 4.1 and 6.0). The light is measured on regular glass
  only; clear glass uses the same values and is further off (in-shape
  error about 2.5x regular's on the same recording).
- **Tab bar:** close to iOS 26.4's `TabView`, not identical. Over photos
  the shader-drawn bar draws untinted labels vibrant, as iOS does (each
  glyph takes the hue of the glass behind it); the selected tint follows
  the glass only by half, and native-mode labels keep flat colours. The native-mode
  lens is UIKit glass and does not bend the bar's edges as iOS's does.
  Icons are CupertinoIcons unless you use `GlassTabBarItem.symbol` (SF
  Symbols drawn by iOS).
- **Photos picker:** items are copied into a temporary or cache directory
  before `onPicked` runs, so very large videos (and H.264 conversions) take
  time to arrive, and the copies stay until `clearGlassPickedPhotos()` or
  the OS deletes them. On Android the H.264 conversion (HEVC videos with
  `compatibleFormat`) runs on the device's codecs, slower than real time
  on low-end phones and emulators. The Android
  document-picker fallback (before Android 11, or without the SDK
  extension) cannot enforce `maxSelection` in its UI; extra items are
  dropped from the end and counted in `GlassPickedPhotos.droppedCount`.
- **iOS look on Android (`GlassRenderMode.shader`):** needs Impeller.
  Where `ImageFilter.isShaderFilterSupported` is false (Skia, or
  `--no-enable-impeller`, an opt-out Flutter is removing), glass falls
  back to a frosted blur with no lens, rim or merging. GPU memory is the
  limit: under Impeller every shader backdrop renders into full-screen
  offscreen textures whatever the glass's size, about 110-200 MB each on a
  1080x2340 phone, and a screen with 10+ groups drawn group by group
  reached 1.1-3.9 GB and was killed by Android's low-memory killer. So on
  Android all shader glass of a route draws through one shared layer,
  painted after the route: one backdrop capture and one blur per stratum
  (glass over glass starts a new stratum), with each group's content
  composited after its glass. The example Gallery peaks about 0.9 GB over
  idle with every group shader glass (3.9 GB group by group). Limits of
  the layer: non-glass content painted after a group in the same route
  and overlapping its glass draws beneath that glass; wrap such content in
  `GlassOverlayContent` to keep it above (the package's own
  content laid over glass in a sibling, like the tab bar's row and a
  sheet's content, is handled); menus draw their glass group by group, and so does a page while a transition snapshots it
  (`ZoomPageTransitionsBuilder`; a transient peak of about 0.5 GB on the
  emulator, with 8 groups as with 24, since the snapshot renders once). A
  transition that moves the page through its own painter without a
  snapshot (`allowSnapshotting: false` on a Zoom transition) draws the
  glass in place, inside the page, for the transition only. The tab bar's vibrant labels read the layer's glass as
  they do in place (about 100 MB more over the Gallery's run).
  `LiquidGlassThemeData.androidShaderBudget` (default null: no cap) still
  caps the groups that draw group by group; the rest draw a frosted blur.
  Fonts stay Roboto (not SF Pro), and scroll physics,
  the back gesture and haptics stay Android's; making those iOS-like is
  not part of the package.
- **Full-screen cover drag:** SwiftUI's cover has no drag to dismiss, so
  `dragToDismiss` (off by default) borrows the sheet's thresholds.
- **Colour picker sheet:** laid out and coloured as iOS 26.4's
  UIColorPickerViewController, light and dark (measured, saved colours,
  Spectrum map and the eyedropper's loupe included). Its eyedropper reads only what the app itself draws (the
  page under the sheet): not other apps, the status bar or platform views
  such as maps, web views and native-mode glass. Saved colours live in
  memory unless the app passes `savedColors` / `onSavedColorsChanged` and
  stores them; a long press opens UIKit's context menu to delete one.

## License

MIT — see [LICENSE](LICENSE). The package includes code adapted from
liquid_glass_widgets (MIT); see [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES).
