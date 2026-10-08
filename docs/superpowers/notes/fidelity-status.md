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
  see above). Measured in fidelity group 2: SwiftUI sizes merged shapes per
  member, not per blob, so the union-extent fill factor is refuted (see
  below).
- **Task 8c (colour-matrix contingency): not triggered.** The trigger
  condition (per-channel colour residual over ΔE 2.0 after the tone LUT)
  was not measured in the final round; median ΔE 1.09 with the worst
  per-scene ΔE documented in the round-2 table above.

## Fidelity group 2: merged shapes (borrow item A2, shipped)

Run: `build/fidelity/g2-1` (Flutter on simulator 2AC3AF21, iPhone 17 Pro, iOS 26.4; SwiftUI refs from `build/fidelity/final`. SwiftUI on 2AC3 vs the E7A8 refs differs by at most 3 levels, mean < 0.004, on 5 checked scenes; Flutter on 2AC3 equals `release-dev7` bit for bit). **47/75 pass (was 46), min SSIM 0.9532, 0 below 0.95, median 0.9830 / ΔE 1.09.** Parity model vs Flutter: 75/75, min SSIM 0.9960, max ΔE 0.34. All non-merge scenes are pixel-identical to `release-dev7` inside the glass (only the status bar differs).

| scene | before (release-dev7) | after (g2-1) |
|---|---|---|
| merge-gap4-photo-light | 0.9662 / 1.99 (fail) | 0.9738 / 1.84 (pass) |
| merge-gap16-photo-light | 0.9798 / 2.03 | 0.9798 / 2.03 (unchanged: its circles do not touch) |
| merge-gap30-photo-light | 0.9802 / 1.91 | 0.9802 / 1.91 (unchanged) |

Measurement (new `g2-*` scenes in `tool/scenes/measure.json`, `gen_measure.py`: 13 layouts × {light, dark} over flat grey v128 and light over the photo; captures in `build/fidelity/g2-measure`, SwiftUI only):

- **Size-dependent appearance is per member, not per blob.** Over flat grey, SwiftUI's small-shape level (204 light / 88 dark, the same as a lone 60 pt circle) holds for every merged layout: rows of 2 and 3, 2×2 grids at gaps 0/4/16/30 (blob 120×120 pt), and a vertical pair of 200×56 capsules at gap 4 (blob 200×116). Two merged 72 pt circles stay in the large class (213 / 60). Over the photo a capsule renders identically whether its neighbour merges (gap 4) or not (gap 30). So the plan's union-extent fill factor (Task 8) and any per-blob frost/lens size would make merged layouts worse; the per-shape fill, frost and lens size terms stay.
- **The merge-scene colour error is not merging.** merge-gap30 (unmerged in both renderers) has the same interior error (model 8-16 levels too bright) as gap4/gap16; it is the small-shape colour response over dark backdrops (small regular glass is steeper: over flats 51→255 SwiftUI goes 170→253, the model 182→253), i.e. the regular fill/tone family, left to the colour refit.
- **The neck was a lens crease.** With a unit normal from the smooth-union field, the normal flips sides at the neck's saddle, so the lens drew a hard vertical seam through the bridge; SwiftUI refracts the bridge smoothly as one surface. Neck SSIM (|x − mid| < 15 pt) on merge-gap4 was 0.918 vs 0.980 elsewhere.

What changed: inside merge necks (where the lens field's smin weight h > 0, new `lensBlend` in the shader, `field_blend` in the model) the lens uses the field over its gradient length as depth and scales the displacement by the gradient length (clamped 0.05-1), after liquid_glass_widgets' blended geometry (which builds normals from the unnormalised SDF gradient). Outside necks the factor is exactly 1, so single shapes and separated groups are bit-identical. No constants changed. Model sweep (model vs SwiftUI, 3 merge scenes + 11 g2 photo layouts, mean SSIM): off 0.9637; displacement scale only 0.9699; depth only 0.9682; both 0.9705 (shipped); both with h-weighted gate 0.9701; exponent 2 on either term worse.

## Fidelity groups 1 and 3: colour refit (g13, shipped)

Run: `build/fidelity/g13-2` (Flutter on the reference simulator E7A8B4A,
iPhone 17 Pro, iOS 26.4, constants passed at launch via `CONSTANTS`;
SwiftUI refs from `build/fidelity/final`; seven mid-transition screenshots
from the first pass — regular-circle-photo-dark, clear-rect16-photo-light,
clear-rect16-photo-dark, tinted-capsule-photo-light,
tinted-rect16-photo-light, regular-capsule-text-dark,
clear-rect28-text-dark — were recaptured individually).
**55/75 pass (was 47 in `g13-base`), median SSIM 0.9830 / ΔE 1.29, mean
0.9803 / 1.270, min SSIM 0.9525, 0 below 0.95, no scene lost.** Eight
gains, zero losses; the median ΔE rises 1.09 → 1.29 (the fit trades ΔE on
already-passing gradient scenes for SSIM on the small-shape fails). Model
score predicted 48 → 56; the device lands at 55.

Target scenes, device SSIM/ΔE (`g13-base` → `g13-2`, \* = pass):

| scene | before | after |
|---|---|---|
| regular-rect16-gradient-light | 0.9953 / 2.11 | 0.9955 / 1.84 \* |
| regular-rect28-gradient-light | 0.9944 / 2.10 | 0.9946 / 1.83 \* |
| regular-capsule-gradient-light | 0.9897 / 2.15 | 0.9893 / 1.88 \* |
| regular-rect16-text-dark | 0.9893 / 2.17 | 0.9903 / 1.41 \* |
| regular-rect28-text-dark | 0.9888 / 2.15 | 0.9897 / 1.41 \* |
| regular-rect16-photo-light | 0.9769 / 2.64 | 0.9768 / 2.65 |
| regular-rect28-photo-light | 0.9775 / 2.56 | 0.9775 / 2.56 |
| tinted-capsule-gradient-light | 0.9807 / 2.31 | 0.9806 / 2.14 |
| merge-gap16-photo-light | 0.9798 / 2.03 | 0.9820 / 1.67 \* |
| regular-capsule-photo-dark | 0.9540 / 2.29 | 0.9525 / 1.98 |
| regular-rect16-photo-dark | 0.9636 / 3.66 | 0.9693 / 3.48 |
| regular-rect28-photo-dark | 0.9645 / 3.55 | 0.9702 / 3.38 |
| tinted-capsule-photo-dark | 0.9630 / 1.65 | 0.9624 / 1.50 |
| regular-capsule-text-dark | 0.9666 / 1.80 | 0.9763 / 1.29 \* |
| regular-capsule-gradient-dark | 0.9744 / 2.16 | 0.9753 / 1.69 \* |
| regular-circle-photo-dark | 0.9712 / 1.61 \* | 0.9713 / 1.70 \* |

Measured basis (`build/g13/flat_response.txt`, flat-grey captures at
halfMin 28-70 pt): **SwiftUI's small shapes switch to a steeper tone
response class between 32 and 34 pt half shorter side.** At v128 dark the
small class (≤ 32 pt) reads 88 and the large class (≥ 34 pt) 59-60
(model: 72 / 68); light reads 204 vs 213 (model: 209 / 210). Light small
shapes also clip a step (34 → 170 between backdrop levels 47 and 51)
where the model's fill-only response stays gradual, and dark small shapes
jump early (226 → 247 at the top while the model gives 116). A size
window on the fill alone cannot make both sides of that switch.

What changed (constants only, no shader/model code): `regular` and
`regularDark` get fitted `toneKnots` plus a `smallToneKnots` LUT with
`smallSizeLo` 32 / `smallSizeHi` 34 (full weight at ≤ 32 pt half shorter
side, linear to off at 34 pt); regularDark also refits `toneLift` 0.7827 →
0.7708, `rimIntensity` 0.3493 → 0.3293, `fillColor` #1B1817 → #191818;
both sets refit `fillOpacity` (0.6804 → 0.6839, 0.665 → 0.6672),
`saturation` (1.7415 → 1.7401, 1.8791 → 1.967), `tintStrength`
(1.0219 → 1.024, 1.0084 → 1.0054) and take `fillSizeDrop` to 0 (the
small-shape response moved into the small tone LUT). Clear sets are
untouched.

The fits: `build/g13/L2.log` frees the regular light keys (pass 17 → 21,
loss 2.48 → 1.43 on the light family), `build/g13/D1.log` the regularDark
keys (pass 14 → 20, loss 3.82 → 1.77). The first combination (`combo1`)
reached 54/75 on device (`g13-1`) but regular-circle-photo-dark failed by
0.0003 SSIM; a margin search (`build/g13b/cd.py` coordinate descent on the
weakest passing regularDark scene, then `pt.py` probe points A-D, combo3)
traded a little of that loss back for circle-photo-dark margin — device
margin 0.0013 SSIM / 0.30 ΔE (the same scene the earlier run missed by
0.0003).

Known residuals after g13: regular rect photo-dark ΔE is still > 3
(rect16 3.48, rect28 3.38 — SSIM now 0.97), rect photo-light sits at ΔE
~2.6 with SSIM ~0.977, regular-capsule-photo-dark/light and
tinted-capsule-photo/gradient stay below the bars, and the clear-family
residuals are unchanged (group 4 material). Parity: model vs the g13-2
Flutter captures 75/75 (`test_glass_model.py` now points there).

## Fidelity group 4: clear glass edges (shipped)

Run: `build/fidelity/g4-1` (Flutter on the reference simulator E7A87B4A,
shipped build, no `-constants`; SwiftUI refs copied from `g13-2`;
regular-capsule-photo-light recaptured once after a mid-transition frame).
**58/75 pass (was 55 in `g13-2`), median SSIM 0.9830 / ΔE 1.28, mean
0.9809 / 1.255, min SSIM 0.9525 (unchanged), 0 below 0.95.** Three gains,
zero losses; no regular, tinted or merge scene moved.

| scene | g13-2 | g4-1 |
|---|---|---|
| clear-capsule-photo-dark | 0.9689 / 1.22 | 0.9733 / 1.12 \* |
| clear-rect16-photo-light | 0.9676 / 2.07 | 0.9726 / 2.00 \* |
| clear-rect16-photo-dark | 0.9678 / 1.84 | 0.9705 / 1.76 \* |
| clear-rect28-photo-light | 0.9654 / 2.10 | 0.9705 / 2.04 |
| clear-rect28-photo-dark | 0.9659 / 1.88 | 0.9689 / 1.81 |
| clear-capsule-text-light | 0.9532 / 0.69 | 0.9633 / 0.60 |
| clear-capsule-text-dark | 0.9541 / 0.69 | 0.9595 / 0.63 |
| clear-rect16-text-light | 0.9656 / 0.68 | 0.9611 / 0.67 |
| clear-rect16-text-dark | 0.9685 / 0.65 | 0.9643 / 0.66 |
| clear-rect28-text-light | 0.9611 / 0.70 | 0.9583 / 0.68 |
| clear-rect28-text-dark | 0.9644 / 0.67 | 0.9606 / 0.67 |

Measured basis (`measure_lens.py` decode of the `measure-v1/v2` clear
scenes against the model, `build/g4b/lensdiff-std.txt`): the displacement
field already matches SwiftUI to 0.1-0.4 pt on rect sides and circles (1-2
pt only in the capsule's outer 3 pt and rect corners at 1-4 pt), but the
decoded blur does not: SwiftUI's clear blur stays 1.1-1.4 pt through the
band, ours rose to 2.0-2.2 pt at 1-4 pt depth and 3.3-3.9 pt at the edge,
because the post-lens taps were stretched through the lens Jacobian up to
4x. New per-variant constant `postJacobianMax` (uVar O.w; 4 = old
behaviour, regular sets keep 4) clamps that stretch. Clear sets ship 1.15
with a coordinate-descent refit whose objective is the predicted device
pass count (model + per-scene g13-2 device−model offset, margin 0.001 SSIM
/ 0.03 ΔE, no predicted loss): blurSigma 1.2 → 1.28 / 1.1534 → 1.2334,
postBlurShare 0.45 → 0.31 / 0.2882 → 0.1482, frostWideMixCentre −0.08,
lensEdge +1 pt, lensDecay +0.25 pt, lensStrength −2.54 → −2.49,
rimIntensity 0 → 0.15, rimMix 0.63 → 0.48 / 0.5247 → 0.3747. Model
predicted 58/75 and the device landed on exactly the predicted gains.
Parity model vs `g4-1`: 75/75 (`test_glass_model.py` now points there).

Tried and rejected (model, full 75 unless noted):

- **The WIP edge-lens commit 47441d5** (Jacobian clamp 1.3 and a lens depth
  knee at 0.933 × lensSizeRef, for every variant): model 56 → 58 but loses
  clear-capsule-photo-light and softens regular-circle-photo-light;
  reverted. The depth knee alone loses a scene (13/24 clear vs 14); only
  the clamp, made per-variant, survived.
- **liquid_glass_widgets 1.10.0 curved-glass lens profile** (paraxial
  `(1 − d/B)^p` displacement from their circular bevel,
  `liquid_glass_render.frag`): p 2 / B 18 pt, p 2 / B 22, p 3 / B 24 all
  lose 6 of 14 passing clear scenes (min SSIM 0.73-0.88). SwiftUI's
  measured profile is exponential with a steeper outer 1-2 pt, which
  lens v3 + `lensEdge` already fit; nothing was borrowed.
- **Post share fading in over the outer band** (2 or 4 pt): +0 / +1 clear
  scene, dominated by the clamp.

Remaining clear failures: rect28 photo (SSIM 0.970-0.969, ΔE 2.04 light)
and all capsule/rect text scenes (0.958-0.964). The refit traded
0.003-0.004 SSIM on the rect text scenes (none passing before or after)
for the photo gains; text-band residual is the mirrored-content phase match
noted in round 4.

### Item 8 (regular photo scenes): tried, not shipped

A predicted-device coordinate descent over 46 regular/regularDark keys
(blur, frost tail, fill, saturation, dim, shadow, rim, rimBack, tone
knots; `build/g4b/cd3a.log`) ran a full round with **no pass gain**. It
lifts SSIM (predicted regular-capsule-photo-dark 0.9525 → 0.9560, rect
photo-dark 0.969 → 0.973) and the loss, but ΔE stays the blocker: rect
photo-dark 3.48 → 3.35, rect photo-light 2.65 → 2.62, tinted-capsule-photo-
light 2.36 → 2.32, and capsule-photo-light worsens 1.90 → 1.97. Per the
zero-gain rule the constants stay. Diagnosis (`build/g4b/lab.py`):
the rect photo error is a broad interior offset over the photo's dark
regions (light: dL −2.1, da −1.3; dark: dL −1.9 with 1.28x L contrast),
absent on gradient/text backdrops, so it is a backdrop-dependent colour
response the grey tone LUT + single saturation gain cannot express (a
chroma-dependent vibrancy term is the next candidate).

### Item 8 round 2 (2026-10-08): ambient backdrop term, measured, off by default

New shader/model term (`ambientMix`, `ambientReach`, uniform block P): the
glass adds `ambientMix x (avg - luma(avg))`, `avg` = 5x5 taps of the blurred
backdrop over the shape's (blended) rect inflated by `ambientReach`; off for
the small-shape class. Model parity with the term at 0 still holds on all 75
scenes (`test_model_matches_flutter_output`).

- Predicted-device descents (`build/g8/cd4.py`, light regular set, 27 scenes)
  never beat 22/22 base passes. The LS fit that fixes the rect photo ΔE
  (`build/g8/p1.json` L40: rect16/28-photo-light 2.65 -> 1.95) loses 5:
  tinted-rect16/28-photo-light (1.91 -> 2.2) and all three merge-gap photo
  scenes (1.5 -> 2.1), plus capsule-photo-light (1.90 -> 2.40). Raising
  `ambientReach` to 60 recovers 2 of the 5 but drops the gains; the
  zero-loss end of that frontier is `cdL2` (mix 0.18, reach 60, saturation
  1.44, retuned tone knots) with 0 gains.
- Dark set: the LS fit (`build/g8/large40lab.log`) gets rect16-photo-dark
  only to ΔE 2.94 (bar 2.0); not pursued.
- Device check, `build/fidelity/g8-1` (cdL2 via `-constants`): **58/75, 0
  gains, 0 losses**, min SSIM 0.9525 (unchanged), median ΔE 1.28 -> 1.12,
  mean ΔE 1.255 -> 1.195. Device matched the prediction to ~0.0003 SSIM /
  0.1 ΔE. Nearest miss: regular-capsule-photo-light 0.9694/1.53 (ΔE now
  passes, SSIM 0.0006 short); rect photo-light still 2.74/2.67.
- A follow-up SSIM descent from cdL2 (blur, frost tail, rim, lens, shadow)
  only drifted `frostWideSigma` with no pass change; stopped.
- Capture note: the first g8-1 pass had three blank (all-white) Flutter
  screenshots (regular-capsule-photo-light/dark, regular-circle-photo-light);
  a `RENDERERS=flutter SKIP_BUILD=1` recapture of those prefixes fixed them.
  Check for SSIM < 0.7 outliers before trusting a run.

Verdict: zero gains, so per the rule nothing ships; the term stays in the
shader and model with `ambientMix` 0 (behaviour identical to g4-1). The
residual is a frontier between the rect photo scenes and tinted/merge photo
scenes that a single global chroma term cannot split: SwiftUI appears to
treat tinted and merged glass differently from plain large rects.

