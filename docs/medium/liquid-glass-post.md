# I Measured Apple's Liquid Glass Against SwiftUI, Pixel by Pixel — and Brought It to Flutter

*iOS 26 Liquid Glass for Flutter, with Material 3 on Android, behind one API.*

![Adaptive Liquid Glass demo on iOS 26](https://raw.githubusercontent.com/AymanOmara/adaptive_liquid_glass/main/screenshots/demo.gif)

When Apple shipped Liquid Glass in iOS 26, every Flutter developer I know asked the same question: *how do we get that in our apps?*

There are already a few glass packages out there. Most of them look "glassy". None of them answered the question I actually cared about: **does it look like iOS?** Not "close enough in a screenshot" — the same as a native SwiftUI app, side by side.

So I built [`adaptive_liquid_glass`](https://pub.dev/packages/adaptive_liquid_glass), and instead of eyeballing it, I measured it.

---

## The idea: one API, three renderers

App code never checks the platform. You write the widget once, and the package picks the right renderer:

- **iOS 26+** → SwiftUI's own Liquid Glass. Not an imitation — the real thing, pixel-identical to a SwiftUI app.
- **Older iOS** → a fragment-shader glass, tuned against SwiftUI's.
- **Android** → a proper Material 3 surface: colours from your `Theme`, ink ripple on interactive glass. No glass code runs at all.

Android users get an app that feels like Android. iOS users get an app that feels like iOS 26. You write it once.

It's also **RTL-safe**: directional insets everywhere, and the light angle is *not* mirrored — matching what iOS actually does.

---

## One line of code

The API mirrors SwiftUI's `.glassEffect(_:in:)`:

```dart
const Text('Hello').glassEffect(padding: const EdgeInsets.all(12));

// A glass button, also one line:
const Icon(Icons.add).glassEffect(onPressed: add);
```

Need more control? The full widget:

```dart
LiquidGlass(
  glass: Glass.regular.tint(Colors.blue),
  shape: const GlassShape.rect(20),
  padding: const EdgeInsetsDirectional.all(16),
  onPressed: () {},            // makes it a button
  child: const Text('Continue'),
)
```

Presets cover the common cases — `Glass.regular`, `Glass.clear` (for photos and video), `Glass.smoke`, `Glass.accent`, `Glass.tinted(color)` — and they all chain: `Glass.smoke.interactive()`.

Pass `onPressed` and the glass becomes a real button: semantics, focus, Enter/Space, and the press stretch and glow on iOS (ripple on Android).

No theme, no init call, no platform checks required.

---

## Measuring instead of guessing

This is the part I'm proudest of.

I built a fidelity pipeline that renders the same scene twice — once in SwiftUI with `.glassEffect`, once in Flutter — on the same simulator (iPhone 17 Pro, iOS 26.4), then scores the difference with two metrics:

- **SSIM** (structural similarity — does it have the same shape, blur and highlights?)
- **CIEDE2000 ΔE** (perceptual colour difference — would your eye notice the tint is off?)

75 scenes: regular, clear and tinted glass; capsules, circles and rounded rectangles; photo, text and gradient backgrounds; light and dark; merged groups.

The results:

| Renderer | Result |
|---|---|
| **Native (iOS 26+)** | **75/75 at parity** with SwiftUI — min SSIM 0.9996, max ΔE 0.05 |
| **Shader (older iOS)** | every scene above SSIM 0.95; median SSIM 0.983, median ΔE 1.19 |

Motion got the same treatment. The press, release and morph animations use SwiftUI's **measured** springs, including its size-dependent press growth — a big button grows less than a small one, exactly like iOS.

And the pipeline ships in the repo, so anyone can re-run it.

---

## Not just a blur — a full component set

![GlassTabBar: press, tap and drag the lens](https://raw.githubusercontent.com/AymanOmara/adaptive_liquid_glass/main/screenshots/tabbar.gif)

Glass on its own isn't an app. So the package includes the iOS 26 controls, each with a Material 3 counterpart on Android:

- **Navigation:** tab bar (with the draggable lens), navigation bar, toolbar, screen layout
- **Controls:** buttons, toggles, text and search fields, chips, badges, page control, progress, gauges
- **Lists:** inset-grouped list sections, disclosure groups, swipe actions
- **Overlays:** sheets, menus, context menus, popovers, pickers, date picker, alerts, action sheets, toasts
- **States:** an empty state like SwiftUI's `ContentUnavailableView`

Glass next to glass goes in a `GlassGroup`, the package's version of SwiftUI's `GlassEffectContainer`. Members sample the same backdrop and can **blend and morph** into each other, just like SwiftUI.

Wherever a component's geometry was measured against SwiftUI, the docs say so. Wherever it wasn't yet, the docs say that too.

---

## Being honest about the gaps

I'd rather tell you what isn't perfect than have you find out in production:

- Native glass on iOS 26 doesn't get SwiftUI's own touch glow (it does get the stretch and growth).
- The shader's touch glow is a bit brighter than SwiftUI's.
- The tab bar is close to iOS 26.4's `TabView`, not identical — icons are CupertinoIcons, not SF Symbols.
- The context menu follows the system look but couldn't be measured (the simulator won't open it from synthetic touches).

The full list lives in the README's *Known limitations*.

---

## Try it

```yaml
dependencies:
  adaptive_liquid_glass: ^0.1.6
```

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
```

A complete small app — navigation bar, tab bar, controls, sheet, toast — is in `example/lib/quick_start.dart`.

- 📦 pub.dev: https://pub.dev/packages/adaptive_liquid_glass
- 💻 GitHub: https://github.com/AymanOmara/adaptive_liquid_glass

If you build something with it, I'd love to see it. Issues, ideas and PRs are welcome — especially if you catch a pixel that doesn't match iOS.

---

*Tags: Flutter, iOS, Liquid Glass, Dart, Mobile Development*
