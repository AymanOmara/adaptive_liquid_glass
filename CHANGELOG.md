## Unreleased

* `Widget.glassEffect(glass:, shape:, id:, unionId:, padding:)`: one-line
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

## 0.1.0-dev.1

* First development release: `LiquidGlass`, `GlassGroup`, `Glass`,
  `GlassShape`, `LiquidGlassTheme`, `GlassBackdropSource` and
  `GlassForeground`; shader glass fitted to SwiftUI on iOS, Apple's native
  glass on iOS 26+ (opt-in), Material 3 on Android.
