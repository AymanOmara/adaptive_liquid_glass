# adaptive_liquid_glass Phase 1 (Core Material) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the `LiquidGlass` / `GlassGroup` core of the `adaptive_liquid_glass` Flutter plugin: SwiftUI-matched glass on iOS (shader, opt-in native), Material 3 on Android, with a fidelity harness that measures the match against real SwiftUI.

**Architecture:** Every `LiquidGlass` belongs to a `GlassGroup` (implicit when none is present). The group resolves one effective render mode, collects member shapes in a `GlassRegistry`, and in shader mode paints one clip + one `BackdropFilterLayer` whose `ImageFilter.shader` draws all members (lens, blur, rim, tint, shadow, smooth-min merge) in a single pass. Native mode swaps the backdrop for one `UiKitView` hosting `UIGlassContainerEffect` + `UIGlassEffect` subviews; material mode renders each member as a Material 3 surface.

**Tech Stack:** Flutter 3.47.6 (floor 3.32), Dart ≥ 3.8, Impeller fragment shaders (GLSL 460 via impellerc), Swift / UIKit (iOS 26 glass APIs), Python 3.14 + scikit-image for scoring, `idb` for touch injection, ffmpeg for frame extraction.

**Spec:** `docs/superpowers/specs/2026-10-04-phase1-core-material-design.md` (read §14 Amendments: they override earlier sections).

## Global Constraints

- Package name `adaptive_liquid_glass`; Flutter plugin, iOS native code only; no Android native code.
- `environment: sdk: ^3.8.0`, `flutter: ">=3.32.0"`.
- iOS deployment target 15.0; native mode only when iOS major ≥ 26.
- Runtime dependencies: Flutter SDK only (no `plugin_platform_interface`, no third-party packages).
- Max 16 shapes per group shader pass.
- Fidelity bars: SSIM ≥ 0.97 and mean CIEDE2000 ΔE ≤ 2.0 inside each scene's glass region (shape bounds inflated by 12 pt); reference runtime iOS 26.4, iPhone 17 Pro simulator (`E7A87B4A-3E48-44F8-A588-704D56774FF0`).
- Performance bar: 5-item glass tab bar over a scrolling list holds 60 fps on iPhone 12, profile build.
- All public API symbols carry `///` doc comments (`public_member_api_docs` is enabled).
- Lengths in public API and constants are logical pixels; the shader receives physical pixels.
- Layout code is direction-aware (`EdgeInsetsDirectional`, `AlignmentDirectional`); the light angle is not mirrored in RTL.
- Every commit message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Glass inside a scrolling list or during a route transition** — the lens must stay locked to what is behind the glass while it moves (no stale offset). Pinned in Task 10 (scroll and route-transition tests) and Task 8 (probe confirms texture space).
2. **Zero-size, off-screen or not-yet-laid-out members** — must not crash or emit NaN uniforms; they are skipped. Pinned in Task 7 (packer skips empty/non-finite rects) and Task 10 (zero-size widget test).
3. **The shader asset still loading on the first frame** — the child renders without glass instead of throwing; glass appears once loaded. Pinned in Task 10.
4. **More than 16 members in one group** — extra members still render (own implicit group) and a non-fatal error is reported. Pinned in Task 6 and Task 10.
5. **Reduce Transparency toggled while the app runs** — every glass widget switches to opaque without a restart. Pinned in Task 3 (event channel), Task 4 (resolver) and Task 10 (live toggle widget test).

---

## File Map

| Path | Responsibility |
|---|---|
| `pubspec.yaml`, `analysis_options.yaml`, `LICENSE`, `CHANGELOG.md`, `README.md` | package metadata |
| `lib/adaptive_liquid_glass.dart` | public exports |
| `lib/testing.dart` | exports `GlassConstants` and friends for the example/fitting harness |
| `lib/src/core/glass.dart` | `Glass`, `GlassVariant` |
| `lib/src/core/glass_shape.dart` | `GlassShape` family, `concentricRadius` |
| `lib/src/core/glass_render_mode.dart` | `GlassRenderMode`, `EffectiveGlassMode` |
| `lib/src/core/glass_environment.dart` | `GlassEnvironment` value |
| `lib/src/core/render_mode_resolver.dart` | `resolveGlassMode` |
| `lib/src/core/theme.dart` | `LiquidGlassThemeData`, `LiquidGlassTheme` |
| `lib/src/core/glass_constants.dart` | fitted constants + JSON |
| `lib/src/core/swiftui_spring.dart` | SwiftUI spring → `SpringDescription` |
| `lib/src/platform/glass_platform.dart` | method/event channel, live `GlassEnvironment` |
| `lib/src/shader/glass_program.dart` | loads the fragment program once |
| `lib/src/shader/glass_uniforms.dart` | pure uniform packing |
| `lib/src/shader/texture_space.dart` | probe result: how shader coords map to the screen |
| `lib/src/shader/render_glass_backdrop.dart` | render object that pushes clip + backdrop layer |
| `lib/src/group/glass_entry.dart` | one member's registry record |
| `lib/src/group/glass_registry.dart` | members of a group |
| `lib/src/group/glass_group.dart` | `GlassGroup` widget, scope, mode resolution, motion listeners |
| `lib/src/group/morph_controller.dart` | `glassId` springs |
| `lib/src/interaction/press_controller.dart` | `.interactive()` spring + geometry |
| `lib/src/liquid_glass.dart` | `LiquidGlass` widget + member plumbing |
| `lib/src/material/material_glass.dart` | Android rendering |
| `lib/src/degraded/degraded_glass.dart` | no-shader fallback |
| `lib/src/native/native_glass_layer.dart` | `UiKitView` + per-view channel |
| `lib/src/foreground/glass_backdrop_source.dart` | `GlassBackdropSource`, sampling |
| `lib/src/foreground/glass_foreground.dart` | `GlassForeground` |
| `shaders/liquid_glass.frag` | the glass shader |
| `ios/Classes/AdaptiveLiquidGlassPlugin.swift` | channels + view factory registration |
| `ios/Classes/GlassPlatformView.swift` | native glass container view |
| `test/...` | unit + widget tests (mirrors `lib/src`) |
| `example/` | demo, scene renderer, SwiftUI reference host, integration tests |
| `tool/scenes/` | `scenes.json`, background generator |
| `tool/fidelity/` | capture, compare, motion, fit scripts |

---

### Task 1: Scaffold the plugin and the `Glass` value type

**Files:**
- Create (via `flutter create`): plugin skeleton, `example/`
- Modify: `pubspec.yaml`, `analysis_options.yaml`, `lib/adaptive_liquid_glass.dart`
- Delete: generated `lib/adaptive_liquid_glass_platform_interface.dart`, `lib/adaptive_liquid_glass_method_channel.dart`, generated tests for them
- Create: `lib/src/core/glass.dart`, `test/core/glass_test.dart`, `LICENSE`

**Interfaces:**
- Produces: `enum GlassVariant { regular, clear, identity }`; `class Glass { static const Glass regular, clear, identity; GlassVariant variant; Color? tintColor; bool isInteractive; Glass tint(Color? color); Glass interactive([bool enabled = true]); }`

- [ ] **Step 1: Generate the plugin skeleton**

```bash
cd "/Users/aymanomara/Android Studio Projects/adaptive_liquid_glass"
flutter create --template=plugin --platforms=ios --org com.aymanomara --project-name adaptive_liquid_glass -i swift .
rm -f lib/adaptive_liquid_glass_platform_interface.dart lib/adaptive_liquid_glass_method_channel.dart
rm -f test/adaptive_liquid_glass_test.dart test/adaptive_liquid_glass_method_channel_test.dart
```

Expected: `ios/`, `example/`, `lib/`, `test/` exist; `docs/` untouched.

- [ ] **Step 2: Replace `pubspec.yaml`**

```yaml
name: adaptive_liquid_glass
description: >-
  iOS 26 Liquid Glass for Flutter, measured against SwiftUI, with Material 3
  counterparts on Android behind one API.
version: 0.1.0-dev.1
repository: https://github.com/aymanomara/adaptive_liquid_glass
topics: [liquid-glass, cupertino, material, ui, shader]

environment:
  sdk: ^3.8.0
  flutter: ">=3.32.0"

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  plugin:
    platforms:
      ios:
        pluginClass: AdaptiveLiquidGlassPlugin
  shaders:
    - shaders/liquid_glass.frag
```

Create a placeholder shader so the asset entry resolves (replaced in Task 8):

```bash
mkdir -p shaders && cat > shaders/liquid_glass.frag <<'EOF'
#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform sampler2D uTexture;
out vec4 fragColor;
void main() { fragColor = texture(uTexture, FlutterFragCoord().xy / uSize); }
EOF
```

- [ ] **Step 3: Replace `analysis_options.yaml`**

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-raw-types: true
    strict-inference: true

linter:
  rules:
    public_member_api_docs: true
    prefer_final_locals: true
    prefer_const_constructors: true
    directives_ordering: true
```

Add an MIT `LICENSE` with `Copyright (c) 2026 Ayman Omara`.

- [ ] **Step 4: Write the failing test** — `test/core/glass_test.dart`

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presets have no tint and are not interactive', () {
    for (final g in [Glass.regular, Glass.clear, Glass.identity]) {
      expect(g.tintColor, isNull);
      expect(g.isInteractive, isFalse);
    }
    expect(Glass.regular.variant, GlassVariant.regular);
    expect(Glass.clear.variant, GlassVariant.clear);
    expect(Glass.identity.variant, GlassVariant.identity);
  });

  test('tint and interactive chain without mutating the original', () {
    const blue = Color(0xFF0000FF);
    final g = Glass.regular.tint(blue).interactive();
    expect(g.variant, GlassVariant.regular);
    expect(g.tintColor, blue);
    expect(g.isInteractive, isTrue);
    expect(Glass.regular.tintColor, isNull);
    expect(g.interactive(false).isInteractive, isFalse);
    expect(g.tint(null).tintColor, isNull);
  });

  test('value equality', () {
    const red = Color(0xFFFF0000);
    expect(Glass.clear.tint(red), Glass.clear.tint(red));
    expect(Glass.clear.tint(red).hashCode, Glass.clear.tint(red).hashCode);
    expect(Glass.clear, isNot(Glass.regular));
  });
}
```

- [ ] **Step 5: Run it to verify it fails**

Run: `flutter test test/core/glass_test.dart`
Expected: FAIL — `Glass` / `GlassVariant` undefined.

- [ ] **Step 6: Implement** — `lib/src/core/glass.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The material variants of Liquid Glass, mirroring SwiftUI's `Glass`.
enum GlassVariant {
  /// Standard glass: frosted, adapts to the content behind it.
  regular,

  /// Highly transparent glass for rich media backgrounds.
  clear,

  /// No glass effect; the child is shown as is.
  identity,
}

/// An immutable description of a Liquid Glass material.
///
/// Mirrors SwiftUI: `Glass.regular.tint(color).interactive()`.
@immutable
class Glass {
  const Glass._(this.variant, {this.tintColor, this.isInteractive = false});

  /// Standard glass (`Glass.regular`).
  static const Glass regular = Glass._(GlassVariant.regular);

  /// Clear glass (`Glass.clear`).
  static const Glass clear = Glass._(GlassVariant.clear);

  /// No effect (`Glass.identity`).
  static const Glass identity = Glass._(GlassVariant.identity);

  /// Which glass material this is.
  final GlassVariant variant;

  /// Optional tint colour blended into the glass body.
  final Color? tintColor;

  /// Whether the glass reacts to touch (stretch, glow, bounce).
  final bool isInteractive;

  /// Returns a copy tinted with [color]; `null` removes the tint.
  Glass tint(Color? color) =>
      Glass._(variant, tintColor: color, isInteractive: isInteractive);

  /// Returns a copy that reacts to touch when [enabled].
  Glass interactive([bool enabled = true]) =>
      Glass._(variant, tintColor: tintColor, isInteractive: enabled);

  @override
  bool operator ==(Object other) =>
      other is Glass &&
      other.variant == variant &&
      other.tintColor == tintColor &&
      other.isInteractive == isInteractive;

  @override
  int get hashCode => Object.hash(variant, tintColor, isInteractive);

  @override
  String toString() =>
      'Glass.${variant.name}(tint: $tintColor, interactive: $isInteractive)';
}
```

Replace `lib/adaptive_liquid_glass.dart`:

```dart
/// iOS 26 Liquid Glass for Flutter with Material 3 counterparts on Android.
library;

export 'src/core/glass.dart';
```

Replace `ios/Classes/AdaptiveLiquidGlassPlugin.swift` with a stub that compiles (filled in Task 3):

```swift
import Flutter
import UIKit

public class AdaptiveLiquidGlassPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {}
}
```

Strip the generated example code that called the deleted platform interface: replace `example/lib/main.dart` with

```dart
import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('adaptive_liquid_glass')))));
```

and delete `example/integration_test/plugin_integration_test.dart` and `example/test/widget_test.dart` if generated.

- [ ] **Step 7: Run tests and analysis**

Run: `flutter test && flutter analyze`
Expected: all tests PASS; `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: scaffold plugin and Glass value type

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `GlassShape` and concentric radius

**Files:**
- Create: `lib/src/core/glass_shape.dart`, `test/core/glass_shape_test.dart`
- Modify: `lib/adaptive_liquid_glass.dart` (export)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `sealed class GlassShape` with `const GlassShape.capsule()`, `const GlassShape.circle()`, `const GlassShape.rect(double cornerRadius)`, `const GlassShape.concentric({double minimum = 0})`.
  - `Rect GlassShape.resolveRect(Size size)` — the drawn rect inside a box of `size` (circle = centred square).
  - `double GlassShape.resolveRadius(Size size, {double? concentricRadius})` — corner radius in logical px; for `concentric`, `concentricRadius` is what the group computed (null → capsule).
  - `OutlinedBorder GlassShape.toBorder(Size size)` — `RoundedSuperellipseBorder` (or `CircleBorder`).
  - top-level `double concentricRadius({required Rect container, required double containerRadius, required Rect child, double minimum = 0})`.

- [ ] **Step 1: Write the failing test** — `test/core/glass_shape_test.dart`

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const box = Size(200, 60);

  test('capsule radius is half the shortest side', () {
    expect(const GlassShape.capsule().resolveRadius(box), 30);
    expect(const GlassShape.capsule().resolveRect(box), Offset.zero & box);
  });

  test('circle is a centred square', () {
    const shape = GlassShape.circle();
    expect(shape.resolveRect(box), const Rect.fromLTWH(70, 0, 60, 60));
    expect(shape.resolveRadius(box), 30);
    expect(shape.toBorder(box), isA<CircleBorder>());
  });

  test('rect radius is clamped to half the shortest side', () {
    expect(const GlassShape.rect(16).resolveRadius(box), 16);
    expect(const GlassShape.rect(100).resolveRadius(box), 30);
    expect(const GlassShape.rect(-4).resolveRadius(box), 0);
  });

  test('concentric uses the group value, else falls back to capsule', () {
    const shape = GlassShape.concentric(minimum: 6);
    expect(shape.resolveRadius(box, concentricRadius: 12), 12);
    expect(shape.resolveRadius(box), 30);
  });

  test('borders use the continuous corner curve', () {
    final border = const GlassShape.rect(16).toBorder(box);
    expect(border, isA<RoundedSuperellipseBorder>());
    expect((border as RoundedSuperellipseBorder).borderRadius,
        BorderRadius.circular(16));
  });

  test('concentricRadius subtracts the smallest inset', () {
    final r = concentricRadius(
      container: const Rect.fromLTWH(0, 0, 300, 100),
      containerRadius: 28,
      child: const Rect.fromLTWH(8, 12, 100, 76),
    );
    expect(r, 20); // smallest inset is 8 (left)
  });

  test('concentricRadius never goes below minimum', () {
    final r = concentricRadius(
      container: const Rect.fromLTWH(0, 0, 300, 100),
      containerRadius: 10,
      child: const Rect.fromLTWH(20, 20, 100, 60),
      minimum: 4,
    );
    expect(r, 4);
  });

  test('equality', () {
    expect(const GlassShape.rect(8), const GlassShape.rect(8));
    expect(const GlassShape.rect(8), isNot(const GlassShape.rect(9)));
    expect(const GlassShape.capsule(), const GlassShape.capsule());
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/glass_shape_test.dart`
Expected: FAIL — `GlassShape` undefined.

- [ ] **Step 3: Implement** — `lib/src/core/glass_shape.dart`

```dart
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The shape a piece of Liquid Glass is drawn in.
///
/// Mirrors the `in:` argument of SwiftUI's `glassEffect(_:in:)`. Corners use
/// Apple's continuous curve (a rounded superellipse), never circular arcs.
@immutable
sealed class GlassShape {
  const GlassShape();

  /// A capsule: corner radius is half the shortest side.
  const factory GlassShape.capsule() = CapsuleGlassShape;

  /// A circle fitted to the shortest side, centred in the box.
  const factory GlassShape.circle() = CircleGlassShape;

  /// A rectangle with continuous corners of [cornerRadius].
  const factory GlassShape.rect(double cornerRadius) = RectGlassShape;

  /// A rectangle whose corners are concentric with the enclosing glass.
  ///
  /// Outside any enclosing glass it behaves like [GlassShape.capsule].
  const factory GlassShape.concentric({double minimum}) = ConcentricGlassShape;

  /// The rect the shape occupies inside a box of [size].
  Rect resolveRect(Size size) => Offset.zero & size;

  /// The corner radius in logical pixels for a box of [size].
  ///
  /// [concentricRadius] is supplied by the group for [ConcentricGlassShape].
  double resolveRadius(Size size, {double? concentricRadius});

  /// The equivalent Flutter border, for clipping and Material rendering.
  OutlinedBorder toBorder(Size size) => RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(resolveRadius(size)),
      );
}

/// See [GlassShape.capsule].
final class CapsuleGlassShape extends GlassShape {
  /// Creates a capsule shape.
  const CapsuleGlassShape();

  @override
  double resolveRadius(Size size, {double? concentricRadius}) =>
      size.shortestSide / 2;

  @override
  bool operator ==(Object other) => other is CapsuleGlassShape;

  @override
  int get hashCode => (CapsuleGlassShape).hashCode;
}

/// See [GlassShape.circle].
final class CircleGlassShape extends GlassShape {
  /// Creates a circle shape.
  const CircleGlassShape();

  @override
  Rect resolveRect(Size size) => Rect.fromCenter(
        center: size.center(Offset.zero),
        width: size.shortestSide,
        height: size.shortestSide,
      );

  @override
  double resolveRadius(Size size, {double? concentricRadius}) =>
      size.shortestSide / 2;

  @override
  OutlinedBorder toBorder(Size size) => const CircleBorder();

  @override
  bool operator ==(Object other) => other is CircleGlassShape;

  @override
  int get hashCode => (CircleGlassShape).hashCode;
}

/// See [GlassShape.rect].
final class RectGlassShape extends GlassShape {
  /// Creates a rectangle with continuous corners.
  const RectGlassShape(this.cornerRadius);

  /// Requested corner radius; clamped to half the shortest side.
  final double cornerRadius;

  @override
  double resolveRadius(Size size, {double? concentricRadius}) =>
      cornerRadius.clamp(0.0, size.shortestSide / 2);

  @override
  bool operator ==(Object other) =>
      other is RectGlassShape && other.cornerRadius == cornerRadius;

  @override
  int get hashCode => cornerRadius.hashCode;
}

/// See [GlassShape.concentric].
final class ConcentricGlassShape extends GlassShape {
  /// Creates a concentric shape.
  const ConcentricGlassShape({this.minimum = 0});

  /// Smallest radius the shape will use.
  final double minimum;

  @override
  double resolveRadius(Size size, {double? concentricRadius}) =>
      (concentricRadius ?? size.shortestSide / 2)
          .clamp(0.0, size.shortestSide / 2);

  @override
  bool operator ==(Object other) =>
      other is ConcentricGlassShape && other.minimum == minimum;

  @override
  int get hashCode => minimum.hashCode;
}

/// Radius for a child whose corners are concentric with [container].
///
/// The inset is the smallest distance between the child's and the
/// container's edges; the result is `containerRadius - inset`, floored at
/// [minimum].
double concentricRadius({
  required Rect container,
  required double containerRadius,
  required Rect child,
  double minimum = 0,
}) {
  final inset = [
    child.left - container.left,
    child.top - container.top,
    container.right - child.right,
    container.bottom - child.bottom,
  ].reduce(math.min);
  return math.max(containerRadius - math.max(inset, 0), minimum);
}
```

Add `export 'src/core/glass_shape.dart';` to `lib/adaptive_liquid_glass.dart`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/glass_shape_test.dart && flutter analyze`
Expected: PASS; no issues.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: GlassShape with continuous corners and concentric radius

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Platform channel — iOS version and Reduce Transparency

**Files:**
- Create: `lib/src/core/glass_environment.dart`, `lib/src/platform/glass_platform.dart`, `test/platform/glass_platform_test.dart`
- Modify: `ios/Classes/AdaptiveLiquidGlassPlugin.swift`, `ios/adaptive_liquid_glass.podspec` (deployment target)

**Interfaces:**
- Produces:
  - `class GlassEnvironment { TargetPlatform platform; int? iosMajorVersion; bool reduceTransparency; bool shaderSupported; GlassEnvironment copyWith({...}); static GlassEnvironment current(); }`
  - `class GlassPlatform { static GlassPlatform instance; ValueListenable<GlassEnvironment> get environment; void ensureStarted(); @visibleForTesting void debugReset(); }`
  - Channel names: method `adaptive_liquid_glass` (`getEnvironment` → `{'iosMajorVersion': int, 'reduceTransparency': bool}`); event `adaptive_liquid_glass/reduce_transparency` (bool stream).

- [ ] **Step 1: Write the failing test** — `test/platform/glass_platform_test.dart`

```dart
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const method = MethodChannel('adaptive_liquid_glass');
  const events = 'adaptive_liquid_glass/reduce_transparency';

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    GlassPlatform.instance.debugReset();
    messenger.setMockMethodCallHandler(method, null);
    messenger.setMockStreamHandler(const EventChannel(events), null);
  });

  test('does not touch the channel off iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var calls = 0;
    messenger.setMockMethodCallHandler(method, (_) async {
      calls++;
      return null;
    });
    GlassPlatform.instance.ensureStarted();
    await pumpEventQueue();
    expect(calls, 0);
    expect(GlassPlatform.instance.environment.value.iosMajorVersion, isNull);
  });

  test('reads version and live Reduce Transparency on iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(method, (call) async {
      expect(call.method, 'getEnvironment');
      return {'iosMajorVersion': 26, 'reduceTransparency': false};
    });
    late MockStreamHandlerEventSink sink;
    messenger.setMockStreamHandler(
      const EventChannel(events),
      MockStreamHandler.inline(onListen: (_, s) => sink = s),
    );

    GlassPlatform.instance.ensureStarted();
    await pumpEventQueue();
    final env = GlassPlatform.instance.environment;
    expect(env.value.iosMajorVersion, 26);
    expect(env.value.reduceTransparency, isFalse);

    sink.success(true);
    await pumpEventQueue();
    expect(env.value.reduceTransparency, isTrue);
  });

  test('a channel failure leaves defaults in place', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(method, (_) async {
      throw PlatformException(code: 'x');
    });
    GlassPlatform.instance.ensureStarted();
    await pumpEventQueue();
    expect(GlassPlatform.instance.environment.value.iosMajorVersion, isNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/platform/glass_platform_test.dart`
Expected: FAIL — import not found.

- [ ] **Step 3: Implement** — `lib/src/core/glass_environment.dart`

```dart
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Facts about the running device that decide how glass is rendered.
@immutable
class GlassEnvironment {
  /// Creates an environment description.
  const GlassEnvironment({
    required this.platform,
    required this.iosMajorVersion,
    required this.reduceTransparency,
    required this.shaderSupported,
  });

  /// Environment known synchronously at startup (no channel data yet).
  factory GlassEnvironment.current() => GlassEnvironment(
        platform: defaultTargetPlatform,
        iosMajorVersion: null,
        reduceTransparency: false,
        shaderSupported: ui.ImageFilter.isShaderFilterSupported,
      );

  /// The target platform.
  final TargetPlatform platform;

  /// iOS major version, or `null` when unknown or not iOS.
  final int? iosMajorVersion;

  /// Whether iOS Reduce Transparency is on.
  final bool reduceTransparency;

  /// Whether `ImageFilter.shader` is available (Impeller).
  final bool shaderSupported;

  /// Returns a copy with the given fields replaced.
  GlassEnvironment copyWith({
    TargetPlatform? platform,
    int? iosMajorVersion,
    bool? reduceTransparency,
    bool? shaderSupported,
  }) =>
      GlassEnvironment(
        platform: platform ?? this.platform,
        iosMajorVersion: iosMajorVersion ?? this.iosMajorVersion,
        reduceTransparency: reduceTransparency ?? this.reduceTransparency,
        shaderSupported: shaderSupported ?? this.shaderSupported,
      );

  @override
  bool operator ==(Object other) =>
      other is GlassEnvironment &&
      other.platform == platform &&
      other.iosMajorVersion == iosMajorVersion &&
      other.reduceTransparency == reduceTransparency &&
      other.shaderSupported == shaderSupported;

  @override
  int get hashCode => Object.hash(
      platform, iosMajorVersion, reduceTransparency, shaderSupported);
}
```

`lib/src/platform/glass_platform.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/glass_environment.dart';

/// Live device facts from the iOS side of the plugin.
class GlassPlatform {
  GlassPlatform._();

  /// The shared instance.
  static final GlassPlatform instance = GlassPlatform._();

  static const MethodChannel _method = MethodChannel('adaptive_liquid_glass');
  static const EventChannel _events =
      EventChannel('adaptive_liquid_glass/reduce_transparency');

  final ValueNotifier<GlassEnvironment> _environment =
      ValueNotifier(GlassEnvironment.current());
  StreamSubscription<Object?>? _subscription;
  bool _started = false;

  /// The current environment; updates when iOS settings change.
  ValueListenable<GlassEnvironment> get environment => _environment;

  /// Starts reading from the platform once. Safe to call repeatedly.
  void ensureStarted() {
    if (_started) return;
    _started = true;
    _environment.value = GlassEnvironment.current();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final map =
          await _method.invokeMapMethod<String, Object?>('getEnvironment');
      if (map != null) {
        _environment.value = _environment.value.copyWith(
          iosMajorVersion: map['iosMajorVersion'] as int?,
          reduceTransparency: map['reduceTransparency'] as bool?,
        );
      }
      _subscription = _events.receiveBroadcastStream().listen((value) {
        _environment.value =
            _environment.value.copyWith(reduceTransparency: value as bool);
      });
    } on PlatformException catch (e, s) {
      FlutterError.reportError(FlutterErrorDetails(
          exception: e, stack: s, library: 'adaptive_liquid_glass'));
    } on MissingPluginException {
      // Running without the iOS plugin (tests, add-to-app); keep defaults.
    }
  }

  /// Resets state between tests.
  @visibleForTesting
  void debugReset() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _started = false;
    _environment.value = GlassEnvironment.current();
  }
}
```

Note: `FlutterError.reportError` in a unit test marks the test failed only if `FlutterError.onError` throws; the default test handler records the error — so in the "channel failure" test, wrap with `FlutterError.onError = (_) {}` at the start and restore it in `tearDown`. Add that to the test:

```dart
  test('a channel failure leaves defaults in place', () async {
    final previous = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = previous);
    // ... body as above
```

- [ ] **Step 4: Implement the Swift side** — `ios/Classes/AdaptiveLiquidGlassPlugin.swift`

```swift
import Flutter
import UIKit

public class AdaptiveLiquidGlassPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var sink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AdaptiveLiquidGlassPlugin()
    let method = FlutterMethodChannel(
      name: "adaptive_liquid_glass", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: method)
    let events = FlutterEventChannel(
      name: "adaptive_liquid_glass/reduce_transparency",
      binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getEnvironment":
      result([
        "iosMajorVersion": ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
        "reduceTransparency": UIAccessibility.isReduceTransparencyEnabled,
      ])
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    NotificationCenter.default.addObserver(
      self, selector: #selector(reduceTransparencyChanged),
      name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NotificationCenter.default.removeObserver(
      self, name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
    sink = nil
    return nil
  }

  @objc private func reduceTransparencyChanged() {
    sink?(UIAccessibility.isReduceTransparencyEnabled)
  }
}
```

In `ios/adaptive_liquid_glass.podspec` set `s.platform = :ios, '15.0'` and `s.swift_version = '5.9'`.

- [ ] **Step 5: Run tests + build the example for iOS simulator**

Run: `flutter test test/platform && flutter analyze && (cd example && flutter build ios --simulator --debug)`
Expected: PASS; no issues; `✓ Built build/ios/iphonesimulator/Runner.app`.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: platform channel for iOS version and Reduce Transparency

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Render-mode resolver

**Files:**
- Create: `lib/src/core/glass_render_mode.dart`, `lib/src/core/render_mode_resolver.dart`, `test/core/render_mode_resolver_test.dart`
- Modify: `lib/adaptive_liquid_glass.dart` (export `GlassRenderMode`)

**Interfaces:**
- Consumes: `GlassEnvironment` (Task 3).
- Produces:
  - `enum GlassRenderMode { auto, shader, native, material }` (public)
  - `enum EffectiveGlassMode { shader, degraded, native, material, opaque }` (internal)
  - `EffectiveGlassMode resolveGlassMode({required GlassRenderMode requested, required bool nativeEnabled, required GlassEnvironment environment})`

- [ ] **Step 1: Write the failing test** — `test/core/render_mode_resolver_test.dart`

```dart
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/core/glass_render_mode.dart';
import 'package:adaptive_liquid_glass/src/core/render_mode_resolver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

GlassEnvironment env({
  TargetPlatform platform = TargetPlatform.iOS,
  int? ios = 26,
  bool rt = false,
  bool shader = true,
}) =>
    GlassEnvironment(
        platform: platform,
        iosMajorVersion: platform == TargetPlatform.iOS ? ios : null,
        reduceTransparency: rt,
        shaderSupported: shader);

EffectiveGlassMode r(GlassRenderMode m, GlassEnvironment e,
        {bool native = false}) =>
    resolveGlassMode(requested: m, nativeEnabled: native, environment: e);

void main() {
  const auto = GlassRenderMode.auto;

  test('auto on Android is material', () {
    expect(r(auto, env(platform: TargetPlatform.android)),
        EffectiveGlassMode.material);
  });

  test('auto on iOS is shader unless native is enabled and available', () {
    expect(r(auto, env()), EffectiveGlassMode.shader);
    expect(r(auto, env(), native: true), EffectiveGlassMode.native);
    expect(r(auto, env(ios: 18), native: true), EffectiveGlassMode.shader);
    expect(r(auto, env(ios: null), native: true), EffectiveGlassMode.shader);
  });

  test('no shader support degrades', () {
    expect(r(auto, env(shader: false)), EffectiveGlassMode.degraded);
    expect(r(GlassRenderMode.shader, env(shader: false)),
        EffectiveGlassMode.degraded);
  });

  test('explicit modes win', () {
    expect(r(GlassRenderMode.material, env()), EffectiveGlassMode.material);
    expect(r(GlassRenderMode.shader, env(platform: TargetPlatform.android)),
        EffectiveGlassMode.shader);
    expect(r(GlassRenderMode.native, env()), EffectiveGlassMode.native);
  });

  test('explicit native below iOS 26 or off iOS falls to shader', () {
    expect(r(GlassRenderMode.native, env(ios: 18)), EffectiveGlassMode.shader);
    expect(r(GlassRenderMode.native, env(platform: TargetPlatform.android)),
        EffectiveGlassMode.shader);
  });

  test('Reduce Transparency turns shader and degraded into opaque', () {
    expect(r(auto, env(rt: true)), EffectiveGlassMode.opaque);
    expect(r(auto, env(rt: true, shader: false)), EffectiveGlassMode.opaque);
    expect(r(GlassRenderMode.shader, env(rt: true)), EffectiveGlassMode.opaque);
  });

  test('Reduce Transparency leaves native and material alone', () {
    expect(r(auto, env(rt: true), native: true), EffectiveGlassMode.native);
    expect(r(GlassRenderMode.material, env(rt: true)),
        EffectiveGlassMode.material);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/render_mode_resolver_test.dart`
Expected: FAIL — imports missing.

- [ ] **Step 3: Implement**

`lib/src/core/glass_render_mode.dart`:

```dart
/// How a glass widget is rendered.
enum GlassRenderMode {
  /// Pick per platform: shader on iOS (native on iOS 26+ when enabled in the
  /// theme), Material 3 elsewhere.
  auto,

  /// Flutter fragment shader glass.
  shader,

  /// Apple's own UIKit glass view (iOS 26+; falls back to [shader]).
  native,

  /// A Material 3 surface.
  material,
}

/// The rendering path actually used after resolution. Internal.
enum EffectiveGlassMode { shader, degraded, native, material, opaque }
```

`lib/src/core/render_mode_resolver.dart`:

```dart
import 'package:flutter/foundation.dart';

import 'glass_environment.dart';
import 'glass_render_mode.dart';

/// Resolves the rendering path. Order is spec §5 as amended in §14.2.
EffectiveGlassMode resolveGlassMode({
  required GlassRenderMode requested,
  required bool nativeEnabled,
  required GlassEnvironment environment,
}) {
  final isIOS = environment.platform == TargetPlatform.iOS;
  final nativeAvailable = isIOS && (environment.iosMajorVersion ?? 0) >= 26;
  final shaderPath = environment.shaderSupported
      ? EffectiveGlassMode.shader
      : EffectiveGlassMode.degraded;

  final EffectiveGlassMode mode = switch (requested) {
    GlassRenderMode.material => EffectiveGlassMode.material,
    GlassRenderMode.shader => shaderPath,
    GlassRenderMode.native =>
      nativeAvailable ? EffectiveGlassMode.native : shaderPath,
    GlassRenderMode.auto => !isIOS
        ? EffectiveGlassMode.material
        : (nativeEnabled && nativeAvailable)
            ? EffectiveGlassMode.native
            : shaderPath,
  };

  if (environment.reduceTransparency &&
      (mode == EffectiveGlassMode.shader ||
          mode == EffectiveGlassMode.degraded)) {
    return EffectiveGlassMode.opaque;
  }
  return mode;
}
```

Add `export 'src/core/glass_render_mode.dart' show GlassRenderMode;` to the library.

- [ ] **Step 4: Run tests**

Run: `flutter test test/core && flutter analyze`
Expected: PASS; no issues.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: render mode resolver

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Constants, SwiftUI springs and theme

**Files:**
- Create: `lib/src/core/glass_constants.dart`, `lib/src/core/swiftui_spring.dart`, `lib/src/core/theme.dart`, `lib/testing.dart`, `test/core/glass_constants_test.dart`, `test/core/swiftui_spring_test.dart`, `test/core/theme_test.dart`
- Modify: `lib/adaptive_liquid_glass.dart`

**Interfaces:**
- Consumes: `Glass` (Task 1), `GlassRenderMode` (Task 4).
- Produces:
  - `GlassVariantConstants { double blurSigma, lensBand, lensStrength, dispersion, rimWidth, rimIntensity, lumaLift, dim, shadowRadius, shadowOpacity, tintStrength; Map<String,double> toJson(); factory fromJson(Map<String,Object?>) }`
  - `GlassMotionConstants { double pressScale, pressStretch, glowRadius, pressResponse, pressDamping, morphResponse, morphDamping }` (+ JSON)
  - `GlassConstants { GlassVariantConstants regular, clear, regularDark, clearDark; double cornerExponent; GlassMotionConstants motion; static const GlassConstants standard; GlassVariantConstants of(GlassVariant v, [Brightness b = Brightness.light]); toJson/fromJson }` — SwiftUI glass looks different in dark mode, so each variant has a light and a dark set.
  - `SpringDescription swiftUISpring({required double response, required double dampingFraction})`
  - `LiquidGlassThemeData { double lightAngle = -3π/4; Glass defaultGlass = Glass.regular; GlassRenderMode defaultMode = auto; bool nativeEnabled = false; GlassConstants constants = GlassConstants.standard; copyWith }`
  - `LiquidGlassTheme extends InheritedWidget { static LiquidGlassThemeData of(BuildContext) }`

- [ ] **Step 1: Write the failing tests**

`test/core/swiftui_spring_test.dart`:

```dart
import 'dart:math' as math;

import 'package:adaptive_liquid_glass/src/core/swiftui_spring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dampingFraction 1 is critically damped', () {
    final s = swiftUISpring(response: 0.5, dampingFraction: 1);
    expect(s.mass, 1);
    expect(s.damping * s.damping, closeTo(4 * s.mass * s.stiffness, 1e-6));
  });

  test('stiffness follows the response period', () {
    final s = swiftUISpring(response: 0.5, dampingFraction: 0.7);
    expect(s.stiffness, closeTo(math.pow(2 * math.pi / 0.5, 2), 1e-9));
    expect(s.damping, closeTo(4 * math.pi * 0.7 / 0.5, 1e-9));
  });
}
```

`test/core/glass_constants_test.dart`:

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/testing.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('JSON round-trips', () {
    const c = GlassConstants.standard;
    expect(GlassConstants.fromJson(c.toJson()), c);
  });

  test('partial JSON overrides only given keys', () {
    final c = GlassConstants.fromJson({
      'regular': {'blurSigma': 9.0},
      'cornerExponent': 5.0,
    });
    expect(c.regular.blurSigma, 9.0);
    expect(c.regular.lensBand, GlassConstants.standard.regular.lensBand);
    expect(c.cornerExponent, 5.0);
    expect(c.clear, GlassConstants.standard.clear);
  });

  test('of() picks the variant and brightness; identity maps to regular', () {
    const c = GlassConstants.standard;
    expect(c.of(GlassVariant.clear), c.clear);
    expect(c.of(GlassVariant.identity), c.regular);
    expect(c.of(GlassVariant.regular, Brightness.dark), c.regularDark);
    expect(c.of(GlassVariant.clear, Brightness.dark), c.clearDark);
  });
}
```

`test/core/theme_test.dart`:

```dart
import 'dart:math' as math;

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('defaults without a theme', (tester) async {
    late LiquidGlassThemeData data;
    await tester.pumpWidget(Builder(builder: (c) {
      data = LiquidGlassTheme.of(c);
      return const SizedBox();
    }));
    expect(data.lightAngle, closeTo(-3 * math.pi / 4, 1e-12));
    expect(data.defaultGlass, Glass.regular);
    expect(data.defaultMode, GlassRenderMode.auto);
    expect(data.nativeEnabled, isFalse);
  });

  testWidgets('nearest theme wins and notifies on change', (tester) async {
    late LiquidGlassThemeData data;
    Widget app(bool native) => LiquidGlassTheme(
          data: LiquidGlassThemeData(nativeEnabled: native),
          child: Builder(builder: (c) {
            data = LiquidGlassTheme.of(c);
            return const SizedBox();
          }),
        );
    await tester.pumpWidget(app(false));
    expect(data.nativeEnabled, isFalse);
    await tester.pumpWidget(app(true));
    expect(data.nativeEnabled, isTrue);
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/core`
Expected: FAIL — missing files.

- [ ] **Step 3: Implement** — `lib/src/core/swiftui_spring.dart`

```dart
import 'dart:math' as math;

import 'package:flutter/physics.dart';

/// Converts SwiftUI's `.spring(response:dampingFraction:)` to Flutter.
///
/// SwiftUI: stiffness = (2π / response)², damping = 4π·ζ / response, mass 1.
SpringDescription swiftUISpring({
  required double response,
  required double dampingFraction,
}) =>
    SpringDescription(
      mass: 1,
      stiffness: math.pow(2 * math.pi / response, 2).toDouble(),
      damping: 4 * math.pi * dampingFraction / response,
    );
```

`lib/src/core/glass_constants.dart` (initial values are starting points; Task 16 replaces them with fitted values and records the scene ids next to each):

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'glass.dart';

GlassVariantConstants _v(Map<String, Object?> j, String key,
        GlassVariantConstants base) =>
    GlassVariantConstants.fromJson(
        (j[key] as Map?)?.cast<String, Object?>() ?? const {}, base);

double _d(Map<String, Object?> j, String k, double fallback) =>
    (j[k] as num?)?.toDouble() ?? fallback;

/// Per-variant rendering constants (lengths in logical px).
@immutable
class GlassVariantConstants {
  /// Creates variant constants.
  const GlassVariantConstants({
    required this.blurSigma,
    required this.lensBand,
    required this.lensStrength,
    required this.dispersion,
    required this.rimWidth,
    required this.rimIntensity,
    required this.lumaLift,
    required this.dim,
    required this.shadowRadius,
    required this.shadowOpacity,
    required this.tintStrength,
  });

  /// Reads keys present in [j]; missing keys come from [base].
  factory GlassVariantConstants.fromJson(
          Map<String, Object?> j, GlassVariantConstants base) =>
      GlassVariantConstants(
        blurSigma: _d(j, 'blurSigma', base.blurSigma),
        lensBand: _d(j, 'lensBand', base.lensBand),
        lensStrength: _d(j, 'lensStrength', base.lensStrength),
        dispersion: _d(j, 'dispersion', base.dispersion),
        rimWidth: _d(j, 'rimWidth', base.rimWidth),
        rimIntensity: _d(j, 'rimIntensity', base.rimIntensity),
        lumaLift: _d(j, 'lumaLift', base.lumaLift),
        dim: _d(j, 'dim', base.dim),
        shadowRadius: _d(j, 'shadowRadius', base.shadowRadius),
        shadowOpacity: _d(j, 'shadowOpacity', base.shadowOpacity),
        tintStrength: _d(j, 'tintStrength', base.tintStrength),
      );

  /// Gaussian sigma of the frost blur.
  final double blurSigma;

  /// Width of the refracting edge band.
  final double lensBand;

  /// Lens displacement as a fraction of [lensBand]; sign sets direction.
  final double lensStrength;

  /// Red/blue split as a fraction of the lens displacement.
  final double dispersion;

  /// Width of the specular rim.
  final double rimWidth;

  /// Brightness added at the rim.
  final double rimIntensity;

  /// Lift applied to dark content behind the glass.
  final double lumaLift;

  /// Darkening applied to the content (used by `clear`).
  final double dim;

  /// Shadow falloff radius outside the shape.
  final double shadowRadius;

  /// Shadow strength at the shape edge.
  final double shadowOpacity;

  /// How strongly `.tint()` colours the glass.
  final double tintStrength;

  /// JSON form.
  Map<String, double> toJson() => {
        'blurSigma': blurSigma,
        'lensBand': lensBand,
        'lensStrength': lensStrength,
        'dispersion': dispersion,
        'rimWidth': rimWidth,
        'rimIntensity': rimIntensity,
        'lumaLift': lumaLift,
        'dim': dim,
        'shadowRadius': shadowRadius,
        'shadowOpacity': shadowOpacity,
        'tintStrength': tintStrength,
      };

  @override
  bool operator ==(Object other) =>
      other is GlassVariantConstants && mapEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}

/// Motion constants for `.interactive()` and `glassId` morphs.
@immutable
class GlassMotionConstants {
  /// Creates motion constants.
  const GlassMotionConstants({
    required this.pressScale,
    required this.pressStretch,
    required this.glowRadius,
    required this.pressResponse,
    required this.pressDamping,
    required this.morphResponse,
    required this.morphDamping,
  });

  /// Reads keys present in [j]; missing keys come from [base].
  factory GlassMotionConstants.fromJson(
          Map<String, Object?> j, GlassMotionConstants base) =>
      GlassMotionConstants(
        pressScale: _d(j, 'pressScale', base.pressScale),
        pressStretch: _d(j, 'pressStretch', base.pressStretch),
        glowRadius: _d(j, 'glowRadius', base.glowRadius),
        pressResponse: _d(j, 'pressResponse', base.pressResponse),
        pressDamping: _d(j, 'pressDamping', base.pressDamping),
        morphResponse: _d(j, 'morphResponse', base.morphResponse),
        morphDamping: _d(j, 'morphDamping', base.morphDamping),
      );

  /// Uniform scale gained at full press.
  final double pressScale;

  /// Extra scale along the touch direction at full press.
  final double pressStretch;

  /// Radius of the touch glow.
  final double glowRadius;

  /// SwiftUI spring response for press/release.
  final double pressResponse;

  /// SwiftUI damping fraction for press/release.
  final double pressDamping;

  /// SwiftUI spring response for morphs.
  final double morphResponse;

  /// SwiftUI damping fraction for morphs.
  final double morphDamping;

  /// JSON form.
  Map<String, double> toJson() => {
        'pressScale': pressScale,
        'pressStretch': pressStretch,
        'glowRadius': glowRadius,
        'pressResponse': pressResponse,
        'pressDamping': pressDamping,
        'morphResponse': morphResponse,
        'morphDamping': morphDamping,
      };

  @override
  bool operator ==(Object other) =>
      other is GlassMotionConstants && mapEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}

/// All fitted constants. Exported from `testing.dart` only.
@immutable
class GlassConstants {
  /// Creates a constants set.
  const GlassConstants({
    required this.regular,
    required this.clear,
    required this.regularDark,
    required this.clearDark,
    required this.cornerExponent,
    required this.motion,
  });

  /// Reads keys present in [j]; missing keys come from [standard].
  factory GlassConstants.fromJson(Map<String, Object?> j) => GlassConstants(
        regular: _v(j, 'regular', standard.regular),
        clear: _v(j, 'clear', standard.clear),
        regularDark: _v(j, 'regularDark', standard.regularDark),
        clearDark: _v(j, 'clearDark', standard.clearDark),
        cornerExponent: _d(j, 'cornerExponent', standard.cornerExponent),
        motion: GlassMotionConstants.fromJson(
            (j['motion'] as Map?)?.cast<String, Object?>() ?? const {},
            standard.motion),
      );

  /// The shipped values. Fitted in Task 16 against `tool/scenes/scenes.json`.
  static const GlassConstants standard = GlassConstants(
    regular: GlassVariantConstants(
      blurSigma: 4,
      lensBand: 14,
      lensStrength: 0.35,
      dispersion: 0.15,
      rimWidth: 1.2,
      rimIntensity: 0.55,
      lumaLift: 0.08,
      dim: 0,
      shadowRadius: 12,
      shadowOpacity: 0.12,
      tintStrength: 0.35,
    ),
    clear: GlassVariantConstants(
      blurSigma: 1,
      lensBand: 14,
      lensStrength: 0.35,
      dispersion: 0.15,
      rimWidth: 1.2,
      rimIntensity: 0.6,
      lumaLift: 0,
      dim: 0.2,
      shadowRadius: 12,
      shadowOpacity: 0.10,
      tintStrength: 0.35,
    ),
    regularDark: GlassVariantConstants(
      blurSigma: 4,
      lensBand: 14,
      lensStrength: 0.35,
      dispersion: 0.15,
      rimWidth: 1.2,
      rimIntensity: 0.4,
      lumaLift: 0,
      dim: 0.15,
      shadowRadius: 12,
      shadowOpacity: 0.2,
      tintStrength: 0.35,
    ),
    clearDark: GlassVariantConstants(
      blurSigma: 1,
      lensBand: 14,
      lensStrength: 0.35,
      dispersion: 0.15,
      rimWidth: 1.2,
      rimIntensity: 0.45,
      lumaLift: 0,
      dim: 0.3,
      shadowRadius: 12,
      shadowOpacity: 0.18,
      tintStrength: 0.35,
    ),
    cornerExponent: 4,
    motion: GlassMotionConstants(
      pressScale: 0.1,
      pressStretch: 0.08,
      glowRadius: 60,
      pressResponse: 0.35,
      pressDamping: 0.65,
      morphResponse: 0.45,
      morphDamping: 0.75,
    ),
  );

  /// Regular-glass constants.
  final GlassVariantConstants regular;

  /// Clear-glass constants.
  final GlassVariantConstants clear;

  /// Regular glass in dark mode.
  final GlassVariantConstants regularDark;

  /// Clear glass in dark mode.
  final GlassVariantConstants clearDark;

  /// Superellipse exponent approximating Apple's continuous corners.
  final double cornerExponent;

  /// Motion constants.
  final GlassMotionConstants motion;

  /// Constants for [variant] in [brightness]; `identity` never draws, so it
  /// maps to regular.
  GlassVariantConstants of(GlassVariant variant,
      [Brightness brightness = Brightness.light]) {
    final dark = brightness == Brightness.dark;
    if (variant == GlassVariant.clear) return dark ? clearDark : clear;
    return dark ? regularDark : regular;
  }

  /// JSON form.
  Map<String, Object?> toJson() => {
        'regular': regular.toJson(),
        'clear': clear.toJson(),
        'regularDark': regularDark.toJson(),
        'clearDark': clearDark.toJson(),
        'cornerExponent': cornerExponent,
        'motion': motion.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      other is GlassConstants &&
      other.regular == regular &&
      other.clear == clear &&
      other.regularDark == regularDark &&
      other.clearDark == clearDark &&
      other.cornerExponent == cornerExponent &&
      other.motion == motion;

  @override
  int get hashCode => Object.hash(
      regular, clear, regularDark, clearDark, cornerExponent, motion);
}
```

`lib/src/core/theme.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'glass.dart';
import 'glass_constants.dart';
import 'glass_render_mode.dart';

/// App-wide defaults for Liquid Glass.
@immutable
class LiquidGlassThemeData {
  /// Creates theme data.
  const LiquidGlassThemeData({
    this.lightAngle = -3 * math.pi / 4,
    this.defaultGlass = Glass.regular,
    this.defaultMode = GlassRenderMode.auto,
    this.nativeEnabled = false,
    this.constants = GlassConstants.standard,
  });

  /// Direction toward the light, radians, y-down screen space.
  /// Default is up and to the left. Not mirrored in RTL.
  final double lightAngle;

  /// Glass used when a widget does not specify one.
  final Glass defaultGlass;

  /// Mode used when a widget does not specify one.
  final GlassRenderMode defaultMode;

  /// Whether `auto` may use Apple's native glass on iOS 26+.
  final bool nativeEnabled;

  /// Rendering constants. Override only for fidelity work.
  final GlassConstants constants;

  /// Returns a copy with the given fields replaced.
  LiquidGlassThemeData copyWith({
    double? lightAngle,
    Glass? defaultGlass,
    GlassRenderMode? defaultMode,
    bool? nativeEnabled,
    GlassConstants? constants,
  }) =>
      LiquidGlassThemeData(
        lightAngle: lightAngle ?? this.lightAngle,
        defaultGlass: defaultGlass ?? this.defaultGlass,
        defaultMode: defaultMode ?? this.defaultMode,
        nativeEnabled: nativeEnabled ?? this.nativeEnabled,
        constants: constants ?? this.constants,
      );

  @override
  bool operator ==(Object other) =>
      other is LiquidGlassThemeData &&
      other.lightAngle == lightAngle &&
      other.defaultGlass == defaultGlass &&
      other.defaultMode == defaultMode &&
      other.nativeEnabled == nativeEnabled &&
      other.constants == constants;

  @override
  int get hashCode =>
      Object.hash(lightAngle, defaultGlass, defaultMode, nativeEnabled, constants);
}

/// Provides [LiquidGlassThemeData] to descendants.
class LiquidGlassTheme extends InheritedWidget {
  /// Creates a theme scope.
  const LiquidGlassTheme({super.key, required this.data, required super.child});

  /// The theme data.
  final LiquidGlassThemeData data;

  /// Nearest theme data, or the defaults.
  static LiquidGlassThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LiquidGlassTheme>()?.data ??
      const LiquidGlassThemeData();

  @override
  bool updateShouldNotify(LiquidGlassTheme oldWidget) => data != oldWidget.data;
}
```

`lib/testing.dart`:

```dart
/// Fidelity-tuning hooks. Not part of the stable API.
library;

export 'src/core/glass_constants.dart';
```

Add `export 'src/core/theme.dart';` to `lib/adaptive_liquid_glass.dart`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/core && flutter analyze`
Expected: PASS; no issues.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: glass constants, SwiftUI spring conversion and theme

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 6: Group registry and member entries

**Files:**
- Create: `lib/src/group/glass_entry.dart`, `lib/src/group/glass_registry.dart`, `test/group/glass_registry_test.dart`

**Interfaces:**
- Consumes: `Glass`, `GlassShape`.
- Produces:
  - `class GlassPressGeometry { double scaleX, scaleY; Offset translation; double glow; Offset? touch; static const identity; Rect apply(Rect r); double get radiusScale; }` — `touch` is in the member's local coordinates.
  - `class GlassEntry { GlassShape shape; Glass glass; Object? glassId; Object? unionId; RenderBox? box; GlassPressGeometry press; Rect? morphRect; GlassEntry? container; bool get isLaidOut; }` — `morphRect` is in the group's local coordinates.
  - `class GlassRegistry extends ChangeNotifier { static const int maxShapes = 16; List<GlassEntry> get entries; bool register(GlassEntry e); void unregister(GlassEntry e); void markNeedsPaint(); }`

- [ ] **Step 1: Write the failing test** — `test/group/glass_registry_test.dart`

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/group/glass_entry.dart';
import 'package:adaptive_liquid_glass/src/group/glass_registry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

GlassEntry entry() =>
    GlassEntry(shape: const GlassShape.capsule(), glass: Glass.regular);

void main() {
  test('register / unregister notify listeners', () {
    final r = GlassRegistry();
    var n = 0;
    r.addListener(() => n++);
    final e = entry();
    expect(r.register(e), isTrue);
    expect(r.entries, [e]);
    r.unregister(e);
    expect(r.entries, isEmpty);
    r.unregister(e); // second removal is a no-op
    expect(n, 2);
  });

  test('the 17th member is refused with a non-fatal error', () {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);

    final r = GlassRegistry();
    for (var i = 0; i < GlassRegistry.maxShapes; i++) {
      expect(r.register(entry()), isTrue);
    }
    expect(r.register(entry()), isFalse);
    expect(r.entries.length, 16);
    expect(errors, hasLength(1));
    expect(errors.single.exceptionAsString(), contains('16'));
  });

  test('press geometry scales about the centre and translates', () {
    const g = GlassPressGeometry(
        scaleX: 1.5, scaleY: 1, translation: Offset(10, 0), glow: 1);
    final out = g.apply(const Rect.fromLTWH(0, 0, 100, 40));
    expect(out, const Rect.fromLTWH(-15, 0, 150, 40));
    expect(g.radiusScale, 1);
    expect(GlassPressGeometry.identity.apply(const Rect.fromLTWH(1, 2, 3, 4)),
        const Rect.fromLTWH(1, 2, 3, 4));
  });

  test('entries without a laid-out box are not laid out', () {
    expect(entry().isLaidOut, isFalse);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/group/glass_registry_test.dart`
Expected: FAIL — files missing.

- [ ] **Step 3: Implement** — `lib/src/group/glass_entry.dart`

```dart
import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../core/glass.dart';
import '../core/glass_shape.dart';

/// Press deformation of one member, produced by the press controller.
@immutable
class GlassPressGeometry {
  /// Creates a press geometry.
  const GlassPressGeometry({
    this.scaleX = 1,
    this.scaleY = 1,
    this.translation = Offset.zero,
    this.glow = 0,
    this.touch,
  });

  /// No deformation.
  static const GlassPressGeometry identity = GlassPressGeometry();

  /// Horizontal scale about the shape centre.
  final double scaleX;

  /// Vertical scale about the shape centre.
  final double scaleY;

  /// Offset of the shape centre, logical px.
  final Offset translation;

  /// Touch glow strength, 0..1.
  final double glow;

  /// Touch point in the member's local coordinates.
  final Offset? touch;

  /// [r] deformed by this geometry.
  Rect apply(Rect r) => Rect.fromCenter(
        center: r.center + translation,
        width: r.width * scaleX,
        height: r.height * scaleY,
      );

  /// Corner radii scale with the smaller axis scale.
  double get radiusScale => math.min(scaleX, scaleY);
}

/// One `LiquidGlass` registered with a group.
class GlassEntry {
  /// Creates an entry.
  GlassEntry({
    required this.shape,
    required this.glass,
    this.glassId,
    this.unionId,
  });

  /// Shape of the glass.
  GlassShape shape;

  /// Glass material.
  Glass glass;

  /// Morph identity (`glassEffectID`).
  Object? glassId;

  /// Union identity (`glassEffectUnion`).
  Object? unionId;

  /// The member's render box; set when its render object is created.
  RenderBox? box;

  /// Current press deformation.
  GlassPressGeometry press = GlassPressGeometry.identity;

  /// While morphing: the rect to draw, in the group's local coordinates.
  Rect? morphRect;

  /// The enclosing glass, for `GlassShape.concentric`.
  GlassEntry? container;

  /// Whether [box] is attached and has a non-empty size.
  bool get isLaidOut {
    final b = box;
    return b != null && b.attached && b.hasSize && !b.size.isEmpty;
  }
}
```

`lib/src/group/glass_registry.dart`:

```dart
import 'package:flutter/foundation.dart';

import 'glass_entry.dart';

/// The members of one `GlassGroup`.
class GlassRegistry extends ChangeNotifier {
  /// Maximum shapes drawn in one shader pass.
  static const int maxShapes = 16;

  final List<GlassEntry> _entries = [];

  /// Registered entries in registration order.
  List<GlassEntry> get entries => List.unmodifiable(_entries);

  /// Adds [e]. Returns `false` (and reports a non-fatal error) when full;
  /// the caller then renders [e] in its own implicit group.
  bool register(GlassEntry e) {
    if (_entries.length >= maxShapes) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: FlutterError(
            'A GlassGroup can merge at most $maxShapes shapes. Extra shapes '
            'are drawn on their own and will not merge.'),
        library: 'adaptive_liquid_glass',
      ));
      return false;
    }
    _entries.add(e);
    notifyListeners();
    return true;
  }

  /// Removes [e] if present.
  void unregister(GlassEntry e) {
    if (_entries.remove(e)) notifyListeners();
  }

  /// Asks the group to repaint (geometry or press state changed).
  void markNeedsPaint() => notifyListeners();
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/group && flutter analyze`
Expected: PASS; no issues.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: glass group registry and entries

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Uniform packing and union merging

**Files:**
- Create: `lib/src/shader/glass_uniforms.dart`, `test/shader/glass_uniforms_test.dart`

**Interfaces:**
- Consumes: `GlassVariant`, `GlassConstants`.
- Produces:
  - `class GlassShapeUniform { Rect rect; double radius; GlassVariant variant; Color? tint; Object? unionId; }` — `rect`/`radius` in **physical px, texture space**.
  - `class GlassFrameUniforms { List<GlassShapeUniform> shapes; double devicePixelRatio; double lightAngle; double smoothing /*physical px*/; GlassConstants constants; Brightness brightness /*default light*/; bool highContrast; Color? opaqueColor; Offset? touch /*physical px, texture space*/; double glow; }` — `brightness` picks the light or dark constant sets.
  - `const int kFirstUserFloat = 2;`
  - `List<GlassShapeUniform> mergeUnions(List<GlassShapeUniform> shapes)`
  - `List<double> packGlassUniforms(GlassFrameUniforms u)` — 232 floats, written to the shader starting at float index `kFirstUserFloat`.
  - Float layout (offsets into the returned list): `0` uGlobal(count, dpr, lightAngle, opaque) · `4` uGlobal2(smoothing, cornerExponent, highContrast, 0) · `8` uOpaque(r,g,b,0) · `12` uTouch(x, y, glow, glowRadiusPx) · `16` uRects[16] · `80` uInfo[16](radiusPx, variant, 0, 0) · `144` uTints[16](r,g,b,strength) · `208` uVar[6] (regular A,B,C then clear A,B,C).

- [ ] **Step 1: Write the failing test** — `test/shader/glass_uniforms_test.dart`

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_uniforms.dart';
import 'package:adaptive_liquid_glass/testing.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

GlassShapeUniform s(Rect r,
        {double radius = 10,
        GlassVariant v = GlassVariant.regular,
        Color? tint,
        Object? union}) =>
    GlassShapeUniform(
        rect: r, radius: radius, variant: v, tint: tint, unionId: union);

GlassFrameUniforms frame(List<GlassShapeUniform> shapes,
        {Color? opaque, Offset? touch, double glow = 0}) =>
    GlassFrameUniforms(
      shapes: shapes,
      devicePixelRatio: 3,
      lightAngle: -2,
      smoothing: 60,
      constants: GlassConstants.standard,
      opaqueColor: opaque,
      touch: touch,
      glow: glow,
    );

void main() {
  test('layout size and header', () {
    final f = packGlassUniforms(frame([s(const Rect.fromLTWH(1, 2, 30, 40))]));
    expect(f.length, 232);
    expect(f.sublist(0, 4), [1, 3, -2, 0]);
    expect(f.sublist(4, 8), [60, GlassConstants.standard.cornerExponent, 0, 0]);
    expect(f.sublist(16, 20), [1, 2, 30, 40]);
    expect(f.sublist(80, 84), [10, 0, 0, 0]);
  });

  test('variant constants are scaled to physical px', () {
    final f = packGlassUniforms(frame(const []));
    final reg = GlassConstants.standard.regular;
    final clr = GlassConstants.standard.clear;
    expect(f.sublist(208, 212),
        [reg.blurSigma * 3, reg.lensBand * 3, reg.lensStrength, reg.dispersion]);
    expect(f.sublist(212, 216),
        [reg.rimWidth * 3, reg.rimIntensity, reg.lumaLift, reg.dim]);
    expect(f.sublist(216, 220),
        [reg.shadowRadius * 3, reg.shadowOpacity, reg.tintStrength, 0]);
    expect(f.sublist(220, 224),
        [clr.blurSigma * 3, clr.lensBand * 3, clr.lensStrength, clr.dispersion]);
  });

  test('tint strength is tintStrength × alpha; clear variant index is 1', () {
    const tint = Color.fromARGB(128, 255, 0, 0);
    final f = packGlassUniforms(frame([
      s(const Rect.fromLTWH(0, 0, 10, 10), v: GlassVariant.clear, tint: tint)
    ]));
    expect(f[81], 1);
    expect(f.sublist(144, 147), [1, 0, 0]);
    expect(f[147],
        closeTo(GlassConstants.standard.clear.tintStrength * tint.a, 1e-9));
  });

  test('empty, non-finite and identity shapes are skipped', () {
    final f = packGlassUniforms(frame([
      s(Rect.zero),
      s(const Rect.fromLTWH(0, 0, double.nan, 5)),
      s(const Rect.fromLTWH(0, 0, 5, 5), v: GlassVariant.identity),
      s(const Rect.fromLTWH(5, 6, 7, 8)),
    ]));
    expect(f[0], 1);
    expect(f.sublist(16, 20), [5, 6, 7, 8]);
    expect(f.every((x) => x.isFinite), isTrue);
  });

  test('count is capped at 16', () {
    final f = packGlassUniforms(frame(
        List.generate(20, (i) => s(Rect.fromLTWH(i * 10.0, 0, 5, 5)))));
    expect(f[0], 16);
  });

  test('dark brightness packs the dark constant sets', () {
    final f = packGlassUniforms(GlassFrameUniforms(
      shapes: const [],
      devicePixelRatio: 1,
      lightAngle: 0,
      smoothing: 0,
      constants: GlassConstants.standard,
      brightness: Brightness.dark,
    ));
    final d = GlassConstants.standard.regularDark;
    expect(f.sublist(212, 216), [d.rimWidth, d.rimIntensity, d.lumaLift, d.dim]);
    expect(f[223 + 4], GlassConstants.standard.clearDark.dim);
  });

  test('opaque and touch', () {
    final f = packGlassUniforms(frame(const [],
        opaque: const Color(0xFF00FF00), touch: const Offset(7, 9), glow: 0.5));
    expect(f[3], 1);
    expect(f.sublist(8, 11), [0, 1, 0]);
    expect(f.sublist(12, 15), [7, 9, 0.5]);
    expect(f[15], GlassConstants.standard.motion.glowRadius * 3);
  });

  test('mergeUnions joins same-id shapes into their bounding rect', () {
    final out = mergeUnions([
      s(const Rect.fromLTWH(0, 0, 40, 40), radius: 20, union: 'a'),
      s(const Rect.fromLTWH(100, 0, 40, 40), radius: 12, union: 'a'),
      s(const Rect.fromLTWH(0, 100, 10, 10)),
    ]);
    expect(out, hasLength(2));
    expect(out.first.rect, const Rect.fromLTWH(0, 0, 140, 40));
    expect(out.first.radius, 12);
    expect(out.last.rect, const Rect.fromLTWH(0, 100, 10, 10));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/shader/glass_uniforms_test.dart`
Expected: FAIL — file missing.

- [ ] **Step 3: Implement** — `lib/src/shader/glass_uniforms.dart`

```dart
import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../core/glass.dart';
import '../core/glass_constants.dart';

/// First float index after the engine-owned `uSize` vec2.
const int kFirstUserFloat = 2;

const int _maxShapes = 16;

/// One shape for the shader, in physical px, texture space.
@immutable
class GlassShapeUniform {
  /// Creates a shape uniform.
  const GlassShapeUniform({
    required this.rect,
    required this.radius,
    required this.variant,
    this.tint,
    this.unionId,
  });

  /// Shape bounds.
  final Rect rect;

  /// Corner radius.
  final double radius;

  /// Glass variant.
  final GlassVariant variant;

  /// Optional tint.
  final Color? tint;

  /// Union identity; equal ids merge into one shape.
  final Object? unionId;
}

/// Everything the shader needs for one frame.
@immutable
class GlassFrameUniforms {
  /// Creates frame uniforms.
  const GlassFrameUniforms({
    required this.shapes,
    required this.devicePixelRatio,
    required this.lightAngle,
    required this.smoothing,
    required this.constants,
    this.brightness = Brightness.light,
    this.highContrast = false,
    this.opaqueColor,
    this.touch,
    this.glow = 0,
  });

  /// Light or dark appearance (selects constant sets).
  final Brightness brightness;

  /// Shapes to draw (already union-merged).
  final List<GlassShapeUniform> shapes;

  /// Physical px per logical px.
  final double devicePixelRatio;

  /// Light direction, radians, y-down.
  final double lightAngle;

  /// Smooth-min radius in physical px (group spacing × dpr).
  final double smoothing;

  /// Rendering constants.
  final GlassConstants constants;

  /// Increase Contrast is on.
  final bool highContrast;

  /// Non-null when Reduce Transparency forces an opaque surface.
  final Color? opaqueColor;

  /// Touch point, physical px, texture space.
  final Offset? touch;

  /// Touch glow strength 0..1.
  final double glow;
}

bool _drawable(GlassShapeUniform s) =>
    s.variant != GlassVariant.identity &&
    s.rect.isFinite &&
    s.rect.width > 0 &&
    s.rect.height > 0 &&
    s.radius.isFinite;

/// Merges shapes that share a non-null `unionId` into their bounding rect,
/// keeping the smallest radius and the first shape's variant and tint.
List<GlassShapeUniform> mergeUnions(List<GlassShapeUniform> shapes) {
  final out = <GlassShapeUniform>[];
  final byId = <Object, int>{};
  for (final s in shapes) {
    final id = s.unionId;
    final at = id == null ? null : byId[id];
    if (at == null) {
      if (id != null) byId[id] = out.length;
      out.add(s);
      continue;
    }
    final prev = out[at];
    final rect = prev.rect.expandToInclude(s.rect);
    out[at] = GlassShapeUniform(
      rect: rect,
      radius: math.min(math.min(prev.radius, s.radius), rect.shortestSide / 2),
      variant: prev.variant,
      tint: prev.tint,
      unionId: id,
    );
  }
  return out;
}

/// Packs [u] into the float layout documented in `shaders/liquid_glass.frag`.
List<double> packGlassUniforms(GlassFrameUniforms u) {
  final dpr = u.devicePixelRatio;
  final shapes = u.shapes.where(_drawable).take(_maxShapes).toList();
  final f = List<double>.filled(232, 0);

  f[0] = shapes.length.toDouble();
  f[1] = dpr;
  f[2] = u.lightAngle;
  f[3] = u.opaqueColor == null ? 0 : 1;

  f[4] = u.smoothing;
  f[5] = u.constants.cornerExponent;
  f[6] = u.highContrast ? 1 : 0;

  final o = u.opaqueColor;
  if (o != null) {
    f[8] = o.r;
    f[9] = o.g;
    f[10] = o.b;
  }

  final t = u.touch;
  if (t != null) {
    f[12] = t.dx;
    f[13] = t.dy;
    f[14] = u.glow;
  }
  f[15] = u.constants.motion.glowRadius * dpr;

  for (var i = 0; i < shapes.length; i++) {
    final s = shapes[i];
    final v = u.constants.of(s.variant, u.brightness);
    f.setAll(16 + i * 4, [s.rect.left, s.rect.top, s.rect.width, s.rect.height]);
    f.setAll(80 + i * 4,
        [s.radius, s.variant == GlassVariant.clear ? 1 : 0, 0, 0]);
    final tint = s.tint;
    if (tint != null) {
      f.setAll(144 + i * 4, [tint.r, tint.g, tint.b, v.tintStrength * tint.a]);
    }
  }

  var k = 208;
  for (final v in [
    u.constants.of(GlassVariant.regular, u.brightness),
    u.constants.of(GlassVariant.clear, u.brightness),
  ]) {
    f.setAll(k, [v.blurSigma * dpr, v.lensBand * dpr, v.lensStrength, v.dispersion]);
    f.setAll(k + 4, [v.rimWidth * dpr, v.rimIntensity, v.lumaLift, v.dim]);
    f.setAll(k + 8, [v.shadowRadius * dpr, v.shadowOpacity, v.tintStrength, 0]);
    k += 12;
  }
  return f;
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/shader && flutter analyze`
Expected: PASS; no issues.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: shader uniform packing and union merging

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Texture-space probe, the glass shader, program loader

This task answers one open question before the render object is written:
inside `BackdropFilterLayer(ImageFilter.shader)`, is `FlutterFragCoord()`
in **screen** physical px (with `uSize` = screen size) or **local to the
filter bounds**? It also proves `vec4` uniform arrays compile under impellerc.

**Files:**
- Create: `example/shaders/probe.frag`, `example/integration_test/probe_test.dart`, `docs/superpowers/notes/shader-probe.md`
- Modify: `example/pubspec.yaml` (shader asset, `integration_test` dev dependency)
- Create: `lib/src/shader/texture_space.dart`, `test/shader/texture_space_test.dart`
- Replace: `shaders/liquid_glass.frag`
- Create: `lib/src/shader/glass_program.dart`, `example/integration_test/shader_smoke_test.dart`

**Interfaces:**
- Produces:
  - `enum GlassTextureSpace { global, local }`, `const GlassTextureSpace kGlassTextureSpace` (value from the probe)
  - `Rect toTextureSpace(Rect globalLogical, {required Offset filterOriginGlobal, required double devicePixelRatio, GlassTextureSpace space = kGlassTextureSpace})` and `Offset pointToTextureSpace(Offset, {...same})`
  - `class GlassProgram { static GlassProgram instance; static const String assetKey; ValueListenable<ui.FragmentProgram?> get program; Future<void> load(); }`

- [ ] **Step 1: Write the probe shader** — `example/shaders/probe.frag`

```glsl
#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;

uniform vec2 uSize;
uniform vec4 uArr[4];
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  vec2 p = FlutterFragCoord().xy;
  float arrayOk = step(0.24, uArr[2].x) * step(uArr[2].x, 0.26);
  fragColor = vec4(p.x / uSize.x, p.y / uSize.y, (uSize.x / 4096.0) * arrayOk, 1.0);
}
```

In `example/pubspec.yaml` add:

```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
flutter:
  shaders:
    - shaders/probe.frag
```

- [ ] **Step 2: Write the probe test** — `example/integration_test/probe_test.dart`

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('backdrop shader texture space', (tester) async {
    expect(ui.ImageFilter.isShaderFilterSupported, isTrue,
        reason: 'Impeller must be on');
    final program = await ui.FragmentProgram.fromAsset('shaders/probe.frag');
    final shader = program.fragmentShader();
    for (var i = 0; i < 16; i++) {
      shader.setFloat(2 + i, 0);
    }
    shader.setFloat(2 + 8, 0.25); // uArr[2].x

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xFFFFFFFF))),
        Positioned(
          left: 200,
          top: 300,
          width: 100,
          height: 100,
          child: ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.shader(shader),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ]),
    ));
    await tester.pumpAndSettle();

    final png = await binding.takeScreenshot('probe');
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(png));
    final image = (await codec.getNextFrame()).image;
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final dpr = tester.view.devicePixelRatio;

    List<double> px(double x, double y) {
      final i = ((y * dpr).round() * image.width + (x * dpr).round()) * 4;
      return [for (var c = 0; c < 3; c++) data.getUint8(i + c) / 255];
    }

    final c = px(250, 350);
    final widthFromB = c[2] * 4096;
    // ignore: avoid_print
    print('PROBE screenPx=${image.width}x${image.height} dpr=$dpr '
        'center rgb=$c uSize.x≈$widthFromB');

    final globalR = 250 * dpr / image.width;
    final isGlobal = (c[0] - globalR).abs() < 0.01 &&
        (widthFromB - image.width).abs() < 24;
    final isLocal = (c[0] - 0.5).abs() < 0.01 &&
        (widthFromB - 100 * dpr).abs() < 24;
    // ignore: avoid_print
    print('PROBE result: ${isGlobal ? 'global' : isLocal ? 'local' : 'UNKNOWN'}');
    expect(c[2], greaterThan(0), reason: 'uniform array indexing failed');
    expect(isGlobal || isLocal, isTrue);
  });
}
```

- [ ] **Step 3: Run the probe on the iOS 26.4 simulator**

```bash
xcrun simctl boot E7A87B4A-3E48-44F8-A588-704D56774FF0 || true
cd example && flutter test integration_test/probe_test.dart -d E7A87B4A-3E48-44F8-A588-704D56774FF0
```

Expected: PASS and a line `PROBE result: global` or `PROBE result: local`.
If it prints `UNKNOWN`: stop and use superpowers:systematic-debugging on the printed values before going on — every later task depends on this mapping.

- [ ] **Step 4: Record the result** — `docs/superpowers/notes/shader-probe.md`

Write the printed PROBE lines, the date, Flutter version (`flutter --version | head -1`), simulator runtime, and the conclusion (global/local, arrays OK).

- [ ] **Step 5: Write the failing texture-space test** — `test/shader/texture_space_test.dart`

```dart
import 'package:adaptive_liquid_glass/src/shader/texture_space.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const r = Rect.fromLTWH(200, 300, 100, 50);
  test('global space scales by dpr', () {
    expect(
        toTextureSpace(r,
            filterOriginGlobal: const Offset(190, 290),
            devicePixelRatio: 3,
            space: GlassTextureSpace.global),
        const Rect.fromLTWH(600, 900, 300, 150));
  });
  test('local space is relative to the filter origin', () {
    expect(
        toTextureSpace(r,
            filterOriginGlobal: const Offset(190, 290),
            devicePixelRatio: 3,
            space: GlassTextureSpace.local),
        const Rect.fromLTWH(30, 30, 300, 150));
    expect(
        pointToTextureSpace(const Offset(191, 292),
            filterOriginGlobal: const Offset(190, 290),
            devicePixelRatio: 2,
            space: GlassTextureSpace.local),
        const Offset(2, 4));
  });
}
```

- [ ] **Step 6: Implement** — `lib/src/shader/texture_space.dart`

Set `kGlassTextureSpace` to the probe's answer.

```dart
import 'package:flutter/painting.dart';

/// Where `FlutterFragCoord()` lives for a backdrop shader filter.
enum GlassTextureSpace {
  /// Screen physical px; `uSize` is the screen.
  global,

  /// Physical px relative to the filter's clip origin.
  local,
}

/// Measured by `example/integration_test/probe_test.dart`; see
/// `docs/superpowers/notes/shader-probe.md`.
const GlassTextureSpace kGlassTextureSpace = GlassTextureSpace.global;

/// Maps a global logical rect into shader texture space.
Rect toTextureSpace(
  Rect globalLogical, {
  required Offset filterOriginGlobal,
  required double devicePixelRatio,
  GlassTextureSpace space = kGlassTextureSpace,
}) {
  final shifted = space == GlassTextureSpace.global
      ? globalLogical
      : globalLogical.shift(-filterOriginGlobal);
  return Rect.fromLTRB(
    shifted.left * devicePixelRatio,
    shifted.top * devicePixelRatio,
    shifted.right * devicePixelRatio,
    shifted.bottom * devicePixelRatio,
  );
}

/// Maps a global logical point into shader texture space.
Offset pointToTextureSpace(
  Offset globalLogical, {
  required Offset filterOriginGlobal,
  required double devicePixelRatio,
  GlassTextureSpace space = kGlassTextureSpace,
}) {
  final p = space == GlassTextureSpace.global
      ? globalLogical
      : globalLogical - filterOriginGlobal;
  return p * devicePixelRatio;
}
```

Run: `flutter test test/shader/texture_space_test.dart` — Expected: PASS.

- [ ] **Step 7: Write the glass shader** — replace `shaders/liquid_glass.frag`

```glsl
#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;

// Float layout must match lib/src/shader/glass_uniforms.dart.
uniform vec2 uSize;        // engine: texture size
uniform vec4 uGlobal;      // count, dpr, lightAngle, opaque
uniform vec4 uGlobal2;     // smoothing px, cornerExponent, highContrast, -
uniform vec4 uOpaque;      // rgb
uniform vec4 uTouch;       // x, y, glow, glowRadius px
uniform vec4 uRects[16];   // x, y, w, h px
uniform vec4 uInfo[16];    // radius px, variant(0 regular, 1 clear), -, -
uniform vec4 uTints[16];   // rgb, strength
uniform vec4 uVar[6];      // per variant: A(blur, band, lens, disp) B(rimW, rimI, lift, dim) C(shadowR, shadowO, tintS, -)
uniform sampler2D uTexture;

out vec4 fragColor;

vec4 tex(vec2 px) {
  vec2 uv = clamp(px / uSize, vec2(0.0), vec2(1.0));
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(uTexture, uv);
}

vec4 blurred(vec2 px, float sigma) {
  if (sigma < 0.5) return tex(px);
  vec4 acc = vec4(0.0);
  float wsum = 0.0;
  for (int i = 0; i < 24; i++) {
    float fi = float(i) + 0.5;
    float rr = sqrt(fi / 24.0) * sigma * 2.5;
    float a = fi * 2.39996323;
    float w = exp(-(rr * rr) / (2.0 * sigma * sigma));
    acc += tex(px + vec2(cos(a), sin(a)) * rr) * w;
    wsum += w;
  }
  return acc / wsum;
}

float sdSuperellipseBox(vec2 p, vec2 halfSize, float r, float n) {
  r = min(r, min(halfSize.x, halfSize.y));
  vec2 q = abs(p) - halfSize + r;
  vec2 m = max(q, 0.0);
  float corner = pow(pow(m.x, n) + pow(m.y, n), 1.0 / n);
  return corner + min(max(q.x, q.y), 0.0) - r;
}

float shapeDist(int i, vec2 p) {
  vec4 rc = uRects[i];
  vec2 hs = rc.zw * 0.5;
  return sdSuperellipseBox(p - (rc.xy + hs), hs, uInfo[i].x, uGlobal2.y);
}

float smin(float a, float b, float k) {
  if (k <= 0.0) return min(a, b);
  float h = max(k - abs(a - b), 0.0) / k;
  return min(a, b) - h * h * k * 0.25;
}

float field(vec2 p) {
  float d = 1e6;
  for (int i = 0; i < 16; i++) {
    if (i >= int(uGlobal.x)) break;
    d = smin(d, shapeDist(i, p), uGlobal2.x);
  }
  return d;
}

void main() {
  vec2 px = FlutterFragCoord().xy;
  vec4 base = tex(px);
  int count = int(uGlobal.x);
  if (count == 0) { fragColor = base; return; }

  // Per-shape attributes blended by proximity (for merged regions).
  float wsum = 0.0;
  float clearMix = 0.0;
  vec4 tint = vec4(0.0);
  float d = 1e6;
  for (int i = 0; i < 16; i++) {
    if (i >= count) break;
    float di = shapeDist(i, px);
    d = smin(d, di, uGlobal2.x);
    float w = exp(-max(di, 0.0) / (uGlobal2.x * 0.5 + 1.0));
    wsum += w;
    clearMix += w * uInfo[i].y;
    tint += w * uTints[i];
  }
  clearMix /= wsum;
  tint /= wsum;

  vec4 A = mix(uVar[0], uVar[3], clearMix);
  vec4 B = mix(uVar[1], uVar[4], clearMix);
  vec4 C = mix(uVar[2], uVar[5], clearMix);
  float hc = uGlobal2.z;

  float inside = 1.0 - smoothstep(-0.75, 0.75, d);

  // Shadow outside the shape.
  if (inside <= 0.0) {
    float sr = max(C.x * 0.5, 1.0);
    float sh = C.y * exp(-(d * d) / (2.0 * sr * sr));
    fragColor = vec4(base.rgb * (1.0 - sh), base.a);
    return;
  }

  // Opaque (Reduce Transparency).
  if (uGlobal.w > 0.5) {
    vec3 solid = mix(uOpaque.rgb, tint.rgb, tint.a);
    fragColor = vec4(mix(base.rgb, solid, inside), 1.0);
    return;
  }

  float e = 1.0;
  vec2 nrm = vec2(field(px + vec2(e, 0.0)) - field(px - vec2(e, 0.0)),
                  field(px + vec2(0.0, e)) - field(px - vec2(0.0, e)));
  nrm = normalize(nrm + vec2(1e-6));

  float depth = -d;
  float band = max(A.y, 1.0);
  float t = clamp(1.0 - depth / band, 0.0, 1.0);
  float lensAmt = A.z * (1.0 - 0.5 * hc) * t * t * band;
  vec2 sp = px + nrm * lensAmt;

  vec4 g = blurred(sp, A.x);
  vec3 col = g.rgb;
  vec2 disp = nrm * lensAmt * A.w;
  col.r = mix(col.r, blurred(sp + disp, A.x * 0.5).r, t);
  col.b = mix(col.b, blurred(sp - disp, A.x * 0.5).b, t);

  float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
  col += B.z * (1.0 - luma);
  col *= (1.0 - B.w);
  col = mix(col, tint.rgb, tint.a);

  vec2 L = vec2(cos(uGlobal.z), sin(uGlobal.z));
  float rimW = max(B.x * (1.0 + hc), 0.5);
  float rim = 1.0 - smoothstep(0.0, rimW, depth);
  float spec = rim * (max(dot(nrm, L), 0.0) + 0.35 * max(dot(nrm, -L), 0.0));
  col += B.y * (1.0 + hc) * spec;

  if (uTouch.z > 0.0) {
    vec2 dt = px - uTouch.xy;
    float gr = max(uTouch.w, 1.0);
    col += 0.25 * uTouch.z * exp(-dot(dt, dt) / (2.0 * gr * gr));
  }

  fragColor = vec4(mix(base.rgb, clamp(col, 0.0, 1.0), inside), 1.0);
}
```

Note: `field()` is evaluated 4× for the normal; Task 18 optimises it if the performance bar fails.

- [ ] **Step 8: Implement the program loader** — `lib/src/shader/glass_program.dart`

```dart
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Loads `liquid_glass.frag` once and shares it.
class GlassProgram {
  GlassProgram._();

  /// The shared instance.
  static final GlassProgram instance = GlassProgram._();

  /// Asset key of the shader inside this package.
  static const String assetKey =
      'packages/adaptive_liquid_glass/shaders/liquid_glass.frag';

  final ValueNotifier<ui.FragmentProgram?> _program = ValueNotifier(null);
  Future<void>? _loading;

  /// The loaded program, or `null` until [load] completes.
  ValueListenable<ui.FragmentProgram?> get program => _program;

  /// Starts loading (idempotent). Failures are reported and may be retried.
  Future<void> load() => _loading ??= ui.FragmentProgram.fromAsset(assetKey)
          .then<void>((p) => _program.value = p)
          .catchError((Object e, StackTrace s) {
        _loading = null;
        FlutterError.reportError(FlutterErrorDetails(
            exception: e, stack: s, library: 'adaptive_liquid_glass'));
      });
}
```

- [ ] **Step 9: Shader smoke test on the simulator** — `example/integration_test/shader_smoke_test.dart`

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_uniforms.dart';
import 'package:adaptive_liquid_glass/src/shader/texture_space.dart';
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('glass shader changes pixels only near the shape', (tester) async {
    await GlassProgram.instance.load();
    final shader = GlassProgram.instance.program.value!.fragmentShader();
    final dpr = tester.view.devicePixelRatio;
    const shapeGlobal = Rect.fromLTWH(100, 200, 200, 60);
    const filterBounds = Rect.fromLTWH(60, 160, 280, 140);
    final floats = packGlassUniforms(GlassFrameUniforms(
      shapes: [
        GlassShapeUniform(
          rect: toTextureSpace(shapeGlobal,
              filterOriginGlobal: filterBounds.topLeft, devicePixelRatio: dpr),
          radius: 30 * dpr,
          variant: GlassVariant.regular,
        )
      ],
      devicePixelRatio: dpr,
      lightAngle: -2.356,
      smoothing: 0,
      constants: GlassConstants.standard,
    ));
    for (var i = 0; i < floats.length; i++) {
      shader.setFloat(kFirstUserFloat + i, floats[i]);
    }

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(children: [
        // Stripes so lensing and blur are visible.
        Positioned.fill(
          child: Row(children: [
            for (var i = 0; i < 40; i++)
              Expanded(
                  child: ColoredBox(
                      color: i.isEven
                          ? const Color(0xFF101010)
                          : const Color(0xFFF0F0F0))),
          ]),
        ),
        Positioned.fromRect(
          rect: filterBounds,
          child: ClipRect(
            child: BackdropFilter(
                filter: ui.ImageFilter.shader(shader),
                child: const SizedBox.expand()),
          ),
        ),
      ]),
    ));
    await tester.pumpAndSettle();

    final png = await binding.takeScreenshot('smoke');
    final image = (await (await ui.instantiateImageCodec(
                Uint8List.fromList(png)))
            .getNextFrame())
        .image;
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    int lum(Offset p) {
      final i = ((p.dy * dpr).round() * image.width + (p.dx * dpr).round()) * 4;
      return data.getUint8(i);
    }

    // Centre of the glass: blurred stripes → mid grey, not pure black/white.
    final mid = lum(shapeGlobal.center);
    expect(mid, inInclusiveRange(40, 230));
    // Far outside the shadow: untouched stripe values.
    final far = lum(const Offset(64, 164));
    expect(far == 0x10 || far == 0xF0, isTrue, reason: 'far=$far');
  });
}
```

Run:

```bash
cd example && flutter test integration_test/shader_smoke_test.dart -d E7A87B4A-3E48-44F8-A588-704D56774FF0
```

Expected: PASS. If impellerc rejects the shader, the build error names the line; fix it there (GLSL subset: no recursion, constant loop bounds).

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "feat: glass shader, texture-space probe and program loader

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Material and degraded renderers

**Files:**
- Create: `lib/src/core/shape_border.dart`, `lib/src/material/material_glass.dart`, `lib/src/degraded/degraded_glass.dart`, `test/material/material_glass_test.dart`, `test/degraded/degraded_glass_test.dart`

**Interfaces:**
- Consumes: `Glass`, `GlassShape`, `GlassConstants`.
- Produces:
  - `OutlinedBorder sizeIndependentBorder(GlassShape shape)` — capsule/concentric → `StadiumBorder`, circle → `CircleBorder`, rect(r) → `RoundedSuperellipseBorder(BorderRadius.circular(r))`.
  - `Color opaqueGlassColor(Brightness b)` — light `0xFFF2F2F7`, dark `0xFF1C1C1E`.
  - `class MaterialGlass extends StatelessWidget { MaterialGlass({required Glass glass, required GlassShape shape, bool fadeIn = false, required Widget child}) }`
  - `class DegradedGlass extends StatelessWidget { DegradedGlass({required Glass glass, required GlassShape shape, required GlassConstants constants, Color? opaqueColor, required Widget child}) }`

- [ ] **Step 1: Write the failing tests**

`test/material/material_glass_test.dart`:

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/material/material_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
      theme: ThemeData(
          colorScheme:
              ColorScheme.fromSeed(seedColor: Colors.teal, brightness: b)),
      home: Scaffold(body: Center(child: child)),
    );

Material materialOf(WidgetTester t) => t.widget<Material>(find
    .descendant(of: find.byType(MaterialGlass), matching: find.byType(Material))
    .first);

void main() {
  testWidgets('regular → surfaceContainerHigh, elevation 1, stadium',
      (t) async {
    await t.pumpWidget(host(const MaterialGlass(
        glass: Glass.regular,
        shape: GlassShape.capsule(),
        child: Text('hi'))));
    final m = materialOf(t);
    final scheme = Theme.of(t.element(find.text('hi'))).colorScheme;
    expect(m.color, scheme.surfaceContainerHigh);
    expect(m.elevation, 1);
    expect(m.shape, isA<StadiumBorder>());
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('clear → translucent surfaceContainerLow, no elevation',
      (t) async {
    await t.pumpWidget(host(const MaterialGlass(
        glass: Glass.clear, shape: GlassShape.rect(12), child: Text('hi'))));
    final m = materialOf(t);
    final scheme = Theme.of(t.element(find.text('hi'))).colorScheme;
    expect(m.color, scheme.surfaceContainerLow.withValues(alpha: 0.85));
    expect(m.elevation, 0);
    expect(m.shape, isA<RoundedSuperellipseBorder>());
  });

  testWidgets('tint → primaryContainer of a seeded scheme', (t) async {
    await t.pumpWidget(host(MaterialGlass(
        glass: Glass.regular.tint(Colors.orange),
        shape: const GlassShape.circle(),
        child: const Text('hi'))));
    expect(
        materialOf(t).color,
        ColorScheme.fromSeed(seedColor: Colors.orange).primaryContainer);
  });

  testWidgets('interactive adds a ripple without stealing child taps',
      (t) async {
    var taps = 0;
    await t.pumpWidget(host(MaterialGlass(
      glass: Glass.regular.interactive(),
      shape: const GlassShape.capsule(),
      child: TextButton(onPressed: () => taps++, child: const Text('go')),
    )));
    expect(find.byType(InkWell), findsWidgets);
    await t.tap(find.text('go'));
    expect(taps, 1);
  });

  testWidgets('identity renders only the child', (t) async {
    await t.pumpWidget(host(const MaterialGlass(
        glass: Glass.identity,
        shape: GlassShape.capsule(),
        child: Text('hi'))));
    expect(
        find.descendant(
            of: find.byType(MaterialGlass), matching: find.byType(Material)),
        findsNothing);
  });

  testWidgets('fadeIn animates opacity from 0 to 1', (t) async {
    await t.pumpWidget(host(const MaterialGlass(
        glass: Glass.regular,
        shape: GlassShape.capsule(),
        fadeIn: true,
        child: Text('hi'))));
    expect(t.widget<Opacity>(find.byType(Opacity)).opacity, 0);
    await t.pumpAndSettle();
    expect(t.widget<Opacity>(find.byType(Opacity)).opacity, 1);
  });
}
```

`test/degraded/degraded_glass_test.dart`:

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/degraded/degraded_glass.dart';
import 'package:adaptive_liquid_glass/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget c) =>
    Directionality(textDirection: TextDirection.ltr, child: Center(child: c));

void main() {
  testWidgets('blur + clip when not opaque', (t) async {
    await t.pumpWidget(host(const DegradedGlass(
        glass: Glass.regular,
        shape: GlassShape.capsule(),
        constants: GlassConstants.standard,
        child: Text('hi'))));
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(ClipPath), findsOneWidget);
  });

  testWidgets('opaque draws a solid shape and no backdrop', (t) async {
    await t.pumpWidget(host(const DegradedGlass(
        glass: Glass.regular,
        shape: GlassShape.capsule(),
        constants: GlassConstants.standard,
        opaqueColor: Color(0xFFF2F2F7),
        child: Text('hi'))));
    expect(find.byType(BackdropFilter), findsNothing);
    final box = t.widget<DecoratedBox>(find.byType(DecoratedBox));
    expect((box.decoration as ShapeDecoration).color, const Color(0xFFF2F2F7));
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/material test/degraded`
Expected: FAIL — files missing.

- [ ] **Step 3: Implement** — `lib/src/core/shape_border.dart`

```dart
import 'package:flutter/painting.dart';

import 'glass_shape.dart';

/// A border that needs no layout size: used by Material and degraded paths.
OutlinedBorder sizeIndependentBorder(GlassShape shape) => switch (shape) {
      CapsuleGlassShape() || ConcentricGlassShape() => const StadiumBorder(),
      CircleGlassShape() => const CircleBorder(),
      RectGlassShape(:final cornerRadius) => RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(cornerRadius)),
    };

/// Solid fill used when Reduce Transparency is on (iOS system grouped
/// background colours).
Color opaqueGlassColor(Brightness brightness) => brightness == Brightness.dark
    ? const Color(0xFF1C1C1E)
    : const Color(0xFFF2F2F7);
```

`lib/src/material/material_glass.dart`:

```dart
import 'package:flutter/material.dart';

import '../core/glass.dart';
import '../core/glass_shape.dart';
import '../core/shape_border.dart';

/// Material 3 rendering of a glass member (spec §8).
class MaterialGlass extends StatelessWidget {
  /// Creates a Material glass surface.
  const MaterialGlass({
    super.key,
    required this.glass,
    required this.shape,
    this.fadeIn = false,
    required this.child,
  });

  /// Glass description.
  final Glass glass;

  /// Shape.
  final GlassShape shape;

  /// Fade in when first shown (members that appear after the group).
  final bool fadeIn;

  /// Content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (glass.variant == GlassVariant.identity) return child;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = glass.tintColor;
    final Color color = tint != null
        ? ColorScheme.fromSeed(seedColor: tint, brightness: theme.brightness)
            .primaryContainer
        : glass.variant == GlassVariant.clear
            ? scheme.surfaceContainerLow.withValues(alpha: 0.85)
            : scheme.surfaceContainerHigh;

    Widget surface = Material(
      color: color,
      elevation: glass.variant == GlassVariant.regular ? 1 : 0,
      shadowColor: scheme.shadow,
      surfaceTintColor: Colors.transparent,
      shape: sizeIndependentBorder(shape),
      clipBehavior: Clip.antiAlias,
      child: glass.isInteractive
          ? InkWell(onTap: () {}, excludeFromSemantics: true, child: child)
          : child,
    );

    if (fadeIn) {
      surface = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 200),
        builder: (context, v, child) => Opacity(opacity: v, child: child),
        child: surface,
      );
    }
    return surface;
  }
}
```

`lib/src/degraded/degraded_glass.dart`:

```dart
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../core/glass.dart';
import '../core/glass_constants.dart';
import '../core/glass_shape.dart';
import '../core/shape_border.dart';

/// Glass without shader support: blur, tint and a rim; no lensing or merging.
class DegradedGlass extends StatelessWidget {
  /// Creates a degraded glass surface.
  const DegradedGlass({
    super.key,
    required this.glass,
    required this.shape,
    required this.constants,
    this.opaqueColor,
    required this.child,
  });

  /// Glass description.
  final Glass glass;

  /// Shape.
  final GlassShape shape;

  /// Rendering constants.
  final GlassConstants constants;

  /// Non-null when Reduce Transparency forces a solid surface.
  final Color? opaqueColor;

  /// Content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (glass.variant == GlassVariant.identity) return child;
    final border = sizeIndependentBorder(shape);
    final c = constants.of(glass.variant, MediaQuery.platformBrightnessOf(context));
    final tint = glass.tintColor;

    final opaque = opaqueColor;
    if (opaque != null) {
      return DecoratedBox(
        decoration: ShapeDecoration(color: opaque, shape: border),
        child: child,
      );
    }

    final fill = tint != null
        ? tint.withValues(alpha: c.tintStrength * tint.a)
        : const Color(0xFFFFFFFF).withValues(alpha: c.lumaLift);
    return ClipPath(
      clipper: ShapeBorderClipper(shape: border),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: c.blurSigma, sigmaY: c.blurSigma),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: fill,
            shape: border.copyWith(
              side: BorderSide(
                color: const Color(0xFFFFFFFF)
                    .withValues(alpha: c.rimIntensity * 0.6),
                width: c.rimWidth,
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/material test/degraded && flutter analyze`
Expected: PASS; no issues.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: Material 3 and degraded glass renderers

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 10: `GlassGroup`, `LiquidGlass` and the backdrop render object

The heart of the package. After this task the shader path works end to end
for still glass (no press, no morph, no native yet; an effective `native`
mode renders through the shader until Task 13).

**Files:**
- Create: `lib/src/shader/render_glass_backdrop.dart`, `lib/src/group/glass_group.dart`, `lib/src/liquid_glass.dart`, `test/liquid_glass_test.dart`
- Modify: `lib/src/platform/glass_platform.dart` (test setter), `lib/src/shader/glass_program.dart` (test reset), `lib/adaptive_liquid_glass.dart` (exports)

**Interfaces:**
- Consumes: everything from Tasks 1–9.
- Produces:
  - `enum GlassMemberRendering { backdrop, material, degraded }` (Task 13 adds `native`)
  - `class GlassGroupScope extends InheritedWidget { GlassRegistry registry; GlassMemberRendering rendering; GlassConstants constants; Color? opaqueColor; bool settled; GlassRenderMode? requestedMode; static GlassGroupScope? maybeOf(BuildContext); static GlassGroupScope of(BuildContext); }`
  - `class GlassGroup extends StatefulWidget { GlassGroup({double spacing = 0, GlassRenderMode? mode, required Widget child}) }` (public)
  - `class LiquidGlass extends StatelessWidget { LiquidGlass({Glass? glass, GlassShape shape = const GlassShape.capsule(), Object? glassId, Object? unionId, GlassRenderMode? mode, required Widget child}); static Future<void> precache(); }` (public)
  - `class GlassBackdropConfig { double spacing, lightAngle, devicePixelRatio; GlassConstants constants; Brightness brightness; bool highContrast; Color? opaqueColor; }`
  - `class GlassBackdrop extends SingleChildRenderObjectWidget` → `RenderGlassBackdrop`, which exposes `GlassBackdropDebugFrame? debugLastFrame` (`uniforms`, `localBounds`, `filterOriginGlobal`).
  - `GlassPlatform.debugEnvironment` setter; `GlassProgram.debugReset({bool skipLoad = false})`.
  - Smoothing rule: `smoothing = 2 × spacing × dpr` (polynomial smin joins shapes when the gap < k/2, so shapes touch when the gap < `spacing`, matching `GlassEffectContainer(spacing:)`).

- [ ] **Step 1: Add the test hooks**

In `GlassPlatform`:

```dart
  /// Replaces the environment in tests and stops platform reads.
  @visibleForTesting
  set debugEnvironment(GlassEnvironment value) {
    _started = true;
    _environment.value = value;
  }
```

In `GlassProgram`:

```dart
  bool _skipLoad = false;

  /// Clears the loaded program. With [skipLoad], [load] does nothing.
  @visibleForTesting
  void debugReset({bool skipLoad = false}) {
    _skipLoad = skipLoad;
    _loading = null;
    _program.value = null;
  }
```

and make `load()` start with `if (_skipLoad) return Future.value();`.

- [ ] **Step 2: Write the failing tests** — `test/liquid_glass_test.dart`

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/core/shape_border.dart';
import 'package:adaptive_liquid_glass/src/degraded/degraded_glass.dart';
import 'package:adaptive_liquid_glass/src/material/material_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/shader/render_glass_backdrop.dart';
import 'package:adaptive_liquid_glass/src/shader/texture_space.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

void env({bool rt = false, bool shader = true, int? version = 26}) {
  GlassPlatform.instance.debugEnvironment = GlassEnvironment(
    platform: defaultTargetPlatform,
    iosMajorVersion: defaultTargetPlatform == TargetPlatform.iOS ? version : null,
    reduceTransparency: rt,
    shaderSupported: shader,
  );
}

Widget at(Rect r, Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(children: [Positioned.fromRect(rect: r, child: child)]),
    );

RenderGlassBackdrop backdropOf(WidgetTester t, [int index = 0]) => t
    .renderObjectList<RenderGlassBackdrop>(find.byType(GlassBackdrop))
    .elementAt(index);

Rect expected(WidgetTester t, Rect global, GlassBackdropDebugFrame f) =>
    toTextureSpace(global,
        filterOriginGlobal: f.filterOriginGlobal,
        devicePixelRatio: t.view.devicePixelRatio);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('standalone glass draws one shape at its global rect',
      (t) async {
    env();
    const r = Rect.fromLTWH(20, 40, 100, 50);
    await t.pumpWidget(at(r, const LiquidGlass(child: SizedBox.expand())));
    final f = backdropOf(t).debugLastFrame!;
    final dpr = t.view.devicePixelRatio;
    expect(f.uniforms.shapes.single.rect, expected(t, r, f));
    expect(f.uniforms.shapes.single.radius, 25 * dpr);
    expect(f.localBounds.contains(Offset.zero), isTrue);
  }, variant: ios);

  testWidgets('a GlassGroup draws its members in one pass', (t) async {
    env();
    await t.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: GlassGroup(
          spacing: 10,
          child: Row(mainAxisSize: MainAxisSize.min, children: const [
            LiquidGlass(child: SizedBox(width: 50, height: 50)),
            SizedBox(width: 8),
            LiquidGlass(child: SizedBox(width: 50, height: 50)),
          ]),
        ),
      ),
    ));
    expect(find.byType(GlassBackdrop), findsOneWidget);
    final f = backdropOf(t).debugLastFrame!;
    expect(f.uniforms.shapes, hasLength(2));
    expect(f.uniforms.smoothing, 2 * 10 * t.view.devicePixelRatio);
  }, variant: ios);

  testWidgets('zero-size glass is skipped without errors', (t) async {
    env();
    await t.pumpWidget(at(Rect.zero, const LiquidGlass(child: SizedBox())));
    expect(backdropOf(t).debugLastFrame, isNull);
    expect(t.takeException(), isNull);
  }, variant: ios);

  testWidgets('child renders while the shader is still loading', (t) async {
    env();
    await t.pumpWidget(at(const Rect.fromLTWH(0, 0, 100, 40),
        const LiquidGlass(child: Text('hi', textDirection: TextDirection.ltr))));
    expect(find.text('hi'), findsOneWidget);
    expect(t.takeException(), isNull);
  }, variant: ios);

  testWidgets('glass inside a scrolled list tracks its position', (t) async {
    env();
    final controller = ScrollController();
    await t.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: ListView(controller: controller, children: [
        for (var i = 0; i < 20; i++)
          SizedBox(
            height: 100,
            child: i == 3
                ? const LiquidGlass(
                    key: ValueKey('g'), child: SizedBox.expand())
                : null,
          ),
      ]),
    ));
    controller.jumpTo(50);
    await t.pump();
    final f = backdropOf(t).debugLastFrame!;
    final global = t.getRect(find.byKey(const ValueKey('g')));
    expect(global.top, 250);
    expect(f.uniforms.shapes.single.rect, expected(t, global, f));
  }, variant: ios);

  testWidgets('glass tracks a route transition', (t) async {
    env();
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(CupertinoApp(navigatorKey: nav, home: const SizedBox()));
    nav.currentState!.push(CupertinoPageRoute<void>(
      builder: (_) => const Center(
        child: LiquidGlass(
            key: ValueKey('g'), child: SizedBox(width: 80, height: 40)),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 150));
    final f = backdropOf(t).debugLastFrame!;
    final global = t.getRect(find.byKey(const ValueKey('g')));
    expect(f.uniforms.shapes.single.rect.left,
        closeTo(expected(t, global, f).left, 0.5));
    await t.pumpAndSettle();
  }, variant: ios);

  testWidgets('Android renders Material', (t) async {
    env();
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: const LiquidGlass(
                    child: SizedBox(width: 80, height: 40))))));
    expect(find.byType(MaterialGlass), findsOneWidget);
    expect(find.byType(GlassBackdrop), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Reduce Transparency switches to opaque while running',
      (t) async {
    env();
    await t.pumpWidget(at(const Rect.fromLTWH(0, 0, 100, 40),
        const LiquidGlass(child: SizedBox.expand())));
    expect(backdropOf(t).debugLastFrame!.uniforms.opaqueColor, isNull);
    env(rt: true);
    await t.pump();
    expect(backdropOf(t).debugLastFrame!.uniforms.opaqueColor,
        opaqueGlassColor(Brightness.light));
  }, variant: ios);

  testWidgets('no shader support uses the degraded renderer', (t) async {
    env(shader: false);
    await t.pumpWidget(at(const Rect.fromLTWH(0, 0, 100, 40),
        const LiquidGlass(child: SizedBox.expand())));
    expect(find.byType(DegradedGlass), findsOneWidget);
  }, variant: ios);

  testWidgets('the 17th member renders in its own group', (t) async {
    env();
    await t.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: GlassGroup(
        child: Wrap(children: [
          for (var i = 0; i < 17; i++)
            const LiquidGlass(child: SizedBox(width: 20, height: 20)),
        ]),
      ),
    ));
    expect(t.takeException(), isFlutterError);
    expect(find.byType(GlassBackdrop), findsNWidgets(2));
    expect(backdropOf(t, 0).debugLastFrame!.uniforms.shapes, hasLength(16));
    expect(backdropOf(t, 1).debugLastFrame!.uniforms.shapes, hasLength(1));
  }, variant: ios);

  testWidgets('concentric child radius = container radius − inset',
      (t) async {
    env();
    await t.pumpWidget(at(
      const Rect.fromLTWH(0, 0, 200, 100),
      const GlassGroup(
        child: LiquidGlass(
          shape: GlassShape.rect(28),
          child: Padding(
            padding: EdgeInsetsDirectional.all(8),
            child: LiquidGlass(
                shape: GlassShape.concentric(), child: SizedBox.expand()),
          ),
        ),
      ),
    ));
    final shapes = backdropOf(t).debugLastFrame!.uniforms.shapes;
    expect(shapes[1].radius, 20 * t.view.devicePixelRatio);
  }, variant: ios);

  testWidgets('unionId merges members into one shape', (t) async {
    env();
    await t.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: GlassGroup(
          child: Row(mainAxisSize: MainAxisSize.min, children: const [
            LiquidGlass(unionId: 'a', child: SizedBox(width: 40, height: 40)),
            SizedBox(width: 60),
            LiquidGlass(unionId: 'a', child: SizedBox(width: 40, height: 40)),
          ]),
        ),
      ),
    ));
    expect(backdropOf(t).debugLastFrame!.uniforms.shapes, hasLength(1));
  }, variant: ios);
}
```

- [ ] **Step 3: Run to verify they fail**

Run: `flutter test test/liquid_glass_test.dart`
Expected: FAIL — `LiquidGlass`, `GlassGroup`, `GlassBackdrop` undefined.

- [ ] **Step 4: Implement the render object** — `lib/src/shader/render_glass_backdrop.dart`

```dart
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/glass.dart';
import '../core/glass_constants.dart';
import '../core/glass_shape.dart';
import '../group/glass_entry.dart';
import '../group/glass_registry.dart';
import 'glass_program.dart';
import 'glass_uniforms.dart';
import 'texture_space.dart';

/// Per-group drawing parameters.
@immutable
class GlassBackdropConfig {
  /// Creates a config.
  const GlassBackdropConfig({
    required this.spacing,
    required this.lightAngle,
    required this.devicePixelRatio,
    required this.constants,
    required this.brightness,
    required this.highContrast,
    this.opaqueColor,
  });

  /// Light or dark appearance.
  final Brightness brightness;

  /// Group spacing (logical px).
  final double spacing;

  /// Light direction.
  final double lightAngle;

  /// Device pixel ratio.
  final double devicePixelRatio;

  /// Constants.
  final GlassConstants constants;

  /// Increase Contrast.
  final bool highContrast;

  /// Reduce Transparency fill.
  final Color? opaqueColor;

  @override
  bool operator ==(Object other) =>
      other is GlassBackdropConfig &&
      other.spacing == spacing &&
      other.lightAngle == lightAngle &&
      other.devicePixelRatio == devicePixelRatio &&
      other.constants == constants &&
      other.brightness == brightness &&
      other.highContrast == highContrast &&
      other.opaqueColor == opaqueColor;

  @override
  int get hashCode => Object.hash(spacing, lightAngle, devicePixelRatio,
      constants, brightness, highContrast, opaqueColor);
}

/// What the last paint computed; for tests.
@immutable
class GlassBackdropDebugFrame {
  /// Creates a debug frame.
  const GlassBackdropDebugFrame(
      this.uniforms, this.localBounds, this.filterOriginGlobal);

  /// Uniforms sent to the shader.
  final GlassFrameUniforms uniforms;

  /// Clip rect, local to the render object.
  final Rect localBounds;

  /// Global logical position of the clip origin.
  final Offset filterOriginGlobal;
}

/// Paints the group's glass behind its child.
class GlassBackdrop extends SingleChildRenderObjectWidget {
  /// Creates the backdrop.
  const GlassBackdrop({
    super.key,
    required this.registry,
    required this.config,
    this.backdropKey,
    super.child,
  });

  /// Members to draw.
  final GlassRegistry registry;

  /// Drawing parameters.
  final GlassBackdropConfig config;

  /// Shared backdrop capture key from an enclosing `BackdropGroup`.
  final BackdropKey? backdropKey;

  @override
  RenderGlassBackdrop createRenderObject(BuildContext context) =>
      RenderGlassBackdrop(
          registry: registry, config: config, backdropKey: backdropKey);

  @override
  void updateRenderObject(
      BuildContext context, RenderGlassBackdrop renderObject) {
    renderObject
      ..registry = registry
      ..config = config
      ..backdropKey = backdropKey;
  }
}

/// See [GlassBackdrop].
class RenderGlassBackdrop extends RenderProxyBox {
  /// Creates the render object.
  RenderGlassBackdrop({
    required GlassRegistry registry,
    required GlassBackdropConfig config,
    BackdropKey? backdropKey,
  })  : _registry = registry,
        _config = config,
        _backdropKey = backdropKey;

  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();
  final LayerHandle<BackdropFilterLayer> _backdrop =
      LayerHandle<BackdropFilterLayer>();

  /// The last computed frame (null when nothing was drawable).
  GlassBackdropDebugFrame? debugLastFrame;

  GlassRegistry _registry;

  /// Members to draw.
  GlassRegistry get registry => _registry;
  set registry(GlassRegistry value) {
    if (identical(value, _registry)) return;
    if (attached) _registry.removeListener(markNeedsPaint);
    _registry = value;
    if (attached) _registry.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  GlassBackdropConfig _config;

  /// Drawing parameters.
  GlassBackdropConfig get config => _config;
  set config(GlassBackdropConfig value) {
    if (value == _config) return;
    _config = value;
    markNeedsPaint();
  }

  BackdropKey? _backdropKey;

  /// Shared capture key.
  BackdropKey? get backdropKey => _backdropKey;
  set backdropKey(BackdropKey? value) {
    if (value == _backdropKey) return;
    _backdropKey = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _registry.addListener(markNeedsPaint);
    GlassProgram.instance.program.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _registry.removeListener(markNeedsPaint);
    GlassProgram.instance.program.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _clip.layer = null;
    _backdrop.layer = null;
    super.dispose();
  }

  Rect _baseGlobalRect(GlassEntry e, Matrix4 toGlobal) {
    final morph = e.morphRect;
    if (morph != null) return MatrixUtils.transformRect(toGlobal, morph);
    final box = e.box!;
    return MatrixUtils.transformRect(
        box.getTransformTo(null), e.shape.resolveRect(box.size));
  }

  double _baseRadius(GlassEntry e, Rect baseGlobal) {
    final c = e.container;
    final shape = e.shape;
    double? concentric;
    if (shape is ConcentricGlassShape && c != null && c.isLaidOut) {
      final cBox = c.box!;
      concentric = concentricRadius(
        container: MatrixUtils.transformRect(
            cBox.getTransformTo(null), c.shape.resolveRect(cBox.size)),
        containerRadius: c.shape.resolveRadius(cBox.size),
        child: baseGlobal,
        minimum: shape.minimum,
      );
    }
    return shape.resolveRadius(baseGlobal.size, concentricRadius: concentric);
  }

  GlassBackdropDebugFrame? _buildFrame() {
    final dpr = _config.devicePixelRatio;
    final toGlobal = getTransformTo(null);
    final fromGlobal = Matrix4.tryInvert(toGlobal);
    if (fromGlobal == null) return null;

    final drawn = <(GlassEntry, Rect, double)>[];
    for (final e in _registry.entries) {
      if (!e.isLaidOut || e.glass.variant == GlassVariant.identity) continue;
      final base = _baseGlobalRect(e, toGlobal);
      if (!base.isFinite || base.isEmpty) continue;
      final radius = _baseRadius(e, base) * e.press.radiusScale;
      drawn.add((e, e.press.apply(base), radius));
    }
    if (drawn.isEmpty) return null;

    final union =
        drawn.map((d) => d.$2).reduce((a, b) => a.expandToInclude(b));
    final c = _config.constants;
    final margin = math.max(c.regular.shadowRadius, c.clear.shadowRadius) * 2 +
        _config.spacing +
        2;
    final localBounds =
        MatrixUtils.transformRect(fromGlobal, union).inflate(margin);
    final origin = MatrixUtils.transformPoint(toGlobal, localBounds.topLeft);

    final shapes = mergeUnions([
      for (final (e, rect, radius) in drawn)
        GlassShapeUniform(
          rect: toTextureSpace(rect,
              filterOriginGlobal: origin, devicePixelRatio: dpr),
          radius: radius * dpr,
          variant: e.glass.variant,
          tint: e.glass.tintColor,
          unionId: e.unionId,
        ),
    ]);

    Offset? touch;
    var glow = 0.0;
    for (final (e, _, _) in drawn) {
      final p = e.press.touch;
      if (p != null && e.press.glow > glow) {
        glow = e.press.glow;
        touch = pointToTextureSpace(
            MatrixUtils.transformPoint(e.box!.getTransformTo(null), p),
            filterOriginGlobal: origin,
            devicePixelRatio: dpr);
      }
    }

    return GlassBackdropDebugFrame(
      GlassFrameUniforms(
        shapes: shapes,
        devicePixelRatio: dpr,
        lightAngle: _config.lightAngle,
        smoothing: 2 * _config.spacing * dpr,
        constants: c,
        brightness: _config.brightness,
        highContrast: _config.highContrast,
        opaqueColor: _config.opaqueColor,
        touch: touch,
        glow: glow,
      ),
      localBounds,
      origin,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final frame = _buildFrame();
    debugLastFrame = frame;
    final program = GlassProgram.instance.program.value;
    if (frame == null ||
        program == null ||
        !ui.ImageFilter.isShaderFilterSupported) {
      _clip.layer = null;
      super.paint(context, offset);
      return;
    }

    final shader = program.fragmentShader();
    final floats = packGlassUniforms(frame.uniforms);
    for (var i = 0; i < floats.length; i++) {
      shader.setFloat(kFirstUserFloat + i, floats[i]);
    }
    final backdrop = _backdrop.layer ??= BackdropFilterLayer();
    backdrop
      ..filter = ui.ImageFilter.shader(shader)
      ..backdropKey = _backdropKey;
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      frame.localBounds,
      (ctx, o) => ctx.pushLayer(backdrop, (_, _) {}, o),
      oldLayer: _clip.layer,
    );
    super.paint(context, offset);
  }
}
```

- [ ] **Step 5: Implement the group** — `lib/src/group/glass_group.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/glass_constants.dart';
import '../core/glass_render_mode.dart';
import '../core/render_mode_resolver.dart';
import '../core/shape_border.dart';
import '../core/theme.dart';
import '../platform/glass_platform.dart';
import '../shader/glass_program.dart';
import '../shader/render_glass_backdrop.dart';
import 'glass_registry.dart';

/// How members of a group render themselves.
enum GlassMemberRendering {
  /// Registered with the group's shader backdrop.
  backdrop,

  /// Each member is a Material surface.
  material,

  /// Each member is a blur-only surface.
  degraded,
}

/// Shares a group's registry and resolved mode with its members.
class GlassGroupScope extends InheritedWidget {
  /// Creates the scope.
  const GlassGroupScope({
    super.key,
    required this.registry,
    required this.rendering,
    required this.constants,
    required this.opaqueColor,
    required this.settled,
    required this.requestedMode,
    required super.child,
  });

  /// The group's registry.
  final GlassRegistry registry;

  /// How members render.
  final GlassMemberRendering rendering;

  /// Constants.
  final GlassConstants constants;

  /// Reduce Transparency fill.
  final Color? opaqueColor;

  /// True after the group's first frame (members added later may animate in).
  final bool settled;

  /// The group's requested mode, reused for overflow groups.
  final GlassRenderMode? requestedMode;

  /// Nearest scope or null.
  static GlassGroupScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassGroupScope>();

  /// Nearest scope; asserts one exists.
  static GlassGroupScope of(BuildContext context) => maybeOf(context)!;

  @override
  bool updateShouldNotify(GlassGroupScope old) =>
      old.registry != registry ||
      old.rendering != rendering ||
      old.constants != constants ||
      old.opaqueColor != opaqueColor ||
      old.settled != settled ||
      old.requestedMode != requestedMode;
}

/// Merges nearby `LiquidGlass` descendants into one shape, like SwiftUI's
/// `GlassEffectContainer(spacing:)`.
///
/// Inside a group, the group's [mode] wins over members' modes.
class GlassGroup extends StatefulWidget {
  /// Creates a group.
  const GlassGroup({super.key, this.spacing = 0, this.mode, required this.child});

  /// Shapes closer than this (logical px) blend together.
  final double spacing;

  /// Rendering mode; defaults to the theme's.
  final GlassRenderMode? mode;

  /// Content containing `LiquidGlass` widgets.
  final Widget child;

  @override
  State<GlassGroup> createState() => _GlassGroupState();
}

class _GlassGroupState extends State<GlassGroup> {
  final GlassRegistry _registry = GlassRegistry();
  final List<Listenable> _motion = [];
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    GlassPlatform.instance.ensureStarted();
    GlassPlatform.instance.environment.addListener(_onEnvironment);
    GlassProgram.instance.load();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _settled = true);
    });
  }

  void _onEnvironment() => setState(() {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribeMotion();
  }

  /// Repaint when an ancestor scrolls or the route animates: the shader
  /// samples screen-space pixels, and those ancestors move us without
  /// repainting us.
  void _subscribeMotion() {
    for (final l in _motion) {
      l.removeListener(_registry.markNeedsPaint);
    }
    _motion.clear();
    var scrollable = Scrollable.maybeOf(context);
    while (scrollable != null) {
      _motion.add(scrollable.position);
      scrollable = Scrollable.maybeOf(scrollable.context);
    }
    final route = ModalRoute.of(context);
    if (route != null) {
      final a = route.animation;
      final s = route.secondaryAnimation;
      if (a != null) _motion.add(a);
      if (s != null) _motion.add(s);
    }
    for (final l in _motion) {
      l.addListener(_registry.markNeedsPaint);
    }
  }

  @override
  void dispose() {
    for (final l in _motion) {
      l.removeListener(_registry.markNeedsPaint);
    }
    GlassPlatform.instance.environment.removeListener(_onEnvironment);
    _registry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = LiquidGlassTheme.of(context);
    final environment = GlassPlatform.instance.environment.value;
    final mode = resolveGlassMode(
      requested: widget.mode ?? theme.defaultMode,
      nativeEnabled: theme.nativeEnabled,
      environment: environment,
    );
    final opaque = mode == EffectiveGlassMode.opaque
        ? opaqueGlassColor(MediaQuery.platformBrightnessOf(context))
        : null;
    final rendering = switch (mode) {
      EffectiveGlassMode.material => GlassMemberRendering.material,
      EffectiveGlassMode.degraded => GlassMemberRendering.degraded,
      EffectiveGlassMode.opaque => environment.shaderSupported
          ? GlassMemberRendering.backdrop
          : GlassMemberRendering.degraded,
      // Task 13 gives native its own path.
      EffectiveGlassMode.shader ||
      EffectiveGlassMode.native =>
        GlassMemberRendering.backdrop,
    };

    final Widget scoped = GlassGroupScope(
      registry: _registry,
      rendering: rendering,
      constants: theme.constants,
      opaqueColor: opaque,
      settled: _settled,
      requestedMode: widget.mode,
      child: widget.child,
    );
    if (rendering != GlassMemberRendering.backdrop) return scoped;

    return GlassBackdrop(
      registry: _registry,
      backdropKey: BackdropGroup.of(context)?.backdropKey,
      config: GlassBackdropConfig(
        spacing: widget.spacing,
        lightAngle: theme.lightAngle,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        constants: theme.constants,
        brightness: MediaQuery.platformBrightnessOf(context),
        highContrast: MediaQuery.highContrastOf(context),
        opaqueColor: opaque,
      ),
      child: scoped,
    );
  }
}
```

`MediaQuery.*Of(context)` throws without a `MediaQuery`. Tests pump under the test view, which provides one through `View`, so the `Directionality`-only hosts above still work.

- [ ] **Step 6: Implement the widget** — `lib/src/liquid_glass.dart`

```dart
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'core/glass.dart';
import 'core/glass_render_mode.dart';
import 'core/glass_shape.dart';
import 'core/theme.dart';
import 'degraded/degraded_glass.dart';
import 'group/glass_entry.dart';
import 'group/glass_group.dart';
import 'group/glass_registry.dart';
import 'material/material_glass.dart';
import 'shader/glass_program.dart';

/// Liquid Glass behind [child], like SwiftUI's `.glassEffect(_:in:)`.
///
/// On iOS this is shader glass (or Apple's own on iOS 26+ when
/// `LiquidGlassThemeData.nativeEnabled`); on Android a Material 3 surface.
class LiquidGlass extends StatelessWidget {
  /// Creates Liquid Glass.
  const LiquidGlass({
    super.key,
    this.glass,
    this.shape = const GlassShape.capsule(),
    this.glassId,
    this.unionId,
    this.mode,
    required this.child,
  });

  /// The glass material; defaults to the theme's `defaultGlass`.
  final Glass? glass;

  /// The shape; defaults to a capsule.
  final GlassShape shape;

  /// Morph identity inside a `GlassGroup` (`glassEffectID`).
  final Object? glassId;

  /// Members with the same id merge into one shape (`glassEffectUnion`).
  final Object? unionId;

  /// Rendering mode when not inside a `GlassGroup` (a group's mode wins).
  final GlassRenderMode? mode;

  /// Content drawn on the glass.
  final Widget child;

  /// Loads the shader ahead of the first frame. Call from `main()` to avoid
  /// a frame without glass at startup.
  static Future<void> precache() => GlassProgram.instance.load();

  @override
  Widget build(BuildContext context) {
    final member = GlassMember(
      glass: glass ?? LiquidGlassTheme.of(context).defaultGlass,
      shape: shape,
      glassId: glassId,
      unionId: unionId,
      mode: mode,
      child: child,
    );
    return GlassGroupScope.maybeOf(context) == null
        ? GlassGroup(mode: mode, child: member)
        : member;
  }
}

/// A `LiquidGlass` inside a group. Internal.
class GlassMember extends StatefulWidget {
  /// Creates a member.
  const GlassMember({
    super.key,
    required this.glass,
    required this.shape,
    required this.glassId,
    required this.unionId,
    required this.mode,
    required this.child,
  });

  /// See [LiquidGlass.glass].
  final Glass glass;

  /// See [LiquidGlass.shape].
  final GlassShape shape;

  /// See [LiquidGlass.glassId].
  final Object? glassId;

  /// See [LiquidGlass.unionId].
  final Object? unionId;

  /// See [LiquidGlass.mode].
  final GlassRenderMode? mode;

  /// Content.
  final Widget child;

  @override
  State<GlassMember> createState() => GlassMemberState();
}

/// State of [GlassMember]. Public so later tasks can extend behaviour.
class GlassMemberState extends State<GlassMember> {
  /// The registry record for this member.
  late final GlassEntry entry = GlassEntry(
    shape: widget.shape,
    glass: widget.glass,
    glassId: widget.glassId,
    unionId: widget.unionId,
  );

  GlassRegistry? _registry;
  bool _overflow = false;
  bool _fadeIn = false;
  bool _first = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = GlassGroupScope.of(context);
    if (_first) {
      _fadeIn = scope.settled && widget.glassId != null;
      _first = false;
    }
    entry.container = ConcentricScope.maybeOf(context);
    final target =
        scope.rendering == GlassMemberRendering.backdrop ? scope.registry : null;
    if (!identical(target, _registry)) {
      _registry?.unregister(entry);
      _registry = target;
      _overflow = target != null && !target.register(entry);
    }
  }

  @override
  void didUpdateWidget(GlassMember old) {
    super.didUpdateWidget(old);
    entry
      ..shape = widget.shape
      ..glass = widget.glass
      ..glassId = widget.glassId
      ..unionId = widget.unionId;
    _registry?.markNeedsPaint();
  }

  @override
  void dispose() {
    _registry?.unregister(entry);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = GlassGroupScope.of(context);
    if (_overflow) {
      return GlassGroup(
        mode: scope.requestedMode,
        child: GlassMember(
          glass: widget.glass,
          shape: widget.shape,
          glassId: widget.glassId,
          unionId: widget.unionId,
          mode: widget.mode,
          child: widget.child,
        ),
      );
    }
    if (widget.glass.variant == GlassVariant.identity) return widget.child;
    return switch (scope.rendering) {
      GlassMemberRendering.material => MaterialGlass(
          glass: widget.glass,
          shape: widget.shape,
          fadeIn: _fadeIn,
          child: widget.child),
      GlassMemberRendering.degraded => DegradedGlass(
          glass: widget.glass,
          shape: widget.shape,
          constants: scope.constants,
          opaqueColor: scope.opaqueColor,
          child: widget.child),
      GlassMemberRendering.backdrop => ConcentricScope(
          entry: entry,
          child: GlassMemberBox(
              entry: entry, registry: _registry!, child: buildContent(context)),
        ),
    };
  }

  /// The child as drawn on the glass. Task 11 wraps it in the press
  /// transform; Task 12 adds the morph fade.
  Widget buildContent(BuildContext context) => widget.child;
}

/// Provides the enclosing glass entry to concentric descendants.
class ConcentricScope extends InheritedWidget {
  /// Creates the scope.
  const ConcentricScope({super.key, required this.entry, required super.child});

  /// The enclosing glass.
  final GlassEntry entry;

  /// Nearest enclosing entry.
  static GlassEntry? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ConcentricScope>()?.entry;

  @override
  bool updateShouldNotify(ConcentricScope old) => old.entry != entry;
}

/// Hands its render box to the entry and reports geometry changes.
class GlassMemberBox extends SingleChildRenderObjectWidget {
  /// Creates the box.
  const GlassMemberBox(
      {super.key, required this.entry, required this.registry, super.child});

  /// The member's entry.
  final GlassEntry entry;

  /// The member's registry.
  final GlassRegistry registry;

  @override
  RenderGlassMember createRenderObject(BuildContext context) {
    final r = RenderGlassMember(entry, registry);
    entry.box = r;
    return r;
  }

  @override
  void updateRenderObject(BuildContext context, RenderGlassMember r) {
    r
      ..entry = entry
      ..registry = registry;
    entry.box = r;
  }
}

/// See [GlassMemberBox].
class RenderGlassMember extends RenderProxyBox {
  /// Creates the render object.
  RenderGlassMember(this.entry, this.registry);

  /// The member's entry.
  GlassEntry entry;

  /// The member's registry.
  GlassRegistry registry;

  Matrix4? _lastTransform;

  @override
  void performLayout() {
    final old = hasSize ? size : null;
    super.performLayout();
    if (old != size) registry.markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    // A repaint boundary between us and the group can move us without
    // repainting the group; catch that one frame later.
    final t = getTransformTo(null);
    if (_lastTransform != null && _lastTransform != t) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (attached) registry.markNeedsPaint();
      });
      SchedulerBinding.instance.ensureVisualUpdate();
    }
    _lastTransform = t;
  }
}
```

Library exports (`lib/adaptive_liquid_glass.dart`):

```dart
export 'src/core/glass.dart';
export 'src/core/glass_render_mode.dart' show GlassRenderMode;
export 'src/core/glass_shape.dart';
export 'src/core/theme.dart';
export 'src/group/glass_group.dart' show GlassGroup;
export 'src/liquid_glass.dart' show LiquidGlass;
```

- [ ] **Step 7: Run tests**

Run: `flutter test && flutter analyze`
Expected: all PASS; no issues. If the route-transition test fails by exactly one frame, check that `_subscribeMotion` received the route animations (print `_motion.length`) before changing anything else.

- [ ] **Step 8: See it on the simulator**

Replace `example/lib/main.dart` with a quick demo: a full-screen photo-like gradient (`DecoratedBox` with a `LinearGradient` of 6 colours plus 30 `Positioned` white bars), a `GlassGroup(spacing: 20)` with three `LiquidGlass` capsules near the bottom, and a `LiquidGlass(shape: GlassShape.rect(28))` card in the middle. Call `await LiquidGlass.precache()` in `main` after `WidgetsFlutterBinding.ensureInitialized()`.

Run: `cd example && flutter run -d E7A87B4A-3E48-44F8-A588-704D56774FF0`
Expected: glass visible, edges lens the bars, the three capsules merge when dragged together (skip dragging; just confirm still rendering). Take a screenshot with `xcrun simctl io E7A87B4A-3E48-44F8-A588-704D56774FF0 screenshot /tmp/alg-task10.png` and look at it.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: GlassGroup, LiquidGlass and shader backdrop render object

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 11: `.interactive()` press response

**Files:**
- Create: `lib/src/interaction/press_controller.dart`, `test/interaction/press_controller_test.dart`
- Modify: `lib/src/liquid_glass.dart` (`GlassMemberState` gains a ticker and `buildContent` override), `test/liquid_glass_test.dart` (press tests)

**Interfaces:**
- Consumes: `GlassMotionConstants`, `swiftUISpring`, `GlassPressGeometry`, `GlassEntry`, `GlassRegistry`.
- Produces: `class GlassPressController extends ChangeNotifier { GlassPressController({required TickerProvider vsync, required GlassMotionConstants motion}); GlassMotionConstants motion; bool reduceMotion; double get amount; void down(Offset local, Size size); void move(Offset local); void up(); GlassPressGeometry geometry(); Matrix4 contentTransform(); }`

- [ ] **Step 1: Write the failing controller test** — `test/interaction/press_controller_test.dart`

```dart
import 'package:adaptive_liquid_glass/src/group/glass_entry.dart';
import 'package:adaptive_liquid_glass/src/interaction/press_controller.dart';
import 'package:adaptive_liquid_glass/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const motion = GlassConstants.standard;

  testWidgets('press grows toward the touch, release springs back',
      (t) async {
    final c = GlassPressController(vsync: const TestVSync(), motion: motion.motion);
    addTearDown(c.dispose);
    expect(c.geometry(), same(GlassPressGeometry.identity));

    c.down(const Offset(100, 20), const Size(100, 40)); // right edge, centre row
    await t.pump(const Duration(seconds: 1));
    final g = c.geometry();
    expect(c.amount, closeTo(1, 0.01));
    expect(g.scaleX, greaterThan(g.scaleY)); // stretched along x
    expect(g.scaleY, closeTo(1 + motion.motion.pressScale, 0.01));
    expect(g.translation.dx, greaterThan(0));
    expect(g.translation.dy, closeTo(0, 1e-6));
    expect(g.glow, closeTo(1, 0.01));
    expect(g.touch, const Offset(100, 20));

    c.up();
    await t.pump(const Duration(seconds: 2));
    expect(c.amount, closeTo(0, 0.01));
  });

  testWidgets('release overshoots below zero (bounce)', (t) async {
    final c = GlassPressController(vsync: const TestVSync(), motion: motion.motion);
    addTearDown(c.dispose);
    c.down(const Offset(50, 20), const Size(100, 40));
    await t.pump(const Duration(seconds: 1));
    c.up();
    var min = 1.0;
    for (var i = 0; i < 60; i++) {
      await t.pump(const Duration(milliseconds: 16));
      if (c.amount < min) min = c.amount;
    }
    expect(min, lessThan(0)); // pressDamping < 1 → overshoot
  });

  testWidgets('reduce motion keeps geometry but still glows', (t) async {
    final c = GlassPressController(vsync: const TestVSync(), motion: motion.motion)
      ..reduceMotion = true;
    addTearDown(c.dispose);
    c.down(const Offset(100, 20), const Size(100, 40));
    await t.pump(const Duration(seconds: 1));
    final g = c.geometry();
    expect(g.scaleX, 1);
    expect(g.scaleY, 1);
    expect(g.translation, Offset.zero);
    expect(g.glow, greaterThan(0.9));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/interaction`
Expected: FAIL — file missing.

- [ ] **Step 3: Implement** — `lib/src/interaction/press_controller.dart`

```dart
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../core/glass_constants.dart';
import '../core/swiftui_spring.dart';
import '../group/glass_entry.dart';

/// Drives `.interactive()`: a spring from 0 (rest) to 1 (pressed).
class GlassPressController extends ChangeNotifier {
  /// Creates a controller.
  GlassPressController({
    required TickerProvider vsync,
    required this.motion,
  }) : _controller = AnimationController.unbounded(vsync: vsync) {
    _controller.addListener(notifyListeners);
  }

  final AnimationController _controller;

  /// Motion constants.
  GlassMotionConstants motion;

  /// When true, only the glow animates (Reduce Motion).
  bool reduceMotion = false;

  Offset? _touch;
  Size _size = Size.zero;

  /// Press amount; may overshoot outside 0..1.
  double get amount => _controller.value;

  /// Pointer went down at [local] on a box of [size].
  void down(Offset local, Size size) {
    _touch = local;
    _size = size;
    _animateTo(1);
  }

  /// Pointer moved while pressed.
  void move(Offset local) {
    _touch = local;
    notifyListeners();
  }

  /// Pointer released or cancelled.
  void up() => _animateTo(0);

  void _animateTo(double target) {
    _controller.animateWith(SpringSimulation(
      swiftUISpring(
          response: motion.pressResponse, dampingFraction: motion.pressDamping),
      _controller.value,
      target,
      _controller.velocity,
    ));
  }

  /// Current deformation; [GlassPressGeometry.identity] at rest.
  GlassPressGeometry geometry() {
    final a = amount;
    if (a.abs() < 1e-4 && !_controller.isAnimating) {
      return GlassPressGeometry.identity;
    }
    final glow = a.clamp(0.0, 1.0);
    if (reduceMotion || _size.isEmpty) {
      return GlassPressGeometry(glow: glow, touch: _touch);
    }
    final centre = _size.center(Offset.zero);
    final touch = _touch ?? centre;
    final dx = ((touch.dx - centre.dx) / (_size.width / 2)).clamp(-1.0, 1.0);
    final dy = ((touch.dy - centre.dy) / (_size.height / 2)).clamp(-1.0, 1.0);
    final s = 1 + motion.pressScale * a;
    return GlassPressGeometry(
      scaleX: s + motion.pressStretch * a * dx.abs(),
      scaleY: s + motion.pressStretch * a * dy.abs(),
      translation: Offset(
        dx * motion.pressStretch * a * _size.width / 4,
        dy * motion.pressStretch * a * _size.height / 4,
      ),
      glow: glow,
      touch: touch,
    );
  }

  /// The same deformation as a transform for the member's content.
  Matrix4 contentTransform() {
    final g = geometry();
    final c = _size.center(Offset.zero);
    return Matrix4.identity()
      ..translateByDouble(c.dx + g.translation.dx, c.dy + g.translation.dy, 0, 1)
      ..scaleByDouble(g.scaleX, g.scaleY, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 4: Wire it into the member** — in `lib/src/liquid_glass.dart`

Change the state declaration to `class GlassMemberState extends State<GlassMember> with SingleTickerProviderStateMixin` and add:

```dart
  GlassPressController? _press;

  GlassPressController _pressController(GlassGroupScope scope) =>
      _press ??= GlassPressController(
          vsync: this, motion: scope.constants.motion)
        ..addListener(() {
          entry.press = _press!.geometry();
          _registry?.markNeedsPaint();
        });
```

Dispose it in `dispose()` (`_press?.dispose();`). Replace `buildContent`:

```dart
  /// The child as drawn on the glass.
  Widget buildContent(BuildContext context) {
    if (!widget.glass.isInteractive) {
      entry.press = GlassPressGeometry.identity;
      return widget.child;
    }
    final scope = GlassGroupScope.of(context);
    final press = _pressController(scope)
      ..motion = scope.constants.motion
      ..reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) =>
          press.down(e.localPosition, context.size ?? Size.zero),
      onPointerMove: (e) => press.move(e.localPosition),
      onPointerUp: (_) => press.up(),
      onPointerCancel: (_) => press.up(),
      child: AnimatedBuilder(
        animation: press,
        builder: (_, child) =>
            Transform(transform: press.contentTransform(), child: child),
        child: widget.child,
      ),
    );
  }
```

Add imports for `interaction/press_controller.dart`.

- [ ] **Step 5: Add widget tests** — append to `test/liquid_glass_test.dart`

```dart
  testWidgets('pressing interactive glass grows the shape and glows',
      (t) async {
    env();
    const r = Rect.fromLTWH(100, 100, 120, 40);
    await t.pumpWidget(at(
        r,
        LiquidGlass(
            glass: Glass.regular.interactive(),
            child: const SizedBox.expand())));
    final before = backdropOf(t).debugLastFrame!.uniforms.shapes.single.rect;
    final gesture = await t.startGesture(r.centerRight - const Offset(4, 0));
    await t.pump(const Duration(milliseconds: 400));
    final pressed = backdropOf(t).debugLastFrame!.uniforms;
    expect(pressed.shapes.single.rect.width, greaterThan(before.width));
    expect(pressed.glow, greaterThan(0.5));
    expect(pressed.touch, isNotNull);
    await gesture.up();
    await t.pumpAndSettle();
    final after = backdropOf(t).debugLastFrame!.uniforms;
    expect(after.shapes.single.rect, before);
    expect(after.glow, 0);
  }, variant: ios);

  testWidgets('non-interactive glass ignores presses', (t) async {
    env();
    const r = Rect.fromLTWH(100, 100, 120, 40);
    await t.pumpWidget(at(r, const LiquidGlass(child: SizedBox.expand())));
    final before = backdropOf(t).debugLastFrame!.uniforms.shapes.single.rect;
    final gesture = await t.startGesture(r.center);
    await t.pump(const Duration(milliseconds: 400));
    expect(backdropOf(t).debugLastFrame!.uniforms.shapes.single.rect, before);
    await gesture.up();
  }, variant: ios);
```

- [ ] **Step 6: Run tests**

Run: `flutter test && flutter analyze`
Expected: PASS; no issues.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: interactive glass press spring

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: `glassId` morphs

**Files:**
- Create: `lib/src/group/morph_controller.dart`, `test/group/morph_test.dart`
- Modify: `lib/src/group/glass_entry.dart` (`lastDrawnLocal`, `contentOpacity`, `isGhost`), `lib/src/group/glass_registry.dart` (`onAdded` / `onRemoved` hooks), `lib/src/shader/render_glass_backdrop.dart` (draw ghosts, record `lastDrawnLocal`), `lib/src/group/glass_group.dart` (own the controller; `TickerProviderStateMixin`), `lib/src/liquid_glass.dart` (content fade)

**Behaviour (the rules the tests pin):**
1. On the group's first frame nothing animates.
2. A member with a new `glassId` registered after the first frame is hidden for its first frame (`morphRect = Rect.zero`), then grows from the nearest drawn shape to its laid-out rect on a SwiftUI spring (`morphResponse`, `morphDamping`); its content fades 0→1 on the same progress.
3. A removed member with a `glassId` becomes a ghost (same entry, `box = null`) that shrinks into the nearest remaining shape's centre and is unregistered when the spring settles.
4. Same id, new view (the SwiftUI `glassEffectID` morph): the new member morphs from the old one's last rect and no ghost is drawn. Flutter mounts the new element before unmounting the old one, so this is handled in `onRemoved` (the new track takes `fromOverride`); if the old one was removed in an earlier frame, the new member takes over the ghost's current rect in `onAdded`.
5. Pure layout changes of a live member never trigger a morph.

**Interfaces:**
- Consumes: `GlassRegistry`, `GlassEntry`, `swiftUISpring`.
- Produces:
  - `GlassEntry`: `Rect? lastDrawnLocal` (group-local, written by the renderer each paint), `final ValueNotifier<double> contentOpacity` (1 by default), `bool get isGhost => box == null && morphRect != null`.
  - `GlassRegistry`: `void Function(GlassEntry)? onAdded`, `void Function(GlassEntry)? onRemoved` (called after the list changes).
  - `class GlassMorphController { GlassMorphController({required TickerProvider vsync, required GlassRegistry registry, required RenderBox? Function() groupBox, required GlassMotionConstants Function() motion}); void markSettled(); void dispose(); }`
  - Renderer: draws entries where `isLaidOut || isGhost`; for ghosts the base rect is `morphRect` converted from group-local.

- [ ] **Step 1: Write the failing tests** — `test/group/morph_test.dart`

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/shader/render_glass_backdrop.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

void env() => GlassPlatform.instance.debugEnvironment = const GlassEnvironment(
    platform: TargetPlatform.iOS,
    iosMajorVersion: 26,
    reduceTransparency: false,
    shaderSupported: true);

List<Rect> shapes(WidgetTester t) => t
    .renderObject<RenderGlassBackdrop>(find.byType(GlassBackdrop))
    .debugLastFrame!
    .uniforms
    .shapes
    .map((s) => s.rect)
    .toList();

Widget scene({required bool showB, bool bOnRight = false}) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: GlassGroup(
          spacing: 10,
          child: SizedBox(
            width: 300,
            height: 60,
            child: Stack(children: [
              const PositionedDirectional(
                start: 0,
                top: 0,
                child: LiquidGlass(
                    glassId: 'a', child: SizedBox(width: 60, height: 60)),
              ),
              if (showB)
                PositionedDirectional(
                  start: bOnRight ? 240 : 80,
                  top: 0,
                  child: LiquidGlass(
                      key: ValueKey(bOnRight),
                      glassId: 'b',
                      child: const SizedBox(width: 60, height: 60)),
                ),
            ]),
          ),
        ),
      ),
    );

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('first frame does not animate', (t) async {
    env();
    await t.pumpWidget(scene(showB: true));
    expect(shapes(t), hasLength(2));
    await t.pump(const Duration(milliseconds: 16));
    final s = shapes(t);
    expect(s[1].width, s[0].width);
  }, variant: ios);

  testWidgets('appearing glass grows from its neighbour', (t) async {
    env();
    await t.pumpWidget(scene(showB: false));
    await t.pump();
    await t.pumpWidget(scene(showB: true));
    expect(shapes(t), hasLength(1)); // hidden on its first frame
    await t.pump(const Duration(milliseconds: 50));
    final mid = shapes(t);
    expect(mid, hasLength(2));
    final dpr = t.view.devicePixelRatio;
    expect(mid[1].left, lessThan(80 * dpr)); // still travelling from 'a'
    await t.pumpAndSettle();
    expect(shapes(t)[1].left, closeTo(80 * dpr, 0.5));
  }, variant: ios);

  testWidgets('removed glass shrinks into its neighbour, then disappears',
      (t) async {
    env();
    await t.pumpWidget(scene(showB: true));
    await t.pump();
    await t.pumpWidget(scene(showB: false));
    expect(shapes(t), hasLength(2)); // ghost
    await t.pumpAndSettle();
    expect(shapes(t), hasLength(1));
  }, variant: ios);

  testWidgets('same id in a new place morphs from the old rect', (t) async {
    env();
    await t.pumpWidget(scene(showB: true));
    await t.pump();
    await t.pumpWidget(scene(showB: true, bOnRight: true));
    await t.pump(const Duration(milliseconds: 50));
    final dpr = t.view.devicePixelRatio;
    final b = shapes(t)[1];
    expect(b.left, greaterThan(80 * dpr));
    expect(b.left, lessThan(240 * dpr));
    await t.pumpAndSettle();
    expect(shapes(t), hasLength(2));
    expect(shapes(t)[1].left, closeTo(240 * dpr, 0.5));
  }, variant: ios);
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/group/morph_test.dart`
Expected: FAIL — e.g. "appearing glass" sees 2 shapes on the first frame.

- [ ] **Step 3: Extend entries and registry**

In `GlassEntry` add:

```dart
  /// Where the renderer last drew this entry, in group-local coordinates.
  Rect? lastDrawnLocal;

  /// Content opacity during morphs.
  final ValueNotifier<double> contentOpacity = ValueNotifier(1);

  /// A removed member still animating out.
  bool get isGhost => box == null && morphRect != null;
```

In `GlassRegistry` add the hooks and call them:

```dart
  /// Called after an entry is added.
  void Function(GlassEntry entry)? onAdded;

  /// Called after an entry is removed.
  void Function(GlassEntry entry)? onRemoved;
```

`register`: after `_entries.add(e);` call `onAdded?.call(e);` then `notifyListeners()`. `unregister`: `if (_entries.remove(e)) { onRemoved?.call(e); notifyListeners(); }`.

The member must clear its box when unmounting so a ghost is recognisable: in `GlassMemberState.dispose()` set `entry.box = null;` **before** `_registry?.unregister(entry)`.

- [ ] **Step 4: Update the renderer**

In `RenderGlassBackdrop._buildFrame`, change the skip condition to

```dart
      if (!(e.isLaidOut || e.isGhost) ||
          e.glass.variant == GlassVariant.identity) {
        continue;
      }
```

and after computing `final pressed = e.press.apply(base);` record
`e.lastDrawnLocal = MatrixUtils.transformRect(fromGlobal, pressed);` (add it
to `drawn` as before). The touch loop must skip ghosts (`e.box == null`).

- [ ] **Step 5: Implement** — `lib/src/group/morph_controller.dart`

```dart
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/glass_constants.dart';
import '../core/swiftui_spring.dart';
import 'glass_entry.dart';
import 'glass_registry.dart';

class _Track {
  _Track(this.entry, this.controller);
  GlassEntry entry;
  final AnimationController controller;
  Rect from = Rect.zero;
  Rect? fromOverride; // set when the old view with this id unmounts later
  Rect? to; // null → resolve from the live box each tick
  bool ghost = false;
}

/// Animates `glassId` appearances, removals and identity moves.
class GlassMorphController {
  /// Creates the controller and installs registry hooks.
  GlassMorphController({
    required this.vsync,
    required this.registry,
    required this.groupBox,
    required this.motion,
  }) {
    registry
      ..onAdded = _onAdded
      ..onRemoved = _onRemoved;
  }

  /// Ticker source.
  final TickerProvider vsync;

  /// The group's registry.
  final GlassRegistry registry;

  /// The group's render box (coordinate space for morph rects).
  final RenderBox? Function() groupBox;

  /// Current motion constants.
  final GlassMotionConstants Function() motion;

  final Map<Object, _Track> _tracks = {};
  bool _settled = false;

  /// Called after the group's first frame; later arrivals animate.
  void markSettled() => _settled = true;

  void _onAdded(GlassEntry e) {
    final id = e.glassId;
    if (id == null || !_settled) return;
    final ghost = _tracks[id];
    final from = ghost != null && ghost.ghost ? ghost.entry.morphRect : null;
    if (ghost != null) _finish(id, removeGhost: true);
    e.morphRect = from ?? Rect.zero; // hidden until laid out
    e.contentOpacity.value = 0;
    final track = _tracks[id] = _Track(e, _newController());
    // Start after layout, when the target rect exists.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!identical(_tracks[id], track)) return;
      track.from =
          track.fromOverride ?? from ?? _nearestDrawn(e) ?? _collapsedAt(e);
      _run(id, track);
    });
  }

  void _onRemoved(GlassEntry e) {
    final id = e.glassId;
    final last = e.lastDrawnLocal;
    if (id == null || !_settled || last == null || e.box != null) return;
    // Same id, new view: the new member mounts before the old one unmounts,
    // so its track already exists. Morph it from where the old one was.
    final live = _tracks[id];
    if (live != null && !live.ghost && !identical(live.entry, e)) {
      live.fromOverride = last;
      return;
    }
    live?.controller.dispose();
    final nearest = _nearestDrawn(e);
    final track = _tracks[id] = _Track(e, _newController())
      ..ghost = true
      ..from = last
      ..to = nearest == null
          ? Rect.fromCenter(center: last.center, width: 0, height: 0)
          : Rect.fromCenter(center: nearest.center, width: 0, height: 0);
    e.morphRect = last;
    // Re-add without hooks so the ghost keeps drawing.
    final hook = registry.onAdded;
    registry.onAdded = null;
    if (!registry.register(e)) {
      registry.onAdded = hook;
      _tracks.remove(id)?.controller.dispose();
      e.morphRect = null;
      return;
    }
    registry.onAdded = hook;
    _run(id, track);
  }

  AnimationController _newController() =>
      AnimationController.unbounded(vsync: vsync);

  Rect? _liveRect(GlassEntry e) {
    final group = groupBox();
    final box = e.box;
    if (group == null || box == null || !box.attached || !box.hasSize) {
      return null;
    }
    return MatrixUtils.transformRect(
        box.getTransformTo(group), e.shape.resolveRect(box.size));
  }

  Rect? _nearestDrawn(GlassEntry self) {
    final target = _liveRect(self) ?? self.lastDrawnLocal;
    Rect? best;
    var bestD = double.infinity;
    for (final o in registry.entries) {
      final r = o.lastDrawnLocal;
      if (identical(o, self) || r == null) continue;
      final d = target == null ? 0.0 : (r.center - target.center).distance;
      if (d < bestD) {
        bestD = d;
        best = r;
      }
    }
    return best;
  }

  Rect _collapsedAt(GlassEntry e) {
    final r = _liveRect(e) ?? Rect.zero;
    return Rect.fromCenter(center: r.center, width: 0, height: 0);
  }

  void _run(Object id, _Track track) {
    final m = motion();
    final c = track.controller;
    void tick() {
      final to = track.to ?? _liveRect(track.entry);
      if (to == null) return;
      final t = c.value;
      track.entry.morphRect = Rect.lerp(track.from, to, t);
      if (!track.ghost) {
        track.entry.contentOpacity.value = t.clamp(0.0, 1.0);
      }
      registry.markNeedsPaint();
    }

    c
      ..value = 0
      ..addListener(tick);
    c
        .animateWith(SpringSimulation(
          swiftUISpring(
              response: m.morphResponse, dampingFraction: m.morphDamping),
          0,
          1,
          0,
        ))
        .whenCompleteOrCancel(() {
      if (identical(_tracks[id], track)) {
        _finish(id, removeGhost: track.ghost);
      }
    });
  }

  void _finish(Object id, {required bool removeGhost}) {
    final track = _tracks.remove(id);
    if (track == null) return;
    track.controller.dispose();
    final e = track.entry;
    if (removeGhost && track.ghost) {
      final hook = registry.onRemoved;
      registry.onRemoved = null;
      registry.unregister(e);
      registry.onRemoved = hook;
    } else {
      e.morphRect = null;
      e.contentOpacity.value = 1;
      registry.markNeedsPaint();
    }
  }

  /// Stops all animations and removes hooks.
  void dispose() {
    for (final t in _tracks.values) {
      t.controller.dispose();
    }
    _tracks.clear();
    registry
      ..onAdded = null
      ..onRemoved = null;
  }
}
```

- [ ] **Step 6: Own the controller in the group** — `lib/src/group/glass_group.dart`

`_GlassGroupState` gains `with TickerProviderStateMixin`, a `GlobalKey _boxKey = GlobalKey();` and

```dart
  late final GlassMorphController _morph = GlassMorphController(
    vsync: this,
    registry: _registry,
    groupBox: () => _boxKey.currentContext?.findRenderObject() as RenderBox?,
    motion: () => LiquidGlassTheme.of(context).constants.motion,
  );
```

Touch `_morph` in `initState` (so hooks install before members register), call `_morph.markSettled()` inside the existing post-frame callback, and `_morph.dispose()` in `dispose()` before `_registry.dispose()`. In `build`, wrap `widget.child` as `KeyedSubtree(key: _boxKey, child: widget.child)` inside the scope so `groupBox` is the group's content box (same origin as `RenderGlassBackdrop` because `GlassBackdrop` is a proxy box).

Note: `motion` reads the theme lazily, outside `build`; use `context.findAncestorWidgetOfExactType<LiquidGlassTheme>()?.data.constants.motion ?? GlassConstants.standard.motion` there instead of `LiquidGlassTheme.of` to avoid a dependency registration outside build.

- [ ] **Step 7: Fade member content** — in `GlassMemberState.buildContent`, wrap the returned widget:

```dart
    return ValueListenableBuilder<double>(
      valueListenable: entry.contentOpacity,
      builder: (_, v, child) => v >= 1 ? child! : Opacity(opacity: v, child: child),
      child: /* the interactive / plain content built above */,
    );
```

- [ ] **Step 8: Run tests**

Run: `flutter test && flutter analyze`
Expected: PASS; no issues.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: glassId morphs with SwiftUI springs

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Native mode (iOS 26+, opt-in)

**Files:**
- Create: `lib/src/group/entry_geometry.dart`, `lib/src/native/native_glass_layer.dart`, `ios/Classes/GlassPlatformView.swift`, `test/native/native_glass_layer_test.dart`, `example/integration_test/native_test.dart`
- Modify: `lib/src/shader/render_glass_backdrop.dart` (use shared geometry), `lib/src/group/glass_group.dart` (`GlassMemberRendering.native`), `lib/src/liquid_glass.dart` (native members register), `ios/Classes/AdaptiveLiquidGlassPlugin.swift` (register factory)

**Interfaces:**
- Produces:
  - `class EntryGeometry { GlassEntry entry; Rect base; Rect drawn; double radius; }` and `List<EntryGeometry> collectEntryGeometry(GlassRegistry registry, Matrix4 groupToGlobal)` — global logical rects; used by both renderers.
  - `GlassMemberRendering.native`
  - `class NativeGlassLayer extends StatefulWidget { NativeGlassLayer({required GlassRegistry registry, required double spacing, required Widget child}) }`
  - Platform view type `adaptive_liquid_glass/native_glass`; per-view channel `adaptive_liquid_glass/native_glass_<id>` method `setShapes` with `{'spacing': double, 'shapes': [{'x','y','w','h','radius': double, 'capsule': bool, 'variant': int, 'tint': int?, 'interactive': bool}]}` in view-local points.
  - `const double kNativeOverhang = 24;` — the platform view extends this far past the group on every side so shadows and press growth are not cut off.

- [ ] **Step 1: Refactor geometry out of the renderer (no behaviour change)**

Create `lib/src/group/entry_geometry.dart`, moving `_baseGlobalRect`, `_baseRadius` and the per-entry loop from `RenderGlassBackdrop._buildFrame` into:

```dart
import 'package:flutter/rendering.dart';

import '../core/glass.dart';
import '../core/glass_shape.dart';
import 'glass_entry.dart';
import 'glass_registry.dart';

/// One entry's resolved geometry in global logical coordinates.
@immutable
class EntryGeometry {
  /// Creates geometry.
  const EntryGeometry(this.entry, this.base, this.drawn, this.radius);

  /// The entry.
  final GlassEntry entry;

  /// Rect before press deformation.
  final Rect base;

  /// Rect as drawn (press applied).
  final Rect drawn;

  /// Corner radius as drawn.
  final double radius;
}

/// Drawable entries of [registry]; [groupToGlobal] converts morph rects.
List<EntryGeometry> collectEntryGeometry(
    GlassRegistry registry, Matrix4 groupToGlobal) {
  final out = <EntryGeometry>[];
  for (final e in registry.entries) {
    if (!(e.isLaidOut || e.isGhost) ||
        e.glass.variant == GlassVariant.identity) {
      continue;
    }
    final morph = e.morphRect;
    final Rect base;
    if (morph != null) {
      base = MatrixUtils.transformRect(groupToGlobal, morph);
    } else {
      final box = e.box!;
      base = MatrixUtils.transformRect(
          box.getTransformTo(null), e.shape.resolveRect(box.size));
    }
    if (!base.isFinite || base.isEmpty) continue;

    double? concentric;
    final shape = e.shape;
    final c = e.container;
    if (shape is ConcentricGlassShape && c != null && c.isLaidOut) {
      final cBox = c.box!;
      concentric = concentricRadius(
        container: MatrixUtils.transformRect(
            cBox.getTransformTo(null), c.shape.resolveRect(cBox.size)),
        containerRadius: c.shape.resolveRadius(cBox.size),
        child: base,
        minimum: shape.minimum,
      );
    }
    final radius =
        shape.resolveRadius(base.size, concentricRadius: concentric) *
            e.press.radiusScale;
    out.add(EntryGeometry(e, base, e.press.apply(base), radius));
  }
  return out;
}
```

`_buildFrame` now calls `collectEntryGeometry(_registry, toGlobal)`, records `lastDrawnLocal` from `g.drawn`, and builds uniforms from `g.drawn` / `g.radius`.

Run: `flutter test` — Expected: everything still PASS.

- [ ] **Step 2: Write the failing Dart test** — `test/native/native_glass_layer_test.dart`

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/native/native_glass_layer.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('native mode sends view-local shapes', (t) async {
    GlassPlatform.instance.debugEnvironment = const GlassEnvironment(
        platform: TargetPlatform.iOS,
        iosMajorVersion: 26,
        reduceTransparency: false,
        shaderSupported: true);
    final messenger = t.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views,
        (call) async => call.method == 'create' ? 0 : null);
    final sent = <Map<Object?, Object?>>[];
    messenger.setMockMethodCallHandler(
        const MethodChannel('adaptive_liquid_glass/native_glass_0'),
        (call) async {
      if (call.method == 'setShapes') {
        sent.add(call.arguments as Map<Object?, Object?>);
      }
      return null;
    });

    await t.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: LiquidGlassTheme(
        data: const LiquidGlassThemeData(nativeEnabled: true),
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: GlassGroup(
            spacing: 12,
            child: LiquidGlass(
                glass: Glass.clear.tint(const Color(0xFF336699)),
                shape: const GlassShape.rect(16),
                child: const SizedBox(width: 100, height: 40)),
          ),
        ),
      ),
    ));
    await t.pump();

    expect(find.byType(NativeGlassLayer), findsOneWidget);
    expect(find.byType(UiKitView), findsOneWidget);
    final last = sent.last;
    expect(last['spacing'], 12.0);
    final shape = (last['shapes']! as List).single as Map<Object?, Object?>;
    expect(shape['x'], kNativeOverhang);
    expect(shape['y'], kNativeOverhang);
    expect(shape['w'], 100.0);
    expect(shape['h'], 40.0);
    expect(shape['radius'], 16.0);
    expect(shape['capsule'], false);
    expect(shape['variant'], 1);
    expect(shape['tint'], 0xFF336699);
    expect(shape['interactive'], false);
  }, variant: ios);
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `flutter test test/native`
Expected: FAIL — `NativeGlassLayer` missing.

- [ ] **Step 4: Implement** — `lib/src/native/native_glass_layer.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/glass.dart';
import '../core/glass_shape.dart';
import '../group/entry_geometry.dart';
import '../group/glass_registry.dart';

/// How far the native view extends past the group on each side.
const double kNativeOverhang = 24;

/// Hosts Apple's glass (`UIGlassContainerEffect` + `UIGlassEffect`) behind
/// the group's content and keeps its shapes in sync.
class NativeGlassLayer extends StatefulWidget {
  /// Creates the layer.
  const NativeGlassLayer({
    super.key,
    required this.registry,
    required this.spacing,
    required this.child,
  });

  /// Members.
  final GlassRegistry registry;

  /// Container spacing.
  final double spacing;

  /// Group content.
  final Widget child;

  @override
  State<NativeGlassLayer> createState() => _NativeGlassLayerState();
}

class _NativeGlassLayerState extends State<NativeGlassLayer> {
  MethodChannel? _channel;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    widget.registry.addListener(_schedule);
  }

  @override
  void didUpdateWidget(NativeGlassLayer old) {
    super.didUpdateWidget(old);
    if (old.registry != widget.registry) {
      old.registry.removeListener(_schedule);
      widget.registry.addListener(_schedule);
    }
    _schedule();
  }

  @override
  void dispose() {
    widget.registry.removeListener(_schedule);
    super.dispose();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _push();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _push() {
    final channel = _channel;
    final box = context.findRenderObject() as RenderBox?;
    if (channel == null || box == null || !box.attached) return;
    final toGlobal = box.getTransformTo(null);
    final fromGlobal = Matrix4.tryInvert(toGlobal);
    if (fromGlobal == null) return;
    final shapes = [
      for (final g in collectEntryGeometry(widget.registry, toGlobal))
        () {
          final r = MatrixUtils.transformRect(fromGlobal, g.drawn)
              .shift(const Offset(kNativeOverhang, kNativeOverhang));
          final shape = g.entry.shape;
          final glass = g.entry.glass;
          return <String, Object?>{
            'x': r.left,
            'y': r.top,
            'w': r.width,
            'h': r.height,
            'radius': g.radius,
            'capsule': shape is CapsuleGlassShape ||
                (shape is ConcentricGlassShape && g.entry.container == null),
            'variant': glass.variant == GlassVariant.clear ? 1 : 0,
            'tint': glass.tintColor?.toARGB32(),
            'interactive': glass.isInteractive,
          };
        }(),
    ];
    channel.invokeMethod<void>(
        'setShapes', {'spacing': widget.spacing, 'shapes': shapes});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -kNativeOverhang,
          top: -kNativeOverhang,
          right: -kNativeOverhang,
          bottom: -kNativeOverhang,
          child: UiKitView(
            viewType: 'adaptive_liquid_glass/native_glass',
            creationParams: {'spacing': widget.spacing, 'shapes': const []},
            creationParamsCodec: const StandardMessageCodec(),
            hitTestBehavior: PlatformViewHitTestBehavior.transparent,
            onPlatformViewCreated: (id) {
              _channel = MethodChannel('adaptive_liquid_glass/native_glass_$id');
              _push();
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}
```

The `Stack`'s positioned children use physical `left/right`; that is intentional (geometry, not reading order), so it stays correct in RTL.

In `glass_group.dart`: add `native` to `GlassMemberRendering`, map `EffectiveGlassMode.native => GlassMemberRendering.native`, and in `build` return `NativeGlassLayer(registry: _registry, spacing: widget.spacing, child: scoped)` for that case. In `GlassMemberState.didChangeDependencies`, register when `scope.rendering` is `backdrop` **or** `native`, and in `build` treat `native` like `backdrop` (the switch arm becomes `GlassMemberRendering.backdrop || GlassMemberRendering.native => ConcentricScope(...)`).

Mixed native/shader groups cannot occur: the mode is resolved once per group (spec §14.6 and §7).

- [ ] **Step 5: Implement the Swift view** — `ios/Classes/GlassPlatformView.swift`

```swift
import Flutter
import UIKit

final class GlassViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    GlassPlatformView(frame: frame, viewId: viewId,
                      args: args as? [String: Any] ?? [:], messenger: messenger)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class GlassPlatformView: NSObject, FlutterPlatformView {
  private let root: UIView
  private let channel: FlutterMethodChannel
  private var container: UIVisualEffectView?
  private var glassViews: [UIVisualEffectView] = []
  private var lastStyles: [String] = []

  init(frame: CGRect, viewId: Int64, args: [String: Any], messenger: FlutterBinaryMessenger) {
    root = UIView(frame: frame)
    root.backgroundColor = .clear
    root.isUserInteractionEnabled = false
    channel = FlutterMethodChannel(
      name: "adaptive_liquid_glass/native_glass_\(viewId)", binaryMessenger: messenger)
    super.init()
    if #available(iOS 26.0, *) {
      let c = UIVisualEffectView(effect: UIGlassContainerEffect())
      c.frame = root.bounds
      c.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      root.addSubview(c)
      container = c
    }
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setShapes", let a = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.apply(a)
      result(nil)
    }
    apply(args)
  }

  func view() -> UIView { root }

  private func apply(_ args: [String: Any]) {
    guard #available(iOS 26.0, *), let container else { return }
    let spacing = args["spacing"] as? Double ?? 0
    let effect = UIGlassContainerEffect()
    effect.spacing = spacing
    container.effect = effect

    let shapes = args["shapes"] as? [[String: Any]] ?? []
    while glassViews.count < shapes.count {
      let v = UIVisualEffectView(effect: nil)
      container.contentView.addSubview(v)
      glassViews.append(v)
      lastStyles.append("")
    }
    while glassViews.count > shapes.count {
      glassViews.removeLast().removeFromSuperview()
      lastStyles.removeLast()
    }
    for (i, s) in shapes.enumerated() {
      let v = glassViews[i]
      let variant = s["variant"] as? Int ?? 0
      let tint = s["tint"] as? Int
      let interactive = s["interactive"] as? Bool ?? false
      let style = "\(variant)|\(tint ?? -1)|\(interactive)"
      if style != lastStyles[i] {
        let g = UIGlassEffect(style: variant == 1 ? .clear : .regular)
        if let tint { g.tintColor = UIColor(argb: tint) }
        g.isInteractive = interactive
        v.effect = g
        lastStyles[i] = style
      }
      v.frame = CGRect(x: s["x"] as? Double ?? 0, y: s["y"] as? Double ?? 0,
                       width: s["w"] as? Double ?? 0, height: s["h"] as? Double ?? 0)
      if s["capsule"] as? Bool == true {
        v.cornerConfiguration = .capsule()
      } else {
        v.cornerConfiguration = .corners(radius: .fixed(s["radius"] as? Double ?? 0))
      }
    }
  }
}

private extension UIColor {
  convenience init(argb: Int) {
    self.init(red: CGFloat((argb >> 16) & 0xFF) / 255,
              green: CGFloat((argb >> 8) & 0xFF) / 255,
              blue: CGFloat(argb & 0xFF) / 255,
              alpha: CGFloat((argb >> 24) & 0xFF) / 255)
  }
}
```

If `.fixed(_:)` does not compile, the Swift name of `+[UICornerRadius fixedRadius:]` is different; find it with
`grep -rn "fixedRadius" $(xcrun --sdk iphonesimulator --show-sdk-path)/System/Library/Frameworks/UIKit.framework/Headers/UICornerRadius.h` and the generated interface in Xcode (Jump to Definition), then use that spelling.

Register the factory in `AdaptiveLiquidGlassPlugin.register`:

```swift
    registrar.register(GlassViewFactory(messenger: registrar.messenger()),
                       withId: "adaptive_liquid_glass/native_glass")
```

- [ ] **Step 6: Simulator integration test** — `example/integration_test/native_test.dart`

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native glass draws on iOS 26', (tester) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: LiquidGlassTheme(
        data: const LiquidGlassThemeData(nativeEnabled: true),
        child: Stack(children: [
          Positioned.fill(
            child: Row(children: [
              for (var i = 0; i < 30; i++)
                Expanded(
                    child: ColoredBox(
                        color: i.isEven
                            ? const Color(0xFF000000)
                            : const Color(0xFFFFFFFF))),
            ]),
          ),
          const Positioned(
            left: 100,
            top: 300,
            width: 200,
            height: 60,
            child: LiquidGlass(child: SizedBox.expand()),
          ),
        ]),
      ),
    ));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(UiKitView), findsOneWidget);

    final png = await binding.takeScreenshot('native');
    final image = (await (await ui.instantiateImageCodec(
                Uint8List.fromList(png)))
            .getNextFrame())
        .image;
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final dpr = tester.view.devicePixelRatio;
    final i = ((330 * dpr).round() * image.width + (200 * dpr).round()) * 4;
    final v = data.getUint8(i);
    expect(v, inInclusiveRange(30, 225),
        reason: 'stripes under native glass should be frosted, got $v');
  });
}
```

`takeScreenshot` on iOS captures Flutter content only. If the native view is missing from the screenshot (the value is pure 0 or 255), switch this check to `xcrun simctl io <udid> screenshot` from a host script (`tool/fidelity/capture.sh` in Task 15 covers that) and keep only the `UiKitView` assertion here.

Run: `cd example && flutter test integration_test/native_test.dart -d E7A87B4A-3E48-44F8-A588-704D56774FF0`
Expected: PASS.

- [ ] **Step 7: Run everything**

Run: `flutter test && flutter analyze && (cd example && flutter build ios --simulator --debug)`
Expected: PASS; no issues; build succeeds.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: native iOS 26 glass via UIGlassContainerEffect platform view

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: Adaptive foreground (`GlassBackdropSource` / `GlassForeground`)

**Files:**
- Create: `lib/src/foreground/glass_backdrop_source.dart`, `lib/src/foreground/glass_foreground.dart`, `test/foreground/foreground_test.dart`
- Modify: `lib/src/group/glass_group.dart` (sampling), `lib/adaptive_liquid_glass.dart` (exports)

**Interfaces:**
- Produces:
  - `class GlassBackdropSource extends StatefulWidget { GlassBackdropSource({required Widget child}) }` — wraps the content that glass floats over (it does not need to be an ancestor of the glass). Registers its `RepaintBoundary` in `GlassBackdropSources.instance`.
  - `class GlassBackdropSources { static final instance; List<RenderRepaintBoundary> get boundaries; ValueListenable<int> get revision; }`
  - `Future<double?> sampleLuminance(RenderRepaintBoundary boundary, Rect globalRegion)` — mean relative luminance (0..1) of the region at 0.25× scale.
  - `class GlassForeground extends InheritedWidget { Brightness backgroundBrightness; static Brightness backgroundBrightnessOf(BuildContext); static Color labelColorOf(BuildContext); }` — without a sample: `MediaQuery.platformBrightnessOf`. Label colour: black at 85 % on light backgrounds, white otherwise.
  - Threshold: luminance ≥ 0.5 → `Brightness.light`.
  - Group samples every 250 ms while at least one source exists and the group renders glass (`backdrop` or `native`).

- [ ] **Step 1: Write the failing test** — `test/foreground/foreground_test.dart`

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  Future<Brightness> run(WidgetTester t, Color background) async {
    GlassPlatform.instance.debugEnvironment = const GlassEnvironment(
        platform: TargetPlatform.iOS,
        iosMajorVersion: 26,
        reduceTransparency: false,
        shaderSupported: true);
    late BuildContext inner;
    await t.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(children: [
        Positioned.fill(
            child: GlassBackdropSource(child: ColoredBox(color: background))),
        Positioned(
          left: 50,
          top: 50,
          width: 100,
          height: 40,
          child: LiquidGlass(child: Builder(builder: (c) {
            inner = c;
            return const SizedBox.expand();
          })),
        ),
      ]),
    ));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await t.pump();
    final b = GlassForeground.backgroundBrightnessOf(inner);
    await t.pumpWidget(const SizedBox()); // cancels timers
    return b;
  }

  testWidgets('white content → light background, dark label', (t) async {
    expect(await run(t, const Color(0xFFFFFFFF)), Brightness.light);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('black content → dark background', (t) async {
    expect(await run(t, const Color(0xFF000000)), Brightness.dark);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('no source → platform brightness', (t) async {
    late BuildContext inner;
    await t.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Builder(builder: (c) {
        inner = c;
        return const SizedBox();
      }),
    ));
    expect(GlassForeground.backgroundBrightnessOf(inner),
        MediaQuery.platformBrightnessOf(inner));
    expect(GlassForeground.labelColorOf(inner), isA<Color>());
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/foreground`
Expected: FAIL — symbols missing.

- [ ] **Step 3: Implement** — `lib/src/foreground/glass_foreground.dart`

```dart
import 'package:flutter/widgets.dart';

/// Brightness of the content behind the nearest glass group.
class GlassForeground extends InheritedWidget {
  /// Creates the scope.
  const GlassForeground(
      {super.key, required this.backgroundBrightness, required super.child});

  /// Sampled brightness of what is behind the glass.
  final Brightness backgroundBrightness;

  /// Sampled brightness, else the platform brightness.
  static Brightness backgroundBrightnessOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<GlassForeground>()
          ?.backgroundBrightness ??
      MediaQuery.platformBrightnessOf(context);

  /// A label colour readable on the glass.
  static Color labelColorOf(BuildContext context) =>
      backgroundBrightnessOf(context) == Brightness.light
          ? const Color(0xD9000000)
          : const Color(0xFFFFFFFF);

  @override
  bool updateShouldNotify(GlassForeground old) =>
      old.backgroundBrightness != backgroundBrightness;
}
```

`lib/src/foreground/glass_backdrop_source.dart`:

```dart
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Registry of content regions that glass may sample.
class GlassBackdropSources {
  GlassBackdropSources._();

  /// Shared instance.
  static final GlassBackdropSources instance = GlassBackdropSources._();

  final List<GlobalKey> _keys = [];
  final ValueNotifier<int> _revision = ValueNotifier(0);

  /// Bumps when sources are added or removed.
  ValueListenable<int> get revision => _revision;

  /// Attached boundaries.
  List<RenderRepaintBoundary> get boundaries => [
        for (final k in _keys)
          if (k.currentContext?.findRenderObject()
              case final RenderRepaintBoundary b when b.attached)
            b,
      ];

  void _add(GlobalKey k) {
    _keys.add(k);
    _revision.value++;
  }

  void _remove(GlobalKey k) {
    _keys.remove(k);
    _revision.value++;
  }
}

/// Marks content that glass floats over, enabling `GlassForeground`.
///
/// Costs a low-resolution GPU readback every 250 ms per glass group.
class GlassBackdropSource extends StatefulWidget {
  /// Creates a source.
  const GlassBackdropSource({super.key, required this.child});

  /// The content behind the glass.
  final Widget child;

  @override
  State<GlassBackdropSource> createState() => _GlassBackdropSourceState();
}

class _GlassBackdropSourceState extends State<GlassBackdropSource> {
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    GlassBackdropSources.instance._add(_key);
  }

  @override
  void dispose() {
    GlassBackdropSources.instance._remove(_key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(key: _key, child: widget.child);
}

/// Mean relative luminance of [globalRegion] within [boundary].
Future<double?> sampleLuminance(
    RenderRepaintBoundary boundary, Rect globalRegion) async {
  if (!boundary.attached || boundary.debugNeedsPaint) return null;
  const scale = 0.25;
  final toLocal = Matrix4.tryInvert(boundary.getTransformTo(null));
  if (toLocal == null) return null;
  final local = MatrixUtils.transformRect(toLocal, globalRegion)
      .intersect(Offset.zero & boundary.size);
  if (local.isEmpty) return null;
  final ui.Image image = await boundary.toImage(pixelRatio: scale);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    final x0 = (local.left * scale).floor().clamp(0, image.width - 1);
    final y0 = (local.top * scale).floor().clamp(0, image.height - 1);
    final x1 = (local.right * scale).ceil().clamp(x0 + 1, image.width);
    final y1 = (local.bottom * scale).ceil().clamp(y0 + 1, image.height);
    var sum = 0.0;
    var n = 0;
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final i = (y * image.width + x) * 4;
        sum += (0.2126 * data.getUint8(i) +
                0.7152 * data.getUint8(i + 1) +
                0.0722 * data.getUint8(i + 2)) /
            255;
        n++;
      }
    }
    return n == 0 ? null : sum / n;
  } finally {
    image.dispose();
  }
}
```

- [ ] **Step 4: Sample in the group** — `lib/src/group/glass_group.dart`

Add to `_GlassGroupState`:

```dart
  Timer? _sampler;
  Brightness? _sampled;
  bool _sampling = false;

  void _updateSampler(GlassMemberRendering rendering) {
    final want = (rendering == GlassMemberRendering.backdrop ||
            rendering == GlassMemberRendering.native) &&
        GlassBackdropSources.instance.boundaries.isNotEmpty;
    if (want && _sampler == null) {
      _sampler = Timer.periodic(
          const Duration(milliseconds: 250), (_) => _sample());
    } else if (!want) {
      _sampler?.cancel();
      _sampler = null;
    }
  }

  Future<void> _sample() async {
    if (_sampling || !mounted) return;
    final box = _boxKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    _sampling = true;
    try {
      final region =
          MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
      for (final b in GlassBackdropSources.instance.boundaries) {
        final l = await sampleLuminance(b, region);
        if (l == null) continue;
        final next = l >= 0.5 ? Brightness.light : Brightness.dark;
        if (mounted && next != _sampled) setState(() => _sampled = next);
        break;
      }
    } finally {
      _sampling = false;
    }
  }
```

Listen to `GlassBackdropSources.instance.revision` in `initState` (→ `setState`), remove the listener and cancel `_sampler` in `dispose`. In `build`, after computing `rendering`, call `_updateSampler(rendering)` and wrap the scoped child: `if (_sampled != null) scoped = GlassForeground(backgroundBrightness: _sampled!, child: scoped);` (make `scoped` non-final). Import `dart:async`.

Exports: add `export 'src/foreground/glass_backdrop_source.dart' show GlassBackdropSource;` and `export 'src/foreground/glass_foreground.dart';`.

- [ ] **Step 5: Run tests**

Run: `flutter test && flutter analyze`
Expected: PASS; no issues.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: adaptive foreground brightness sampling

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 15: Scenes, SwiftUI reference host and static fidelity harness

**Files:**
- Create: `tool/scenes/gen_scenes.py`, `tool/scenes/gen_backgrounds.py`, `tool/scenes/scenes.json` (generated, committed), `example/assets/backgrounds/{photo,text,gradient}.png` (generated, committed)
- Create: `example/lib/scenes/scene.dart`, `example/lib/scenes/scene_view.dart`, `example/lib/launch.dart`; replace `example/lib/main.dart`
- Create: `example/ios/Runner/ReferenceScenes.swift`; modify `example/ios/Runner/AppDelegate.swift`, `example/ios/Runner/Info.plist`, `example/pubspec.yaml`
- Create: `tool/fidelity/requirements.txt`, `tool/fidelity/compare.py`, `tool/fidelity/test_compare.py`, `tool/fidelity/capture.sh`, `tool/fidelity/README.md`
- Modify: `.gitignore` (`build/fidelity/`, `tool/fidelity/.venv/`)

**Interfaces:**
- Scene JSON (`tool/scenes/scenes.json`):

```json
{
  "device": {"width": 402, "height": 874, "scale": 3},
  "scenes": [
    {
      "id": "regular-capsule-photo-light",
      "background": "photo",
      "brightness": "light",
      "spacing": null,
      "shapes": [
        {"x": 101, "y": 560, "w": 200, "h": 56, "shape": "capsule",
         "radius": 0, "variant": "regular", "tint": null}
      ]
    }
  ],
  "motion": []
}
```

  `shape` ∈ `capsule | circle | rect`; `variant` ∈ `regular | clear`; `tint` is `"#RRGGBBAA"` or null; `spacing` non-null → shapes go in one `GlassGroup` / `GlassEffectContainer(spacing:)`. Coordinates are points from the screen's top-left (the status bar is hidden in both renderers).
- Launch arguments (both renderers, read in `AppDelegate`): `-scene <id>`, `-renderer flutter|swiftui`, `-constants <json>` (optional, Flutter only), `-motion <id>` (Task 16).
- Example method channel `example/launch` → `getArgs` returns `{'scene': String?, 'renderer': String?, 'constants': String?, 'motion': String?}`.
- `python3 tool/fidelity/compare.py <run-dir> [--no-fail]` → writes `<run-dir>/report.json` and `<run-dir>/report.html`; exit 1 if any scene misses the bars.
- `tool/fidelity/capture.sh <run-dir> [scene-id-prefix]` with env `CONSTANTS` (JSON) and `RENDERERS` (default `"flutter swiftui"`).

- [ ] **Step 1: Generate backgrounds** — `tool/scenes/gen_backgrounds.py`

```python
"""Deterministic backgrounds shared by the Flutter and SwiftUI renderers."""
import math
import pathlib
import random

from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1206, 2622  # iPhone 17 Pro @3x
OUT = pathlib.Path(__file__).resolve().parents[2] / "example/assets/backgrounds"


def photo() -> Image.Image:
    rnd = random.Random(7)
    img = Image.new("RGB", (W, H))
    px = img.load()
    for y in range(H):
        for x in range(W):
            u, v = x / W, y / H
            px[x, y] = (
                int(127 + 120 * math.sin(6.0 * u + 2.0 * v)),
                int(127 + 120 * math.sin(4.0 * v + 1.3)),
                int(127 + 120 * math.cos(5.0 * u * v + 0.5)),
            )
    d = ImageDraw.Draw(img)
    for _ in range(180):
        x, y, r = rnd.randrange(W), rnd.randrange(H), rnd.randrange(6, 90)
        c = tuple(rnd.randrange(256) for _ in range(3))
        d.ellipse((x - r, y - r, x + r, y + r), fill=c)
    for i in range(0, W, 48):  # thin bars make lensing measurable
        d.rectangle((i, 0, i + 6, H), fill=(250, 250, 250))
    return img.filter(ImageFilter.GaussianBlur(0.6))


def text() -> Image.Image:
    img = Image.new("RGB", (W, H), (255, 255, 255))
    d = ImageDraw.Draw(img)
    font = ImageFont.load_default(size=42)
    words = "liquid glass refracts light and colour from the content behind it ".split()
    rnd = random.Random(3)
    y = 20
    while y < H:
        line = " ".join(rnd.choice(words) for _ in range(9))
        d.text((24, y), line, fill=(20, 20, 20), font=font)
        y += 56
    return img


def gradient() -> Image.Image:
    img = Image.new("RGB", (W, H))
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        c = (int(30 + 200 * t), int(80 + 100 * (1 - t)), int(200 - 150 * t))
        for x in range(W):
            px[x, y] = c
    return img


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in [("photo", photo), ("text", text), ("gradient", gradient)]:
        fn().save(OUT / f"{name}.png", optimize=True)
        print("wrote", OUT / f"{name}.png")
```

- [ ] **Step 2: Generate the scene list** — `tool/scenes/gen_scenes.py`

```python
"""Writes tool/scenes/scenes.json: the static fidelity matrix (spec §10)."""
import json
import pathlib

OUT = pathlib.Path(__file__).with_name("scenes.json")
W, H = 402, 874

SHAPES = {
    "capsule": {"w": 200, "h": 56, "shape": "capsule", "radius": 0},
    "circle": {"w": 72, "h": 72, "shape": "circle", "radius": 0},
    "rect16": {"w": 240, "h": 140, "shape": "rect", "radius": 16},
    "rect28": {"w": 240, "h": 140, "shape": "rect", "radius": 28},
}
VARIANTS = {
    "regular": ("regular", None),
    "clear": ("clear", None),
    "tinted": ("regular", "#0A84FF99"),
}


def centred(spec, y):
    return {**spec, "x": (W - spec["w"]) / 2, "y": y}


scenes = []
for bg in ["photo", "text", "gradient"]:
    for vname, (variant, tint) in VARIANTS.items():
        for sname, spec in SHAPES.items():
            for brightness in ["light", "dark"]:
                scenes.append({
                    "id": f"{vname}-{sname}-{bg}-{brightness}",
                    "background": bg,
                    "brightness": brightness,
                    "spacing": None,
                    "shapes": [{**centred(spec, 560), "variant": variant, "tint": tint}],
                })

for gap in [4, 16, 30]:
    a = {"x": W / 2 - 60 - gap / 2, "y": 600, "w": 60, "h": 60, "shape": "circle",
         "radius": 0, "variant": "regular", "tint": None}
    b = {**a, "x": W / 2 + gap / 2}
    scenes.append({
        "id": f"merge-gap{gap}-photo-light",
        "background": "photo",
        "brightness": "light",
        "spacing": 20,
        "shapes": [a, b],
    })

OUT.write_text(json.dumps(
    {"device": {"width": W, "height": H, "scale": 3}, "scenes": scenes, "motion": []},
    indent=2) + "\n")
print(len(scenes), "scenes")
```

Run:

```bash
python3 -m venv tool/fidelity/.venv
tool/fidelity/.venv/bin/pip install -r tool/fidelity/requirements.txt
tool/fidelity/.venv/bin/python tool/scenes/gen_backgrounds.py
tool/fidelity/.venv/bin/python tool/scenes/gen_scenes.py
```

with `tool/fidelity/requirements.txt`:

```
numpy>=2.1
pillow>=11
scikit-image>=0.25
scipy>=1.14
pytest>=8
```

Expected: three PNGs written; `75 scenes`.

- [ ] **Step 3: Flutter scene renderer**

`example/pubspec.yaml`: add `adaptive_liquid_glass: {path: ../}` (already from the template), assets `assets/backgrounds/` and `../tool/scenes/scenes.json` — Flutter cannot reference files outside the package, so copy instead: add a `tool/scenes/sync_example.sh` that copies `scenes.json` into `example/assets/scenes.json`, and list `assets/scenes.json`. Run it after `gen_scenes.py`.

`example/lib/scenes/scene.dart`:

```dart
import 'dart:convert';

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/services.dart';

class SceneShape {
  SceneShape.fromJson(Map<String, Object?> j)
      : rect = Rect.fromLTWH((j['x']! as num).toDouble(), (j['y']! as num).toDouble(),
            (j['w']! as num).toDouble(), (j['h']! as num).toDouble()),
        shape = switch (j['shape']) {
          'circle' => const GlassShape.circle(),
          'rect' => GlassShape.rect((j['radius']! as num).toDouble()),
          _ => const GlassShape.capsule(),
        },
        glass = _glass(j['variant'] as String?, j['tint'] as String?);

  final Rect rect;
  final GlassShape shape;
  final Glass glass;

  static Glass _glass(String? variant, String? tint) {
    final base = variant == 'clear' ? Glass.clear : Glass.regular;
    if (tint == null) return base;
    final v = int.parse(tint.substring(1), radix: 16); // RRGGBBAA
    return base.tint(Color(((v & 0xFF) << 24) | (v >> 8)));
  }
}

class Scene {
  Scene.fromJson(Map<String, Object?> j)
      : id = j['id']! as String,
        background = j['background']! as String,
        brightness =
            j['brightness'] == 'dark' ? Brightness.dark : Brightness.light,
        spacing = (j['spacing'] as num?)?.toDouble(),
        shapes = [
          for (final s in j['shapes']! as List<Object?>)
            SceneShape.fromJson((s! as Map).cast<String, Object?>())
        ];

  final String id;
  final String background;
  final Brightness brightness;
  final double? spacing;
  final List<SceneShape> shapes;

  static Future<Map<String, Scene>> loadAll() async {
    final j = jsonDecode(await rootBundle.loadString('assets/scenes.json'))
        as Map<String, Object?>;
    return {
      for (final s in j['scenes']! as List<Object?>)
        (s! as Map)['id'] as String:
            Scene.fromJson(s.cast<String, Object?>()),
    };
  }
}
```

`example/lib/scenes/scene_view.dart`:

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/widgets.dart';

import 'scene.dart';

class SceneView extends StatelessWidget {
  const SceneView({super.key, required this.scene});
  final Scene scene;

  @override
  Widget build(BuildContext context) {
    final shapes = Stack(children: [
      for (final s in scene.shapes)
        Positioned.fromRect(
          rect: s.rect,
          child: LiquidGlass(
              glass: s.glass, shape: s.shape, child: const SizedBox.expand()),
        ),
    ]);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(platformBrightness: scene.brightness),
      child: Stack(children: [
        Positioned.fill(
          child: Image.asset('assets/backgrounds/${scene.background}.png',
              fit: BoxFit.fill, filterQuality: FilterQuality.none),
        ),
        Positioned.fill(
          child: scene.spacing == null
              ? shapes
              : GlassGroup(spacing: scene.spacing!, child: shapes),
        ),
      ]),
    );
  }
}
```

(Note: with `spacing == null`, each `LiquidGlass` gets its own implicit group, matching SwiftUI's separate `.glassEffect` views.)

`example/lib/launch.dart`:

```dart
import 'package:flutter/services.dart';

class LaunchArgs {
  LaunchArgs(this.scene, this.renderer, this.constants, this.motion);
  final String? scene;
  final String? renderer;
  final String? constants;
  final String? motion;

  static Future<LaunchArgs> read() async {
    try {
      final m = await const MethodChannel('example/launch')
          .invokeMapMethod<String, Object?>('getArgs');
      return LaunchArgs(m?['scene'] as String?, m?['renderer'] as String?,
          m?['constants'] as String?, m?['motion'] as String?);
    } on MissingPluginException {
      return LaunchArgs(null, null, null, null);
    }
  }
}
```

`example/lib/main.dart`:

```dart
import 'dart:convert';

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/testing.dart';
import 'package:flutter/material.dart';

import 'demo.dart';
import 'launch.dart';
import 'scenes/scene.dart';
import 'scenes/scene_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlass.precache();
  final args = await LaunchArgs.read();
  final constants = args.constants == null
      ? GlassConstants.standard
      : GlassConstants.fromJson(
          (jsonDecode(args.constants!) as Map).cast<String, Object?>());
  final scenes = await Scene.loadAll();
  final scene = args.scene == null ? null : scenes[args.scene];
  runApp(LiquidGlassTheme(
    data: LiquidGlassThemeData(constants: constants),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: scene == null ? const Demo() : SceneView(scene: scene),
    ),
  ));
}
```

Move the Task 10 demo into `example/lib/demo.dart` as `class Demo extends StatelessWidget`.

- [ ] **Step 4: SwiftUI reference host** — `example/ios/Runner/ReferenceScenes.swift`

```swift
import Flutter
import SwiftUI
import UIKit

struct RefShape: Decodable {
  let x, y, w, h, radius: Double
  let shape, variant: String
  let tint: String?
}

struct RefScene: Decodable {
  let id, background, brightness: String
  let spacing: Double?
  let shapes: [RefShape]
}

struct RefFile: Decodable { let scenes: [RefScene] }

enum ReferenceAssets {
  static func path(_ asset: String) -> String? {
    let key = FlutterDartProject.lookupKey(forAsset: asset)
    return Bundle.main.path(forResource: key, ofType: nil)
  }

  static func scene(id: String) -> RefScene? {
    guard let p = path("assets/scenes.json"),
          let data = FileManager.default.contents(atPath: p),
          let file = try? JSONDecoder().decode(RefFile.self, from: data) else { return nil }
    return file.scenes.first { $0.id == id }
  }

  static func image(_ name: String) -> UIImage? {
    path("assets/backgrounds/\(name).png").flatMap(UIImage.init(contentsOfFile:))
  }
}

@available(iOS 26.0, *)
struct ReferenceSceneView: View {
  let scene: RefScene
  let background: UIImage

  var body: some View {
    ZStack(alignment: .topLeading) {
      Image(uiImage: background).resizable().interpolation(.none)
        .frame(width: 402, height: 874)
      if let spacing = scene.spacing {
        GlassEffectContainer(spacing: spacing) { shapes }
      } else {
        shapes
      }
    }
    .frame(width: 402, height: 874, alignment: .topLeading)
    .ignoresSafeArea()
    .environment(\.colorScheme, scene.brightness == "dark" ? .dark : .light)
    .statusBarHidden(true)
  }

  private var shapes: some View {
    ZStack(alignment: .topLeading) {
      ForEach(scene.shapes.indices, id: \.self) { i in
        let s = scene.shapes[i]
        Color.clear
          .frame(width: s.w, height: s.h)
          .glassEffect(glass(s), in: shape(s))
          .position(x: s.x + s.w / 2, y: s.y + s.h / 2)
      }
    }
    .frame(width: 402, height: 874, alignment: .topLeading)
  }

  private func glass(_ s: RefShape) -> Glass {
    var g: Glass = s.variant == "clear" ? .clear : .regular
    if let t = s.tint { g = g.tint(Color(rgbaHex: t)) }
    return g
  }

  private func shape(_ s: RefShape) -> AnyShape {
    switch s.shape {
    case "capsule": AnyShape(Capsule())
    case "circle": AnyShape(Circle())
    default: AnyShape(RoundedRectangle(cornerRadius: s.radius, style: .continuous))
    }
  }
}

extension Color {
  init(rgbaHex: String) {
    let v = UInt32(rgbaHex.dropFirst(), radix: 16) ?? 0
    self.init(.sRGB,
              red: Double((v >> 24) & 0xFF) / 255, green: Double((v >> 16) & 0xFF) / 255,
              blue: Double((v >> 8) & 0xFF) / 255, opacity: Double(v & 0xFF) / 255)
  }
}
```

`example/ios/Runner/AppDelegate.swift`:

```swift
import Flutter
import SwiftUI
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private func arg(_ name: String) -> String? {
    let a = ProcessInfo.processInfo.arguments
    guard let i = a.firstIndex(of: "-\(name)"), i + 1 < a.count else { return nil }
    return a[i + 1]
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let controller = window?.rootViewController as! FlutterViewController
    FlutterMethodChannel(name: "example/launch", binaryMessenger: controller.binaryMessenger)
      .setMethodCallHandler { [weak self] call, result in
        guard call.method == "getArgs", let self else { result(FlutterMethodNotImplemented); return }
        result(["scene": self.arg("scene"), "renderer": self.arg("renderer"),
                "constants": self.arg("constants"), "motion": self.arg("motion")])
      }
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if arg("renderer") == "swiftui", #available(iOS 26.0, *),
       let id = arg("scene"), let scene = ReferenceAssets.scene(id: id),
       let bg = ReferenceAssets.image(scene.background) {
      window?.rootViewController = UIHostingController(
        rootView: ReferenceSceneView(scene: scene, background: bg))
    }
    return ok
  }
}
```

If the generated `AppDelegate` uses the newer implicit-engine template (`FlutterImplicitEngineDelegate` / `didInitializeImplicitFlutterEngine`), keep its structure and put the channel registration where that template exposes the engine's messenger; the SwiftUI swap stays in `didFinishLaunching`.

`example/ios/Runner/Info.plist`: add `UIStatusBarHidden` = `true` and `UIViewControllerBasedStatusBarAppearance` = `false`. Set the Runner deployment target to 15.0 (Xcode project `IPHONEOS_DEPLOYMENT_TARGET` and `example/ios/Podfile` `platform :ios, '15.0'`).

Run: `cd example && flutter build ios --simulator --debug`
Expected: build succeeds.

- [ ] **Step 5: Scorer tests first** — `tool/fidelity/test_compare.py`

```python
import numpy as np
import pytest

from compare import region_for, score


def test_identical_images_pass():
    rng = np.random.default_rng(0)
    a = rng.random((300, 300, 3))
    s = score(a, a.copy())
    assert s["ssim"] == pytest.approx(1.0)
    assert s["delta_e"] == pytest.approx(0.0, abs=1e-9)
    assert s["pass"]


def test_shifted_image_fails():
    rng = np.random.default_rng(1)
    a = rng.random((300, 300, 3))
    b = np.roll(a, 3, axis=1)
    assert not score(a, b)["pass"]


def test_region_inflates_by_12pt_and_clamps():
    scene = {"shapes": [{"x": 0, "y": 10, "w": 100, "h": 50}]}
    x0, y0, x1, y1 = region_for(scene, scale=3, width_px=1206, height_px=2622)
    assert (x0, y0) == (0, 0)  # clamped
    assert (x1, y1) == ((100 + 12) * 3, (60 + 12) * 3)
```

Run: `cd tool/fidelity && .venv/bin/pytest -q` — Expected: FAIL (no `compare` module).

- [ ] **Step 6: Implement the scorer** — `tool/fidelity/compare.py`

```python
"""Scores Flutter vs SwiftUI screenshots inside each scene's glass region."""
import argparse
import html
import json
import pathlib
import sys

import numpy as np
from PIL import Image
from skimage.color import deltaE_ciede2000, rgb2lab
from skimage.metrics import structural_similarity

ROOT = pathlib.Path(__file__).resolve().parents[2]
SSIM_MIN = 0.97
DELTA_E_MAX = 2.0
INFLATE_PT = 12


def region_for(scene, scale, width_px, height_px):
    xs0 = min(s["x"] for s in scene["shapes"]) - INFLATE_PT
    ys0 = min(s["y"] for s in scene["shapes"]) - INFLATE_PT
    xs1 = max(s["x"] + s["w"] for s in scene["shapes"]) + INFLATE_PT
    ys1 = max(s["y"] + s["h"] for s in scene["shapes"]) + INFLATE_PT
    clamp = lambda v, hi: int(max(0, min(hi, round(v * scale))))
    return clamp(xs0, width_px), clamp(ys0, height_px), clamp(xs1, width_px), clamp(ys1, height_px)


def score(a, b):
    ssim = structural_similarity(a, b, channel_axis=2, data_range=1.0)
    de = float(deltaE_ciede2000(rgb2lab(a), rgb2lab(b)).mean())
    return {"ssim": float(ssim), "delta_e": de,
            "pass": bool(ssim >= SSIM_MIN and de <= DELTA_E_MAX)}


def load(path):
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float64) / 255.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("run_dir", type=pathlib.Path)
    ap.add_argument("--no-fail", action="store_true")
    args = ap.parse_args()

    spec = json.loads((ROOT / "tool/scenes/scenes.json").read_text())
    scale = spec["device"]["scale"]
    rows = []
    for scene in spec["scenes"]:
        f = args.run_dir / f"{scene['id']}.flutter.png"
        s = args.run_dir / f"{scene['id']}.swiftui.png"
        if not (f.exists() and s.exists()):
            continue
        a, b = load(f), load(s)
        x0, y0, x1, y1 = region_for(scene, scale, a.shape[1], a.shape[0])
        r = score(a[y0:y1, x0:x1], b[y0:y1, x0:x1])
        diff = (np.abs(a[y0:y1, x0:x1] - b[y0:y1, x0:x1]).mean(axis=2) * 4).clip(0, 1)
        Image.fromarray((diff * 255).astype(np.uint8)).save(args.run_dir / f"{scene['id']}.diff.png")
        rows.append({"id": scene["id"], **r, "region": [x0, y0, x1, y1]})

    (args.run_dir / "report.json").write_text(json.dumps(rows, indent=2))
    cells = "".join(
        f"<tr class={'ok' if r['pass'] else 'bad'}><td>{html.escape(r['id'])}</td>"
        f"<td>{r['ssim']:.4f}</td><td>{r['delta_e']:.2f}</td>"
        f"<td><img src='{r['id']}.flutter.png'></td><td><img src='{r['id']}.swiftui.png'></td>"
        f"<td><img src='{r['id']}.diff.png'></td></tr>" for r in rows)
    (args.run_dir / "report.html").write_text(
        "<meta charset=utf-8><style>img{width:200px}.bad{background:#fdd}"
        "td{padding:4px;font:13px system-ui}</style>"
        f"<p>{sum(r['pass'] for r in rows)}/{len(rows)} pass "
        f"(SSIM ≥ {SSIM_MIN}, ΔE ≤ {DELTA_E_MAX})</p>"
        f"<table><tr><th>scene<th>SSIM<th>ΔE<th>Flutter<th>SwiftUI<th>diff</tr>{cells}</table>")
    failed = [r["id"] for r in rows if not r["pass"]]
    print(f"{len(rows) - len(failed)}/{len(rows)} pass")
    for i in failed:
        print("FAIL", i)
    if failed and not args.no_fail:
        sys.exit(1)


if __name__ == "__main__":
    main()
```

Run: `cd tool/fidelity && .venv/bin/pytest -q` — Expected: 3 passed.

- [ ] **Step 7: Capture script** — `tool/fidelity/capture.sh`

```bash
#!/usr/bin/env bash
# Usage: tool/fidelity/capture.sh <run-dir> [scene-id-prefix]
# Env: CONSTANTS='{"regular":{...}}'  RENDERERS="flutter swiftui"  SKIP_BUILD=1
set -euo pipefail
cd "$(dirname "$0")/../.."
UDID="${UDID:-E7A87B4A-3E48-44F8-A588-704D56774FF0}"
BUNDLE="${BUNDLE:-com.aymanomara.adaptiveLiquidGlassExample}"
OUT="${1:?run dir}"
PREFIX="${2:-}"
RENDERERS="${RENDERERS:-flutter swiftui}"
mkdir -p "$OUT"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
if [[ -z "${SKIP_BUILD:-}" ]]; then
  (cd example && flutter build ios --simulator --debug >/dev/null)
  xcrun simctl install "$UDID" example/build/ios/iphonesimulator/Runner.app
fi

ids=$(python3 -c "import json;print('\n'.join(s['id'] for s in json.load(open('tool/scenes/scenes.json'))['scenes'] if s['id'].startswith('$PREFIX')))")
for id in $ids; do
  for r in $RENDERERS; do
    xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
    extra=()
    [[ "$r" == flutter && -n "${CONSTANTS:-}" ]] && extra=(-constants "$CONSTANTS")
    xcrun simctl launch "$UDID" "$BUNDLE" -scene "$id" -renderer "$r" "${extra[@]}" >/dev/null
    sleep "${SETTLE:-2.5}"
    xcrun simctl io "$UDID" screenshot "$OUT/$id.$r.png" >/dev/null 2>&1
  done
done
echo "captured into $OUT"
```

Confirm the bundle id with `grep PRODUCT_BUNDLE_IDENTIFIER example/ios/Runner.xcodeproj/project.pbxproj | head -1` and fix the default if it differs.

- [ ] **Step 8: First real run (baseline — failures expected)**

```bash
chmod +x tool/fidelity/capture.sh
tool/fidelity/capture.sh build/fidelity/baseline
tool/fidelity/.venv/bin/python tool/fidelity/compare.py build/fidelity/baseline --no-fail
```

Expected: 75 rows in `build/fidelity/baseline/report.html`; most scenes fail before fitting. Open the report and check the **SwiftUI** screenshots show real Liquid Glass (if they show only the background, the `-renderer swiftui` swap did not happen — fix before going on). Write `tool/fidelity/README.md` with the commands above and how to read the report.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "test: fidelity scenes, SwiftUI reference host and scorer

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 16: Motion recordings (press and morph)

**Files:**
- Modify: `tool/scenes/gen_scenes.py` (motion list), `example/lib/scenes/scene.dart` + new `example/lib/scenes/motion_view.dart`, `example/ios/Runner/ReferenceScenes.swift` (motion views)
- Create: `tool/fidelity/record_motion.sh`, `tool/fidelity/compare_motion.py`, `tool/fidelity/test_compare_motion.py`

**Interfaces:**
- Motion entries in `scenes.json`:
  - `{"id": "press-capsule-photo-light", "kind": "press", "background": "photo", "brightness": "light", "shape": {... one shape ..., "variant": "regular"}, "touch": {"x": 280, "y": 588}, "hold_ms": 700}`
  - `{"id": "morph-expand-photo-light", "kind": "morph", "background": "photo", "brightness": "light", "spacing": 20, "before": [shape], "after": [shape, shape], "touch": {"x": 30, "y": 30}}` — tapping the touch point toggles before ↔ after inside `withAnimation(.bouncy)` (SwiftUI) / `setState` (Flutter); shapes carry `glassId` `"g0"`, `"g1"`.
- `record_motion.sh <run-dir> [motion-id]` → `<run-dir>/<id>.<renderer>.mov` and `frames/<id>.<renderer>/%04d.png` at 60 fps.
- `compare_motion.py <run-dir>` → `motion_report.json` per motion: aligned frame count, per-frame SSIM/ΔE, worst frame, pass/fail with the static bars, plus a fitted spring `(response, dampingFraction)` for each renderer from the shape's bounding-box width over time.

- [ ] **Step 1: Install touch injection** (ask the user before installing; both come from Meta's `idb` project)

```bash
brew tap facebook/fb && brew install idb-companion
tool/fidelity/.venv/bin/pip install fb-idb
tool/fidelity/.venv/bin/idb connect E7A87B4A-3E48-44F8-A588-704D56774FF0
```

- [ ] **Step 2: Scenes** — append to `gen_scenes.py` two press entries (capsule regular on photo, light and dark), one morph entry (one 60×60 circle `g0` → `g0` plus a second circle `g1` 70 pt to the right). Regenerate and sync to the example.

- [ ] **Step 3: Renderers** — Flutter `MotionView`: background as in `SceneView`; for `press`, one `LiquidGlass(glass: …interactive())`; for `morph`, a `GlassGroup(spacing:)` whose children come from `before`/`after` with `glassId`, toggled by a full-screen `GestureDetector(behavior: HitTestBehavior.translucent, onTapUp: …)` placed *under* the glass. SwiftUI: same with `.glassEffect(glass.interactive(), in:)`, `.glassEffectID(id, in: namespace)` in a `GlassEffectContainer`, and `.onTapGesture { withAnimation(.bouncy) { expanded.toggle() } }` on the background. `main.dart` / `AppDelegate` route `-motion <id>` to these views.

- [ ] **Step 4: Recording script** — `tool/fidelity/record_motion.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
UDID="${UDID:-E7A87B4A-3E48-44F8-A588-704D56774FF0}"
BUNDLE="${BUNDLE:-com.aymanomara.adaptiveLiquidGlassExample}"
IDB=tool/fidelity/.venv/bin/idb
OUT="${1:?run dir}"; ONLY="${2:-}"
mkdir -p "$OUT/frames"
ids=$(python3 -c "import json;print('\n'.join(m['id'] for m in json.load(open('tool/scenes/scenes.json'))['motion'] if m['id'].startswith('$ONLY')))")
for id in $ids; do
  read -r kind tx ty hold <<<"$(python3 -c "import json;m=[m for m in json.load(open('tool/scenes/scenes.json'))['motion'] if m['id']=='$id'][0];print(m['kind'],m['touch']['x'],m['touch']['y'],m.get('hold_ms',0))")"
  for r in flutter swiftui; do
    xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
    xcrun simctl launch "$UDID" "$BUNDLE" -motion "$id" -renderer "$r" >/dev/null
    sleep 2.5
    mov="$OUT/$id.$r.mov"
    xcrun simctl io "$UDID" recordVideo --codec h264 --force "$mov" & rec=$!
    sleep 0.7
    if [[ "$kind" == press ]]; then
      "$IDB" ui tap --udid "$UDID" --duration "$(python3 -c "print($hold/1000)")" "$tx" "$ty"
    else
      "$IDB" ui tap --udid "$UDID" "$tx" "$ty"
    fi
    sleep 1.5
    kill -INT "$rec"; wait "$rec" || true
    mkdir -p "$OUT/frames/$id.$r"
    ffmpeg -loglevel error -y -i "$mov" -vf fps=60 "$OUT/frames/$id.$r/%04d.png"
  done
done
```

- [ ] **Step 5: Motion scorer tests** — `tool/fidelity/test_compare_motion.py`

```python
import numpy as np

from compare_motion import first_change, fit_spring


def test_first_change_finds_the_onset():
    frames = [np.zeros((10, 10, 3))] * 5 + [np.ones((10, 10, 3))] * 5
    assert first_change(frames, threshold=0.05) == 5


def test_fit_spring_recovers_parameters():
    t = np.arange(0, 1.2, 1 / 60)
    response, zeta = 0.4, 0.7
    w0 = 2 * np.pi / response
    wd = w0 * np.sqrt(1 - zeta**2)
    x = 1 - np.exp(-zeta * w0 * t) * (np.cos(wd * t) + zeta * w0 / wd * np.sin(wd * t))
    r, z = fit_spring(t, x)
    assert abs(r - response) < 0.02
    assert abs(z - zeta) < 0.03
```

Run: `.venv/bin/pytest -q tool/fidelity` — Expected: FAIL (module missing).

- [ ] **Step 6: Implement** — `tool/fidelity/compare_motion.py`

```python
"""Aligns press/morph recordings and scores them frame by frame."""
import json
import pathlib
import sys

import numpy as np
from PIL import Image
from scipy.optimize import curve_fit

from compare import load, score

ROOT = pathlib.Path(__file__).resolve().parents[2]
FRAMES = 60


def first_change(frames, threshold=0.02):
    base = frames[0]
    for i, f in enumerate(frames):
        if np.abs(f - base).mean() > threshold:
            return i
    return len(frames)


def spring(t, response, zeta):
    w0 = 2 * np.pi / response
    if zeta < 1:
        wd = w0 * np.sqrt(1 - zeta**2)
        return 1 - np.exp(-zeta * w0 * t) * (np.cos(wd * t) + zeta * w0 / wd * np.sin(wd * t))
    return 1 - np.exp(-w0 * t) * (1 + w0 * t)


def fit_spring(t, x):
    (r, z), _ = curve_fit(spring, t, x, p0=(0.4, 0.7), bounds=([0.05, 0.05], [2.0, 1.0]))
    return float(r), float(z)


def glass_width(frame, background_row):
    diff = np.abs(frame - background_row).mean(axis=2).max(axis=0)
    cols = np.where(diff > 0.06)[0]
    return float(cols.max() - cols.min()) if cols.size else 0.0


def main():
    run = pathlib.Path(sys.argv[1])
    spec = json.loads((ROOT / "tool/scenes/scenes.json").read_text())
    out = []
    for m in spec["motion"]:
        seqs = {}
        for r in ("flutter", "swiftui"):
            d = run / "frames" / f"{m['id']}.{r}"
            files = sorted(d.glob("*.png"))
            frames = [load(f) for f in files]
            start = first_change(frames)
            seqs[r] = frames[start:start + FRAMES]
        n = min(len(seqs["flutter"]), len(seqs["swiftui"]))
        per = [score(seqs["flutter"][i], seqs["swiftui"][i]) for i in range(n)]
        worst = min(range(n), key=lambda i: per[i]["ssim"]) if n else None
        springs = {}
        for r, frames in seqs.items():
            bg = frames[0]
            w = np.array([glass_width(f, bg) for f in frames])
            if w.max() - w.min() > 2:
                x = (w - w[0]) / (w.max() - w[0])
                springs[r] = fit_spring(np.arange(len(x)) / 60, x)
        out.append({
            "id": m["id"], "frames": n,
            "pass": bool(n and all(p["pass"] for p in per)),
            "worst_frame": worst,
            "worst": per[worst] if worst is not None else None,
            "springs": springs,
        })
    (run / "motion_report.json").write_text(json.dumps(out, indent=2))
    for o in out:
        print(o["id"], "PASS" if o["pass"] else "FAIL", o["springs"])


if __name__ == "__main__":
    main()
```

Run: `.venv/bin/pytest -q tool/fidelity` — Expected: all pass.

- [ ] **Step 7: Baseline motion run**

```bash
tool/fidelity/record_motion.sh build/fidelity/motion-baseline
tool/fidelity/.venv/bin/python tool/fidelity/compare_motion.py build/fidelity/motion-baseline
```

Expected: one line per motion with fitted springs for both renderers. Check a few extracted frames by eye to confirm the press was registered in **both** renderers.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "test: motion recording and spring fitting for press and morph

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 17: Fit the constants to SwiftUI

Fitting on the device is slow (≈3 s per screenshot), so the search runs on a
NumPy port of the shader, and the device only confirms the result.

**Files:**
- Create: `tool/fidelity/glass_model.py`, `tool/fidelity/test_glass_model.py`, `tool/fidelity/fit.py`, `docs/superpowers/notes/fidelity-status.md`
- Modify: `lib/src/core/glass_constants.dart` (`standard` values + provenance comments)

**Interfaces:**
- `glass_model.render(background: np.ndarray, scene: dict, constants: dict, scale: float) -> np.ndarray` — the same maths as `shaders/liquid_glass.frag`, line for line (SDF, smin, 24-tap disc blur, lens, dispersion, lift, dim, tint, rim, shadow), on the full-resolution background.
- `fit.py --family <prefix> [--rounds 3]` — Powell search (`scipy.optimize.minimize(method="Powell")`) over that family's parameters, minimising `Σ (1 − SSIM)·10 + ΔE/2` against cached SwiftUI screenshots; prints the best constants JSON.

- [ ] **Step 1: Parity test first** — `tool/fidelity/test_glass_model.py`

```python
import json
import pathlib

import numpy as np
import pytest

from compare import load, region_for, score
from glass_model import render

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = ROOT / "build/fidelity/baseline"
SPEC = json.loads((ROOT / "tool/scenes/scenes.json").read_text())
STANDARD = json.loads((ROOT / "tool/fidelity/standard_constants.json").read_text())


@pytest.mark.parametrize("scene_id", [
    "regular-capsule-photo-light", "clear-rect28-text-dark", "merge-gap16-photo-light"])
def test_model_matches_flutter_output(scene_id):
    scene = next(s for s in SPEC["scenes"] if s["id"] == scene_id)
    bg = load(ROOT / f"example/assets/backgrounds/{scene['background']}.png")
    flutter = load(BASE / f"{scene_id}.flutter.png")
    model = render(bg, scene, STANDARD, scale=3)
    x0, y0, x1, y1 = region_for(scene, 3, bg.shape[1], bg.shape[0])
    s = score(model[y0:y1, x0:x1], flutter[y0:y1, x0:x1])
    assert s["ssim"] > 0.995, s
```

Export the shipped constants to JSON for the test: add a tiny Dart script `tool/fidelity/dump_constants.dart` (`print(jsonEncode(GlassConstants.standard.toJson()))`, run with `cd example && dart run ../tool/fidelity/dump_constants.dart > ../tool/fidelity/standard_constants.json`; if `dart run` cannot import Flutter packages, write the JSON by hand from `glass_constants.dart`).

- [ ] **Step 2: Implement `glass_model.py`** by porting `shaders/liquid_glass.frag` function by function (`tex` = bilinear sample with edge clamp; `blurred` = the same 24 golden-angle taps and weights; `field`/`smin`/`sdSuperellipseBox` vectorised over the region's pixel grid; per-pixel normals by the same ±1 px central differences). Work only inside the scene region plus 3× shadow radius for speed. Pick constants by the scene's brightness (`regular`/`clear` vs `regularDark`/`clearDark`).

Run: `.venv/bin/pytest -q tool/fidelity/test_glass_model.py`
Expected: PASS. If SSIM is 0.98–0.995, compare the two images' difference map; usual causes are blur tap weights, the sRGB/linear handling of the Impeller texture, or the half-pixel offset in `FlutterFragCoord`. Fix the model, not the shader, unless the shader is the one that disagrees with the spec.

- [ ] **Step 3: Implement `fit.py`**

```python
"""Fits one scene family's constants against SwiftUI screenshots."""
import argparse
import json
import pathlib

import numpy as np
from scipy.optimize import minimize

from compare import load, region_for, score
from glass_model import render

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = json.loads((ROOT / "tool/scenes/scenes.json").read_text())
REF = ROOT / "build/fidelity/baseline"
KEYS = ["blurSigma", "lensBand", "lensStrength", "dispersion", "rimWidth", "rimIntensity",
        "lumaLift", "dim", "shadowRadius", "shadowOpacity", "tintStrength"]
BOUNDS = {"blurSigma": (0, 20), "lensBand": (2, 40), "lensStrength": (-1, 1), "dispersion": (0, 0.6),
          "rimWidth": (0.3, 4), "rimIntensity": (0, 1.5), "lumaLift": (-0.3, 0.4), "dim": (0, 0.6),
          "shadowRadius": (0, 40), "shadowOpacity": (0, 0.5), "tintStrength": (0, 1)}


def family_key(prefix, brightness):
    variant = "clear" if prefix.startswith("clear") else "regular"
    return variant + ("Dark" if brightness == "dark" else "")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--family", required=True, help="scene id prefix, e.g. regular- or clear-")
    ap.add_argument("--brightness", choices=["light", "dark"], required=True)
    ap.add_argument("--start", type=pathlib.Path, default=ROOT / "tool/fidelity/standard_constants.json")
    args = ap.parse_args()

    constants = json.loads(args.start.read_text())
    key = family_key(args.family, args.brightness)
    scenes = [s for s in SPEC["scenes"]
              if s["id"].startswith(args.family) and s["brightness"] == args.brightness]
    data = []
    for s in scenes:
        bg = load(ROOT / f"example/assets/backgrounds/{s['background']}.png")
        ref = load(REF / f"{s['id']}.swiftui.png")
        data.append((s, bg, ref, region_for(s, 3, bg.shape[1], bg.shape[0])))

    def loss(x):
        c = json.loads(json.dumps(constants))
        for k, v in zip(KEYS, x):
            lo, hi = BOUNDS[k]
            c[key][k] = float(np.clip(v, lo, hi))
        total = 0.0
        for s, bg, ref, (x0, y0, x1, y1) in data:
            out = render(bg, s, c, scale=3)
            r = score(out[y0:y1, x0:x1], ref[y0:y1, x0:x1])
            total += (1 - r["ssim"]) * 10 + r["delta_e"] / 2
        return total / len(data)

    x0 = [constants[key][k] for k in KEYS]
    res = minimize(loss, x0, method="Powell",
                   bounds=[BOUNDS[k] for k in KEYS], options={"maxiter": 4000, "xtol": 1e-3})
    for k, v in zip(KEYS, res.x):
        constants[key][k] = round(float(v), 4)
    print(json.dumps(constants, indent=2))
    print("loss", res.fun, "scenes", [s["id"] for s, *_ in data])


if __name__ == "__main__":
    main()
```

`cornerExponent` is fitted separately on the `regular-rect*` scenes (one-dimensional scan 3.0…6.0, step 0.1) before the variant fits.

- [ ] **Step 4: Fit, in this order**, feeding each run's output JSON into the next as `--start`:

1. `cornerExponent` scan on `regular-rect16`, `regular-rect28` (light).
2. `--family regular- --brightness light`, then `dark`.
3. `--family clear- --brightness light`, then `dark`.
4. `--family tinted- --brightness light`/`dark` but only free `tintStrength` (pass a `--only tintStrength` flag; add it).
5. Spacing check on `merge-gap*`: if the model's merge threshold differs from SwiftUI, change the `2 × spacing` factor in `RenderGlassBackdrop` (document the new factor in the spec amendments).
6. Motion: set `pressResponse`/`pressDamping` and `morphResponse`/`morphDamping` to the SwiftUI springs from `motion_report.json`; set `pressScale`/`pressStretch` from the held-frame bounding box (`width_pressed / width_rest − 1`, split by touch direction).

- [ ] **Step 5: Verify on the device with the fitted constants (no rebuild)**

```bash
CONSTANTS="$(cat build/fidelity/fitted.json | tr -d '\n ')" RENDERERS=flutter SKIP_BUILD=1 \
  tool/fidelity/capture.sh build/fidelity/fitted
cp build/fidelity/baseline/*.swiftui.png build/fidelity/fitted/
tool/fidelity/.venv/bin/python tool/fidelity/compare.py build/fidelity/fitted --no-fail
```

Expected: the pass count is far above the baseline. Every scene still failing goes into `docs/superpowers/notes/fidelity-status.md` with its SSIM/ΔE and a one-line diagnosis from its diff image.

**Stop point:** if a whole family stays below the bars after fitting (e.g. every `clear-*` scene at SSIM 0.93), the shader's model is missing something Apple does. Do not keep tuning: report the family, the numbers and the diff images to the user and propose the specific shader change, as a spec amendment, before writing it.

- [ ] **Step 6: Ship the fitted values**

Write the fitted numbers into `GlassConstants.standard` (`lib/src/core/glass_constants.dart`). Above each variant add a comment naming the fit run and scene family, e.g. `// Fitted 2026-10-xx on regular-*-light (24 scenes), mean SSIM 0.981.` Update `tool/fidelity/standard_constants.json`.

Run: `flutter test` (constants JSON round-trip still passes) and a full `capture.sh` + `compare.py` without `--no-fail`.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: fit glass constants to SwiftUI reference

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 18: Performance, docs and publish readiness

**Files:**
- Create: `example/lib/perf_tab_bar.dart`, `example/integration_test/perf_test.dart`, `example/test_driver/perf_driver.dart`
- Modify: `README.md`, `CHANGELOG.md`, `example/lib/main.dart` (route `-perf`), possibly `shaders/liquid_glass.frag` (optimisations)

- [ ] **Step 1: Perf scene** — `PerfTabBar`: a `ListView.builder` of 200 photo tiles under a bottom `GlassGroup(spacing: 8)` with 5 interactive `LiquidGlass` capsules (60×44) inside a 360×64 `LiquidGlass(shape: rect(32))` bar, the whole page wrapped in `BackdropGroup`.

- [ ] **Step 2: Perf test** — `example/integration_test/perf_test.dart`

```dart
import 'package:adaptive_liquid_glass_example/perf_tab_bar.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('glass tab bar over a scrolling list', (tester) async {
    await tester.pumpWidget(const PerfTabBar());
    await tester.pumpAndSettle();
    await binding.traceAction(() async {
      for (var i = 0; i < 6; i++) {
        await tester.fling(find.byType(Scrollable).first, const Offset(0, -900), 3000);
        await tester.pumpAndSettle();
        await tester.fling(find.byType(Scrollable).first, const Offset(0, 900), 3000);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'glass_scroll');
  });
}
```

`example/test_driver/perf_driver.dart`:

```dart
import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
      responseDataCallback: (data) async {
        final timeline = driver.Timeline.fromJson(
            data!['glass_scroll'] as Map<String, dynamic>);
        final summary = driver.TimelineSummary.summarize(timeline);
        await summary.writeTimelineToFile('glass_scroll',
            pretty: true, includeSummary: true);
      },
    );
```

(add `flutter_driver: {sdk: flutter}` to the example's dev_dependencies.)

- [ ] **Step 3: Run on an iPhone 12 (physical, profile)**

The user must connect the device. Then:

```bash
cd example && flutter drive --profile --driver=test_driver/perf_driver.dart \
  --target=integration_test/perf_test.dart -d <iphone-12-udid>
```

Read `example/build/glass_scroll.timeline_summary.json`. Pass: `90th_percentile_frame_rasterizer_time_millis` < 16.7, `missed_frame_rasterizer_budget_count` / `frame_count` ≤ 1 %. If no iPhone 12 is available, record "unverified — no device" in `docs/superpowers/notes/fidelity-status.md` and tell the user; do not claim the bar.

- [ ] **Step 4: If raster time misses the bar, optimise in this order, re-measuring after each:**
1. Early exit: before the blur and normals, if `d > shadowRadius*3` return `base` (most pixels in the clip are far from any shape).
2. Normals: compute the gradient of the nearest shape analytically instead of 4 extra `field()` calls; use the numeric gradient only where two shapes blend (`|a−b| < k`).
3. Blur: 24 → 16 taps when `blurSigma < 3 px`.
Each change must keep `test_glass_model.py` parity (update `glass_model.py` alongside) and the fitted report's pass count.

- [ ] **Step 5: Docs**

`README.md`: what it is; screenshot pairs from the fitted report (Flutter vs SwiftUI); install; `LiquidGlass`, `GlassGroup`, `glassId`/`unionId`, `.interactive()`, `GlassShape`; Android behaviour table (spec §8); `LiquidGlass.precache()`; `BackdropGroup` tip for many glass widgets; native mode opt-in and its limits (spec §14.6); `GlassBackdropSource` cost; accessibility behaviour; requirements (Flutter ≥ 3.32 with Impeller, iOS 15+, native iOS 26+); fidelity numbers with a link to the harness README. `CHANGELOG.md`: `## 0.1.0-dev.1` with the feature list.

- [ ] **Step 6: Publish dry run (do not publish — the user does that)**

```bash
flutter analyze && flutter test && dart pub publish --dry-run
```

Expected: no analyzer issues, all tests pass, dry run reports `Package has 0 warnings.` Fix any warning it lists (description length, missing `repository` reachability, large files — exclude `build/` and the generated backgrounds from the package with `.pubignore` if they push it over the size limit, keeping them in the example only).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "docs: README, changelog, perf harness and publish readiness

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
