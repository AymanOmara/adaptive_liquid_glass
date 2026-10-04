# adaptive_liquid_glass — Phase 1: Core Material

**Date:** 2026-10-04
**Status:** Draft for review
**Package:** `adaptive_liquid_glass` (standalone Flutter plugin, published to pub.dev)

## 1. Intent

A reusable Flutter package that reproduces iOS 26 SwiftUI **Liquid Glass** as
close to pixel- and motion-exact as is measurable, and renders the equivalent
**Material 3** component on Android — behind one API, so app code never
branches on platform.

- **Stated by the owner:** must match SwiftUI Liquid Glass; Android uses Material
  Design; standalone package, published to pub.dev, consumed by other projects;
  eventually the full iOS 26 component set.
- **Assumed:** consumers include RTL/Arabic apps, so every API is
  direction-aware (`AlignmentDirectional`, `EdgeInsetsDirectional`). The light
  angle is not mirrored in RTL, matching iOS.

### Success criteria (Phase 1)

1. Static fidelity: for every reference scene (§10), Flutter shader output vs.
   SwiftUI screenshot on the same simulator scores **SSIM ≥ 0.97** and
   **mean CIEDE2000 ΔE ≤ 2.0** inside the glass region.
2. Motion fidelity: press / release / morph frame sequences at 60 fps stay within
   the same thresholds per frame, after time alignment of the first frame.
3. A screen with a 5-item tab bar of glass over a scrolling list holds 60 fps on
   iPhone 12 (shader mode) in profile builds.
4. On Android every widget renders a Material 3 equivalent with no glass code
   path executed.

## 2. Roadmap (decomposition)

Each phase gets its own spec → plan → implementation cycle.

| Phase | Scope |
|---|---|
| **1 — Core material (this spec)** | `LiquidGlass`, `GlassGroup`, `Glass`, `GlassShape`, theme, mode resolver, shader, native bridge, Material fallback, fidelity harness |
| 2 — Navigation chrome | Tab bar (incl. minimise-on-scroll, search tab), nav bar, toolbar |
| 3 — Controls | Buttons (`.glass`, `.glassProminent`), segmented control, slider, toggle |
| 4 — Overlays | Sheets, menus, alerts, popovers |

## 3. Constraints

- Flutter **≥ 3.32**, Dart **≥ 3.8** (backdrop shader filters on Impeller,
  `RoundedSuperellipseBorder`, `BackdropGroup`).
- iOS deployment target **15.0**; native mode activates only on **iOS 26+**.
- Android: Flutter's default min SDK; no Android native code.
- No runtime dependencies beyond the Flutter SDK.

## 4. Public API

```dart
LiquidGlass(
  glass: Glass.regular.tint(Colors.blue).interactive(),
  shape: const GlassShape.capsule(),
  glassId: 'a',          // optional — morph identity inside a GlassGroup
  unionId: 'tools',      // optional — forces union with same-id siblings
  mode: GlassRenderMode.auto, // auto | shader | native | material
  child: Text('Hello'),
)

GlassGroup(spacing: 20, child: ...)   // = GlassEffectContainer(spacing:)

LiquidGlassTheme(data: LiquidGlassThemeData(...), child: ...)

GlassBackdropSource(child: ...)       // opt-in, enables adaptive foreground
```

| Type | Mirrors | Members |
|---|---|---|
| `Glass` (immutable) | `Glass` | `.regular`, `.clear`, `.identity`; `.tint(Color)`, `.interactive([bool])` |
| `GlassShape` | `Shape` in `glassEffect(in:)` | `capsule()`, `circle()`, `rect(cornerRadius)`, `concentric()` (inherits parent container radius minus inset) |
| `LiquidGlassThemeData` | — | `lightAngle` (default −45°), `defaultGlass`, `defaultMode`, `nativeEnabled` (default `false`) |
| `GlassRenderMode` | — | `auto`, `shader`, `native`, `material` |
| `GlassForeground.of(context)` | label vibrancy | `Brightness` of content behind the glass (only under a `GlassBackdropSource`; otherwise theme brightness) |

All corners use Apple's continuous curve (`RoundedSuperellipseBorder`), never
circular arcs.

## 5. Architecture

```
lib/
  adaptive_liquid_glass.dart   exports only
  src/core/      glass.dart, glass_shape.dart, theme.dart, render_mode_resolver.dart
  src/shader/    glass_render_box.dart, shader_cache.dart, uniforms.dart
  src/group/     glass_group.dart, glass_registry.dart, morph_controller.dart
  src/native/    native_glass_view.dart, platform_channel.dart
  src/material/  material_glass.dart
  src/a11y/      accessibility_flags.dart   (Reduce Transparency via channel)
shaders/liquid_glass.frag
ios/Classes/     AdaptiveLiquidGlassPlugin.swift, GlassPlatformView.swift
example/         demo + reference scenes
tool/reference_ios/   SwiftUI reference app (Xcode project)
tool/fidelity/        capture + compare scripts
```

Each unit has one job:

- **Resolver** — pure function `(platform, iosVersion, theme, mode, a11y, shaderSupported) → effective mode`. No widgets; fully unit-tested.
- **Shader layer** — draws one glass shape (or one merged group) from uniforms.
- **Group** — collects descendant shapes via a registry, emits one merged draw; owns morph springs.
- **Native** — wraps `UiKitView` around a UIKit `UIVisualEffectView` with `UIGlassEffect`; parameter updates via method channel.
- **Material** — maps glass parameters to a Material 3 surface.

### Mode resolution (in order)

1. Explicit `mode` other than `auto` wins (except `native` below iOS 26 → falls to `shader`).
2. Android / other non-iOS → `material`.
3. iOS with Reduce Transparency on → solid opaque surface (Apple behaviour).
4. iOS 26+ and `theme.nativeEnabled` → `native`.
5. `ImageFilter.isShaderFilterSupported == false` → degraded shader-less path (blur + rim painted on top).
6. Otherwise → `shader`.

## 6. Rendering (shader mode)

Per glass shape, inside one `BackdropFilter(filter: ImageFilter.shader(...))`;
all glass on a route shares one capture via `BackdropGroup`.

1. **Shape SDF** — rounded superellipse signed distance; `concentric` resolved on the Dart side.
2. **Frost** — Gaussian blur composed before the shader (`ImageFilter.compose`). `.regular`: stronger blur + luminance lift; `.clear`: minimal blur + dimming layer; `.identity`: no effect, child only.
3. **Lensing** — within an edge band, sample offset along the SDF gradient with a convex profile; red/blue channel offsets for dispersion. Band width and strength are uniforms.
4. **Rim highlight** — thin specular edge, intensity from `dot(normal, lightDir)`; second, weaker opposite rim.
5. **Adaptive tint** — in-shader luminance of the blurred sample darkens/lightens the glass body; `.tint(color)` blends after this.
6. **Shadow** — soft ambient shadow painted outside the shape (not in the backdrop pass).

Parameter values (blur radii, band width, rim widths, tint curves) are **not
guessed**: they are fitted against the reference scenes (§10) and stored as
constants with the scene that fixed them.

### GlassGroup merging

Descendant `LiquidGlass` widgets register their shape and global rect with the
nearest `GlassGroup`. The group draws **one** pass over its bounds; shapes
combine with a smooth-min union whose radius derives from `spacing`. Max **16**
shapes per group (uniform array limit); beyond that, extra shapes render
individually and an assertion fires in debug.

### Morph (`glassId`)

When a `glassId` appears, disappears or changes geometry, `MorphController`
animates the shape's rect/radius with a spring; appear/disappear grow from / shrink
into the nearest same-group shape. Spring parameters fitted to SwiftUI recordings.

### Interactive

`.interactive()` adds: press → scale toward ~1.1 with directional stretch toward
the touch point, radial inner glow at the touch point; release → spring back with
overshoot. Reduce Motion (`MediaQuery.disableAnimations`) → no stretch or
overshoot, glow only.

### Adaptive foreground

Under a `GlassBackdropSource` (a `RepaintBoundary` the app wraps around its
content), the group samples a low-resolution image of the region under each
glass shape at most every 250 ms and when scrolling settles, publishing
`Brightness` through `GlassForeground`. Without a source, the theme's
brightness is used. Off by default — it costs a GPU readback.

## 7. Native mode (iOS 26+, opt-in)

- `UiKitView` hosts `GlassPlatformView`: `UIVisualEffectView(effect: UIGlassEffect)` with `tintColor`, `isInteractive`, and corner configuration from `GlassShape`.
- Flutter `child` paints above the platform view.
- `GlassGroup` with native children wraps them in a `UIGlassContainerEffect` only when **all** members are native; mixed groups fall back to shader for every member (logged in debug).
- Morph across native views is not supported in Phase 1; `glassId` changes cross-fade.

## 8. Material mode (Android)

| Glass | Material 3 |
|---|---|
| `.regular` | `Material(color: surfaceContainerHigh, elevation: 1)` |
| `.clear` | `surfaceContainerLow` at 0.85 opacity, elevation 0 |
| `.tint(c)` | colour from `ColorScheme.fromSeed(c)` → `primaryContainer` |
| `.interactive()` | `InkWell` ripple + M3 pressed state layer |
| `GlassShape` | same `RoundedSuperellipseBorder` (Material shape) |
| `GlassGroup` | layout only, no merging |
| `glassId` change | `AnimatedSwitcher` fade-through |

Colours come from the ambient `Theme`, so the consumer's Material theme is
respected.

## 9. Accessibility

- **Reduce Transparency** — not exposed by Flutter; read on iOS via `UIAccessibility.isReduceTransparencyEnabled` plus its change notification through the plugin channel. When on, glass becomes an opaque surface.
- **Increase Contrast** (`MediaQuery.highContrast`) — stronger rim and border, reduced lensing.
- **Reduce Motion** — see Interactive.
- Glass is decoration only; semantics come from the child.

## 10. Fidelity harness

- `tool/reference_ios/` — SwiftUI app rendering a fixed scene list: 3 backgrounds (photo, text-heavy, flat gradient) × variants (`regular`, `clear`, tinted, interactive pressed) × shapes (capsule, circle, rect 16/28) × light/dark, plus 2-shape merge at 3 spacings and a morph sequence.
- `example/` renders the identical scenes by scene id.
- `tool/fidelity/capture.sh` boots one simulator (iPhone 17 Pro, iOS 26), screenshots both apps per scene; `compare.py` computes SSIM and CIEDE2000 inside the glass mask and writes an HTML report.
- Motion: `xcrun simctl io recordVideo` at 60 fps for both; frames aligned on first visual change.

## 11. Testing

- **Unit:** resolver truth table; `Glass` builder immutability/equality; `GlassShape` → border/SDF parameters; group registry add/remove/limit.
- **Widget (`flutter test`):** material mode structure; theme propagation; group registration lifecycle. Shader output is **not** golden-tested here (no Impeller in the test runner).
- **Integration (`integration_test` on simulator):** fidelity scenes, platform-view creation and updates, Reduce Transparency channel.
- **Performance:** profile-mode timeline of the §1 criterion-3 scene.

## 12. Non-goals (Phase 1)

- Any component beyond `LiquidGlass` / `GlassGroup` (Phases 2–4).
- Glass rendering on Android or web (`mode: shader` is allowed on Android but unsupported/untested).
- Device-tilt-driven highlights (light angle is a theme value; consumers can animate it).
- Merging between native and shader glass.

## 13. Risks

| Risk | Mitigation |
|---|---|
| Apple's exact lens profile / radii unpublished | Fitted from reference scenes; constants traceable to scenes |
| Backdrop shader cost with many shapes | `BackdropGroup` single capture; group merging = one pass; perf criterion in §1 |
| SSIM 0.97 unreachable on some scenes | Report lists per-scene scores; any scene below threshold is a tracked issue, not silently accepted |
| Platform-view overhead in native mode | Opt-in only; documented |

## 14. Amendments (2026-10-04, after SDK verification)

Verified against the installed Flutter 3.47.6 SDK, Xcode 27 and the iOS 26.4
SDK headers. These override the earlier sections where they conflict.

1. **Blur and shadow move into the shader (§6 steps 2 and 6).** A backdrop
   shader filter receives only the already-blurred texture when a blur is
   composed before it, so it could not return the sharp backdrop outside a
   merged shape. The shader therefore samples the sharp backdrop, does a
   24-tap disc blur itself, and paints the soft shadow outside the shape in
   the same pass. A single render object pushes one clip + one
   `BackdropFilterLayer` per group; no `ImageFilter.compose`.
2. **Reduce Transparency (§5, §9)** applies after mode resolution: an
   effective `shader` or `degraded` mode becomes `opaque` (the shader with an
   opaque flag, so merging still works). `native` is left alone because
   UIKit already honours the setting itself.
3. **Default light angle (§4)** is up-leading, `-3π/4` radians in y-down
   screen space, and is not mirrored in RTL (matching iOS).
4. **Reference app (§10)** is not a separate Xcode project: the example's
   iOS Runner hosts the SwiftUI reference scenes and chooses Flutter or
   SwiftUI from launch arguments. Both read the same `scenes.json` and the
   same generated background PNGs, so the pixels behind the glass are
   identical. Fidelity runs pin the **iOS 26.4** simulator runtime
   (iPhone 17 Pro); iOS 27 differences are a later, separate pass.
5. **Pressed state (§10)** is measured from motion recordings (frames held
   mid-press), not static scenes, because SwiftUI's interactive glass only
   reacts to real touches. Touches are injected with `idb`.
6. **Native mode interactivity (§7):** the Flutter child sits above the
   platform view and receives touches, so UIKit's own interactive highlight
   does not run. The Flutter press spring drives the native view's frame
   instead.
7. **Material `glassId` (§8):** an appearing member fades in; a removed
   member disappears immediately (no fade-out, because the widget is gone).
8. **Fitted constants** live in `GlassConstants`, exported only from
   `package:adaptive_liquid_glass/testing.dart`. The example app accepts a
   constants JSON at launch, so the fitting loop needs no rebuilds.
9. **Shapes over the limit (§6)** report a non-fatal `FlutterError` in debug
   instead of an assertion, then render in their own implicit group.

## 15. Amendment: shader model v2 (2026-10-04, after the first fidelity baseline)

The first full baseline (0/75 scenes passing; median SSIM 0.688, median ΔE 14.7) and
side-by-side crops against SwiftUI showed four differences that no constant could fit,
because the shader had no parameter for them. These changes override §6 and §14.1 where
they conflict:

1. **Per-shape corner exponent.** Capsules and circles use exact circular arcs, like
   SwiftUI's `Capsule()` and `Circle()`. Only rectangles use the fitted continuous-corner
   exponent.
2. **Frost is a real blur composed before the shader**:
   `ImageFilter.compose(outer: shader, inner: blur)`. The shader returns premultiplied colour
   with alpha: transparent outside the shape except the shadow. `BackdropFilterLayer`'s
   srcOver blend keeps the sharp backdrop outside the shape. This replaces the in-shader
   24-tap blur, which could not reach SwiftUI's blur radius without aliasing. A group mixing
   regular and clear glass uses a single blur radius, the largest of its members'.
3. **Fill colour and saturation.** Each constant set gains `fillColor`, `fillOpacity` (which
   replaces `lumaLift`) and `saturation`. This lets the glass wash toward white in light mode
   and toward dark grey in dark mode, and mute the colours behind it, as SwiftUI does.
4. **Merge factor.** The smooth-union radius is `mergeFactor × spacing`, with `mergeFactor`
   fitted, instead of a fixed 2×.

The public widget API is unchanged.
