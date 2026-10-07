# adaptive_liquid_glass

iOS 26 **Liquid Glass** for Flutter, measured against SwiftUI, with Material 3
counterparts on Android, behind one API. App code never branches on platform.

- **iOS 26+:** SwiftUI's own Liquid Glass, pixel-identical to a SwiftUI app.
- **Older iOS:** a fragment-shader glass tuned to SwiftUI's.
- **Android:** a Material 3 surface (colours from your `Theme`, ink ripple
  for interactive glass). No glass code runs.
- **RTL-safe:** directional insets throughout; the light angle is not
  mirrored, matching iOS.

## Screenshots

The screenshot gallery shows the example app on iOS 26.4 in light and dark
modes. Plain backgrounds make the controls easier to inspect; photo backgrounds
show the glass effect over imagery.

## Fidelity

The shipped glass constants are certified against Apple's SwiftUI
`.glassEffect` on the reference simulator (iPhone 17 Pro, iOS 26.4):

| path | result |
|---|---|
| Shader (iOS < 26, or `mode: shader`) | every scene at SSIM ≥ 0.95 (minimum 0.9525); 55/75 pass the strict bars (SSIM ≥ 0.97 and ΔE ≤ 2.0); median SSIM 0.983, median ΔE 1.29 |
| Native (iOS 26+, the default) | 75/75 at parity with SwiftUI (minimum SSIM 0.9996, maximum ΔE 0.05) |

Over 75 scenes (regular, clear and tinted glass; capsules, circles and
rounded rectangles; photo, text and gradient backgrounds; light and dark;
merged groups): **55/75 scenes pass** the official bars (SSIM ≥ 0.97,
CIEDE2000 ΔE ≤ 2.0), median SSIM 0.9830 / median ΔE 1.29, min SSIM 0.9525,
**0 scenes below SSIM 0.95** on the 75 in-set scenes (baseline
`build/fidelity/g13-2`). Model↔Flutter parity is 75/75.
The full per-scene record, diagnosis and known residuals:
`docs/superpowers/notes/fidelity-status.md`.

Press and morph motion uses SwiftUI's measured springs (press-in, release
and `.bouncy` morph) and a size-dependent press growth. To re-run, follow
`tool/fidelity/README.md`: capture both renderers with
`tool/fidelity/capture.sh build/fidelity/<run>` (setup and options
documented there), then score with
`tool/fidelity/.venv/bin/python tool/fidelity/compare.py build/fidelity/<run>`.

## Quick start

### Install

```yaml
dependencies:
  adaptive_liquid_glass: ^0.1.0-dev.9
```

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
```

No setup is needed: no theme, no initialisation call, no platform checks.

### Setup (optional)

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
| `LiquidGlassTheme`, `LiquidGlassThemeData` | Optional app-wide defaults (`defaultGlass`, `defaultMode`, `lightAngle`) | — |
| `GlassRenderMode` | Force `auto`, `shader`, `native` or `material` for a subtree | — |
| `AdaptiveLiquidGlass.initialize` | Optional: preload the shaders in `main()` | no-op |
| `GlassBackdropSource`, `GlassForeground` | Adaptive label colour over busy content | — |
| `GlassSystemColors` | iOS 26's red, blue, orange and green | — |
| `GlassButton` (`+ .icon`), `GlassButtonRole`, `GlassButtonStyle`, `GlassButtonShape`, `GlassControlSize`, `GlassControlSizeScope` | SwiftUI's glass and prominent buttons, roles, sizes, shapes, loading | `FilledButton` / `IconButton` / `TextButton` |
| `GlassBackButton` | Circular glass chevron that pops the route | `BackButton` |
| `GlassNavigationBar`, `SliverGlassNavigationBar`, `GlassScrollEdgeStyle` | Inline and large-title nav bars, no bar background; `scrollEdgeStyle` blurs content scrolled under | `AppBar` / `SliverAppBar.large` |
| `GlassScaffold`, `GlassBottomAccessory` | An iOS 26 screen in one widget; the Music-style mini-player slot | Same layout, Material bars |
| `GlassToolbar`, `GlassToolbarSpacer` | The floating bottom toolbar, merged capsules | Material buttons |
| `GlassTabBar`, `GlassTabBarItem` | iOS 26's floating tab bar, draggable lens, `onSearch` tab | `NavigationBar` |
| `GlassToggle` | iOS 26's switch, glass lens thumb | `Switch` |
| `GlassSlider` | Slider with a glass lens thumb, optional `divisions` | `Slider` |
| `GlassSegmentedControl`, `GlassSegment` | Segmented control, sliding lens | `SegmentedButton` |
| `GlassStepper` | Minus/plus capsule stepper | pair of icon buttons |
| `GlassPicker`, `GlassPickerItem` | Menu-style picker, current choice checked | `DropdownButton` |
| `GlassWheelPicker` | `.pickerStyle(.wheel)`: scrolling rows under a clear-glass selection band, haptics | `ListWheelScrollView` on a Material surface |
| `GlassDatePicker` | Compact date picker opening a glass calendar | text button + `showDatePicker` |
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

Sizes are measured from SwiftUI on iOS 26.4 (iOS 26 draws mini as small and
extraLarge as large; icon-only buttons are capsules 12 pt wider than tall).
Set a default with `GlassControlSizeScope(size: GlassControlSize.small, ...)`.

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

Tabs sit `itemWidth` (86.0, as on iOS) apart and move closer evenly when
the bar would not fit, so five tabs fit a phone. Press, drag and release
follow iOS 26's measured springs: the lens trails the finger and wobbles with
its acceleration. The lens is drawn with the package's shader, fitted to iOS
26.4's tab lens: unfrosted, it refracts what lies just outside its edge into
a band and splits colour there. So that the lens can refract the bar, the bar
is shader glass too whenever the shader is available (pass `mode:` to force
another path). Give a tab an `activeIcon` for its selected
state. The selected tab takes `selectedColor` (default: iOS 26's tab bar
blue, measured from SwiftUI's `TabView`); the others take glass's readable
colour. `onSearch` adds iOS 26's search tab, a glass circle beside the bar.
On Android it is a Material 3 `NavigationBar` in the same floating capsule.
Each tab is a selectable button for VoiceOver and TalkBack, the order follows
the reading direction, and with Reduce Motion the pill moves without
animating.

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

### Toggle, slider, segmented control, stepper

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
GlassStepper(value: count, min: 0, max: 10, onChanged: (v) => setState(() => count = v))
```

As in iOS 26, each thumb turns into a clear glass lens while it is
pressed or dragged. The segmented control's lens slides between segments
with a haptic on each one. All four follow the reading direction and
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
- At a partial detent it is floating glass.
- At `large` it runs edge to edge, opaque, with the screen's own corners.
- `GlassSheetDetent.fraction(0.6)` and `.height(400)` make custom detents.

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
value it closed with) to close it from anywhere. Layout matches SwiftUI;
the transition timing is estimated. On Android it is a Material 3
full-screen dialog.

### Menu button and controller

```dart
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
```

The menu opens over the button, from its top corner, as SwiftUI's `Menu`
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
- **Keyboard:** interactive glass takes focus and shows a focus ring;
  `onPressed` glass and buttons answer Enter and Space.
- **Reduce Transparency** (iOS) turns glass into an opaque surface, as iOS
  does (on iOS 26+ SwiftUI's glass does this itself).
- **Increase Contrast** strengthens the rim and reduces lensing on the shader
  path; on iOS 26+ it is whatever SwiftUI's own glass does.

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

## License

MIT — see [LICENSE](LICENSE). The package includes code adapted from
liquid_glass_widgets (MIT); see [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES).
