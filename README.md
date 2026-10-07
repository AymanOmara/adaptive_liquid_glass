# adaptive_liquid_glass

iOS 26 **Liquid Glass** for Flutter, measured against SwiftUI, with Material 3
counterparts on Android, behind one API. App code never branches on platform.

- **iOS 26+:** SwiftUI's own Liquid Glass, pixel-identical to a SwiftUI app.
- **Older iOS:** a fragment-shader glass tuned to SwiftUI's.
- **Android:** a Material 3 surface (colours from your `Theme`, ink ripple
  for interactive glass). No glass code runs.
- **RTL-safe:** directional insets throughout; the light angle is not
  mirrored, matching iOS.

## Fidelity

The shipped glass constants are certified against Apple's SwiftUI
`.glassEffect` on the reference simulator (iPhone 17 Pro, iOS 26.4):
**46/75 scenes pass** the official bars (SSIM ≥ 0.97, CIEDE2000 ΔE ≤ 2.0),
median SSIM 0.9828 / median ΔE 1.09, min SSIM 0.9532, **0 scenes below
SSIM 0.95** on the 75 in-set scenes (a 48-scene held-out set the fit never
saw scores 18/48, min 0.9470). Model↔Flutter parity is 75/75. The full
per-scene record, diagnosis and known residuals:
`docs/superpowers/notes/fidelity-status.md`.

To re-run, follow `tool/fidelity/README.md`: capture both renderers with
`tool/fidelity/capture.sh build/fidelity/<run>` (setup and options
documented there), then score with
`tool/fidelity/.venv/bin/python tool/fidelity/compare.py build/fidelity/<run>`.

## Quick start

### Install

```yaml
dependencies:
  adaptive_liquid_glass: ^0.1.0-dev.7
```

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
```

No setup is needed: no theme, no initialisation call, no platform checks.

### Optional: preload the shaders

Without it, the shaders load on first use: glass draws as a plain blur for a
frame or two before switching over in place, and the scroll edge and tab lens
use their fallbacks until ready. `AdaptiveLiquidGlass.initialize()` loads
them all before the first frame; it is a no-op on Android's Material path and
safe to call twice.

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdaptiveLiquidGlass.initialize();
  runApp(const MyApp());
}
```

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

With `onPressed` the glass is a button: it gets button semantics, takes
focus, answers Enter and Space, and its glass turns interactive (the press
stretch and glow on iOS, the ripple on Android). Pass
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

The shader (older iOS, or `mode: shader`) loads on first use. Until it is
ready (usually a frame or two), glass draws as a plain blur and then switches
over in place. To skip that, optionally load the shaders before the first
frame:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdaptiveLiquidGlass.initialize();
  runApp(const MyApp());
}
```

### Android

On Android, and any platform other than iOS, `auto` renders Material 3:

| Glass | Material 3 |
|---|---|
| `Glass.regular` | `surfaceContainerHigh`, elevation 1 |
| `Glass.clear` | `surfaceContainerLow` at 85 % opacity |
| `.tint(color)` | `primaryContainer` of `ColorScheme.fromSeed(color)` |
| `.interactive()` / `onPressed` | `InkWell` ripple |
| `GlassGroup` | layout only (no merging) |

Text and icons on the surface use its matching "on" colour (`onSurface`, or
the tint's `onPrimaryContainer`).

### Accessibility

- **Reduce Transparency** (iOS) turns glass into an opaque surface, as iOS
  does (on iOS 26+ SwiftUI's glass does this itself).
- **Increase Contrast** strengthens the rim and reduces lensing on the shader
  path; on iOS 26+ it is whatever SwiftUI's own glass does.
- **Reduce Motion** keeps the press glow and drops the stretch and bounce.
- Glass is decoration: semantics come from the child, plus button semantics
  when `onPressed` is set.

## Cookbook

Every recipe is in the example app's Gallery (`example/lib/gallery.dart`).

### Glass button

```dart
const Text('Save').glassEffect(
  onPressed: save,
  padding: const EdgeInsetsDirectional.symmetric(horizontal: 24, vertical: 14),
)
```

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

Tabs sit `itemWidth` (86.15, as on iOS) apart and move closer evenly when
the bar would not fit, so five tabs fit a phone. Press, drag and release
follow iOS 26's measured springs: the lens trails the finger and wobbles with
its acceleration. The lens is drawn with the package's shader, fitted to iOS
26.4's tab lens: unfrosted, it refracts what lies just outside its edge into
a band and splits colour there. So that the lens can refract the bar, the bar
is shader glass too whenever the shader is available (pass `mode:` to force
another path). Give a tab an `activeIcon` for its selected
state. The selected tab takes `selectedColor` (default: the Cupertino theme's
primary colour); the others take glass's readable colour. On Android it is a
Material 3 `NavigationBar` in the same floating capsule. Each tab is a
selectable button for VoiceOver and TalkBack, the order follows the
reading direction, and with Reduce Motion the pill moves without animating.

### Buttons

`GlassButton` is SwiftUI's `.buttonStyle(.glass)` and `.glassProminent`,
with roles, control sizes, border shapes, and disabled and loading states.
Sizes are measured from SwiftUI on iOS 26.4 (iOS 26 draws mini as small and
extraLarge as large; icon-only buttons are capsules 12 pt wider than tall):

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

On Android it is a Material 3 `FilledButton` (`.tonal` for `glass`), an
`IconButton` for icon-only buttons, and a `TextButton` for `cancel`.

### Navigation bar

```dart
// Inline title
Scaffold(
  extendBodyBehindAppBar: true,
  appBar: GlassNavigationBar(title: const Text('Detail'), actions: [...]),
  body: ...,
)

// Large title
CustomScrollView(slivers: [
  SliverGlassNavigationBar(largeTitle: const Text('Inbox'), actions: [...]),
  SliverList(...),
])
```

No bar background, as on iOS 26: a glass back button when the route can
pop, the actions merged into one glass capsule, and a fade at the top once
content is under the bar. The large title scrolls away with the content,
the inline title fades in once it has gone, and pulling down stretches the
large title. Metrics are measured from SwiftUI's `NavigationStack`
(`tool/reference/`). On Android these are `AppBar` and `SliverAppBar.large`.

### Screen layout

```dart
GlassScaffold(
  navigationBar: const GlassNavigationBar(title: Text('Inbox')),
  tabBar: GlassTabBar(items: tabs, selectedIndex: tab, onSelected: pick),
  bottomAccessory: GlassBottomAccessory(child: nowPlaying), // optional
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

### Toggle, slider, segmented control

```dart
GlassToggle(value: wifi, onChanged: (v) => setState(() => wifi = v))
GlassSlider(value: volume, onChanged: (v) => setState(() => volume = v))
GlassSegmentedControl<Period>(
  segments: const [
    GlassSegment(value: Period.day, label: Text('Day')),
    GlassSegment(value: Period.week, label: Text('Week')),
  ],
  selected: period,
  onChanged: (p) => setState(() => period = p),
)
```

As in iOS 26, each thumb turns into a clear glass lens while it is
pressed or dragged. The segmented control's lens slides between segments
with a haptic on each one. All three follow the reading direction and
Reduce Motion. On Android they are `Switch`, `Slider` and
`SegmentedButton`.

### Sheet, menu, search

```dart
showGlassSheet<void>(context: context, builder: (_) => details);

GlassMenuButton(
  icon: CupertinoIcons.ellipsis,
  semanticLabel: 'More',
  items: [
    GlassMenuItem(label: 'Copy', icon: CupertinoIcons.doc_on_doc,
        onSelected: copy),
    GlassMenuItem(label: 'Delete', icon: CupertinoIcons.trash,
        destructive: true, onSelected: delete),
  ],
)

GlassSearchField(onChanged: (q) => setState(() => query = q))
```

- **Sheet:** floats in from the screen's edges with continuous corners.
- **Menu:** a glass panel that springs out of its button.
- **Search field:** a glass capsule with a localized placeholder and a
  clear button.

On Android they become a modal bottom sheet, a `MenuAnchor` and a
`SearchBar`.

### Swipe actions

```dart
GlassSwipeActions(
  key: ValueKey(item.id),
  leading: [GlassSwipeAction(icon: CupertinoIcons.pin_fill, label: 'Pin',
      color: CupertinoColors.systemOrange, onPressed: () => pin(item))],
  trailing: [GlassSwipeAction(icon: CupertinoIcons.trash, label: 'Delete',
      color: CupertinoColors.systemRed, onPressed: () => delete(item))],
  child: ItemRow(item),
)
```

Swiping a row aside reveals tinted glass capsules with their labels
underneath:
- The row rubber-bands past its actions and springs open or shut.
- A full swipe runs the outermost action, with a haptic as it passes the
  threshold.
- Only one row is open at a time. A scroll or a tap closes it.
- VoiceOver and TalkBack get the actions as custom actions.

All of these are in `example/lib/components_demo.dart`
(`flutter run -t lib/components_demo.dart`).

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
buttons side by side. The confirmation dialog is a 240-pt card with its
buttons stacked. As in iOS 26, its cancel action isn't drawn: a tap
outside takes it. On Android they are `AlertDialog`s.

### Sheet detents

```dart
showGlassSheet<void>(
  context: context,
  detents: const [GlassSheetDetent.medium, GlassSheetDetent.large],
  builder: (_) => details,
);
```

The sheet works like SwiftUI's `presentationDetents`:
- It follows a drag between its detents, and a drag or fling below the
  lowest one dismisses it.
- At a partial detent it is floating glass.
- At `large` it runs edge to edge, opaque, with the screen's own corners.

### Popover, picker, stepper, date picker

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

GlassStepper(value: count, max: 10, onChanged: (v) => setState(() => count = v))

GlassDatePicker(
  value: date,
  firstDate: DateTime(2020),
  lastDate: DateTime(2030),
  onChanged: (d) => setState(() => date = d),
)
```

- **Popover:** the glass bubble opens over its button, and the button steps
  aside while it's open, as in SwiftUI. `showGlassPopover` anchors one to
  any widget.
- **Picker:** SwiftUI's menu style. It opens the glass menu with the
  current choice checked.
- **Date picker:** the compact style. It opens a glass calendar.

### Context menu and search tab

```dart
GlassContextMenu(
  items: [GlassMenuItem(label: 'Copy', icon: CupertinoIcons.doc_on_doc,
      onSelected: copy)],
  child: photo,
)

GlassTabBar(items: tabs, selectedIndex: tab, onSelected: pick,
    onSearch: openSearch)
```

- **Context menu:** a long-press lifts the item over the blurred page and
  opens the glass menu beside it.
- **Search tab:** `onSearch` adds iOS 26's search tab, a glass circle
  beside the bar.

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

## Adaptive foreground over busy content

By default the label colour follows the platform brightness. To follow the
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

## Fidelity

The shader is fitted against SwiftUI's own Liquid Glass, rendered on the
reference simulator (iPhone 17 Pro, iOS 26.4), over 75 scenes (regular,
clear and tinted glass; capsules, circles and rounded rectangles; photo,
text and gradient backgrounds; light and dark; merged groups):

| path | result |
|---|---|
| Shader (iOS < 26, or `mode: shader`) | every scene at SSIM ≥ 0.95 (minimum 0.9532); 46/75 pass the strict bars (SSIM ≥ 0.97 and ΔE ≤ 2.0); median SSIM 0.983, median ΔE 1.09 |
| Native (iOS 26+, the default) | 75/75 at parity with SwiftUI (minimum SSIM 0.9996, maximum ΔE 0.05) |

Press and morph motion uses SwiftUI's measured springs (press-in, release
and `.bouncy` morph) and a size-dependent press growth. The harness lives in
`tool/fidelity/` (see its README).

## Known limitations

- **Context menu not measured:** synthetic touches on the simulator do
  not open SwiftUI's `.contextMenu`, so `GlassContextMenu` follows the
  system's look but has not been measured. Springs and press animations of
  the newer components are not measured either.
- **Native mode, runtime light→dark flip:** on iOS 26, 71 of 72 measured
  brightness flips at runtime match SwiftUI. One does not: a regular glass
  capsule over a photo, flipped from light to dark, keeps part of Apple's
  previous look (SSIM 0.84 against a dark launch, which matches). Apple's
  glass appears to keep state from glass drawn earlier in the process; it
  is not fixed by rebuilding the glass.
- **Native interactive glass:** pressing native glass gets this package's
  stretch and growth, but not SwiftUI's own touch glow.
- **Shader glow:** the shader's touch glow is brighter than SwiftUI's.
