# Task 9 — rim direction measurement: FIXED-LIGHT

Measured 2026-10-05 by the GLM session on worktree `alg-glm-task9`, branch
`glm-task9-rim` (commits below). Simulator: iPhone 17 Pro, iOS 26.4, UDID
`2AC3AF21-6F97-4706-AE23-3F507BE9699F` (the Controller-assigned device; the
reference `E7A87B4A` is in use by another session). Captures:
`build/fidelity/rim-measure` (gitignored; 16 scenes, swiftui renderer only).

## Verdict

**Apple's rim highlight is a fixed light. It does not follow the backdrop
content.** No `rimContent` mixing term is warranted; the model's
content-free rim is the right family. The rect-band residual is a
**fixed (rotation-invariant) rim-profile mismatch** — retune the fixed rim
constants; see "Hand-off".

Decisive test — the **residual** (device − model) rim-ring profile per
gradient rotation. The model's rim is purely fixed (directional spec at
315° + isotropic white mix) and its lens/frost/fill content coupling
matches the device (control-ring residual ≈ 0.2–0.7/255 rms), so any
content-following rim the device had would survive in this residual as a
profile that rotates with the gradient. It does not:

| variant set | pair corr @ 0 shift | backdrop corr | fixed fraction | fixed rms | content rms | `rimContent` would remove |
|---|---|---|---|---|---|---|
| regular-light | +0.922 | −0.054 | 0.88 | 4.3 | 1.6 | ≤ 0.29 % of residual variance |
| regular-dark  | +0.979 | −0.037 | 0.93 | 12.6 | 3.3 | ≤ 0.13 % |
| clear-light   | +0.992 | +0.007 | 0.99 | 15.2 | 1.4 | ≤ 0.00 % |
| clear-dark    | +0.934 | +0.034 | 0.96 | 9.8 | 2.1 | ≤ 0.11 % |

Rim ring = outer 4 physical px (×3) inside the outline; profiles binned by
the azimuth the rim faces (0° = screen-up, 90° = screen-right, clockwise);
36 bins of 10°, medians; rms in 8-bit levels (/255). Full data:
`build/fidelity/rim-measure/rim-swiftui.json` (per-rotation profiles for
rings rim 0–4 px, rim0/rim1 halves, control 4–12 pt; device, model and
residual).

## Why the raw profiles alone read "mixed" (and why that is not content rim)

The raw device rim-ring profile does correlate with the backdrop
(regular-light −0.727) — but the deeper **control ring** (4–12 pt: lens,
frost and fill couple to content there, no rim highlight) correlates at
−0.997, and the model — which has **no** content rim — shows the same
coupling at the rim ring (−0.405). That coupling is contrast reduction by
frost/fill, present at all depths, already modelled. Subtracting the model
removes it; what remains is rotation-invariant (table above). For clear
glass the raw profiles alone already read fixed-light (pair corr 0.94–0.99)
— consistent with the model-only clear analysis (M5: isotropic rim).

The backdrop's own azimuthal luminance was verified to rotate exactly with
the gradient (first-harmonic phases 4°/275°/184°/95° for r000/r090/r180/
r270, synthetic test): the measurement can see a content rim if one exists.

## Hand-off for the model session (all fixed, none of it content)

The rotation-mean residual (device − model, /255) is large and structured;
it is the rect-band residual of Task 10, in fixed form:

- **regular-dark**: rim-ring first harmonic amp 15.4/255 at phase 135°
  (down-right) — the device's fixed rim is brightest where the model's
  directional spec (light at 315°, up-left) is weakest. The model's
  directional term overshoots up-left / undershoots down-right for regular.
  Concentrated in the outermost 2 px (rim0 fixed rms 18.3/255).
- **regular-light**: flat +4.7/255 from 2 px inward over the whole band
  (straight and corners alike; a fixed tone/fill offset, not rim shape),
  plus corners −19.3/255 at pixel 0.
- **clear-light/dark**: the outermost corner pixel is 35–41/255 too dark in
  the model (device brighter: the white-mix rim starts at the very edge and
  at corners); −9..−10/255 at pixel 1–2, then flat. Straight edges:
  −5..−6/255 in the outer 2 px (dark), +1.3/255 flat interior (light).
- Depth tables (`residual vs depth`, straight vs corner, 8 bins 0–24 px)
  are in the JSON under `residual_depth` per variant set.

Do **not** add a `rimContent` term: fitting the best luminance-mixing term
to the residual would remove ≤ 0.3 % of its variance (table above).

## Model vs device per scene (shipped constants; region = compare.py glass
region, band = outer 18 pt)

| scene (rotation r000/r090/r180/r270) | SSIM | ΔE | band ΔE |
|---|---|---|---|
| regular-light | 0.9947 / 0.9935 / 0.9946 / 0.9937 | 2.14 / 2.12 / 2.40 / 2.09 | 2.26 / 2.69 / 2.93 / 2.63 |
| regular-dark | 0.9855 / 0.9841 / 0.9821 / 0.9820 | 0.95 / 1.14 / 1.08 / 1.13 | 1.32 / 1.45 / 1.25 / 1.45 |
| clear-light | 0.9951 / 0.9942 / 0.9930 / 0.9941 | 0.50 / 0.55 / 0.57 / 0.56 | 0.82 / 0.88 / 0.96 / 0.89 |
| clear-dark | 0.9924 / 0.9909 / 0.9827 / 0.9910 | 0.22 / 0.38 / 0.38 / 0.36 | 0.59 / 0.73 / 0.83 / 0.71 |

Regular-light's ΔE 2.1–2.4 sits just over the official bar (2.0) and is
the fixed offset documented above — rotation-independent, as expected for a
fixed-light rim mismatch. No magenta fail-loud frames appeared (guard in
`measure_rim.py` asserts this before scoring).

## Method and conventions

- Backgrounds: `gradient-r{000,090,180,270}` — the fidelity `gradient`
  palette on the four screen axes, rotation only (`r000` is bit-identical
  to `gradient.png`). Note the ramp's *luma* falls toward its light end
  (green drops 180→80 while red rises 30→230).
- Scenes: 16 in `tool/scenes/measure.json` (appended): rect16 (240×140 pt,
  radius 16, fidelity-matrix position) × {regular, clear} × {light, dark} ×
  4 rotations. Captured with
  `UDID=2AC3AF21-… RENDERERS=swiftui SCENES=tool/scenes/measure.json
  tool/fidelity/capture.sh build/fidelity/rim-measure <prefix>` (4 prefix
  runs; fresh dir). Disk checked before each run (66–67 GB free).
- The no-glass reference is the background PNG itself (brightness only sets
  `colorScheme`; backgrounds render pixel-exact outside glass — README
  "Capture format and alignment"). Residuals of 3–10/255 max appear on
  <0.1 % of pixels just outside the outline (the glass's own outer shadow);
  bin medians are unaffected.
- Tool: `tool/fidelity/measure_rim.py` (+ `test_measure_rim.py`, 8
  synthetic rim tests: fixed pattern → fixed-light, content pattern →
  content-following with the 90° shift, control-ring pattern alone stays
  fixed-light, magenta guard, azimuth convention). Reproduce:
  `measure_rim.py build/fidelity/rim-measure --model`.
- Units: physical px are ×3 in captures; rings/constants in pt where noted.

## Commits (branch `glm-task9-rim`, not pushed)

- `716c9b7` meas: rotated gradient backgrounds and rim measurement scenes (Task 9)
- `5c725ca` meas: gen_backgrounds/gen_measure changes for the rotated gradients
- `89c873f` feat: rim azimuthal decoder measure_rim.py with synthetic tests (Task 9)
- (this commit) feat: residual-vs-model verdict in measure_rim.py; Task 9 result note

## Pytest (`tool/fidelity/.venv/bin/pytest -q`, this worktree)

```
80 passed, 75 skipped in 25.59s

SKIPPED [75] test_glass_model.py:28: 75-scene parity needs Flutter captures
of the shipped build in build/fidelity/final …
```

The 75-scene parity suite skips in this worktree (no `build/fidelity/final`
captures here); the work package's "147 passing + 2 known-failing parity
cases" refers to the main checkout with captures present. Nothing in this
worktree fails. The scene-count guard in `test_measure_lens.py` was updated
for the 16 new scenes (+16 and the four gradient backgrounds).

## Cleanup

Capture PNGs deleted after scoring (disk-safety rule); the analysis JSON
(`rim-swiftui.json`, ~1 MB) is kept as the record alongside this note.
