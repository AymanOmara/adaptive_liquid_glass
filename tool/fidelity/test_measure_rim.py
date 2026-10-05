"""Synthetic-rim tests for measure_rim.py (Task 9).

Builds full-screen frames = a rotated gradient background plus an additive
ring around the rect16 outline whose brightness follows a known azimuthal
pattern, then checks the decode pipeline:

  * a FIXED pattern (peak up-left, like the model's light angle) must give
    identical profiles across the four gradient rotations -> fixed-light;
  * a CONTENT pattern (ring brightness tracks the backdrop luminance under
    it) must rotate with the gradient -> content-following;
  * content coupling one ring deeper (the control ring, where the lens and
    frost couple to content but no rim highlight is) must not by itself
    produce a content-following rim verdict.

Azimuth convention under test: 0 deg = the rim faces screen-up, 90 deg =
screen-right, clockwise. Physical px (x3) throughout; the shape is the
240x140 pt radius-16 rect of measure.json.
"""
import pathlib
import sys

import numpy as np
import pytest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "tool/scenes"))
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import measure_lens as ml  # noqa: E402
import measure_rim as mr  # noqa: E402

RECT16 = {"w": 240, "h": 140, "shape": "rect", "radius": 16,
          "x": 81.0, "y": 560, "variant": "regular", "tint": None}


def shape_for(rotation):
    return {**RECT16, "_background": f"gradient-r{rotation:03d}"}


def synth_frame(shape, rings):
    """Background + additive rings: each (depth_lo, depth_hi] physical px
    inside the outline gets `brightness(az_deg, backdrop_luma)` added."""
    bg = ml.load(mr.BG_DIR / f"{shape['_background']}.png")
    x0, y0, x1, y1 = mr._window(shape)
    py, px = np.mgrid[y0:y1, x0:x1] + 0.5
    g = ml.shape_geometry(shape, mr.SCALE, px, py)
    az = mr.azimuth_deg(g["nx"], g["ny"])
    luma = (bg[y0:y1, x0:x1] * mr.LUMA).sum(-1)
    frame = bg.copy()
    win = frame[y0:y1, x0:x1]
    for lo, hi, fn in rings:
        m = (g["depth"] > lo) & (g["depth"] <= hi)
        win[m] = np.clip(win[m] + fn(az[m], luma[m])[..., None], 0.0, 1.0)
    return frame


def fixed_pattern(az, luma):
    """Peak where the rim faces up-left (315 deg), like the model's light."""
    return 0.4 * (0.5 + 0.5 * np.cos(np.radians(az - 315.0)))


def content_pattern(az, luma):
    """Brighter where the backdrop under the rim is brighter."""
    return 0.4 * luma


def per_rotation(rings_fn):
    return {str(r): mr.rim_profiles(synth_frame(shape_for(r), rings_fn(r)), shape_for(r))
            for r in mr.ROTATIONS}


def test_azimuth_convention_up_and_right():
    # The rim faces screen-up on the top edge, right on the right edge.
    sh = shape_for(0)
    x0, y0, x1, y1 = mr._window(sh)
    py, px = np.mgrid[y0:y1, x0:x1] + 0.5
    g = ml.shape_geometry(sh, mr.SCALE, px, py)
    az = mr.azimuth_deg(g["nx"], g["ny"])
    m = (g["depth"] > 0) & (g["depth"] <= mr.RIM_PX) & ~g["corner"]
    top = m & (g["ny"] < -0.999)
    right = m & (g["nx"] > 0.999)
    assert np.median(az[top]) % 360 == pytest.approx(0.0, abs=1e-9)
    assert np.median(az[right]) == pytest.approx(90.0, abs=1e-9)


def test_profile_bins_the_azimuth():
    sh = shape_for(0)
    frame = synth_frame(sh, [(0.0, mr.RIM_PX,
                              lambda az, luma: 0.1 * (az < 10.0).astype(float))])
    p = mr.rim_profiles(frame, sh)["rim"]
    assert p["n"] > 0
    assert np.nanmax(p["diff"]) == pytest.approx(0.1, abs=1e-6)
    # Bins away from [0, 10 deg) see only the unmodified background.
    assert np.nanmin(p["diff"]) == pytest.approx(0.0, abs=1e-6)


def test_backdrop_luma_profiles_rotate_with_the_gradient():
    shap = {r: shape_for(r) for r in mr.ROTATIONS}
    per = {str(r): mr.rim_profiles(ml.load(mr.BG_DIR / f"{s['_background']}.png"), s)
           for r, s in shap.items()}
    c = mr.compare_rotations(per, "rim")
    h = c["bg_harmonics"]
    # The ramp's luma FALLS toward its "light" end (green drops 180 -> 80
    # while red only rises 30 -> 230), so the luminance maximum is at the
    # dark-colour end: r000 top (0), r090 left (270), r180 bottom (180),
    # r270 right (90).
    assert h[0]["phase_deg"] == pytest.approx(0.0, abs=5.0)
    assert h[90]["phase_deg"] == pytest.approx(270.0, abs=5.0)
    assert h[180]["phase_deg"] == pytest.approx(180.0, abs=5.0)
    assert h[270]["phase_deg"] == pytest.approx(90.0, abs=5.0)
    # The horizontal rotations modulate more: the shape spans 240 of 402 pt
    # across but only 140 of 874 pt down the screen (measured ~3.9x).
    assert h[90]["amp"] > 2.5 * h[0]["amp"]


def test_fixed_light_synthetic():
    c = mr.compare_rotations(per_rotation(lambda r: [(0.0, mr.RIM_PX, fixed_pattern)]), "rim")
    v = mr.verdict({"rim": c, "control": c}, None)
    assert c["median_pair_corr_zero_shift"] > 0.99
    assert c["fixed_fraction"] > 0.95
    assert abs(c["median_corr_with_backdrop"]) < 0.5
    assert v["verdict"] == "fixed-light"


def test_content_following_synthetic():
    c = mr.compare_rotations(per_rotation(lambda r: [(0.0, mr.RIM_PX, content_pattern)]), "rim")
    v = mr.verdict({"rim": c, "control": c}, None)
    assert c["median_corr_with_backdrop"] > 0.9
    assert c["fixed_fraction"] < 0.4
    assert v["verdict"] == "content-following"
    # Adjacent rotations align once shifted by the 90-deg gradient step.
    for s in c["adjacent_pair_best_shift"]:
        assert abs(s["shift_bins"]) in (9, 27)  # +-90 deg at 36 bins
        assert s["corr"] > 0.9


def test_control_ring_content_does_not_make_the_rim_content_following():
    # A fixed rim pattern plus content coupling one ring deeper (the lens /
    # frost floor): the rim verdict stays fixed-light even though the
    # control ring's profile tracks the backdrop.
    def rings(_r):
        return [(0.0, mr.RIM_PX, fixed_pattern), (*mr.RINGS["control"], content_pattern)]

    per = per_rotation(rings)
    rim = mr.compare_rotations(per, "rim")
    v = mr.verdict({"rim": rim, "control": mr.compare_rotations(per, "control")}, None)
    assert rim["median_pair_corr_zero_shift"] > 0.99
    assert rim["fixed_fraction"] > 0.95
    assert v["verdict"] == "fixed-light"
    ctrl = mr.compare_rotations(per, "control")
    assert ctrl["median_corr_with_backdrop"] > 0.9


def test_magenta_capture_refuses_to_score():
    magenta = np.ones((100, 100, 3))
    magenta[..., 1] = 0.0
    with pytest.raises(SystemExit):
        mr.assert_not_magenta(magenta, "synthetic")


def test_best_shift_finds_the_offset():
    a = np.cos(np.radians(np.arange(36) * 10.0))
    k, v = mr.best_shift(a, np.roll(a, 9))
    assert k in (9, 27)
    assert abs(v) > 0.99
