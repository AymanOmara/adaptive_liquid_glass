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
