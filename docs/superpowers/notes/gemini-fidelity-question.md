# Message for Gemini: how to raise our iOS 26 Liquid Glass match

## Context

I maintain a Flutter package (`adaptive_liquid_glass`) that reproduces Apple's
iOS 26 Liquid Glass (`.glassEffect`) with a fragment shader (Impeller / Flutter
GPU, GLSL ES). We measure fidelity scene by scene against real SwiftUI on an
iPhone 17 Pro simulator (iOS 26.4): same background asset, same shape, both
screenshotted at @3x, then scored on the glass region inflated by 12 pt.

Pass bar per scene: SSIM >= 0.97 and mean CIEDE2000 <= 2.0.
Matrix: 75 scenes = {regular, clear, tinted} x {capsule, circle, rect r16,
rect r28, merge-gap} x {white, gradient, photo, text} x {light, dark} (subset).
Current state: **58 / 75 pass**, median SSIM 0.983, median dE 1.12.

## What the shader does today (one pass, per pixel)

1. Backdrop already blurred by `ImageFilter.blur` (sigma per shape class,
   scaled by shape size) is sampled through a **lens**: an edge-band
   displacement toward the shape interior (decay, band width, strength, and a
   size reference; measured from SwiftUI with a dot-grid scene, matches to
   0.1-0.4 pt).
2. A **post-lens blur** along the displacement (share, sigma), with the sample
   stretch clamped (Jacobian clamp, per family).
3. **Fill**: constant RGB + opacity, saturation boost, then a **tone LUT**
   (9 grey knots, one per family, plus a second LUT for shapes <= 32 pt half
   size), a size-dependent fill drop and tone lift.
4. **Rim** (width, intensity, back-strength, hue shift, luma floor), a
   **specular highlight** keyed on a global light angle, a drop shadow, glow
   on touch.
5. `Tinted` = regular + tint RGB mixed by strength. `Clear` = own constant
   set A-P. Merged shapes: SDF smooth-union with a lens blend across the neck.
6. Composite premultiplied srcOver onto the sharp backdrop inside the clip.

Every uniform is fitted offline: a NumPy port of the shader
(`glass_model.py`) reproduces device captures to SSIM >= 0.9955 / dE <= 0.32
on all 75 scenes, so we fit on the model (least squares + coordinate descent
scored on predicted device passes) and confirm on the device.

## The 17 failing scenes and what blocks them

| family / scene | SSIM | dE | blocker |
|---|---|---|---|
| regular rect16/28 photo light | 0.977 / 0.978 | 2.74 / 2.67 | colour, not structure |
| regular rect16/28 photo dark | 0.969 / 0.970 | 3.47 / 3.38 | colour |
| regular capsule photo light / dark | 0.969 / 0.952 | 1.53 / 1.99 | SSIM just short |
| tinted capsule photo light / dark, gradient light | 0.976 / 0.962 / 0.980 | 2.37 / 1.50 / 2.27 | inherits the small-shape residual under tint |
| clear rect28 photo light / dark | 0.970 / 0.969 | 2.04 / 1.81 | both borderline |
| clear capsule / rect16 / rect28 **text** light+dark (6) | 0.958-0.964 | 0.6-0.7 | SSIM only: the edge band over sharp text |

Observations from the diff images and fits:

- On photo backdrops the regular rect fill has a **colour error that depends
  on the backdrop**: brighter / more saturated regions of the photo come
  through with a different hue shift than the fitted constant fill + global
  saturation can express. A global chroma term we tried (mix in a wide-radius
  backdrop average, `ambientMix x (avg - luma(avg))`, reach 40-60 pt) lowers
  the mean dE from 1.26 to 1.20 but **fixes the rect photo scenes only by
  breaking the tinted and merge-gap photo scenes** (a frontier, 0 net gain).
- Merged circles: SwiftUI treats the merged blob as one large shape (its fill
  and contrast follow the union's size); we apply per-shape size rules.
- Clear glass over **text**: our lens displacement matches, but the edge band
  stays blurrier (SwiftUI 1.1-1.4 pt vs ours ~2 pt after clamping); SSIM
  0.96 and we can't find a parameter that sharpens it without breaking the
  photo scenes.
- Everything is fitted in encoded sRGB at pixel centres; the backdrop blur is
  Gaussian (Impeller's kernel).

## Questions

1. **Compositing model.** Do you know (or can you infer from Apple's public
   material, WWDC25 sessions, UIKit `UIGlassEffect` / `UIVisualEffectView`
   behaviour, or Core Image filter graphs) how Liquid Glass composes colour?
   Specifically: is the fill a `plusLighter` / overlay-style vibrancy blend of
   a luminance-mapped backdrop rather than srcOver of a constant fill? Is any
   stage done in linear or extended-range colour rather than encoded sRGB? Is
   there a per-pixel saturation that depends on backdrop chroma (e.g. a
   "vibrancy" that boosts low-chroma and clamps high-chroma)?
2. **Backdrop-dependent term.** Given the frontier above, what term would you
   add so a plain large rect over a photo can pick up backdrop colour while a
   tinted or merged shape does not? Candidates we considered: chroma-dependent
   desaturation (OKLab), a two-radius ambient (local vs wide), a per-family
   ambient gain, and a luminance-keyed tone LUT where the key is the blurred
   backdrop's local luma instead of a fixed grey ramp.
3. **Merged shapes.** Would you compute the size-dependent terms from the
   union's bounds (or its SDF-derived area) rather than per shape, and is
   there evidence Apple does it that way?
4. **Clear edge over text.** How would you get a sharper edge band at the
   lens without a sharper interior: a separate, smaller sigma inside the
   band, a mip bias, or sampling the un-blurred backdrop in the band and
   blending by band weight?
5. **Metric sanity.** For a ~12 pt-inflated crop, is SSIM >= 0.97 plus
   CIEDE2000 <= 2.0 a reasonable bar, or would a FLIP / Delta-E-2000 on a
   perceptually blurred image be a fairer judge of "indistinguishable"?

If you can propose a concrete equation per answer (inputs available: blurred
backdrop RGB, sharp backdrop RGB, SDF distance to edge, shape half-size,
family, tint RGB + strength, light angle), I can port it into the NumPy
model, fit it, and check it on the device the same day.
