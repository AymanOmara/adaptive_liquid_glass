## Unreleased


### Task 17d — noise floor, tone LUT, hard target met

- Certified fidelity: 46/75 scenes pass (SSIM ≥ 0.97, ΔE ≤ 2.0), median
  SSIM 0.9828 / ΔE 1.09, min SSIM 0.9532, 0 scenes below 0.95 (75 in-set;
  held-out 48-scene set 18/48, min 0.9470).
- Tone LUT: piecewise-linear 9-knot input→output curve per variant set,
  measured from grey flats (covers below the 0.15 code floor); small dark
  shapes gain a `toneLift`.
- Clear glass: lens max-min grid (`lensSizeRef`/`lensStrength`), rim mix,
  post-blur share; regular dark: anisotropic frost (`blurAspectPower`).
- Noise floors: SwiftUI-vs-SwiftUI repeat floor is exactly zero
  (bit-deterministic simulator); SwiftUI-vs-UIKit cross-API floor
  committed; `compare.py --floor` adds report-only within-noise verdicts.


* Native glass is SwiftUI's own: native mode hosts a `GlassEffectContainer`
  with a `.glassEffect` view per member (was UIKit `UIGlassEffect`), so it
  matches SwiftUI pixel for pixel, follows `MediaQuery.platformBrightness`
  like the shader path (and re-themes when it changes at runtime), draws
  circles as circles and supports `unionId`.
* **Breaking:** native glass is the default on iOS 26+; `auto` picks it from
  the first frame (the iOS version is read synchronously at startup).
  `LiquidGlassThemeData.nativeEnabled` is removed; use `mode:` or
  `defaultMode: GlassRenderMode.shader` to opt out.

* `Widget.glassEffect(glass:, shape:, glassId:, unionId:, padding:)`: one-line
  glass, mirroring SwiftUI's `.glassEffect(_:in:)`.
* `LiquidGlass.padding`: insets the child inside the glass (directional).
* `LiquidGlass.adaptiveForeground` (default `true`): text and icons on glass
  take a readable label colour (the Material on-colour on Android); explicit
  colours still win.
* `LiquidGlass.onPressed`: glass as a button, with button semantics, focus,
  Enter/Space activation and interactive glass unless the glass opts out
  with `interactive(false)`.
* `Glass` remembers an explicit `interactive(false)`, so it no longer equals
  the plain preset.
* `LiquidGlass.precache()` is optional: shader glass draws as a blur until
  the shader loads, then switches in place.
* Android and the other non-shader paths no longer load the shader.
* `concentricRadius` is no longer exported.
* Android is declared as a supported platform (a Dart-only plugin entry).

* **Breaking:** `GlassMotionConstants.pressScale` is replaced by
  `pressGrowthArea` and `pressScaleMax`: a pressed shape grows by about the
  same area whatever its size (`sqrt(1 + pressGrowthArea / (w·h))`, capped),
  as SwiftUI does, so small shapes grow more than large ones.
* Press-in and release use separate springs (`releaseResponse`,
  `releaseDamping`); press, release and morph springs, press stretch and
  glow radius are refitted to lossless SwiftUI recordings.
* Shader fidelity: every reference scene is at SSIM ≥ 0.95 against SwiftUI
  (minimum 0.9532, median 0.983, median ΔE 1.09), with a per-variant tone
  curve, anisotropic frost, a wide frost tail and a refitted clear lens.
* Example: an Android host, a dark theme for the gallery, and motion-scene
  harness entries (`-motion`, `-dump`); harness entries default to the
  shader unless `-mode native` is passed.

## 0.1.0-dev.1

* First development release: `LiquidGlass`, `GlassGroup`, `Glass`,
  `GlassShape`, `LiquidGlassTheme`, `GlassBackdropSource` and
  `GlassForeground`; shader glass fitted to SwiftUI on iOS, Apple's native
  glass on iOS 26+ (opt-in), Material 3 on Android.
