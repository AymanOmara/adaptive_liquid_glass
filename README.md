# adaptive_liquid_glass

iOS 26 **Liquid Glass** for Flutter, measured against SwiftUI, with Material 3
counterparts on Android, behind one API. App code never branches on platform.

- **iOS:** a fragment-shader glass tuned to SwiftUI's, or Apple's own UIKit
  glass on iOS 26+ when you opt in.
- **Android:** a Material 3 surface (colours from your `Theme`, ink ripple
  for interactive glass). No glass code runs.
- **RTL-safe:** directional insets throughout; the light angle is not
  mirrored, matching iOS.

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
    nativeEnabled: true,        // Apple's own glass on iOS 26+
  ),
  child: MaterialApp(home: const HomePage()),
)
```

`nativeEnabled` draws with UIKit's `UIGlassEffect` on iOS 26 and later
(through a platform view), and falls back to the shader elsewhere. To force a
path for one subtree, pass `mode:` to `GlassGroup` or `LiquidGlass`
(`GlassRenderMode.auto`, `shader`, `native` or `material`).

The shader loads on first use. Until it is ready (usually a frame or two),
glass draws as a plain blur and then switches over in place. To skip that,
optionally load it before the first frame:

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
  does.
- **Increase Contrast** strengthens the rim and reduces lensing.
- **Reduce Motion** keeps the press glow and drops the stretch and bounce.
- Glass is decoration: semantics come from the child, plus button semantics
  when `onPressed` is set.

## Cookbook

Every recipe is in the example app's Gallery (`example/lib/gallery.dart`).

### Glass button

```dart
LiquidGlass(
  onPressed: save,
  padding: const EdgeInsetsDirectional.symmetric(horizontal: 24, vertical: 14),
  child: const Text('Save'),
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
