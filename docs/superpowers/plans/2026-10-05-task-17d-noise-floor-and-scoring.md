# Task 17d: Noise Floor, Better Scoring and Residual-Driven Refits

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redefine "pass" as "within Apple's own noise", then use the 17c measurements to fix the model residuals that still fail scenes — and iterate until a full refit round adds zero passing scenes.

**Architecture:** Part A upgrades the scorer (percentile ΔE, interior/band split, FLIP via the official `flip-evaluator` wheel) and measures three noise floors on the reference simulator (SwiftUI×2 repeatability, SwiftUI vs UIKit glass, simulator vs real iPhone when one is attached). Part B converts already-measured residuals into model/shader features — the measured input→output tone curve inside glass, a group-level fill size factor for merged blobs, and a measured rim direction — refitting after each and recapturing. Each part ends with the 75-scene device capture; the stop criterion is a refit round that adds 0 passing scenes.

**Tech Stack:** Python 3.14 + NumPy/scikit-image (`tool/fidelity/.venv`), `flip-evaluator` 1.7 (NVIDIA's official wheel, native), Flutter 3.47.6 + Impeller, Swift/UIKit (iOS 26 glass APIs), reference simulator iPhone 17 Pro / iOS 26.4 `E7A87B4A-3E48-44F8-A588-704D56774FF0`.

**Spec:** the ChatGPT consult recorded in the 2026-10-05 Desktop session (five steps: noise floor, better scoring, one-capture measurement, rim highlight, own blur), summarised in `docs/superpowers/notes/fidelity-status.md` "Known residuals" and the 17c status handoff. This plan is its implementation; the residual table there is Part B's task list.

## Global Constraints

- Reference runtime: iPhone 17 Pro simulator, iOS 26.4, UDID `E7A87B4A-3E48-44F8-A588-704D56774FF0` (capture.sh enforces).
- Current fidelity bars: SSIM ≥ 0.97 and mean CIEDE2000 ΔE ≤ 2.0 in the glass region (bounds inflated by 12 pt). **The official bars do not change in 17d**; floor-relative verdicts are reported alongside for sign-off.
- No new Dart runtime dependencies; Python tooling may add to `tool/fidelity/requirements.txt`.
- Measurement code lives in `tool/fidelity/`, is committed, and every new module has tests; run `tool/fidelity/.venv/bin/pytest -q` before committing.
- Captures land in `build/fidelity/` (gitignored); floors and fitted constants are committed (floors under `tool/fidelity/floors/`).
- Lengths in constants are logical px; shader receives physical px (×3 here).
- All commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- The example app must render correctly with any 17d experiment flag absent (flag is opt-in via launch argument, default off).

## Review Focus

1. **Floor run must not silently reuse stale captures** — `capture.sh` into an existing dir reuses screenshots; the noise tasks must capture into fresh dirs or pass `SKIP_EXISTING` consciously. Pinned in Task 2 (noise.py refuses dirs lacking every scene id) and Task 3 (fresh dir per repeat).
2. **FLIP determinism and range** — FLIP must be 0 for identical inputs and ≤ 1 always, or the floor math is meaningless. Pinned in Task 1's tests (identical → 0.0; noise increases it; bounds).
3. **Interior/band masks must match the diagnosis convention** (interior = deeper than 18 pt inside the shape union, band = the 18 pt ring), or per-region numbers contradict the status notes. Pinned in Task 1 (synthetic shape mask test).
4. **UIKit reference must fail loud** like the SwiftUI one (magenta + reason) so a missing iOS 26 host can never score as a match. Pinned in Task 4.
5. **Tone curve must be identity outside the measured span** — glass at code values outside the flat ramp's coverage must not shift at all. Pinned in Task 5 (model test on inputs 0, 0.5, 1 away from the LUT knots).

---

## Part A — scoring and the noise floor

### Task 1: Scorer upgrades (percentile ΔE, interior/band split, FLIP)

**Files:**
- Modify: `tool/fidelity/compare.py` (`score`, `run`, report)
- Modify: `tool/fidelity/requirements.txt` (add `flip-evaluator`)
- Test: `tool/fidelity/test_compare.py`

**Interfaces:**
- Produces: `compare.score(a, b, interior=None, band=None) -> dict` with keys `ssim, delta_e, de_p99, de_max, flip, flip_p99, ssim_interior, delta_e_interior, ssim_band, delta_e_band, pass` (region keys present only when masks given); `compare.region_masks(scene, scale, width_px, height_px) -> (interior, band)` boolean masks.
- Consumes: `measure_lens.shape_geometry` (depth field, px) for the 18 pt convention.

- [ ] Add `flip-evaluator` to requirements and install into `.venv`.
- [ ] Tests first: identical arrays → `de_p99=de_max=flip=0`; salt-noise pair → monotone increase; synthetic 60×60 capsule scene (a circle via `shape_geometry`) → interior mask excludes the outer ring, band = ring; FLIP in [0, 1].
- [ ] Implement: `region_masks` (shape union SDF from `shape_geometry`, interior = depth ≥ 54 px = 18 pt, band = inside `region_for` box and depth < 54 px); `score` gains the percentile/band keys and calls `flip_evaluator.evaluate(a, b, 'LDR')[2]` (mean) and `np.percentile(map, 99)` from the returned gray map; `run()` passes masks per scene and adds all keys to `report.json` rows and report.html columns.
- [ ] `pytest -q` green; re-run `compare.py build/fidelity/final --no-fail` and confirm 42/75 unchanged (metrics added, verdict untouched).
- [ ] Commit: `feat: scorer adds worst-pixel dE, interior/band split and FLIP`.

### Task 2: Two-run comparator (`noise.py`)

**Files:**
- Create: `tool/fidelity/noise.py`
- Test: `tool/fidelity/test_noise.py`

**Interfaces:**
- Produces: `noise.run(dir_a, dir_b, suffix_a='.swiftui.png', suffix_b='.swiftui.png', spec=None) -> {"scenes": [...], "floor": {...}}`; floor = per-metric median and p90 across scenes; writes `noise.json` + `noise.html` into `dir_a`; CLI `noise.py <dirA> <dirB> [--suffix-a ... --suffix-b ...]`.
- Consumes: Task 1's `score`/`region_masks`.

- [ ] Tests first: synthetic pair of dirs with two scenes → floor medians equal the per-scene values; missing-id refusal raises.
- [ ] Implement: iterate spec scenes, require both files (else `sys.exit` naming them), score with Task 1 metrics, aggregate floor, write reports.
- [ ] `pytest -q` green; commit `feat: noise.py scores two capture runs against each other`.

### Task 3: Floor 1 — SwiftUI repeatability

- [ ] `RENDERERS="swiftui" tool/fidelity/capture.sh build/fidelity/noise-s1` then again into `noise-s2` (fresh dirs; the app is identical so `SKIP_BUILD=1` from the second capture on).
- [ ] `noise.py build/fidelity/noise-s1 build/fidelity/noise-s2` → floor: per-metric median/p90 over 75 scenes.
- [ ] Copy the floor json to `tool/fidelity/floors/simulator-swiftui-repeat.json` (committed), record medians in the status note.
- [ ] Commit `meas: SwiftUI-vs-SwiftUI noise floor on the reference simulator`.

### Task 4: Floor 2 — SwiftUI vs UIKit glass

**Files:**
- Modify: `example/ios/Runner/ReferenceScenes.swift` (add `UIKitSceneView` + dispatch)
- Modify: `tool/fidelity/capture.sh` (allow `uikit` renderer)
- Modify: `example/ios/RunnerTests/RunnerTests.swift` if it asserts the renderer set

**Interfaces:**
- Produces: `-renderer uikit -scene <id>` draws the same scene with UIKit APIs: one `UIView` holding the background `UIImageView` (frame 402×874, `contentMode = .center`, `interpolation` none equivalent) and per shape a `UIVisualEffectView(effect: UIGlassEffect(style: .regular/.clear))` with `cornerConfiguration` (`.capsule()` for capsule/circle else `.corners(radius: .fixed(radius))`), all wrapped in a `UIGlassContainerEffect()` host view when `scene.spacing != nil` — mirroring `ios/adaptive_liquid_glass/Sources/adaptive_liquid_glass/GlassPlatformView.swift:74-110`, including tint (`effect.setValue` path used there, or skip tint shapes: UIKit reference is for the noise floor only — document that tinted scenes fall back to untinted and are EXCLUDED from this floor).
- Produces: floor json `tool/fidelity/floors/simulator-swiftui-uikit.json`.

- [ ] Implement `UIKitSceneView` (fail-loud magenta on iOS < 26 or unknown scene, same as `fail()`); dispatch in `LaunchArgs.installReferenceScene` for `arg("renderer") == "uikit"`.
- [ ] capture.sh: add `uikit` to the renderer allowlist.
- [ ] Build + capture `build/fidelity/noise-uikit` with `RENDERERS="uikit"`; sanity: corners outside glass identical to swiftui captures (they share the background path).
- [ ] `noise.py build/fidelity/noise-s1 build/fidelity/noise-uikit --suffix-b .uikit.png` → floor json; exclude `tinted-*` scenes from the floor (documented).
- [ ] Commit `feat: UIKit glass reference renderer and SwiftUI-vs-UIKit floor`.

### Task 5: Floor 3 — simulator vs real iPhone (conditional)

- [ ] `xcrun devicectl list devices` — if a physical iPhone on iOS ≥ 26 is attached: install the example app (`flutter run -d <id> --release`), capture the 75 scenes via the app's own screenshot path (simctl `io screenshot` does not work on device; use `devicectl device copy file` of the app's in-app `binding.takeScreenshot` output or `xcrun devicectl device screenshot`), floor vs `noise-s1`, commit `tool/fidelity/floors/device-vs-simulator.json`.
- [ ] If none attached: add one line to the status note ("device floor blocked: no device attached") and move on. **Do not block Part B on this.**

### Task 6: Floor-relative verdicts (report-only; sign-off gate)

**Files:**
- Modify: `tool/fidelity/compare.py` (`--floor <json>`)

- [ ] Implement: with `--floor`, each row gains `floor_ssim`, `floor_de`, `floor_flip` (the floor's p90 for that metric) and `within_noise = ssim ≥ floor_ssim − 0.005 and delta_e ≤ floor_de + 0.05 and flip ≤ floor_flip + 0.005`; report.html shows a third verdict column; the exit code still follows the official bars.
- [ ] Test: synthetic floor json → verdict math.
- [ ] Run on `build/fidelity/final`, record in the status note how many of the 33 failing scenes are already within Apple's own noise (expected to justify relaxing per-scene bars later — the sign-off is Ayman's, one line at the end of the note).
- [ ] Commit `feat: floor-relative verdicts in compare.py (report-only)`.

## Part B — residual-driven gains (each: model → shader → fit → capture)

### Task 7: Measured tone curve inside glass (attacks the 10 clear-text scenes)

The 17c flat captures (`measure-v3`, flats v000-v255) already measure glass's input→output curve per channel, including below the 0.15 code floor where SwiftUI lifts black strokes.

**Files:**
- Create: `tool/fidelity/tone_curve.py` (decoder: `tone_lut(frost_json, variant_set) -> (knots_in, knots_out)` from the `tone` arrays `measure_frost.py` already emits)
- Modify: `tool/fidelity/glass_model.py` (apply LUT to `col` after the fill mix, before rim; parameters `toneKnots` in constants json: monotonically-clamped cubic sampled at 9 knots, input 0..1)
- Modify: `shaders/liquid_glass.frag` (same 9-knot piecewise-linear LUT, packed in `uVar` extension or a `uTone[9]` uniform block; must be identity when knots are identity)
- Modify: `lib/src/shader/glass_uniforms.dart`, `lib/src/core/glass_constants.dart` (9-knot constants, default identity)
- Modify: `tool/fidelity/fit.py` (`tone*` keys, bounds identity-centred)

- [ ] Decode: knots from `build/fidelity/measure-v3/an/frost-swiftui.json` tone arrays for regular/clear × light/dark; assert monotone and identity-at-extremes within measured noise; write `tool/fidelity/floors/tone-<set>.json` for reference.
- [ ] Model tests: LUT identity → render unchanged vs 17c captures (bit-equal); knots from measurement → clear-capsule-text scenes' interior mean level rises toward SwiftUI's (the known 10-12 level deficit).
- [ ] Shader test: existing `example/integration_test/shader_smoke_test.dart` passes; golden test with identity knots unchanged.
- [ ] Refit tone knots on the model (`fit.py regular/clear/... --only tone*`), then full polish, then device capture; record pass delta.
- [ ] Commit per step (`feat: measured tone curve in model`, `feat: tone curve uniform + shader`, `feat: fit tone curve, capture`).

### Task 8: Merged-blob fill factor (attacks the 2 merge scenes)

- [ ] `glass_model.fill_size_factor`: for merged groups (weights > 0 to more than one shape), evaluate the size factor against the merged blob's half-min (union extent), not per shape; shader packer `packGlassUniforms.mergeUnions` already unions — extend the `uInfo.w` fill scale to use the union rect's half-min.
- [ ] Test: two 30 pt circles 4 pt apart → factor equals a 64 pt blob's factor.
- [ ] Refit `fillSizeRef/fillSizeDrop` on merge scenes, device capture, record delta.
- [ ] Commit `feat: merged blob uses its own fill size factor`.

### Task 9: Rim direction measurement and model (attacks the rect band residuals)

- [ ] Backgrounds: add rotated gradient variants (0/90/180/270°) to `gen_backgrounds.py`; scenes: one rect16 over each rotation (measure.json).
- [ ] `tool/fidelity/measure_rim.py`: decode rim intensity vs angle around the shape from the four rotations; if rim follows the background, the azimuthal profile rotates with the gradient; if fixed-light, it is rotation-invariant. Tests with synthetic rim images.
- [ ] If fixed-light confirmed: model already matches; record the measurement. If content-following: add `rimContent` mixing term (model + shader + constants), fit, capture, record delta.
- [ ] Commit `meas: rim direction measurement` (+ `feat: content rim` only if measured).

### Task 10: Stop-criterion round

- [ ] Full refit of all freed keys on the model (`polishRegular`, `polishClear`), device capture, compare pass count to the previous round.
- [ ] If 0 scenes gained: stop, final status note (floor-relative pass count, per-family table, residual list). If > 0: loop back into the largest failing family with a new targeted measurement first.
- [ ] Final commit: `docs: fidelity status and README results for Task 17d`.

## Self-review notes

- Spec coverage: noise floor (Tasks 3-5), better scoring (Tasks 1, 6), one-capture measurement (subsumed: Task 7 reuses the 17c single-variant captures; the consolidated capture is unnecessary while each variant set measures separately — revisit only if capture time becomes the bottleneck), rim highlight (Task 9), own blur (dropped from this plan: Task 7's tone/blur gains come first; own-blur only if a full round stalls with edge-band residual — record as the documented next lever).
- Type consistency: `score()` keys are the single vocabulary across compare/noise/fit reports.
- Review Focus: all five pinned (Tasks 2/3, 1, 1, 4, 7).
