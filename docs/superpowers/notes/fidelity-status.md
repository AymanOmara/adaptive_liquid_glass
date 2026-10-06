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

## Task 17d round 2 (shipped)

Run: `build/fidelity/final` refreshed after the refit (iPhone 17 Pro, iOS
26.4; SwiftUI side is `baseline-v2`). Full numbers:
`build/fidelity/fit17d/parity-r2.txt` (three-way per scene),
`score-analysis2.txt` (model vs SwiftUI), `parity-std.txt` (previous round).

**46/75 pass. Median SSIM 0.9828, median ΔE 1.15. Min SSIM 0.9452.**
Previous round: 42/75, 0.9811/1.61, min 0.8490, 18 scenes below 0.95
(device side). Round 2: **3 scenes below 0.95**.

What changed (fit stages under `build/fidelity/fit17d/`, assembled
`analysis2.json`):

- **regularDark** (`rd2`, Powell polish of 16 keys, loss 1.448 → 1.116):
  the small-shape **tone lift** engaged — `toneLift` 0.7827 with knee
  0.9995 and size ref 48 pt (small dark shapes get their darks lifted);
  core blur σ 11.45 → 8.25 pt with the wide tail taking over
  (`frostWideMixEdge` 0.40 → 1.08, `frostWideSizeDrop` 1.27 → 2.74);
  dim 0.0147 → 0.0010, fill colour a touch warmer.
- **clear / clearDark** (`c2`, 23-key refits, floor 0.962): tone knots
  freed from identity (dark-end lift inside clear glass), post-blur share
  ~0.29-0.30, lens edge 9-10.6 pt, rim-mix family engaged (rimMix 0.52-0.63,
  `rimIntensity` → 0), blur σ 1.40 → 1.15-1.28 pt with the wide tail
  widened (σ 3.75 → 1.8-1.9 pt, centre weight 0.20 → 0.76-0.78).
- **regular** untouched this round.

`regular` and `regularDark` gains: regular-capsule-photo-dark SSIM
0.8980 → 0.9476; regular-rect1x-photo-dark 0.96 → 0.963 with ΔE 3.9 → 3.6.

### Min-SSIM progress toward the 0.95 hard target

0.8490 (17c round) → **0.9452** (round 2). Three scenes remain below 0.95,
all within 0.005 of the line:

| scene | SSIM | ΔE | diagnosis |
|---|---|---|---|
| clear-capsule-text-dark | 0.9452 | 0.74 | the unmeasured tone curve below the 0.15 code floor (SwiftUI lifts the black text strokes) plus edge-local blur variation; was 0.9017. |
| clear-rect28-text-light | 0.9463 | 0.78 | same tone-floor + edge-blur residual; was 0.8490 (the round-1 minimum). |
| regular-capsule-photo-dark | 0.9476 | 2.25 | dark small-capsule interior still ~1.15x too contrasty; the tone lift recovered most of the 0.8980 gap (this scene's round-1 SSIM; 0.9017 belongs to clear-capsule-text-dark), the rest is the size-dependent fill the single wash cannot express. |

Next candidates (Task 17d): measure the clear tone curve below the 0.15
floor (grey-ramp captures) — it is the shared residual of both clear text
scenes; the dark capsule wants a per-shape contrast term, not more fill.

### Unit-test updates that shipped with the constants

- `test/core/glass_constants_test.dart`: the "standard v4" pin became
  "standard v5" with the round-2 values (regularDark blur σ/toneLift/fill
  colour, clear blur σ, clearDark lens size ref).
- `test/liquid_glass_test.dart`: the composed-blur sigma expectation now
  includes the post-blur share (σ·√(1−share), shipped clear share 0.3).
- `tool/fidelity/test_glass_model.py`: the 17d feature tests neutralise
  the shipped feature keys explicitly (the shipped clear/regularDark sets
  now use the features, so "STANDARD is at defaults" no longer holds);
  tone-LUT identity test now pins that identity differs from the shipped
  fitted knots.

## Task 17d round 3 (not shipped — stop signal, superseded by round 4)

Ran the brief's three stages on the round-2 key set (`build/fidelity/fit17d/`):
c3-clear and c3-clearDark (24 keys, floor 0.962, ftol 1e-5) and rd3
(polishRegularDark, 16 keys). c3-clear and c3-clearDark both returned the
start point unchanged (losses 0.8389 / 0.8518, ~300 evals); a restricted
escalation fitting only the five weak clearDark scenes
(`restrict3.py`, where any expressible capsule gain strictly lowers the
loss) also returned the start point (1.3712, 285 evals). Per-region
diagnosis: the residual of clear-capsule-text-dark is band-local (band SSIM
0.895 vs interior 0.976), tone keys are inert on it, and no single key moves
it more than +0.003 — the pre-round-4 key set cannot express it. rd3 was
stopped mid-run when round 4 landed (its 16-key space cannot touch clear
scenes at all, so the round-3 gate — strictly better min SSIM — was already
unreachable). The residual was expressive only with a new anisotropy degree
of freedom plus a lens re-grid: round 4 below.

## Task 17d round 4 (shipped): hard target met

Device run (reference simulator, build/fidelity/final): **46/75 pass,
min SSIM 0.9532, 0 scenes below 0.95**, median SSIM 0.9828 / ΔE 1.09.
Model↔Flutter parity: 75/75, min SSIM 0.9960, max ΔE 0.34.

What changed from round 2 (all measured on the model first, then verified
on device):

- **Anisotropic frost (`blurAspectPower`, regularDark 0.28).** Directional
  gradient energy inside the dark capsule shows SwiftUI keeps detail along
  a wide shape's long axis and blurs more across it (SwiftUI gx/gy 1.02/0.56
  on capsule-photo-dark vs model 0.80/0.55; capsule-text-dark gy 0.21 vs
  1.04). The composed blur is now σ·(h/w)^p along x and σ·(w/h)^p along y
  for the strongest member. regular-capsule-photo-dark 0.9476 → 0.9540,
  regular-capsule-text-dark 0.953 → 0.963. Light regular sets keep p = 0
  (any p > 0 lowered the light capsule).
- **Clear lens grid (max-min).** The band shows a mirrored copy of the
  content, so SSIM is a phase match on text lines and Powell stalls (round 3
  returned the start point). A max-min grid fixed `lensSizeRef` 28.8 / 28.7
  and `lensStrength` −2.54 for clear / clearDark, and for clear light
  `blurSigma` 1.2 with `postBlurShare` 0.45 (more of the frost after the
  lens: the capsule band wants more blur, the rect interior less).

Lowest scenes now: clear-capsule-text-light 0.9532, regular-capsule-photo-dark
0.9540, clear-capsule-text-dark 0.9541, clear-rect28-text-light 0.9558.
The clear margin rests on a sharp optimum (lensSizeRef ±0.3 pt moves the
capsule by 0.01–0.05), so any later change to the clear lens must be
re-gridded, not Powell-polished.

**Capture-tree caveat and re-certification.** The device numbers above were
captured at f0f780a, before ed4b2c6 (per-variant post-lens sigma) and the
behaviour-neutral rimBack landing. Re-certified on a fresh capture at the
final tree (build/fidelity/final-17d): **46/75, min SSIM 0.9532
(clear-capsule-text-light), 0 scenes below 0.95, median 0.9828 / ΔE 1.09**
— identical; the post-capture commits are below capture noise. (The round-4
note's "regular-capsule-text-dark 0.953 → 0.963" cites the model value;
device is 0.9513 → 0.9613.)

**Held-out robustness (48 scenes the fit never saw** — off-size capsules
200×50/60/64, text bands phase-shifted 1/2.33 pt, one 350×64 rect;
`compare.py build/fidelity/holdout --scenes tool/scenes/measure.json
--prefix holdout-`): **18/48 official bars, min SSIM 0.9470, 2 scenes below
0.95** (holdout-regular-capsule50-photo-dark 0.9470,
holdout-regular-rect350x64-photo-dark 0.9474), median 0.9686 / 1.08,
parity min 0.9925. The hard target is defined and met on the 75 in-set
scenes; off-grid it holds to within 0.003 on the two hardest — both in the
known regular-dark small-shape family. Do not cite "hard target met" as
generalising off-grid; a future round should fit a regular-dark size term
against the holdout set.

## Task A1: continuous-corner outline (shipped)

Run: `build/fidelity/a1-device2` (reference simulator, Flutter recaptured at
the A1 tree, SwiftUI images copied from `build/fidelity/final`).
**46/75 pass (unchanged), median SSIM 0.9830 / ΔE 1.09, mean 0.9798 / 1.324,
min SSIM 0.9532, 0 below 0.95.** Before (`final`, 17d round 4): 46/75,
0.9828 / 1.09, mean 0.9790 / 1.335. No scene changed pass/fail; the largest
SSIM drop anywhere is −0.00006 (regular-rect16-gradient-dark); capsules,
circles and merges are unchanged. Model↔Flutter parity on the new captures:
75/75, min SSIM 0.9960, max ΔE 0.34 (`a1-device2/parity.txt`).

What changed: rect outlines use a continuous corner after liquid_glass_widgets'
`sdfSquircle` — the corner starts `cornerZone × r` from the corner (capped at
half the shorter side) and is a superellipse with
`n = −1 / log2(1 − 0.29289·r / zone)`, so it passes through the circular arc's
45° point and becomes the circle (n = 2) when the zone clamps to r. New
constant `GlassConstants.cornerZone` (1 = old outline), packed in
`uGlobal2.w`. Shapes with a per-shape exponent (capsules, circles; uInfo.z > 0)
keep exact arcs; the packer now writes uInfo.z = 0 for global-corner shapes
(it used to write the global exponent, which hid rects from circles in the
shader). The lens-normal field keeps circular corners.

Clear rect scenes, device SSIM/ΔE (`final` → `a1-device2`):

| scene | before | after | band SSIM |
|---|---|---|---|
| clear-rect16-photo-light | 0.9659 / 2.12 | 0.9676 / 2.07 | 0.935 → 0.940 |
| clear-rect16-photo-dark | 0.9656 / 1.91 | 0.9678 / 1.84 | 0.934 → 0.941 |
| clear-rect28-photo-light | 0.9619 / 2.23 | 0.9654 / 2.10 | 0.921 → 0.931 |
| clear-rect28-photo-dark | 0.9616 / 2.03 | 0.9659 / 1.88 | 0.920 → 0.932 |
| clear-rect16-text-light | 0.9632 / 0.69 | 0.9656 / 0.68 | 0.925 → 0.932 |
| clear-rect16-text-dark | 0.9655 / 0.67 | 0.9685 / 0.65 | 0.931 → 0.941 |
| clear-rect28-text-light | 0.9558 / 0.74 | 0.9611 / 0.70 | 0.899 → 0.916 |
| clear-rect28-text-dark | 0.9583 / 0.71 | 0.9644 / 0.67 | 0.906 → 0.926 |

All rect families gain a little (regular/tinted rect28 +0.001–0.002); none
crossed the 0.97 bar, so the clear-rect band residual is only partly the
corner shape.

Model sweep (model vs SwiftUI via `glass_model.render` with `cornerZone` and the model-only `_lensZone` key, 36 rect scenes):

- Outline zone (lens circular): 1.0 → mean SSIM 0.9803; 1.1 0.9815; 1.15
  0.9818; **1.2 0.9819**; 1.25 0.9819; 1.3 0.9818; 1.4 0.9813; 1.528 0.9805.
  rect16 prefers ~1.3, rect28 ~1.15–1.2. The model's 1.25 pass gain (48/75)
  rests on clear-rect16-text-dark at 0.9702, which the device runs ~0.002
  below, so 1.2 shipped. Model at 1.2: 47/75 (clear-rect16-photo-dark 0.9710
  model vs 0.9678 device — the extra pass did not transfer).
- Zone on the lens-normal field too: worse for clear (1.528: mean 0.9792,
  clear-rect28-text-light 0.9456); lens-only zone is worse still (1.528:
  0.9787). The circular lens field with `normalRadiusScale` 1.55 already
  stands in for SwiftUI's rounder lens normals.
- Re-gridding clear `normalRadiusScale` with the new outline (1.35, 1.5, 1.6,
  1.75) and zone on both fields with lower scales (1.2, 1.3): all worse;
  1.55 stays optimal.

Note: `build/fidelity/final` still holds the pre-A1 Flutter captures, so the
75 parity cases in `test_glass_model.py` must be pointed at (or refreshed
from) `a1-device2` once this lands.

## Tone LUT (Task 17d)

Deviation from the plan, kept deliberately: the shipped tone LUT is the
piecewise-linear 9-knot hat (`tone_curve.py`, `tone_apply`), not the plan's
"monotonically-clamped cubic" — piecewise-linear is parity-exact with the
shader's LUT (one interpolation, no spline divergence between model, Dart
and GPU), and the hat-sum identity property it replaces is algebraic, so
the Review-Focus identity test now pins shipped ≠ identity instead of
identity itself.

## Noise floors (Part A)

- **SwiftUI-vs-SwiftUI repeat floor: every metric is exactly zero**
  (simulator rendering is bit-deterministic across runs) — committed
  `tool/fidelity/floors/simulator-swiftui-repeat.json`. A repeat run is a
  free upper bound on measurement noise: zero.
- **SwiftUI-vs-UIKit cross-API floor** — committed
  `tool/fidelity/floors/simulator-swiftui-uikit.json` (all 75 scenes);
  global p90 SSIM 0.99999, ΔE 35.1, FLIP 0.75. The ΔE and FLIP p90 legs
  are report-only; only the SSIM leg is meaningful, because the tinted
  scenes ARE included in this committed floor and the two APIs render tint
  differently by design (see `example/ios/Runner/ReferenceScenes.swift`).
- **Device floor: blocked** — no physical iPhone attached; re-run when one
  is.
- **Floor-relative verdicts** exist in `compare.py --floor` (`within_noise`
  per scene, mirrored into report.json and report.html). Report-only: the
  per-scene bars stay official until the floor-based rule is signed off.

Sign-off (Ayman): pending — per-scene bars stay official; floor-relative
verdicts are informational until signed.

## Plan-item dispositions

- **Task 8 (merged-blob fill factor): deferred with reason.** The merge
  scenes sit at SSIM 0.965/0.979, above the 0.95 hard target, and the
  union-extent fill factor stays recorded as the known next lever; the
  plan's stop criterion (a round adding zero passes) fired first (round 3,
  see above).
- **Task 8c (colour-matrix contingency): not triggered.** The trigger
  condition (per-channel colour residual over ΔE 2.0 after the tone LUT)
  was not measured in the final round; median ΔE 1.09 with the worst
  per-scene ΔE documented in the round-2 table above.
