# Static fidelity harness

Compares the Flutter renderer against SwiftUI's iOS 26 Liquid Glass, scene by
scene, on the reference simulator (iPhone 17 Pro, iOS 26.4,
`E7A87B4A-3E48-44F8-A588-704D56774FF0`).

## One-time setup

```bash
python3 -m venv tool/fidelity/.venv
tool/fidelity/.venv/bin/pip install -r tool/fidelity/requirements.txt
```

Regenerate the inputs only when the scene matrix or backgrounds change (both
outputs are committed):

```bash
tool/fidelity/.venv/bin/python tool/scenes/gen_backgrounds.py   # example/assets/backgrounds/*.png
tool/fidelity/.venv/bin/python tool/scenes/gen_scenes.py        # tool/scenes/scenes.json (75 scenes)
tool/scenes/sync_example.sh                                     # copies it to example/assets/scenes.json
```

## Run

```bash
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8   # CocoaPods under Ruby 4 needs this
tool/fidelity/capture.sh build/fidelity/<run>            # builds, installs, captures all scenes
tool/fidelity/.venv/bin/python tool/fidelity/compare.py build/fidelity/<run> [--no-fail] [--prefix <id-prefix>]
open build/fidelity/<run>/report.html
```

`capture.sh <run-dir> [scene-id-prefix]` options (environment):

- `CONSTANTS='{"regular":{...}}'` passes `-constants` to the Flutter renderer only.
- `RENDERERS="flutter"` recaptures one side (default `"flutter swiftui"`).
- `SCENES=tool/scenes/measure.json` captures another scene list (it must be
  synced into `example/assets/` and is passed to both hosts as `-sceneFile`).
- `SKIP_BUILD=1` reuses the installed app. `SETTLE=<s>` changes the wait before
  each screenshot (default 2.5 s). `UDID`, `BUNDLE` override the device and app.

Each scene launches the example app with `-scene <id> -renderer flutter|swiftui`.
`swiftui` swaps the root view controller (in `SceneDelegate`) for
`ReferenceSceneView` in `example/ios/Runner/ReferenceScenes.swift`, which draws
the same background asset and real `.glassEffect` shapes. Screenshots are taken
on the host with `xcrun simctl io <udid> screenshot` (`binding.takeScreenshot`
is unreliable on the simulator and misses UIKit content).

Scorer tests: `cd tool/fidelity && .venv/bin/pytest -q`.

## Reading the report

`compare.py` crops each scene to its glass region (union of shape bounds
inflated by 12 pt, at @3x) and scores Flutter against SwiftUI:

- **SSIM** (structure, 1.0 = identical) must be ≥ 0.97.
- **ΔE** (mean CIEDE2000 colour difference) must be ≤ 2.0.

`report.html` lists every scene (failing rows in red) with both screenshots and
a diff image (absolute difference ×4, white = large). `report.json` has the same
numbers (`{"scored", "passed", "missing", "scenes": [...]}`, each scene with
its pixel region). Without `--no-fail` the script exits 1 if any scene misses
the bars, if any scene lacks either screenshot (listed as `MISSING` and in
`missing`), or if nothing was scored. After a partial capture
(`capture.sh <run> <prefix>`), pass the same `--prefix` so the rest of the
matrix does not count as missing.

Fail-loud guards: `capture.sh` refuses a simulator that is not an iPhone 17 Pro
on iOS 26.4, a prefix that matches no scene, an unknown renderer, and a stale
`example/assets/scenes.json`. It also names the scene and renderer if a launch or
screenshot fails. In the app, an unknown `-scene` (Flutter) or a failed SwiftUI
reference swap (unknown scene, missing background, iOS < 26) shows a solid
magenta screen with a red error label instead of falling back, so such a capture
can never score well.

## Capture format and alignment (measured 2026-10-04)

- `simctl io screenshot` on this setup writes **8-bit RGBA PNGs tagged sRGB
  IEC61966-2.1**, 1206×2622, for both renderers (not 16-bit or Display P3).
  `compare.py` therefore only drops alpha (`.convert('RGB')`), identically for
  both images; no colour-space conversion is needed.
- Backgrounds align pixel-exactly between the renderers outside the glass:
  on `regular-capsule-photo-light` the mean and max absolute difference in the
  top-left and bottom-right 300×300 px corners, and across the whole top half
  of the screen, are 0 (best shift search: (0, 0)). Across all 75 baseline
  scenes, every pixel outside the glass bounds inflated by 60 pt is identical
  (mean 0, max 0).

## Baselines

| run | shader model | pass | median SSIM | median ΔE | mean SSIM | mean ΔE |
|---|---|---|---|---|---|---|
| `build/fidelity/baseline` | v1 (in-shader 24-tap blur, global corner exponent, `lumaLift`, smoothing 2×spacing) | 0/75 | 0.688 | 14.7 | 0.702 | 15.1 |
| `build/fidelity/baseline-v2` | v2 (spec §15: per-shape corners, composed frost blur, fill colour + saturation, `mergeFactor`) | 0/75 | 0.924 | 10.1 | 0.874 | 10.9 |
| `build/fidelity/lens-v3` | v2 + lens v3 (Task 15c), standard constants = measured lens + Task 17 fit | 20/75 | 0.948 | 2.80 | 0.944 | 5.1 |
| `build/fidelity/final` | v2 + lens v3 + size-dependent frost and fill (Task 17b), shipped `GlassConstants.standard` (no `-constants`) | 41/75 | 0.981 | 1.50 | 0.964 | 1.69 |
| `build/fidelity/final` (Task 17c) | 17b + frost wide tail (`frostWide*`, sharp core + wide component from the coded captures), shipped `GlassConstants.standard` | 42/75 | 0.981 | 1.56 | 0.9655 | 1.71 |

In v2, 65 of the 75 scenes improved in SSIM and 62 in ΔE. Regular glass now
sits at a median SSIM of 0.939 and ΔE of 7.0. Clear glass in dark mode got
worse: the worst scene is `clear-rect16-text-dark` at ΔE 25.4. Both runs use
the starting constants; fitting (Task 17) comes next.

## Model parity and fitting (Task 17)

`glass_model.py` is a NumPy port of `shaders/liquid_glass.frag` (v2 with lens
v3 and the frost wide tail): the composed blur is Impeller's kernel on the
full background (edge
clamped), the shader
runs at pixel centres in encoded sRGB, and the result is composited
premultiplied srcOver onto the sharp background inside the backdrop clip.
`test_glass_model.py` checks it against the device captures in
`build/fidelity/final` on all 75 scenes (bar: SSIM ≥ 0.99 and ΔE ≤ 1.0 per
scene; Task 17c: min SSIM 0.9955, max ΔE 0.32). The frost sigma per group is
`group_blur_sigma` (largest per-shape `blurSigma·min(1, halfMin/blurSizeRef)`)
and the per-shape fill factor is `fill_size_factor`, as the renderer and
packer compute them.

**Frost wide tail** (Task 17c): `measure_frost.py` decodes the transfer
function of SwiftUI's frost from captures over grey x-codes (periods 32-160
px, four phase steps each) and the input→output tone curve from flat greys.
`fit_frost.py` fits the sharp-core + wide-tail decomposition to those curves
per variant set and writes `frostWide*`; only the tail was shipped (see
`docs/superpowers/notes/fidelity-status.md`, "Fitting decisions").

**Blur kernel** (Task 15c, replaces the Task 17 `blurScale` table): a least
squares fit of a free symmetric kernel to a σ 1.38 pt device capture gave a
Gaussian of exactly the requested σ, truncated at radius
`round((σ_px − 0.5)·√3)` and renormalised. The truncation is what made the
effective blur look 0.81–0.95× narrower. With it, all 75 `lens-v3` scenes
reproduce at SSIM ≥ 0.9958 (median 0.9984) and ΔE ≤ 0.38. σ above about 8 pt
(where Impeller may downsample) is not re-verified.

Fitting (each stage takes the previous stage's JSON):

```bash
F="tool/fidelity/.venv/bin/python tool/fidelity/fit.py"
$F corner      --start tool/fidelity/standard_constants.json --out build/fidelity/fit/s1.json
$F regular     --start build/fidelity/fit/s1.json --out build/fidelity/fit/s2.json --restarts 20
$F regularDark --start ... ; $F clear --start ... ; $F clearDark --start ...
$F tinted      --start ... ; $F merge --start ... 
$F polishRegular --start ... --only blurSigma,blurSizeRef,fillOpacity,fillSizeRef,fillSizeDrop,saturation,tintStrength \
    --out build/fidelity/fitted.json   # joint fit over regular-*, tinted-*, merge-*
$F score       --start build/fidelity/fitted.json [--scenes <prefix>]
```

`--only KEY[,KEY]` frees a subset; `--procs` sets the worker count; `--seed`
changes the random restarts. Per-scene status of the shipped constants:
`docs/superpowers/notes/fidelity-status.md`. The loss is
the mean of `(1 − SSIM)·10 + ΔE/2` over the stage's scenes.

## Lens measurement (Task 15c)

`tool/scenes/measure.json` (`gen_measure.py`) holds 18 base scenes (capsule,
circle, rect16, rect28 × regular, clear in light; capsule × regular, clear in
dark; and a Task 17b size series of radius-16 rects with half-sizes 20, 50,
100 and 150 pt × regular, clear), each over the 16 coordinate-code backgrounds of `gen_backgrounds.py`
(`gen_backgrounds.py codes` writes only those). A code is a grey sinusoid along
x or y, period 128 or 160 px, in four phase steps. Per pixel, the four steps
give the sampled coordinate as a phase, `atan2(I3 - I1, I0 - I2)`, which a
per-channel affine colour change and any symmetric blur cannot move; the two
periods beat at 640 px to pick the fringe order.

```bash
SCENES=tool/scenes/measure.json RENDERERS=swiftui tool/fidelity/capture.sh build/fidelity/measure-v1
tool/fidelity/.venv/bin/python tool/fidelity/measure_lens.py build/fidelity/measure-v1 \
    --out build/fidelity/measure-v1/an --charts <dir>
```

It prints per-scene profiles (peak, band, mirroring, dispersion, and the
decode error outside the glass, which must stay near 0), writes
`lens-<renderer>.json`, `field-*.npz` and `lens-fit-<renderer>.json` (one
`lens_v3` least-squares fit per variant on the decoded field), and charts.
`--renderer flutter` decodes Flutter captures of the same scenes.


Result (iPhone 17 Pro, iOS 26.4): SwiftUI's edge displacement is along the
normal only, the same in light and dark, with no measurable dispersion, and
fits `lens_v3` to 1–2 px rms: amplitude 47 pt, decay 6.4–6.5 pt, cut-off band
18.0–18.4 pt for both variants; regular glass shrinks the whole profile by
`halfMin / 38.4 pt` on smaller shapes (clear does not, down to 28 pt). These are
the shipped `lensStrength`, `lensBand`, `lensDecay` and `lensSizeRef`. Decoding
Flutter captures of the same scenes returns the shipped values to within 0.3 %.

## Motion: press and morph (Tasks 16, 16b)

`tool/scenes/gen_motion.py` writes `tool/scenes/motion.json` (copy it to
`example/assets/motion.json`). `record_motion.sh` records every motion in both
renderers on the motion simulator (7E156D58) and `compare_motion.py` scores
Flutter against SwiftUI frame by frame with the static bars, and fits springs
and press amplitudes from the glass bounding box.

```
tool/fidelity/record_motion.sh build/fidelity/run [id-prefix]       # both renderers
RENDERERS=swiftui SKIP_BUILD=1 tool/fidelity/record_motion.sh build/fidelity/run-b
tool/fidelity/.venv/bin/python tool/fidelity/compare_motion.py build/fidelity/run [--strips DIR]
tool/fidelity/.venv/bin/python tool/fidelity/compare_motion.py build/fidelity/run --noise-ref build/fidelity/run-b
```

**Capture (lossless).** The app's `-dump x,y,w,h,frames` renders the crop
through the render server on every display frame, from a display link on its
own thread (`FrameDump` in `example/ios/Runner/MotionScenes.swift`); the
pixels equal `simctl io screenshot` within 1/255 for both renderers. The
recorder resamples the frames to a 60 fps grid by their time stamps
(`<id>.<renderer>.times.json`; a display frame the capture missed is listed
as `held` and not scored). `DUMP=0` falls back to h264 (`simctl io
recordVideo`), which costs about 0.04 SSIM. Disk guards: the recorder stops
under 20 GB free (`MIN_FREE_GB`) or above 3 GB per run (`MAX_RUN_GB`); a run
of all motions in both renderers is about 0.4 GB. Delete `frames/` after
scoring.

**Alignment.** Each clip is aligned at its own first change; presses are
aligned again at the touch-up (idb's hold timer jitters by frames), and each
segment gets a sub-frame phase (the second clip is interpolated between
neighbouring frames, one phase per segment), because SwiftUI animates from
the touch time while the capture samples at display frames. Every score is
shift-refined: frames are compared after this alignment. The report keeps
the raw timing apart: `onset_offset` and `release_offset` are the unaligned
first-change differences (frames, Flutter minus SwiftUI; each take starts
its capture 0.8 s before the touch, so they are the touch-to-pixels latency
difference plus idb's touch jitter), and `shift`/`release_shift` are the
refinements applied on top.

**Noise floor.** `--noise-ref DIR` scores each renderer's clips of one run
against the same renderer's clips of another (`noise_report.json`). Measured
(Task 16b, SwiftUI against SwiftUI): runs B and C pass the static bars on
every frame in 5 of 5 motions (worst SSIM 0.970, worst ΔE 1.03), but only
after discarding run A, recorded right after a build, which had SwiftUI
hitches (a frame repeated mid-motion): A against B passed 3 of 5 and C
against A 2 of 5 (1–3 failing frames each). The 5 of 5 holds for clean takes
only. `--noise-ref` flags this: a frame repeated mid-motion in one take but
not the other prints `HITCH` (`hitch` in the report, window positions per
take); re-record the hitching run before trusting the floor or a Flutter
score.
