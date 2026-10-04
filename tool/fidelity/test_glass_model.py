"""Parity: the NumPy glass model reproduces Flutter's on-device output."""
import json
import pathlib

import numpy as np
import pytest

from compare import load, region_for, score
from glass_model import render

ROOT = pathlib.Path(__file__).resolve().parents[2]
# Flutter captures with the lens v3 build and the standard constants (Task 15c).
BASE = ROOT / "build/fidelity/lens-v3"
SPEC = json.loads((ROOT / "tool/scenes/scenes.json").read_text())
STANDARD = json.loads((ROOT / "tool/fidelity/standard_constants.json").read_text())

PARITY_SCENES = [
    "regular-capsule-photo-light",
    "clear-rect28-text-dark",
    "regular-circle-photo-dark",
    "merge-gap16-photo-light",
    "clear-capsule-photo-dark",
]


@pytest.mark.skipif(not BASE.exists(), reason="needs build/fidelity/lens-v3 captures")
@pytest.mark.parametrize("scene_id", PARITY_SCENES)
def test_model_matches_flutter_output(scene_id):
    scene = next(s for s in SPEC["scenes"] if s["id"] == scene_id)
    bg = load(ROOT / f"example/assets/backgrounds/{scene['background']}.png")
    flutter = load(BASE / f"{scene_id}.flutter.png")
    model = render(bg, scene, STANDARD, scale=3)
    x0, y0, x1, y1 = region_for(scene, 3, bg.shape[1], bg.shape[0])
    s = score(model[y0:y1, x0:x1], flutter[y0:y1, x0:x1])
    assert s["ssim"] >= 0.99 and s["delta_e"] <= 1.0, s


def test_impeller_kernel_is_a_truncated_gaussian():
    from glass_model import impeller_kernel
    k = impeller_kernel(1.3764 * 3)  # clear: 4.13 px -> radius 6 (measured)
    assert k.size == 13 and abs(k.sum() - 1) < 1e-12
    assert k[6] == k.max() and k[0] / k[6] == pytest.approx(np.exp(-0.5 * (6 / 4.1292) ** 2))
    assert impeller_kernel(15.5664).size == 2 * 26 + 1


def test_missing_keys_fall_back_to_standard_like_dart():
    """Task 17 stage files predate lensDecay/lensSizeRef; the model must fill
    missing keys from standard_constants.json, as GlassConstants.fromJson does."""
    from glass_model import render_window, resolve_constants
    partial = json.loads(json.dumps(STANDARD))
    for name in ("regular", "clear", "regularDark", "clearDark"):
        del partial[name]["lensDecay"]
        del partial[name]["lensSizeRef"]
    del partial["mergeFactor"]
    assert resolve_constants(partial) == resolve_constants(STANDARD)
    assert resolve_constants({"regular": {"blurSigma": 9}})["regular"]["blurSigma"] == 9
    assert resolve_constants({"regular": {"blurSigma": 9}})["regular"]["lensDecay"] == \
        STANDARD["regular"]["lensDecay"]
    bg = np.random.default_rng(0).random((2622, 1206, 3))
    for sid in ("regular-capsule-photo-light", "clear-circle-text-dark"):
        scene = next(s for s in SPEC["scenes"] if s["id"] == sid)
        a, _ = render_window(bg, scene, partial)
        b, _ = render_window(bg, scene, STANDARD)
        assert np.array_equal(a, b), sid


def test_lens_v3_clamps_negative_depth():
    from glass_model import lens_v3
    v = lens_v3(np.array([-0.7, 0.0]), 300.0, 140.0, 19.0, 54.0, 0.0)
    assert v[0] == v[1] == pytest.approx(-140.0)
