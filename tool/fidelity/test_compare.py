import numpy as np
import pytest

from compare import region_for, score


def test_identical_images_pass():
    rng = np.random.default_rng(0)
    a = rng.random((300, 300, 3))
    s = score(a, a.copy())
    assert s["ssim"] == pytest.approx(1.0)
    assert s["delta_e"] == pytest.approx(0.0, abs=1e-9)
    assert s["pass"]


def test_shifted_image_fails():
    rng = np.random.default_rng(1)
    a = rng.random((300, 300, 3))
    b = np.roll(a, 3, axis=1)
    assert not score(a, b)["pass"]


def test_region_inflates_by_12pt_and_clamps():
    scene = {"shapes": [{"x": 0, "y": 10, "w": 100, "h": 50}]}
    x0, y0, x1, y1 = region_for(scene, scale=3, width_px=1206, height_px=2622)
    assert (x0, y0) == (0, 0)  # clamped
    assert (x1, y1) == ((100 + 12) * 3, (60 + 12) * 3)


# --- run(): missing screenshots and empty runs -------------------------------

import json

from PIL import Image

from compare import run

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


def test_empty_run_fails(tmp_path):
    assert run(tmp_path, spec=SPEC) == 1
    report = json.loads((tmp_path / "report.json").read_text())
    assert report["scored"] == 0
    assert report["missing"] == ["a", "b"]


def test_empty_run_with_no_fail_exits_zero(tmp_path):
    assert run(tmp_path, no_fail=True, spec=SPEC) == 0


def test_missing_pair_fails_and_is_listed(tmp_path, capsys):
    for r in ["flutter", "swiftui"]:
        _png(tmp_path / f"a.{r}.png", 0)
    _png(tmp_path / "b.flutter.png", 0)  # b has no swiftui capture
    assert run(tmp_path, spec=SPEC) == 1
    report = json.loads((tmp_path / "report.json").read_text())
    assert report["scored"] == 1 and report["passed"] == 1
    assert report["missing"] == ["b"]
    assert "MISSING b" in capsys.readouterr().out


def test_complete_identical_run_passes(tmp_path):
    for sid in ["a", "b"]:
        for r in ["flutter", "swiftui"]:
            _png(tmp_path / f"{sid}.{r}.png", 0)
    assert run(tmp_path, spec=SPEC) == 0


def test_shape_mismatch_raises(tmp_path):
    _png(tmp_path / "a.flutter.png", 0)
    _png(tmp_path / "a.swiftui.png", 0, size=(30, 40))
    with pytest.raises(ValueError, match="a: flutter"):
        run(tmp_path, spec={**SPEC, "scenes": SPEC["scenes"][:1]})


def test_prefix_limits_missing_to_the_subset(tmp_path):
    for r in ["flutter", "swiftui"]:
        _png(tmp_path / f"a.{r}.png", 0)
    assert run(tmp_path, spec=SPEC, prefix="a") == 0
    assert json.loads((tmp_path / "report.json").read_text())["missing"] == []
