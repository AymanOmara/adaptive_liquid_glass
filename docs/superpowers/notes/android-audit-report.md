# Android / Material path audit — `adaptive_liquid_glass`

**Task A1 · worktree** `alg-android-audit` (branch `android-audit`)
**Date** 2026-10-05 · **Flutter** 3.47.6 (stable) · **Emulator** Pixel_8_Pro AVD,
Android 37.2-beta3 (arm64, Google APIs, 16 KB pages), Impeller **OpenGLES**
backend.
**Scope** spec `docs/superpowers/specs/2026-10-04-phase1-core-material-design.md`
§1 (criterion 4), §5–§8, §12.

Criterion 4 under test: *“On Android every widget renders a Material 3
equivalent with no glass code path executed.”*

---

## 1. Test results

| Run | Command | Result |
|---|---|---|
| Baseline (before this audit) | `flutter test` | **109 passed**, 0 failed |
| New file only | `flutter test test/android_material_path_test.dart` | **14 passed**, 0 failed |
| Full suite (with new file) | `flutter test` | **123 passed**, 0 failed |
| Analyzer | `flutter analyze test/android_material_path_test.dart` | **No issues found** |
| Formatter | `dart format test/android_material_path_test.dart` | 1 file formatted |

New file: `test/android_material_path_test.dart` (14 tests, all run under
`debugDefaultTargetPlatformOverride = TargetPlatform.android` via
`TargetPlatformVariant.only(TargetPlatform.android)`; the file-level `tearDown`
resets the override, and the variant's own teardown resets it before the
binding's foundation-debug-variable invariant check).

What the new tests assert (all observed passing):

- **`LiquidGlass` renders a `Material`, not glass.** A `MaterialGlass` with a
  `Material` (elevation 1, `Clip.antiAlias`) is in the tree; **no**
  `GlassBackdrop` widget, **no** `RenderGlassBackdrop` render object (the
  shader-backed render object type from `lib/src/shader/render_glass_backdrop.dart`),
  **no** `RenderGlassMember`, **no** `DegradedGlass`, **no** `BackdropFilter`
  widget and **no** `BackdropFilterLayer` anywhere in the layer tree.
- **`GlassGroup` with 3 members** → exactly three `MaterialGlass`/`Material`
  surfaces, all `surfaceContainerHigh`, no group backdrop (no `GlassBackdrop`,
  no shader layers).
- **Shapes**: capsule → `StadiumBorder`; circle → `CircleBorder`;
  `rect(16)` → `RoundedSuperellipseBorder(borderRadius: 16)`;
  concentric (outside a container) → `StadiumBorder`.
- **Variants**: `Glass.clear` → `surfaceContainerLow` at alpha 0.85, elevation 0;
  `Glass.regular.tint(orange)` → `ColorScheme.fromSeed(orange).primaryContainer`;
  `Glass.identity` → child only, no `MaterialGlass`/`Material` in its subtree.
- **Interactive**: `InkWell` present, `excludeFromSemantics: true`, ripple
  clipped by `Material`'s `Clip.antiAlias`; non-interactive glass has no
  `InkWell`.
- **Theme-driven colour, not constants**: the Material colour equals
  `Theme.of(context).colorScheme.surfaceContainerHigh` in both a light and a
  dark `ThemeData` (and differs between them), and tracks two different seeds
  (teal, deepPurple). No hard-coded colours found in the material path
  (`lib/src/material/material_glass.dart`; the only literal is the spec'd
  alpha `0.85`; `opaqueGlassColor`'s literals are the iOS Reduce-Transparency
  path, never used on Android).
- **Explicit `mode: GlassRenderMode.shader` on Android** (documented deviation,
  see §4.4): in the widget-test runtime
  `ui.ImageFilter.isShaderFilterSupported == false`, so the resolver's
  `shader → degraded` fallback runs: `MaterialGlass` is absent and a
  `DegradedGlass` with a `BackdropFilter` blur renders — i.e. glass code really
  executes on Android when the consumer explicitly asks for shader (spec §5
  step 1 lets an explicit mode win; §12 declares it allowed but
  unsupported/untested). On an Impeller device where the shader filter is
  supported the full `GlassBackdrop` shader path would run instead; the test
  branches on the runtime value and asserts both outcomes.

## 2. Build result

- **`example/` as shipped:** `flutter build apk --debug` **fails** —

  ```
  Flutter failed to read file at
  ".../alg-android-audit/example/android/app/build.gradle".
  PathNotFoundException: Cannot open file, path =
  '.../example/android/app/build.gradle' (OS Error: No such file or directory, errno = 2)
  ```

  `example/` has no `android/` platform folder at all (iOS only). See §4.1.

- **Scratch Android host (audit harness).** Because the task forbids adding
  anything but test files to this worktree, a throwaway Flutter app was created
  outside the worktree (`$TMPDIR/opencode/alg_android_demo`), depending on this
  worktree's package by path, with page 1 a **verbatim copy** of
  `example/lib/demo.dart` (same `LiquidGlassTheme`/`MaterialApp` wrapper, same
  `LiquidGlass.precache()` call as `example/lib/main.dart:16`) and page 2 an
  audit gallery of shapes/variants. `flutter build apk --debug` there:

  - first run after `flutter clean`: **succeeded** (`✓ Built
    build/app/outputs/flutter-apk/app-debug.apk`), **with a shader warning**:

    ```
    warning: Shader '.../alg-android-audit/shaders/liquid_glass.frag'
    is incompatible with SkSL. This shader will not load when running with
    the Skia backend.
    impellerc failure: Compilation failed for target: SkSL
    SkSL Error: error: 35: index expression must be constant
        vec4 rc = uRects[i];
    ```

  - (One earlier build invocation exited 1 with the same impellerc text;
    two subsequent runs, including one after `flutter clean`, exited 0 with
    the warning above. The reproducible steady state is: build succeeds,
    warning emitted.)

- **Runtime on the emulator**: APK installed (`Success`), app launched and
  rendered. `adb logcat` shows the Flutter process starting under
  **Impeller (OpenGLES)**, no Flutter/Dart exceptions, no shader-load errors,
  no `E flutter` entries (only OS/Play-services noise: Finsky, AiAiBesties,
  XR flags). The demo screen renders and is interactable (swipes/taps worked).

## 3. Screenshots

All at `/Users/aymanomara/Android Studio Projects/alg-android-audit/`, taken
with `adb exec-out screencap -p`. Note: this audit session cannot render
images, so the descriptions below combine the known widget structure with
programmatic pixel sampling of the PNGs (sampled values quoted).

| File | What it shows |
|---|---|
| `android-demo.png` | Verbatim `example/lib/demo.dart` on Android. Six-stop diagonal gradient + 30 white stripes backdrop; centred `GlassShape.rect(28)` renders as an **opaque near-white Material surface** (sampled ≈ RGB 227–236, i.e. light `surfaceContainerHigh`) with the black “Liquid Glass” label — the backdrop gradient/stripes are **not** refracted or blurred through it (correct: no glass on Android). Bottom `GlassGroup` of three members renders as **three separate flat stadium surfaces** — no merge bulge, no group blend, exactly the layout-only behaviour spec §8 requires. |
| `android-gallery.png` | Audit harness page: near-black scaffold (16,16,20). Shapes row — capsule (stadium) and circle surfaces; `rect(16)` and concentric below. Variants — `regular` opaque surface (236,230,240 = light `surfaceContainerHigh`), `clear` visibly dimmer/translucent (212,208,216 ≈ `surfaceContainerLow` @ 0.85 over dark), `tint(blue)` clearly blue (216,226,255 ≈ `fromSeed(0xFF3B82F6).primaryContainer`), `identity` with **no surface** (background shows through around the bare text). Interactive tile and a 2-member group below. |
| `android-ripple.png` | Same page captured mid-hold (2.5 s press) on the interactive tile. No ripple discolouration discernible at the sampled pixels (the InkWell splash is subtle at 1.2 s and screencap timing is coarse); ripple presence, pressed-state layer and shape clipping are verified structurally by the widget tests instead. Kept as a record of the interactive path running without errors. |

No other example screens exist without code changes: `LaunchArgs` come from an
iOS-only method channel (`example/launch.dart`), so on Android the example
always shows the single `Demo` screen; the scene viewer requires the iOS host.

## 4. Problems found

### 4.1 Important — the example app cannot build for Android

- **Where**: `example/` (no `android/` directory; `example/pubspec.yaml` has no
  Android platform either).
- **Evidence**: §2 — `flutter build apk --debug` fails with
  `PathNotFoundException … example/android/app/build.gradle`.
- **Impact**: Phase-1 criterion 4 (“every widget renders a Material 3
  equivalent on Android”) cannot be demonstrated, smoke-tested or screenshotted
  from the shipped example; consumers on Android have no reference app. The
  Android path is effectively untested CI-wise.
- **Proposed fix** (in the main checkout, not applied):

  ```bash
  cd example && flutter create --platforms=android --org dev.alg --project-name adaptive_liquid_glass_example .
  ```

  plus an Android entry in the example's README test matrix.

### 4.2 Important — `liquid_glass.frag` fails SkSL compilation on Android builds

- **Where**: `shaders/liquid_glass.frag:43-48` — `shapeDist(int i, …)` indexes
  the uniform arrays through a function parameter (`uRects[i]`, `uInfo[i]`),
  which SkSL rejects (“index expression must be constant”). The accesses at
  lines 100-103 are fine (loop-induction index in a constant-bounded loop).
- **Evidence**: §2 — impellerc warning on every Android APK build containing
  this package; “will not load when running with the Skia backend”.
- **Impact**: today, Android defaults to material mode so nothing breaks
  visually. But any consumer who forces `mode: GlassRenderMode.shader` on
  Android (§12 allows it), or any Flutter configuration that falls back to
  Skia, gets a shader that cannot load — the render object silently paints
  children without glass (`render_glass_backdrop.dart:310-320` guards on
  program != null). It also pollutes every Android build log with a failure
  warning.
- **Proposed patch** (report-only; index arrays only inside the unrolled
  loops):

  ```diff
  --- a/shaders/liquid_glass.frag
  +++ b/shaders/liquid_glass.frag
  @@ -43,10 +43,11 @@
  -float shapeDist(int i, vec2 p) {
  -  vec4 rc = uRects[i];
  -  vec2 hs = rc.zw * 0.5;
  -  float n = uInfo[i].z > 0.0 ? uInfo[i].z : uGlobal2.y;
  -  return sdSuperellipseBox(p - (rc.xy + hs), hs, uInfo[i].x, n);
  -}
  +// Index-free form: the uniform arrays are indexed only from the
  +// constant-bounded loops below, whose induction variable SkSL treats as a
  +// constant index expression; a function parameter is not one.
  +float shapeOf(vec2 p, vec4 rc, vec4 info) {
  +  vec2 hs = rc.zw * 0.5;
  +  float n = info.z > 0.0 ? info.z : uGlobal2.y;
  +  return sdSuperellipseBox(p - (rc.xy + hs), hs, info.x, n);
  +}
  @@ -56,8 +57,9 @@
     float d = 1e6;
     for (int i = 0; i < 16; i++) {
       if (i >= int(uGlobal.x)) break;
  -    d = smin(d, shapeDist(i, p), uGlobal2.x);
  +    d = smin(d, shapeOf(p, uRects[i], uInfo[i]), uGlobal2.x);
     }
  @@ -84,7 +86,8 @@
     for (int i = 0; i < 16; i++) {
       if (i >= count) break;
  -    float di = shapeDist(i, px);
  +    vec4 info = uInfo[i];
  +    float di = shapeOf(px, uRects[i], info);
       float e = max(di, 0.0);
  ```

### 4.3 Important — a shader code path does execute on Android (criterion 4, letter)

- **Where**: `lib/src/group/glass_group.dart:154` — `GlassGroup.initState`
  unconditionally calls `GlassProgram.instance.load()` for **every** group,
  whatever the resolved mode; and `lib/src/liquid_glass.dart:54`
  (`LiquidGlass.precache`) does the same for any platform
  (`example/lib/main.dart:16` calls it, so the demo compiles the fragment
  program on Android at startup).
- **Evidence**: code reading; on-device run shows no error because Impeller
  GLES compiles the program fine — but the load (asset read + SL→SPIR-V
  compile) runs and holds GPU memory that material mode never uses.
  Criterion 4 says *no glass or shader code path may run*.
- **Impact**: wasted startup work and memory on every Android app using the
  package; a strict reading of criterion 4 is violated even though nothing is
  rendered with it.
- **Proposed patch** (report-only; load lazily, only for the path that draws):

  ```diff
  --- a/lib/src/group/glass_group.dart
  +++ b/lib/src/group/glass_group.dart
  @@ -151,7 +151,6 @@ class _GlassGroupState extends State<GlassGroup> with TickerProviderStateMixin {
       _morph; // install the registry hooks before members register
       GlassPlatform.instance.ensureStarted();
       GlassPlatform.instance.environment.addListener(_onEnvironment);
  -    GlassProgram.instance.load();
       GlassBackdropSources.instance.revision.addListener(_onSources);
  @@ -297,6 +296,11 @@ class _GlassGroupState extends State<GlassGroup> with TickerProviderStateMixin {
       _updateSampler(rendering);

  +    // Only the backdrop path draws the shader program. Material and
  +    // degraded members never do (spec §1 criterion 4: no glass code path
  +    // on Android), so don't load — or pay for — the program there.
  +    if (rendering == GlassMemberRendering.backdrop) {
  +      GlassProgram.instance.load();
  +    }
  +
       Widget scoped = GlassGroupScope(
  ```

  `LiquidGlass.precache` can stay platform-agnostic (it is an explicit
  consumer opt-in) but should be documented as iOS-only-useful; the example
  should skip it on Android (`if (Platform.isIOS)`, or leave as an accepted
  startup cost after this fix).

### 4.4 Minor (spec-sanctioned, documented here) — explicit `mode: shader` runs glass on Android

- **Where**: `lib/src/core/render_mode_resolver.dart:18-28` — explicit
  non-auto modes win (§5 step 1), so `mode: GlassRenderMode.shader` on Android
  resolves to `shader` (Impeller) or `degraded` (elsewhere). The new test
  `explicit mode:shader on Android is honored (documented deviation)` records
  the degraded branch: `DegradedGlass` + `BackdropFilter` blur on Android.
- Spec §12 explicitly permits this (“`mode: shader` is allowed on Android but
  unsupported/untested”), so no code change is proposed. Combined with §4.2,
  however, the shader-under-Skia case would silently render no glass at all.
  Optional hardening: resolve `shader → material` on Android, or
  `FlutterError.reportError` in debug when the shader path is requested on
  Android.

### 4.5 Minor — shape mapping deviates from the §8 table

- **Where**: `lib/src/core/shape_border.dart:8-14`. Spec §8 says every
  `GlassShape` maps to “same `RoundedSuperellipseBorder` (Material shape)”;
  the implementation maps capsule/concentric → `StadiumBorder` and circle →
  `CircleBorder`, with only `rect(r)` → `RoundedSuperellipseBorder(r)`.
- Visually equivalent for these shapes (a stadium *is* a rect with
  r = shortestSide/2; §15.1 made capsules/circles circular anyway) and the
  shader path agrees (`cornerExponent = 2.0` for capsules/circles). No fix
  needed; the spec table should be updated to match.

### 4.6 Minor — interactive Material glass has a no-op `onTap` and no semantics

- **Where**: `lib/src/material/material_glass.dart:53` —
  `InkWell(onTap: () {}, excludeFromSemantics: true, …)`. The empty callback
  exists only to enable the ripple. Consequences: the glass API offers no tap
  callback (consumer widgets inside must handle taps — verified they still
  receive them), and the ripple surface announces nothing to accessibility
  services (matches §9 “glass is decoration only; semantics come from the
  child”). Acceptable; documenting because M3 usually pairs an ink surface
  with an actionable role. If the API later grows `onTap`, pass it through and
  drop `excludeFromSemantics`.

No other defects found in the Android path: no hard-coded Material colours,
no `BackdropFilter`/shader objects in any material-mode tree (widget + render
+ layer level), correct light/dark theming, correct `Theme` sourcing.

## 5. Material 3 conformance notes

- **Elevation and tonal surface** — `.regular` maps to
  `Material(color: surfaceContainerHigh, elevation: 1, shadowColor:
  colorScheme.shadow, surfaceTintColor: transparent)` exactly as the §8 table
  says. Using a container tone for the surface and disabling the tonal overlay
  is internally consistent M3 (tone communicates level; elevation 1 adds a
  faint shadow). `.clear` is `surfaceContainerLow` at 0.85 opacity, elevation
  0 — translucent surfaces are not a standard M3 container, but it is a
  reasonable stand-in for “clear glass” and stays theme-derived. Colors follow
  the consumer's scheme in both brightnesses (tested).
- **Shape** — continuous-corner `RoundedSuperellipseBorder` for rects
  (Apple's curve, as §4 requires); exact `Stadium`/`Circle` for capsule and
  circle (consistent with §15.1). Ripples and ink are clipped to the shape via
  `Material.clipBehavior: Clip.antiAlias` (tested). The rect border is
  size-independent (unclamped requested radius) whereas the shader clamps to
  `shortestSide/2` (`glass_shape.dart:93-94`) — an invisible difference for
  sane layouts; noting for completeness.
- **Ripple / ink on interactive glass** — `.interactive()` wraps the child in
  the ripple-capable `InkWell` on the `Material` surface: pressed-state
  overlay + splash appear and are clipped to the glass shape, per §8's
  “`InkWell` ripple + M3 pressed state layer”. Verified structurally in
  widget tests; the on-device press screenshot did not capture a visible
  splash (timing), with no runtime errors during interaction. Non-interactive
  glass correctly has no ink.
- **Text contrast** — the surface never sets a foreground/text style
  (decoration-only, §9), so contrast depends on the consumer's child. Points
  to document for consumers: on `tint(c)` the fill is
  `ColorScheme.fromSeed(c).primaryContainer`, so label text should use the
  matching `onPrimaryContainer` (a plain `onSurface`/black label can fail
  contrast on saturated containers — the demo's black label is safe on the
  untinted light surface but would not be on the blue tint tile);
  `Glass.clear` at 0.85 over a saturated background slightly lowers the
  guaranteed contrast vs an opaque container (M3 contrast guidance assumes
  opaque surfaces). An `onColor` helper (or docs) would close this.

## 6. Files produced by this audit

- `test/android_material_path_test.dart` — new (14 tests).
- `ANDROID_AUDIT_REPORT.md` — this report.
- `android-demo.png`, `android-gallery.png`, `android-ripple.png` —
  screenshots (referenced above; not committed).
