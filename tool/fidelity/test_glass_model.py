"""Parity: the NumPy glass model reproduces Flutter's on-device output."""
import json
import pathlib

import pytest

from compare import load, region_for, score
from glass_model import render

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = ROOT / "build/fidelity/baseline-v2"
SPEC = json.loads((ROOT / "tool/scenes/scenes.json").read_text())
STANDARD = json.loads((ROOT / "tool/fidelity/standard_constants.json").read_text())

PARITY_SCENES = [
    "regular-capsule-photo-light",
    "clear-rect28-text-dark",
    "regular-circle-photo-dark",
    "merge-gap16-photo-light",
]


@pytest.mark.skipif(not BASE.exists(), reason="needs build/fidelity/baseline-v2 captures")
@pytest.mark.parametrize("scene_id", PARITY_SCENES)
def test_model_matches_flutter_output(scene_id):
    scene = next(s for s in SPEC["scenes"] if s["id"] == scene_id)
    bg = load(ROOT / f"example/assets/backgrounds/{scene['background']}.png")
    flutter = load(BASE / f"{scene_id}.flutter.png")
    model = render(bg, scene, STANDARD, scale=3)
    x0, y0, x1, y1 = region_for(scene, 3, bg.shape[1], bg.shape[0])
    s = score(model[y0:y1, x0:x1], flutter[y0:y1, x0:x1])
    assert s["ssim"] >= 0.99 and s["delta_e"] <= 1.0, s
