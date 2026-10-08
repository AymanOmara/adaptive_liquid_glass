# Message for Gemini (round 4): what we measured after your round-3 terms

## Context (same project)

Flutter package `adaptive_liquid_glass`: iOS 26 Liquid Glass (`.glassEffect`) reproduced
with one fragment shader (Impeller, GLSL ES). Fidelity measured scene by scene against real
SwiftUI on an iPhone 17 Pro simulator (iOS 26.4): same backdrop, same shape, both at @3x,
scored on the glass region inflated by 12 pt. Pass bar: SSIM >= 0.97 and mean CIEDE2000 <= 2.0.
75 scenes = {regular, clear, tinted} x {capsule, circle, rect r16, rect r28, merge-gap}
x {white, gradient, photo, text} x {light, dark} (subset). A NumPy port of the shader
(`glass_model.py`) reproduces device captures to SSIM >= 0.9955 / dE <= 0.32, so we fit on
the model and confirm on the device; device matches prediction to ~0.0003 SSIM / 0.05 dE.

Pipeline per pixel: blurred backdrop (Gaussian, sigma per shape class) sampled through an
edge-band lens (exponential displacement profile, measured to 0.1-0.4 pt), post-lens blur
along the displacement with a Jacobian clamp, fill = constant RGB + opacity, saturation gain,
9-knot tone LUT (+ a second LUT for shapes <= 32 pt half size), size-dependent fill drop and
tone lift, rim, specular highlight, drop shadow; premultiplied srcOver on the sharp backdrop.
Everything in encoded sRGB.

## Your round-3 proposals, measured (predicted-device scoring, confirmed on device)

| term | result |
|---|---|
| 1 linear light (fill/sat/dim/tint in linear) | at shipped constants 4-5/27 light scenes pass (was 22/27); a full linear refit of all fill/tone keys did not finish in a 2 h box. Untried in full. |
| 2 compressive vibrancy gain 1/(1+k\|C\|) | neutral: 0 gains / 0 losses at k 1-3 (light); dark loses 2 rect gradient scenes at shipped saturation. |
| 3 luma-keyed tone LUT | **shipped**, mix 0.6 with the grey ramp: +1 scene (regular-capsule-photo-light 0.9714 / 1.49). Now 59/75. |
| 4 gated ambient x (1 - tint) x K_family | refuted: the device wants the 0.18 ambient on tinted rects too; gating loses 4 tinted scenes. Rect photo dE does not respond to ambient alone (2.74 -> 2.75-2.92). |
| 5 merged size from R_eff = sqrt(A_union/pi) | refuted: all three merge scenes prefer per-shape size rules (dE 1.3-1.5 -> 2.1-2.3). |
| 6 clear dual-sample edge (sigma_edge, k_sharp) | in the model every text scene lost 0.007-0.009 SSIM at k 0.55 / sigma 1.3; the descent drifts to k 0.02 / sigma 4 (interior sharpening, no gain). The shader has no sharp-backdrop texture anyway. |

Current: **59/75**, median SSIM 0.983, median dE 1.19, min SSIM 0.9525.

## The 16 remaining failures

| scene | SSIM | dE | note |
|---|---|---|---|
| regular rect16 / rect28 photo light | 0.977 / 0.978 | 2.66 / 2.59 | colour only; the error is a broad interior offset over the photo's dark regions (Lab: dL -2.1, da -1.3), absent on gradient/text backdrops |
| regular rect16 / rect28 photo dark | 0.969 / 0.970 | 3.4-3.5 | same, dL -1.9 and 1.28x L contrast |
| regular capsule photo dark | 0.9525 | 1.99 | small dark shape ~1.15x too contrasty inside; tone lift recovered most of it |
| tinted capsule photo light / gradient light | 0.976 / 0.980 | 2.34 / 2.23 | inherits the small-shape residual under tint |
| clear rect28 photo light / dark | 0.970 / 0.969 | 2.04 / 1.81 | borderline both |
| clear capsule / rect16 / rect28 text light+dark (6) | 0.958-0.964 | 0.6-0.7 | SSIM only: edge band over sharp black text. SwiftUI's blur stays 1.1-1.4 pt through the band; ours is 2.0-2.2 pt at 1-4 pt depth even after the Jacobian clamp. SSIM on text lines behaves like a phase match, so descents stall. |

Key facts we now believe:

- Saturation and tone knots move the small shapes and the large rects together; every term
  that fixes rect-photo dE breaks tinted/merge or capsule scenes. The regular rect photo
  residual is **in the dark regions of the photo only** (dL -2 with 1.28x L contrast in dark).
- Our tone LUT is a 1-D map on luma (now luma-keyed). The rect residual looks like a
  **2-D response: luma x chroma** (dark saturated regions of the photo come through lighter
  and less saturated in SwiftUI than our map gives), while bright regions already match.
- The 0.15 code floor of our tone measurement (grey ramps 0.15-0.85) means the darkest end
  of SwiftUI's tone curve is unmeasured; the text scenes and the dark-region rect residual
  may share that cause.

## Questions (concrete equations please; inputs: blurred backdrop RGB, sharp backdrop RGB,
SDF distance, half size, family, tint RGB + strength)

1. **Dark-region lift.** Propose a term that lifts and desaturates only dark, chromatic
   backdrop regions under regular glass (e.g. a soft-knee black lift keyed on min(R,G,B) or
   OKLab L with a chroma factor), with 2-3 parameters we can fit, and that is naturally
   near-zero on gradient/text/white backdrops. Would you model it as a per-channel
   `max`-style lift (Apple's "vibrancy" is known to be luminosity-sensitive) or as a 2-D LUT
   on (L, C)?
2. **Measuring the tone curve below 0.15.** We capture grey ramps under real SwiftUI glass.
   Design a probe scene that measures the response for codes 0.00-0.15 and for saturated
   dark colours (e.g. a 2-D chip grid of OKLab L x C at fixed hue), so we can fit the term
   from direct measurements instead of photo scenes. How many chips, what size (our
   shapes are 30-120 pt), and how to keep the lens/rim out of the measurement?
3. **Small-shape contrast (capsule photo dark).** The dark capsule keeps 1.15x too much
   interior contrast after the tone lift. Is this a blur-radius effect (SwiftUI blurs small
   shapes more in dark mode) or a contrast compression? Give a test to separate the two
   (we can capture any scene) and the term for each outcome.
4. **Clear text edge.** Given there is no sharp backdrop texture in the shader, the only
   levers are the blur sigma field and the lens. SwiftUI's sigma stays 1.1-1.4 pt through
   the band while ours rises with depth. Would you (a) make sigma a function of SDF depth
   (sigma(d) = sigma_c - (sigma_c - sigma_e) * exp(-d/tau)), (b) pre-blur with a smaller
   sigma and add the extra interior blur as a second pass inside only, or (c) accept the
   mirrored-content phase mismatch and change nothing? If (a) or (b), the equation and the
   fitting order.
5. **Fit strategy.** Given the coupling (one saturation/tone set serves small and large
   shapes and tinted), would you split the regular family into size classes with their own
   fill/saturation/tone (we already have a second LUT for <= 32 pt) or add a continuous
   size key (mix by half size) to saturation and the tone knots? Which parameterisation
   fits better with 75 scenes and ~50 keys, and what regulariser avoids overfitting?

Answer each with: the equation, the parameters and their expected range, and the single
scene you'd use to validate it first.
