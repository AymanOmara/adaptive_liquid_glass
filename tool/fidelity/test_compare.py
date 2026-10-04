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
