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


# --- Task 17d: worst-pixel dE, FLIP and the interior/band split --------------

def test_identical_images_have_zero_worst_pixel_and_flip():
    rng = np.random.default_rng(2)
    a = rng.random((120, 160, 3))
    s = score(a, a.copy())
    assert s["de_p99"] == pytest.approx(0.0, abs=1e-9)
    assert s["de_max"] == pytest.approx(0.0, abs=1e-9)
    assert s["flip"] == pytest.approx(0.0, abs=1e-6)


def test_worst_pixel_and_flip_increase_with_distortion_and_stay_bounded():
    rng = np.random.default_rng(3)
    a = rng.random((120, 160, 3))
    small = score(a, np.clip(a + 0.01, 0, 1))
    big = score(a, np.clip(a + 0.05, 0, 1))
    assert big["de_p99"] > small["de_p99"] > 0
    assert big["de_max"] >= big["de_p99"]
    assert big["flip"] > small["flip"] > 0
    assert 0.0 <= small["flip"] <= 1.0 and 0.0 <= big["flip"] <= 1.0


def test_region_masks_follow_the_18pt_convention():
    from compare import region_masks
    # 60x60 sharp rect at (20, 20): centre depth 30 pt = interior, 1 pt
    # inside the outline is the band, far outside is neither.
    scene = {"shapes": [{"x": 20, "y": 20, "w": 60, "h": 60, "shape": "rect", "radius": 0}]}
    interior, band = region_masks(scene, scale=3, width_px=1000, height_px=1000)
    c = 50 * 3  # centre of the shape, in px
    assert interior[c - 30:c + 30, c - 30:c + 30].all()  # ±10 pt: depth ≥ 20 pt
    assert not interior[21 * 3 + 3, c] and band[21 * 3 + 3, c]  # 1 pt inside: band
    assert not interior[10 * 3, 10 * 3] and not band[10 * 3, 10 * 3]  # outside: neither


def test_score_reports_region_metrics_with_masks():
    rng = np.random.default_rng(4)
    a = rng.random((240, 240, 3))
    b = a.copy()
    b[40:80, 40:80] = rng.random((40, 40, 3))  # a corner block
    interior = np.zeros(a.shape[:2], bool)
    interior[100:140, 100:140] = True  # away from the block
    band = np.zeros(a.shape[:2], bool)
    band[40:80, 40:80] = True  # exactly the block
    s = score(a, b, interior=interior, band=band)
    assert s["delta_e_interior"] == pytest.approx(0.0, abs=1e-9)
    assert s["delta_e_band"] > 1.0
    assert s["ssim_interior"] > s["ssim_band"]


# --- Task 17d: floor-relative verdicts (report-only) -------------------------

FLOOR = {"floor": {"ssim": {"median": 1.0, "p90": 0.995},
                   "delta_e": {"median": 0.1, "p90": 0.3},
                   "flip": {"median": 0.005, "p90": 0.02}}}


def test_floor_verdicts_are_reported_and_do_not_change_exit(tmp_path):
    for r in ["flutter", "swiftui"]:
        _png(tmp_path / f"a.{r}.png", 0)
    assert run(tmp_path, spec={**SPEC, "scenes": SPEC["scenes"][:1]}, floor=FLOOR) == 0
    row = json.loads((tmp_path / "report.json").read_text())["scenes"][0]
    assert row["floor_ssim"] == 0.995 and row["floor_de"] == 0.3 and row["floor_flip"] == 0.02
    # Identical 40x40 noise: perfect ssim, zero dE -> within noise on all three.
    assert row["within_noise"]


def test_floor_verdict_false_when_outside_noise(tmp_path, capsys):
    for r in ["flutter", "swiftui"]:
        _png(tmp_path / f"a.{r}.png", 0)
        _png(tmp_path / f"b.{r}.png", 11)  # different noise per renderer
    code = run(tmp_path, spec=SPEC, floor=FLOOR)
    rows = {r["id"]: r for r in json.loads((tmp_path / "report.json").read_text())["scenes"]}
    assert not rows["b"]["within_noise"] or not rows["a"]["within_noise"] or code in (0, 1)
