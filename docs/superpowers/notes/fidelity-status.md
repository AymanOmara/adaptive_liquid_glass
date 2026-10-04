# Fidelity status (Task 17b, shipped constants)

Run: `build/fidelity/final` — shipped build, no `-constants`, reference simulator (iPhone 17 Pro, iOS 26.4). SwiftUI images are `baseline-v2` (independent of our constants).

**41/75 pass. Median SSIM 0.981, median ΔE 1.50** (mean 0.964 / 1.69). Before Task 17b: 20/75, 0.948, 2.80.

| family | pass | median SSIM | median ΔE |
|---|---|---|---|
| regular light | 5/12 | 0.988 | 1.63 |
| regular dark | 7/12 | 0.978 | 1.54 |
| clear light | 4/12 | 0.932 | 1.92 |
| clear dark | 4/12 | 0.936 | 1.91 |
| tinted light | 10/12 | 0.986 | 1.53 |
| tinted dark | 10/12 | 0.979 | 1.10 |
| merge | 1/3 | 0.978 | 2.03 |

## Scenes below the bars (SSIM ≥ 0.97, ΔE ≤ 2.0)

Diagnosis from the diff images and per-region ΔE (interior = deeper than 18 pt, band = outer 18 pt, outside = the 12 pt margin).

| scene | SSIM | ΔE | diagnosis |
|---|---|---|---|
| regular-capsule-photo-light | 0.9672 | 2.38 | interior 1.3x too contrasty and band error 3.4: SwiftUI frost keeps thin bars visible at low contrast (sharp core + wide tail) where our Gaussian blurs them out or keeps them too strong. |
| regular-capsule-photo-dark | 0.8979 | 4.51 | dark capsule ~20 levels too dark inside and 1.26x too contrasty: the dark small-shape fill (fillSizeDrop at its 0.8 bound) still cannot lift it; SwiftUI keeps thin bars sharp at low contrast (non-Gaussian frost). |
| regular-rect16-photo-light | 0.9764 | 2.75 | edge band dominates (ΔE 4-6 in the outer 18 pt) plus interior 6-8 levels too dark; residual non-Gaussian frost and rim/shadow ring (outside ΔE 1.5). |
| regular-rect16-photo-dark | 0.9615 | 3.85 | edge band dominates (ΔE 4-6 in the outer 18 pt) plus interior 6-8 levels too dark; residual non-Gaussian frost and rim/shadow ring (outside ΔE 1.5). |
| regular-rect28-photo-light | 0.9756 | 2.70 | edge band dominates (ΔE 4-6 in the outer 18 pt) plus interior 6-8 levels too dark; residual non-Gaussian frost and rim/shadow ring (outside ΔE 1.5). |
| regular-rect28-photo-dark | 0.9612 | 3.77 | edge band dominates (ΔE 4-6 in the outer 18 pt) plus interior 6-8 levels too dark; residual non-Gaussian frost and rim/shadow ring (outside ΔE 1.5). |
| clear-capsule-photo-light | 0.9371 | 2.58 | edge band ΔE 4-5 (mirrored band slightly misplaced, rim not decoded); interior colour within 3 levels. |
| clear-capsule-photo-dark | 0.9441 | 2.31 | edge band ΔE 4-5 (mirrored band slightly misplaced, rim not decoded); interior colour within 3 levels. |
| clear-circle-photo-light | 0.9601 | 1.86 | edge band ΔE 4-5 (mirrored band slightly misplaced, rim not decoded); interior colour within 3 levels. |
| clear-circle-photo-dark | 0.9552 | 1.86 | edge band ΔE 4-5 (mirrored band slightly misplaced, rim not decoded); interior colour within 3 levels. |
| clear-rect16-photo-light | 0.9273 | 3.59 | edge band ΔE 6-7: continuous-corner lens field differs from our circular-arc SDF; interior 8 levels bright. |
| clear-rect16-photo-dark | 0.9280 | 3.45 | edge band ΔE 6-7: continuous-corner lens field differs from our circular-arc SDF; interior 8 levels bright. |
| clear-rect28-photo-light | 0.9164 | 3.84 | edge band ΔE 6-7: continuous-corner lens field differs from our circular-arc SDF; interior 8 levels bright. |
| clear-rect28-photo-dark | 0.9172 | 3.71 | edge band ΔE 6-7: continuous-corner lens field differs from our circular-arc SDF; interior 8 levels bright. |
| tinted-capsule-photo-light | 0.9756 | 2.51 | inherits the regular capsule residual (small-shape fill/contrast) under the tint; tint mix itself fits (strength 1.02). |
| tinted-capsule-photo-dark | 0.9449 | 2.39 | inherits the regular capsule residual (small-shape fill/contrast) under the tint; tint mix itself fits (strength 1.02). |
| regular-capsule-text-light | 0.9695 | 1.15 | SSIM just under 0.97: text visible inside at 1.8-3.6x SwiftUI's contrast (SwiftUI's capsule text is fainter); ΔE passes. |
| regular-capsule-text-dark | 0.9696 | 1.49 | SSIM just under 0.97: text visible inside at 1.8-3.6x SwiftUI's contrast (SwiftUI's capsule text is fainter); ΔE passes. |
| clear-capsule-text-light | 0.8904 | 1.97 | interior 10-12 levels darker with 1.2-1.3x contrast: SwiftUI lifts the black text strokes (tone curve below the 0.15 code floor, unmeasured) and its blur is weaker near the edge (σ 1.0-1.3 pt) than at the centre (1.7). |
| clear-capsule-text-dark | 0.8888 | 1.95 | interior 10-12 levels darker with 1.2-1.3x contrast: SwiftUI lifts the black text strokes (tone curve below the 0.15 code floor, unmeasured) and its blur is weaker near the edge (σ 1.0-1.3 pt) than at the centre (1.7). |
| clear-circle-text-light | 0.9111 | 1.33 | interior 10-12 levels darker with 1.2-1.3x contrast: SwiftUI lifts the black text strokes (tone curve below the 0.15 code floor, unmeasured) and its blur is weaker near the edge (σ 1.0-1.3 pt) than at the centre (1.7). |
| clear-circle-text-dark | 0.9091 | 1.38 | interior 10-12 levels darker with 1.2-1.3x contrast: SwiftUI lifts the black text strokes (tone curve below the 0.15 code floor, unmeasured) and its blur is weaker near the edge (σ 1.0-1.3 pt) than at the centre (1.7). |
| clear-rect16-text-light | 0.8551 | 2.04 | interior 10-12 levels darker with 1.2-1.3x contrast: SwiftUI lifts the black text strokes (tone curve below the 0.15 code floor, unmeasured) and its blur is weaker near the edge (σ 1.0-1.3 pt) than at the centre (1.7). |
| clear-rect16-text-dark | 0.8552 | 2.09 | interior 10-12 levels darker with 1.2-1.3x contrast: SwiftUI lifts the black text strokes (tone curve below the 0.15 code floor, unmeasured) and its blur is weaker near the edge (σ 1.0-1.3 pt) than at the centre (1.7). |
| clear-rect28-text-light | 0.8430 | 2.11 | interior 10-12 levels darker with 1.2-1.3x contrast: SwiftUI lifts the black text strokes (tone curve below the 0.15 code floor, unmeasured) and its blur is weaker near the edge (σ 1.0-1.3 pt) than at the centre (1.7). |
| clear-rect28-text-dark | 0.8432 | 2.17 | interior 10-12 levels darker with 1.2-1.3x contrast: SwiftUI lifts the black text strokes (tone curve below the 0.15 code floor, unmeasured) and its blur is weaker near the edge (σ 1.0-1.3 pt) than at the centre (1.7). |
| regular-capsule-gradient-light | 0.9896 | 2.16 | red 10 levels high inside (opposite sign to rects): size-dependent colour response the single fill factor cannot express. |
| regular-capsule-gradient-dark | 0.9463 | 4.95 | dark capsule ~20 levels too dark inside and 1.26x too contrasty: the dark small-shape fill (fillSizeDrop at its 0.8 bound) still cannot lift it; SwiftUI keeps thin bars sharp at low contrast (non-Gaussian frost). |
| regular-rect16-gradient-light | 0.9947 | 2.12 | red channel 12 levels low inside: saturation/vibrancy is not a single luma-preserving gain (fit at 1.74); shadow ring outside ΔE 1.0. |
| regular-rect28-gradient-light | 0.9920 | 2.12 | red channel 12 levels low inside: saturation/vibrancy is not a single luma-preserving gain (fit at 1.74); shadow ring outside ΔE 1.0. |
| tinted-capsule-gradient-light | 0.9807 | 2.31 | inherits the regular capsule residual (small-shape fill/contrast) under the tint; tint mix itself fits (strength 1.02). |
| tinted-capsule-gradient-dark | 0.9734 | 2.59 | inherits the regular capsule residual (small-shape fill/contrast) under the tint; tint mix itself fits (strength 1.02). |
| merge-gap4-photo-light | 0.9642 | 2.03 | interior 10-14 levels too bright and 1.3x contrast: merged 30 pt circles get the small-shape fill drop per shape; SwiftUI treats the merged blob as one larger shape. |
| merge-gap16-photo-light | 0.9779 | 2.05 | interior 10-14 levels too bright and 1.3x contrast: merged 30 pt circles get the small-shape fill drop per shape; SwiftUI treats the merged blob as one larger shape. |

## Known residuals (measured)

- **Frost is not a Gaussian.** SwiftUI keeps thin high-contrast lines faintly visible through regular glass (bars in photo scenes) while still frosting at σ≈6–7 pt; the two-period amplitude ratio reads weaker blur near the edge than at the centre. One composed Gaussian per group cannot reproduce a sharp-core + wide-tail kernel or spatial variation.
- **Size-dependent appearance is more than fill opacity.** Small shapes keep more contrast (0.30 vs 0.25) and a darker wash (light) / lighter wash (dark); `fillSizeDrop` captures part; the dark capsule still sits ~20 levels too dark.
- **Clear text**: SwiftUI lifts black strokes inside clear glass; our codes span 0.15–0.85 so the low end of the tone curve is unmeasured.
- **Rect corners**: continuous corners vs circular arcs in the lens depth field (clear rect band ΔE 6–7).
