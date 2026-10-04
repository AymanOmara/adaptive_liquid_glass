# Fidelity status (Task 17c, shipped constants)

Run: `build/fidelity/final` — shipped build, no `-constants`, reference
simulator (iPhone 17 Pro, iOS 26.4). SwiftUI images are `baseline-v2`
(independent of our constants).

**42/75 pass. Median SSIM 0.981, median ΔE 1.56** (mean 0.9655 / 1.71).
Before Task 17c: 41/75, 0.981, 1.50; before 17b: 20/75, 0.948, 2.80.

Task 17c added the **frost wide tail** (`frostWide*` constants, measured with
five code periods by `tool/fidelity/measure_frost.py`, fitted by
`tool/fidelity/fit_frost.py`): SwiftUI's frost is a sharp core plus a wide
component, `(1 − w)·G(core) + w·G(core ⊕ wide)`, with the weight `w`
increasing with the sampled point's depth and a size term. The tail lifted
clear-family SSIM by 0.006–0.013 on device and gained
`regular-capsule-text-light`; no scene regressed a bar.

| family | pass | median SSIM | median ΔE |
|---|---|---|---|
| regular light | 6/12 | 0.988 | 1.65 |
| regular dark | 7/12 | 0.978 | 1.59 |
| clear light | 4/12 | 0.937 | 1.98 |
| clear dark | 4/12 | 0.941 | 2.00 |
| tinted light | 10/12 | 0.986 | 1.55 |
| tinted dark | 10/12 | 0.979 | 1.10 |
| merge | 1/3 | 0.979 | 2.01 |

## Scenes below the bars (SSIM ≥ 0.97, ΔE ≤ 2.0)

Diagnosis from the diff images and per-region ΔE (interior = deeper than
18 pt, band = outer 18 pt, outside = the 12 pt margin).

| scene | SSIM | ΔE | diagnosis |
|---|---|---|---|
| regular-capsule-photo-light | 0.9687 | 2.30 | interior still 1.3x too contrasty: the wide tail helped but SwiftUI's sharp-core + wide-tail kernel varies more with depth than one composed blur + one weight can express. |
| regular-capsule-photo-dark | 0.8980 | 4.51 | dark capsule ~20 levels too dark inside and 1.26x too contrasty: the dark small-shape fill (fillSizeDrop at its 0.8 bound) still cannot lift it. |
| regular-rect16-photo-light | 0.9762 | 2.70 | edge band dominates (ΔE 4-6 in the outer 18 pt) plus interior 6-8 levels too dark; residual rim/shadow ring (outside ΔE 1.5). |
| regular-rect16-photo-dark | 0.9622 | 3.93 | edge band dominates (ΔE 4-6 in the outer 18 pt) plus interior 6-8 levels too dark; residual rim/shadow ring (outside ΔE 1.5). |
| regular-rect28-photo-light | 0.9753 | 2.64 | as rect16. |
| regular-rect28-photo-dark | 0.9618 | 3.84 | as rect16. |
| regular-capsule-text-dark | 0.9699 | 1.50 | SSIM just under 0.97: text visible inside at 1.8-3.6x SwiftUI's contrast (SwiftUI's capsule text is fainter); ΔE passes. |
| regular-capsule-gradient-light | 0.9897 | 2.15 | red 10 levels high inside (opposite sign to rects): size-dependent colour response the single fill factor cannot express. |
| regular-capsule-gradient-dark | 0.9463 | 4.95 | dark capsule ~20 levels too dark inside and 1.26x too contrasty. |
| regular-rect16-gradient-light | 0.9947 | 2.11 | red channel 12 levels low inside: saturation/vibrancy is not a single luma-preserving gain (fit at 1.74); shadow ring outside ΔE 1.0. |
| regular-rect28-gradient-light | 0.9920 | 2.11 | as rect16 gradient. |
| tinted-capsule-photo-light | 0.9758 | 2.50 | inherits the regular capsule residual (small-shape fill/contrast) under the tint; tint mix itself fits (strength 1.02). |
| tinted-capsule-photo-dark | 0.9450 | 2.38 | as above, dark. |
| tinted-capsule-gradient-light | 0.9807 | 2.31 | as above, light. |
| tinted-capsule-gradient-dark | 0.9734 | 2.59 | as above, dark. |
| clear-capsule-photo-light | 0.9443 | 2.57 | edge band ΔE 4-5 (mirrored band slightly misplaced, rim not decoded); interior colour within 3 levels. |
| clear-capsule-photo-dark | 0.9514 | 2.26 | as above, dark. |
| clear-circle-photo-light | 0.9616 | 1.94 | as capsule; ΔE now passes, SSIM 0.01 short. |
| clear-circle-photo-dark | 0.9569 | 1.93 | as above, dark. |
| clear-rect16-photo-light | 0.9289 | 3.65 | edge band ΔE 6-7: continuous-corner lens field differs from our circular-arc SDF; interior 8 levels bright. |
| clear-rect16-photo-dark | 0.9298 | 3.51 | as above, dark. |
| clear-rect28-photo-light | 0.9179 | 3.89 | as rect16. |
| clear-rect28-photo-dark | 0.9190 | 3.77 | as rect16. |
| clear-capsule-text-light | 0.9025 | 2.09 | interior 10-12 levels darker with 1.2-1.3x contrast: SwiftUI lifts the black text strokes (tone curve below the 0.15 code floor, unmeasured) and its blur is weaker near the edge (σ 1.0-1.3 pt) than at the centre (1.7). The wide tail recovered half the SSIM gap; the tone curve is the rest. |
| clear-capsule-text-dark | 0.9017 | 2.07 | as above, dark. |
| clear-circle-text-light | 0.9169 | 1.46 | as capsule text; ΔE passes. |
| clear-circle-text-dark | 0.9154 | 1.51 | as above, dark. |
| clear-rect16-text-light | 0.8610 | 2.02 | as capsule text. |
| clear-rect16-text-dark | 0.8617 | 2.10 | as above, dark. |
| clear-rect28-text-light | 0.8490 | 2.09 | as capsule text. |
| clear-rect28-text-dark | 0.8497 | 2.17 | as above, dark. |
| merge-gap4-photo-light | 0.9652 | 2.01 | interior 10-14 levels too bright and 1.3x contrast: merged 30 pt circles get the small-shape fill drop per shape; SwiftUI treats the merged blob as one larger shape. |
| merge-gap16-photo-light | 0.9786 | 2.09 | as gap4. |

## Fitting decisions (Task 17c)

- **The shipped values keep the Task 17b core blur and add only the wide
  tail.** `fit_frost.py` also refits the core sigma/size ref against the
  measured transfer curves; adopting that core regressed full-scene model
  parity (40/75 vs 41/75) because the 17b core was fitted jointly with fill
  and rim on full scenes. A full-scene polish of the five `frostWide*` keys
  (`build/fidelity/fit17c/polish/`) then pushed the regular sets' tail
  toward off (lower mean loss) but gave up the pass the tail buys
  (41/75 vs 42/75); the polish outcome was rejected — the bars are
  pass-count based.
- `fit_frost.py` in the repo reproduces the fitted tail from
  `measure_frost.py`'s output (its own optimum is slightly tighter than the
  shipped run's: rms 1.58 vs 1.73 code levels).

## Known residuals (measured)

- **Frost kernel varies with depth and size beyond one weight.** The sharp
  core + wide tail captures most of SwiftUI's non-Gaussian frost; what
  remains is spatial variation (edge σ 1.0-1.3 pt vs centre 1.7 in clear
  glass) and a depth-dependent core/tail split.
- **Clear tone curve below the 0.15 code floor.** SwiftUI lifts black text
  strokes inside clear glass; our codes span 0.15-0.85 so the low end is
  unmeasured (Task 17d's grey ramp addresses this).
- **Size-dependent appearance is more than fill opacity.** Small shapes keep
  more contrast and a darker wash (light) / lighter wash (dark); the dark
  capsule still sits ~20 levels too dark.
- **Rect corners**: continuous corners vs circular arcs in the lens depth
  field (clear rect band ΔE 6-7).
