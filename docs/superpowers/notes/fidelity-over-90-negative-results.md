# Fidelity work toward exceeding 90%

## Baseline and scope

The last certified run is `build/fidelity/g4-1`: 58/75 (77.3%). The
official bars stay SSIM >= 0.97 and mean CIEDE2000 <= 2.0, over the existing
75 scenes with their existing crops. Exceeding 90% requires at least 68/75.
Median SSIM is already 0.9830; pass percentage is not mean similarity.

Astra 6 planned and began this work in `codex/clear-edge-fidelity`, isolated
from Claude's live checkout. Claude's three latest project chats were checked
on 2026-10-08: regular-photo ambient colour fitting, unrelated component work,
and completed screenshot/demo work. Keep all those pending edits intact.
Do not access Claude's active simulator or interrupt its processes.

## Research basis

- Apple's [Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/)
  describes lensing, size-dependent material characteristics, backdrop-dependent
  tint/dynamic range, and ambient colour spill on larger surfaces. It supplies
  qualitative behaviour, not numeric shader settings.
- [Flutter fragment shaders](https://docs.flutter.dev/ui/design/graphics/fragment-shaders)
  documents Impeller-only custom image filters. Performance and shader/model
  parity remain required when promoting any sampling change.
- Reviewed implementation references:
  [ybouane/liquidglass](https://github.com/ybouane/liquidglass/blob/main/src/shaders.ts)
  and [AndroidLiquidGlass](https://github.com/Kyant0/AndroidLiquidGlass).
  No source code was copied. Their optics do not replace this project's measured
  exponential lens profile without evidence of improved native matching.

## Implementation sequence

1. Quantify clear-glass residuals using existing coordinate-code captures,
   independently of the test text's phase. Astra measured small straight-side
   phase errors on rects/circles and larger outer-band errors on capsules.
2. Screen phase, spatial blur, and sampling-kernel hypotheses on clear text.
   Keep hypotheses model-only and disabled in the shipped defaults.
3. Validate a candidate on all 24 clear scenes with unchanged thresholds,
   reporting raw model scores separately from estimated device scores. Use the
   saved device-minus-model residual only to select candidates; it cannot
   certify a new rendering algorithm. Require at least one safe gain, no lost
   passes, and predicted minimum SSIM >= 0.95.
4. Port a winning hypothesis to GLSL and Dart, preserving Claude's appended
   ambient uniforms. Verify model/shader parity, full existing tests, and frame
   cost before fresh capture. Do not port rejected hypotheses.
5. Validate on all 75 scenes and held-out sizes/backgrounds. Coordinate fresh
   native captures when Claude's simulator work finishes; do not reuse saved
   Flutter screenshots as proof of the new renderer.
6. Combine complementary regular-photo colour work only after separate
   validation. Clear glass has eight failures, so clear-only changes cannot
   take 58 passes beyond 90%. Keep aiming above 68 passes without weakening
   thresholds or overfitting the text pattern.

## Current implementation

`tool/fidelity/probe_clear.py` provides a repeatable candidate checker with
automatic baseline evaluation, fixed official bars, device/model residuals,
no-regression checks, safety margins (0.001 SSIM / 0.03 Delta E), and explicit
uncertified output. It caps workers at two to avoid competing with Claude's
fitter. Its tests cover verdict safety and disabled-feature render neutrality.

The fitter now copies reference crops to release their full-frame storage and
shares identical geometry across scene IDs/backgrounds. Retained reference
pixels for the 24 clear scenes fall from 1737 MiB to 141 MiB; all 24 baseline
SSIM/Delta E values are exactly unchanged. The new geometry cache also retains
tint/variant/spacing in its key, verified by a regression test.

Model-only research switches in `glass_model.py` permit destination/source
depth weighting, consistent lens depth/direction fields, post-blur isotropy,
a second-order local sampling-map probe,
Gaussian-Hermite quadrature, and a dense Gaussian diagnostic. None is a
Flutter setting or a shipped visual change.

Initial phase correction, destination-depth weighting, alternative wide
kernels, and continuous lens-corner experiments have not earned a production
change. Rejected candidates remain results under `build/astra-clear-edge`,
not default constants. No fidelity gain is certified yet.

### Completed refinement round

All six blur/radius candidates in `build/astra-clear-edge/refine-report-v2.json`
added zero safe gains and lost two captured passes in the residual-based
prediction. Using a consistent lens-depth field, with or without isotropic
post-blur, added zero text passes and lowered predicted minimum SSIM to about
0.910; rejected. The results distinguish the raw model baseline (18/24 clear
passes) from the captured baseline (16/24). No shader/constants change ships.

Validation: 33 model/probe checks passed before the geometry-cache change;
13 focused checks passed after the cache/field additions; two representative
captured model/Flutter parity checks passed (regular dark capsule photo and
clear rect28 light text). The memory optimizations additionally reproduced
all 24 previous clear baseline SSIM/Delta E values exactly. These checks
verify tooling and default rendering; they do not certify a new visual gain.

Next useful measurement: capture high-frequency frost transfer across depth
and both axes independently of the repeated text background. The measured
low-frequency phase corrections and generic Gaussian replacements did not
unlock the text scenes. A fitted depth/frequency-dependent blur model should
be measured before further production shader changes; coordinate captures on
a separate simulator once the capture workload is available.

## Reproduce

Run in this isolated checkout with the existing harness environment:

```sh
tool/fidelity/.venv/bin/python tool/fidelity/probe_clear.py \
  --reference /absolute/path/to/build/fidelity/g4-1 \
  --candidates tool/fidelity/clear_probe_candidates.json \
  --out build/astra-clear-edge/report.json --workers 1
```

Saved captures are local, uncommitted inputs. Missing references fail loudly.
`--text-only` is a screening run and cannot qualify a candidate for full
validation. No simulator is launched, installed, captured, or modified.

## Continued measurements and experiments

Added independent fine-detail probes (`gen_fine_probe.py`): 112 untinted
clear capsule/rect28 scenes, both axes, periods 8/12/16/24/32/128/160 pixels,
four phase steps, amplitude 0.2. `capture_fine.py` confines capture to the
dedicated Codex iPhone 17 Pro on iOS 26.4, limits each simulator operation,
checks free disk space, and rejects home/startup/error frames against the
expected unobstructed background. These probes are outside the 75-scene
scoring matrix. No valid new native frames have been captured yet.

Saved measure-v3 captures remain usable. `measure_detail.py` compares their
32/48/80-pixel detail response with the current model, streaming cropped
frames and clearing backdrop caches. Results in
`build/astra-clear-edge/detail-report.json` show amplitude ratios near one
on straight edges. At 2–3 pt depth the corner phase-error p90 is about
0.84 pt on capsules and 0.90 pt on rect28, consistent across these periods.
Errors are wrapped by the code period; these diagnostics are not fidelity
scores. Finer probes are needed to resolve the remaining text response.

Apple documents that `Capsule()` defaults to continuous corners:
https://developer.apple.com/documentation/swiftui/capsule/init(style:)
Testing capsule lens exponents 1.8/1.9/2.1/2.2/2.4 added zero text passes;
the circular default remains preferable. Direction-dependent core/wide blur
and denser post-refraction quadrature (5/7 taps per axis) likewise added zero
passes. All remain private, disabled model experiments.

A corner displacement correction derived from independent measure-v1
128/160-pixel capsule coordinates improved capsule text slightly. Applying
that calibration to circles caused regressions and was rejected. Restricting
it to capsules, with separately measured light/dark profiles, preserved all
captured clear passes across the full 24-scene model check. Full correction
predicts capsule-text SSIM 0.96329 → 0.96686 light and 0.95949 → 0.96220 dark;
the 24-scene mean improvement is 0.000418. Half/full corrections both remain
18/24 raw-model and 16/24 predicted-device passes, with zero new safe gains.
Results: `build/astra-clear-edge/capsule-correction-report.json`. No production
shader or constants change is justified by this result.

Fresh capture attempts used a separate simulator
`F2C8F03A-2C47-4810-A71A-C506F620D92D`. The installed demo failed to launch;
a minimal native-only host compiled, but installation also timed out. A
bounded reboot retry then timed out waiting for boot readiness. Other agents'
simulators and the shared simulator service were not restarted. The native
host and research assets are saved under `build/astra-clear-edge/native-probe`.

Validation: 20 focused probe/capture checks passed, compilation checks and
diff whitespace checks passed. Default rendering is unchanged. The last
certified overall result remains 58/75 (77.3%); 90% has not been achieved.
