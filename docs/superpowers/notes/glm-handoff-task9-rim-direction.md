# GLM work package — Task 9: rim direction measurement

> Hand this file (plus the repo) to a GLM session. It is self-contained.
> Written 2026-10-05 by the Claude session executing
> `docs/superpowers/plans/2026-10-05-task-17d-noise-floor-and-scoring.md`
> (Task 17d). Read the plan's Part B, Task 9 for the original spec; this
> file is the binding brief.

## Context

Repo: `~/Android Studio Projects/adaptive_liquid_glass`, branch
`feat/phase1-core`. The package reproduces SwiftUI's iOS 26 Liquid Glass in
Flutter; fidelity is measured against an iPhone 17 Pro / iOS 26.4 simulator
(75 scenes, bars SSIM ≥ 0.97, ΔE ≤ 2.0). Workflow reference:
`tool/fidelity/README.md`. Status: `docs/superpowers/notes/fidelity-status.md`.

**Coordination — another session is working in this repo concurrently** on
the shader/model parity fix and Task 8b (dark small-shape fill). Do NOT
modify: `tool/fidelity/glass_model.py`, `tool/fidelity/fit.py`,
`tool/fidelity/standard_constants.json`, `shaders/`, `lib/`, or
`tool/fidelity/capture.sh`. Your files: `tool/fidelity/gen_backgrounds.py`
(extend), `tool/fidelity/measure_rim.py` (new),
`tool/fidelity/test_measure_rim.py` (new), measurement scene specs, and
captures under `build/fidelity/` (gitignored).

## The question Task 9 answers

The rect scenes fail on the edge band (ΔE 4–6 in the outer 18 pt ring). The
model has a specular rim whose intensity is currently **fixed relative to
the glass**, not to the backdrop behind it. Measure whether Apple's rim
highlight follows the backdrop content or is a fixed-light (rotation-
invariant) effect:

- If fixed-light → the model already matches; record the measurement, done.
- If content-following → the model needs a `rimContent` mixing term; build
  it **in the model only** (do not touch the shader — hand the fitted term
  back; the other session integrates it).

## Steps

1. **Rotated backgrounds.** Extend `tool/fidelity/gen_backgrounds.py` with
   rotated gradient variants at 0/90/180/270° of an existing gradient
   backdrop (same palette, rotation only). Regenerate into
   `example/assets/backgrounds/` following the existing naming scheme.
   Backgrounds are committed (they are fixtures, unlike captures).

2. **Measurement scenes.** Add four scenes to the measurement spec (the
   spec `measure.json`/`measure_frost.py` consumes — follow how the frost
   size-series scenes were added for Task 8b): one 16-pt-radius rect over
   each rotation, **clear** and **regular** variants (8 scenes total, light
   and dark if the spec carries brightness — mirror the frost measurement's
   convention). Regular (not clear) is what the failing rect band belongs
   to; clear is the control.

3. **Capture.** Boot the reference simulator (UDID
   `E7A87B4A-3E48-44F8-A588-704D56774FF0`; `capture.sh` enforces it):
   `RENDERERS="swiftui" tool/fidelity/capture.sh build/fidelity/rim-measure`
   — capture into a **fresh** dir (capture.sh reuses stale screenshots in
   an existing dir). Use the same render/capture flow the frost measurement
   used; `tool/fidelity/README.md` "Run" section.

4. **Decode — `tool/fidelity/measure_rim.py`.** For each rotation, decode
   the rim intensity as a function of angle around the shape: sample the
   difference between the glass render and the no-glass reference along the
   rim ring (the outer ~4 px inside the shape edge), bin by azimuth (0° =
   screen-up or the gradient's 0° axis — state your convention), and report
   the azimuthal profile per rotation. Compare profiles across rotations:
   correlation ≈ 1 with the backdrop ⇒ content-following; profiles
   identical across rotations ⇒ fixed-light. Tests first with synthetic rim
   images (a ring whose brightness follows a known azimuthal pattern) in
   `tool/fidelity/test_measure_rim.py`. Run
   `tool/fidelity/.venv/bin/pytest -q` before committing (suite was 147
   passing + 2 known-failing parity cases owned by the other session — do
   not fix those).

5. **If content-following.** Fit a `rimContent` term in the **model only**
   (`glass_model.py` is off-limits — instead, deliver: the measured
   azimuthal profile, the proposed formula, fitted parameter values per
   variant set, and the per-scene model SSIM/ΔE deltas as a JSON + short
   markdown note next to this file:
   `docs/superpowers/notes/glm-task9-rim-result.md`). The other session
   integrates model + shader + constants in one parity-preserving change.

## Rules

- Commit your work in small commits on `feat/phase1-core` prefixed
  `meas:` (measurement) / `feat:` (new tooling), ending each message with:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (keep this line
  even though you are GLM — it is the repo's convention).
- Never let a missing iOS 26 host score as a match: the reference app
  renders magenta + reason on unsupported hosts; if you see magenta in a
  capture, stop and report, do not score it.
- Numbers are physical px ×3 in captures, logical pt in specs/constants —
  keep the distinction explicit in what you write.
- The official bars (SSIM ≥ 0.97, ΔE ≤ 2.0) do not change.

## Report back

Append to `docs/superpowers/notes/glm-task9-rim-result.md`: the verdict
(fixed-light vs content-following, with the correlation numbers), commits,
and pytest output. If blocked (simulator won't boot, spec ambiguity), write
the blocker there and stop — the other session picks it up.
