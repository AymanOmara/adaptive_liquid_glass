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
tool/fidelity/.venv/bin/python tool/fidelity/compare.py build/fidelity/<run> [--no-fail]
open build/fidelity/<run>/report.html
```

`capture.sh <run-dir> [scene-id-prefix]` options (environment):

- `CONSTANTS='{"regular":{...}}'` passes `-constants` to the Flutter renderer only.
- `RENDERERS="flutter"` recaptures one side (default `"flutter swiftui"`).
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
numbers plus the pixel region. Without `--no-fail` the script exits 1 if any
scene misses the bars.

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
