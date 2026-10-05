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

## 0.0.1

* TODO: Describe initial release.
