"""Coordinate-coded backgrounds and the lens-field decoder (Task 15c)."""
import json
import pathlib
import sys

import numpy as np
import pytest
from scipy.ndimage import gaussian_filter, map_coordinates

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool/scenes"))

import gen_backgrounds as gb  # noqa: E402
import measure_lens as ml  # noqa: E402

H, W = 160, 400  # small synthetic canvas


def code_stack(axis, h=H, w=W):
    """The 16 code backgrounds (as float images) on an h x w canvas."""
    return {name: np.asarray(gb.code(axis_, period, step, w, h), np.float64) / 255.0
            for name, (axis_, period, step) in gb.CODES.items() if axis_ == axis}


def test_code_set_is_two_axes_two_periods_four_steps():
    assert len(gb.CODES) == 16
    assert {p for _, p, _ in gb.CODES.values()} == {128, 160}
    img = np.asarray(gb.code("x", 128, 0, W, H), np.float64) / 255.0
    assert img.shape == (H, W, 3)
    assert np.all(img[..., 0] == img[..., 2])  # grey: R = G = B
    assert np.all(img[0] == img[-1])  # x code is constant down a column
    lo, hi = 0.5 - gb.CODE_AMP, 0.5 + gb.CODE_AMP
    assert img.min() >= lo - 1 / 255 and img.max() <= hi + 1 / 255
    # One period: value repeats every 128 px.
    assert np.allclose(img[0, :128], img[0, 128:256])


def test_decode_of_untouched_backgrounds_is_identity():
    xs = code_stack("x")
    ys = code_stack("y")
    dec = ml.decode({**xs, **ys})
    py, px = np.mgrid[0:H, 0:W] + 0.5
    assert np.abs(dec["sx"][..., 1] - px).max() < 0.15
    assert np.abs(dec["sy"][..., 1] - py).max() < 0.15


def _warp(img, sx, sy):
    """Samples img (pixel centres at i + 0.5) at (sx, sy), bilinear."""
    return np.stack([map_coordinates(img[..., c], [sy - 0.5, sx - 0.5], order=1, mode="nearest")
                     for c in range(3)], -1)


def test_decode_recovers_displacement_through_blur_affine_and_saturation():
    rng = np.random.default_rng(1)
    py, px = np.mgrid[0:H, 0:W] + 0.5
    # Smooth field with displacement up to 40 px (beyond a fine half period).
    dx = 40 * np.sin(px / 70.0) * np.cos(py / 50.0)
    dy = 25 * np.cos(px / 90.0)
    a = np.array([0.35, 0.40, 0.30])
    b = np.array([0.55, 0.50, 0.60])
    sat = 1.4
    sigma = 15.0
    out = {}
    for name, img in {**code_stack("x"), **code_stack("y")}.items():
        blurred = np.stack([gaussian_filter(img[..., c], sigma, mode="nearest") for c in range(3)], -1)
        col = _warp(blurred, px + dx, py + dy)
        luma = (col * [0.2126, 0.7152, 0.0722]).sum(-1, keepdims=True)
        col = luma + (col - luma) * sat
        col = col * a + b
        col = np.round(np.clip(col + rng.normal(0, 0.4 / 255, col.shape), 0, 1) * 255) / 255
        out[name] = col
    dec = ml.decode(out)
    m = (slice(30, -30), slice(60, -60))  # away from the clamped canvas edge
    for c in range(3):
        assert np.median(np.abs(dec["sx"][..., c] - (px + dx))[m]) < 0.3
        assert np.median(np.abs(dec["sy"][..., c] - (py + dy))[m]) < 0.3
        assert np.percentile(np.abs(dec["sx"][..., c] - (px + dx))[m], 99) < 1.5
    # The two periods' modulation ratio recovers the blur sigma.
    assert np.median(dec["sigma_x"][m]) == pytest.approx(sigma, abs=1.5)
    # Linearity residual is near zero for an affine pipeline.
    assert np.median(np.abs(dec["resid_x"][m])) < 0.05


def test_measure_scene_matrix():
    spec = json.loads((ROOT / "tool/scenes/measure.json").read_text())
    ids = [s["id"] for s in spec["scenes"]]
    lens_bases = {
        f"{v}-{s}-light" for v in ("regular", "clear")
        for s in ("capsule", "circle", "rect16", "rect28")} | {
        "regular-capsule-dark", "clear-capsule-dark"} | {
        f"{v}-rect16-s{h}-light" for v in ("regular", "clear") for h in (20, 50, 100, 150)}
    # Task 17c: dark size series (x codes only) and tone flats.
    dark_bases = {f"{v}-{s}-dark" for v in ("regular", "clear")
                  for s in ("circle", "rect16", "rect16-s20", "rect16-s50", "rect16-s100",
                            "rect16-s150")}
    tone_bases = {f"{v}-{s}-{b}" for v in ("regular", "clear") for s in ("rect16", "capsule")
                  for b in ("light", "dark")}
    # Class probes: 9 probe shapes x 2 appearances over mid grey, the capsule
    # over 7 fine flats x 2, 4 circle extremes, 3 merge pairs x 2.
    probe_bases = {f"regular-{s}-{b}" for b in ("light", "dark") for s in (
        "circle56", "circle60", "circle64", "circle68", "capsule60", "capsule64",
        "capsule68", "capsule72", "rect16-124x60", "merge4", "merge16", "merge30")}
    # Task 9 adds rect16 x {regular, clear} x {light, dark} over the four
    # rotated gradients (bases shared with the lens scenes, new backgrounds).
    assert len(ids) == len(set(ids)) == 18 * 28 + 12 * 20 + 8 * 16 + 18 + 14 + 4 + 6 + 16
    # The Task 15c / 17b scenes keep their ids and order.
    assert ids[:18 * 16] == [f"{b}--{c}" for b in dict.fromkeys(
        i.split("--")[0] for i in ids[:18 * 16]) for c in gb.CODES]
    bases = {i.split("--")[0] for i in ids}
    assert bases == lens_bases | dark_bases | tone_bases | probe_bases | {
        "regular-circle-light", "regular-circle-dark"}
    for b in lens_bases:
        assert {f"{b}--{c}" for c in [*gb.CODES, *gb.FROST_CODES]} <= set(ids)
    for b in dark_bases:
        assert {f"{b}--{c}" for c in [*gb.CODES, *gb.FROST_CODES] if c.startswith("code-x")} \
            <= set(ids)
    for b in tone_bases:
        assert {f"{b}--{c}" for c in gb.FLATS} <= set(ids)
    # Size series (Task 17b): half the shorter side is the named size, and the
    # decode window (shape + 16 pt) stays on the 402 x 874 pt screen.
    for s in spec["scenes"]:
        sh = s["shapes"][0]
        if "-s" in s["id"].split("--")[0].split("rect16")[-1]:
            assert min(sh["w"], sh["h"]) / 2 == int(s["id"].split("-s")[1].split("-")[0])
        assert sh["x"] >= 16 and sh["y"] + sh["h"] + 16 <= 874 and sh["x"] + sh["w"] + 16 <= 402
    assert {s["background"] for s in spec["scenes"]} == \
        set(gb.CODES) | set(gb.FROST_CODES) | set(gb.FLATS) | set(gb.PROBE_FLATS) \
        | {f"gradient-r{d:03d}" for d in gb.GRADIENT_DEGREES}


def test_shape_geometry_depth_and_normal():
    shape = {"x": 10, "y": 20, "w": 100, "h": 40, "shape": "capsule", "radius": 0}
    g = ml.shape_geometry(shape, scale=1, px=np.array([60.0, 60.0, 10.5]),
                          py=np.array([20.5, 40.0, 40.0]))
    assert g["depth"] == pytest.approx([0.5, 20.0, 0.5], abs=1e-6)
    assert g["nx"][0] == pytest.approx(0, abs=1e-6) and g["ny"][0] == pytest.approx(-1)
    assert g["nx"][2] == pytest.approx(-1)


def test_lens_v3_profile_shape():
    from glass_model import lens_v3
    d = np.array([0.0, 10.0, 54.0, 80.0])
    # Large shape: unscaled profile, -A at the edge, 0 at and beyond the band.
    v = lens_v3(d, half_min=300.0, amp=140.0, decay=19.0, band=54.0, size_ref=115.0)
    assert v[0] == pytest.approx(-140.0)
    assert -140 < v[1] < -50
    assert v[2] == pytest.approx(0.0, abs=1e-9) and v[3] == 0.0
    # Shapes smaller than size_ref get a geometrically similar, smaller lens.
    s = 57.5 / 115.0
    small = lens_v3(d * s, half_min=57.5, amp=140.0, decay=19.0, band=54.0, size_ref=115.0)
    assert small == pytest.approx(v * s)
    # size_ref 0 disables the scaling.
    assert lens_v3(d, 10.0, 140.0, 19.0, 54.0, 0.0) == pytest.approx(v)


def test_fit_lens_recovers_synthetic_parameters():
    from glass_model import lens_v3
    rng = np.random.default_rng(2)
    samples = []
    for half in (84.0, 108.0, 210.0):
        depth = rng.uniform(2, half, 4000)
        dn = lens_v3(depth, half, 141.0, 19.3, 54.0, 115.0) + rng.normal(0, 0.5, depth.size)
        samples.append((depth, np.full(depth.size, half), dn))
    p = ml.fit_lens(samples)
    assert p["amp"] == pytest.approx(141.0, rel=0.02)
    assert p["decay"] == pytest.approx(19.3, rel=0.03)
    assert p["band"] == pytest.approx(54.0, rel=0.03)
    assert p["size_ref"] == pytest.approx(115.0, rel=0.03)
    assert p["rms"] < 0.7


def test_field_samples_drop_fringe_order_disagreements(tmp_path):
    n = 10
    depth = np.full((1, n), 5.0)
    gap = np.zeros((1, n, 3))
    gap[0, :4, 1] = 40.0  # > P1/4: the two periods disagree on these
    np.savez(tmp_path / "f.npz", px=np.zeros((1, n)), py=np.zeros((1, n)),
             sx=np.zeros((1, n, 3)), sy=np.zeros((1, n, 3)), depth=depth,
             nx=np.ones((1, n)), ny=np.zeros((1, n)), corner=np.zeros((1, n), bool),
             clipped=np.zeros((1, n), bool), amp=np.ones((1, n)), gap=gap)
    d, h, dn = ml.field_samples(tmp_path / "f.npz", 50.0, False, stride=1)
    assert d.size == n - 4


def test_fit_lens_finds_a_knee_near_the_smallest_shape():
    """Clear glass scales only below ~87 px half-size (Task 17b size series);
    from the default start the solver fell into size_ref ~ 10 px (rms 3.7)."""
    from glass_model import lens_v3
    rng = np.random.default_rng(3)
    samples = []
    for half in (60.0, 84.0, 108.0, 150.0, 210.0, 300.0, 450.0):
        depth = rng.uniform(2, half, 4000)
        dn = lens_v3(depth, half, 141.0, 19.6, 55.7, 86.6) + rng.normal(0, 0.5, depth.size)
        # A few rim outliers, as in the device fields.
        dn[:40] += rng.normal(0, 60, 40)
        samples.append((depth, np.full(depth.size, half), dn))
    # Started below every shape's half-size, size_ref has no gradient (s = 1
    # everywhere); fit_lens must restart from several knees and keep the best.
    p = ml.fit_lens(samples, x0=(140.0, 19.0, 55.0, 3.0))
    assert p["size_ref"] == pytest.approx(86.6, rel=0.05)
    assert p["amp"] == pytest.approx(141.0, rel=0.02)
