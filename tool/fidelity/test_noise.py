"""Two-run comparator (Task 17d noise floors)."""
import json

import numpy as np
import pytest
from PIL import Image

from noise import run

SPEC = {
    "device": {"width": 40, "height": 40, "scale": 1},
    "scenes": [
        {"id": "a", "shapes": [{"x": 5, "y": 5, "w": 20, "h": 20}]},
        {"id": "b", "shapes": [{"x": 5, "y": 5, "w": 20, "h": 20}]},
    ],
}


def _png(path, seed, size=(40, 40)):
    rng = np.random.default_rng(seed)
    Image.fromarray((rng.random((*size, 3)) * 255).astype(np.uint8)).save(path)


def _dirs(tmp_path):
    for d, k in (("d1", 1), ("d2", 2)):
        (tmp_path / d).mkdir(parents=True, exist_ok=True)
        for f in ("a", "b"):
            _png(tmp_path / d / f"{f}.swiftui.png", hash((f, k)) % 2**31)
    return tmp_path / "d1", tmp_path / "d2"


def test_floor_medians_equal_scene_values(tmp_path):
    d1, d2 = _dirs(tmp_path)
    out = run(d1, d2, spec=SPEC)
    assert set(out["scenes"][0]) >= {"id", "ssim", "delta_e", "flip", "de_p99"}
    for m in ("ssim", "delta_e", "de_p99", "flip"):
        vals = [s[m] for s in out["scenes"]]
        assert out["floor"][m]["median"] == pytest.approx(float(np.median(vals)))
    assert (d1 / "noise.json").exists()


def test_identical_runs_give_zero_floor(tmp_path):
    d1 = tmp_path / "d1"
    d2 = tmp_path / "d2"
    d1.mkdir()
    d2.mkdir()
    for f in ("a", "b"):
        _png(d1 / f"{f}.swiftui.png", 7)
        (d2 / f"{f}.swiftui.png").write_bytes((d1 / f"{f}.swiftui.png").read_bytes())
    out = run(d1, d2, spec=SPEC)
    assert out["floor"]["ssim"]["median"] == pytest.approx(1.0)
    assert out["floor"]["delta_e"]["median"] == pytest.approx(0.0, abs=1e-6)


def test_missing_capture_exits_naming_the_file(tmp_path):
    d1, d2 = _dirs(tmp_path)
    (d2 / "b.swiftui.png").unlink()
    with pytest.raises(SystemExit, match="b"):
        run(d1, d2, spec=SPEC)


def test_custom_suffixes_pick_the_right_files(tmp_path):
    d1, d2 = _dirs(tmp_path)
    _png(d2 / "a.uikit.png", 5)
    out = run(d1, d2, suffix_a=".swiftui.png", suffix_b=".uikit.png",
              spec={**SPEC, "scenes": SPEC["scenes"][:1]})
    assert out["scenes"][0]["id"] == "a"
