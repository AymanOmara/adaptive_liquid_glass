# Backdrop shader texture-space probe

- Date: 2026-10-04
- Flutter: `Flutter 3.47.6 • channel stable • https://github.com/flutter/flutter.git`
- Runtime: iOS 26.4 simulator, iPhone 17 Pro (`E7A87B4A-3E48-44F8-A588-704D56774FF0`), Impeller (Metal), Xcode 27
- Test: `example/integration_test/probe_test.dart` with `example/shaders/probe.frag`

## Output

```
PROBE screenPx=1206x2622 dpr=3.0 center rgb=[0.6235294117647059, 0.4, 0.29411764705882354] uSize.x≈1204.7058823529412
PROBE result: global
```

Sample at logical (250, 350) = physical (750, 1050):

- R = 159/255 = 0.6235; global prediction 750/1206 = 0.6219 (local would be 0.5)
- G = 102/255 = 0.4000; global prediction 1050/2622 = 0.4005
- B ⇒ uSize.x ≈ 1205 (quantised to 8 bits); screen width 1206 (local would be 300)

## Conclusion

- Inside `BackdropFilter(ImageFilter.shader)` under a `ClipRect`,
  `FlutterFragCoord()` is in **screen physical px** and `uSize` is the
  **screen size**: `kGlassTextureSpace = GlassTextureSpace.global`.
- `uniform vec4` arrays compile under impellerc and index correctly
  (`uArr[2].x` read back as 0.25 → B channel non-zero).

## Second case: inside an `Opacity` saveLayer (fix round 1)

Same 100×100 `ClipRect` + `BackdropFilter` at global (200, 300). Its parent
is a `Positioned` at left 150, top 250, 200×200, wrapping
`Opacity(opacity: 0.99)`, so the offscreen layer does not start at the
screen origin. Readback is unchanged: a full-screen `RepaintBoundary` at
the origin.

```
PROBE saveLayer screenPx=1206x2622 dpr=3.0 center rgb=[0.6236878589819767, 0.40186175480293124, 0.29490988314517724] uSize.x≈1207.950881362646
PROBE saveLayer result: global
```

The values are corrected for the opacity over white: c = (c′ − 0.01)/0.99.
Raw bytes at (250,350) were 160,104,77. At physical (750, 1050):

| hypothesis | R expected | G expected | uSize.x expected |
|---|---|---|---|
| screen-global (origin 0,0, 1206×2622) | 0.6219 | 0.4005 | 1206 |
| layer-relative (origin 450,750 px, 600×600) | 0.5 | 0.5 | 600 |
| filter-local (origin 600,900 px, 300×300) | 0.5 | 0.5 | 300 |
| **measured** | **0.6237** | **0.4019** | **≈1208** |

`FlutterFragCoord()` and `uSize` stay **screen-global** inside the
saveLayer. They are not relative to the layer. The test asserts this, so a
future engine change that makes them layer-relative will fail it.

Not measured: `ShaderMask`, `ColorFiltered`, and route `FadeTransition`.
They use the same saveLayer mechanism as `Opacity`, so the same result is
expected, but it is unverified.

## Readback rule for later tests

Pixel readbacks must use a `RepaintBoundary` that covers the full screen
at the origin, and `toImage(pixelRatio: dpr)`. "Global" means relative to
the root render target. A boundary that does not start at the origin
becomes its own root target when rasterised, which would shift the
coordinates the shader sees.

## Readback method (and why not `takeScreenshot`)

The first run used `binding.takeScreenshot` as the brief's test did. It printed:

```
PROBE screenPx=1206x2622 dpr=3.0 center rgb=[0.00784313725490196, 0.00784313725490196, 0.00784313725490196] uSize.x≈32.12549019607843
PROBE result: UNKNOWN
```

When saved, that PNG showed the flutter_test "Test starting..." placeholder,
not the test widget. It was a stale frame from the iOS plugin's
`drawViewHierarchyInRect:afterScreenUpdates:`, encoded as 16-bit RGBA
Display-P3. Its decoded values were also unusable for exact comparisons.

The test now reads pixels with `RepaintBoundary.toImage(pixelRatio: dpr)`
on a boundary at the screen origin, covering the full screen. Cross-check:
the probe frame was held on screen while the host ran
`xcrun simctl io <udid> screenshot`. That 8-bit sRGB capture matched the
`toImage` readback byte for byte at every sampled point:

| logical point | toImage RGB | simctl RGB |
|---|---|---|
| (10, 10) | 255,255,255 | 255,255,255 |
| (200, 300) | 127,88,75 | 127,88,75 |
| (250, 350) | 159,102,75 | 159,102,75 |
| (299, 399) | 190,116,75 | 190,116,75 |
| (195, 350) | 255,255,255 | 255,255,255 |

So the global mapping holds on screen too, not only for offscreen rendering.

## Side finding

impellerc reports `liquid_glass.frag` as incompatible with SkSL, because of
dynamic uniform-array indexing (`index expression must be constant`). It is a
warning: the shader will not load under the Skia backend. `ImageFilter.shader`
needs Impeller anyway.

## Third case: shader under a composed blur (shader model v2, 2026-10-04)

Shader model v2 (spec §15) frosts with
`ImageFilter.compose(outer: ImageFilter.shader(s), inner: ImageFilter.blur(σ, tileMode: clamp))`.
`probe.frag` gained two modes for this: an exact readout (`uArr[3].y` = 1..4
writes `FlutterFragCoord.x`, `.y`, `uSize.x`, `uSize.y` as low byte, high
byte, fraction, so there is no 8-bit quantisation) and a pass-through
(`uArr[3].x` = 1 returns `texture(uTexture, px / uSize)`).

Exact readout at the clip's top-left and bottom-right pixels:

```
PROBE composed sigma=8.0  box=(200,300,300,400) fragX=[600.5, 899.5]  fragY=[900.5, 1199.5]  uSize=(1247, 2663) screen=1206x2622
PROBE composed sigma=8.0  box=(40,600,340,660)  fragX=[120.5, 1019.5] fragY=[1800.5, 1979.5] uSize=(1247, 2663)
PROBE composed sigma=20.0 box=(200,300,300,400) fragX=[600.5, 899.5]  fragY=[900.5, 1199.5]  uSize=(1303, 2719)
PROBE composed sigma=20.0 box=(40,600,340,660)  fragX=[120.5, 1019.5] fragY=[1800.5, 1979.5] uSize=(1303, 2719)
```

(Without the blur, the same readout gives `uSize = (1206, 2622)`.)

- `FlutterFragCoord()` stays **screen-global physical px** (pixel centres,
  independent of the clip position and of σ).
- `uSize` is **not** the screen size any more: it is the blurred input's
  size, the screen grown by 41 px (σ = 8) or 97 px (σ = 20) on each axis.
- The growth is on the **right and bottom only**: the texture origin stays
  at the screen origin. A pass-through of a hard black|white edge at logical
  x = 200 (and, separately, y = 350) comes back centred at 200.00 / 350.00
  (σ = 8) and 200.08 / 350.08 (σ = 20). A left/top pad of even 20 px would
  shift it by ≈ 7 logical px.

So `tex(px) = texture(uTexture, px / uSize)` samples the pixel under `px`,
and shape rects packed in screen-global texture space line up with
`FlutterFragCoord`. The glass shader uses `uSize` only inside `tex()`, so
the composition is safe. Nothing may treat `uSize` as the screen size.
`probe_test.dart` asserts all of this.

## Composed blur sigma unit

The `composed blur sigma unit` probe blurs a hard edge at logical x = 200
and measures the 15.87 % → 84.13 % rise (2σ) along a row:

| requested σ (logical) | blur only (logical) | composed (logical) | ratio |
|---|---|---|---|
| 2  | 1.82  | 1.82  | 0.91 |
| 8  | 7.34  | 7.23  | 0.90–0.92 |
| 12 | 10.34 | 10.30 | 0.86 |
| 20 | 16.84 | 16.84 | 0.84 |

The unit is **logical px**: under the root dpr transform the engine scales
σ by dpr (σ = 8 measured 21.7 physical px; a physical-px unit would have
measured ≈ 7.3 / 3). Composing the shader does not change it. The engine's
effective σ is 8–16 % below the requested value and the shortfall grows with
σ. That is Impeller's kernel approximation, not a unit error. The renderer
therefore passes `blurSigma` straight through (no dpr factor), and the fit
absorbs the shortfall.
