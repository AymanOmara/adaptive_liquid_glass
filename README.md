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

The package is not on pub.dev yet (coming soon). Depend on it from git:

```yaml
dependencies:
  adaptive_liquid_glass:
    git:
      url: https://github.com/aymanomara/adaptive_liquid_glass
```

After the pub.dev release, this will be:

```yaml
dependencies:
  adaptive_liquid_glass: ^0.1.0  # after release
```

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
```

No setup is needed: no theme, no initialisation call, no platform checks.

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
over in place. To skip that, optionally load it before the first frame:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlass.precache();
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
follow iOS 26's measured springs: the lens trails the finger, wobbles with
its acceleration and bends the tabs at its rim. Give a tab an `activeIcon` for its selected
state. The selected tab takes `selectedColor` (default: the Cupertino theme's
primary colour); the others take glass's readable colour. On Android it is a
Material 3 `NavigationBar` in the same floating capsule. Each tab is a
selectable button for VoiceOver and TalkBack, the order follows the
reading direction, and with Reduce Motion the pill moves without animating.

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

- **Native mode, runtime light→dark flip:** on iOS 26, 71 of 72 measured
  brightness flips at runtime match SwiftUI. One does not: a regular glass
  capsule over a photo, flipped from light to dark, keeps part of Apple's
  previous look (SSIM 0.84 against a dark launch, which matches). Apple's
  glass appears to keep state from glass drawn earlier in the process; it
  is not fixed by rebuilding the glass.
- **Native interactive glass:** pressing native glass gets this package's
  stretch and growth, but not SwiftUI's own touch glow.
- **Shader glow:** the shader's touch glow is brighter than SwiftUI's.
