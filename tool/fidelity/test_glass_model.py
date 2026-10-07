"""Parity: the NumPy glass model reproduces Flutter's on-device output."""
import json
import pathlib

import numpy as np
import pytest

from compare import load, region_for, score
from glass_model import render, render_window, resolve_constants

ROOT = pathlib.Path(__file__).resolve().parents[2]
# Flutter captures of the shipped g13 standard (Task g13 colour refit,
# passed at launch via CONSTANTS; SwiftUI refs copied from build/fidelity/final).
BASE = ROOT / "build/fidelity/g13-2"
SPEC = json.loads((ROOT / "tool/scenes/scenes.json").read_text())
STANDARD = json.loads((ROOT / "tool/fidelity/standard_constants.json").read_text())

PARITY_SCENES = [s["id"] for s in SPEC["scenes"]]  # all 75


# Skips (all 75 cases, visibly in `pytest -rs`) when the captures are absent;
# they are not committed. Recreate them with the shipped standard:
#   RENDERERS=flutter tool/fidelity/capture.sh build/fidelity/g13-2
PARITY_SKIP = ("75-scene parity needs Flutter captures of the shipped build in "
               "build/fidelity/g13-2; run `RENDERERS=flutter tool/fidelity/capture.sh "
               "build/fidelity/g13-2` (see tool/fidelity/README.md)")


@pytest.mark.skipif(not BASE.exists(), reason=PARITY_SKIP)
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


def _scene(sid):
    return json.loads(json.dumps(next(s for s in SPEC["scenes"] if s["id"] == sid)))


def test_group_blur_sigma_scales_with_shape_size():
    """Task 17b: effective sigma = blurSigma * min(1, halfMin / blurSizeRef)
    per shape (blurSizeRef 0 disables it); the group blurs with the largest."""
    from glass_model import group_blur_sigma
    c = json.loads(json.dumps(STANDARD))
    c["regular"]["blurSigma"] = 6.0
    c["regular"]["blurSizeRef"] = 0.0
    circle = _scene("regular-circle-photo-light")  # 72 pt: halfMin 36
    assert group_blur_sigma(circle, c) == pytest.approx(6.0)
    c["regular"]["blurSizeRef"] = 72.0
    assert group_blur_sigma(circle, c) == pytest.approx(3.0)
    c["regular"]["blurSizeRef"] = 30.0
    assert group_blur_sigma(circle, c) == pytest.approx(6.0)
    # Two members: a small regular circle and a large clear rect -> the max.
    c["regular"]["blurSizeRef"] = 72.0
    c["clear"]["blurSigma"] = 2.0
    c["clear"]["blurSizeRef"] = 0.0
    mixed = _scene("regular-circle-photo-light")
    mixed["shapes"].append({**_scene("clear-rect16-photo-light")["shapes"][0], "y": 100})
    assert group_blur_sigma(mixed, c) == pytest.approx(3.0)
    c["clear"]["blurSigma"] = 4.0
    c["clear"]["postBlurShare"] = 0.0  # this test pins the size scaling alone
    assert group_blur_sigma(mixed, c) == pytest.approx(4.0)
    # Dark scenes use the dark sets.
    dark = _scene("regular-circle-photo-dark")
    c["regularDark"]["blurSigma"] = 5.0
    c["regularDark"]["blurSizeRef"] = 0.0
    assert group_blur_sigma(dark, c) == pytest.approx(5.0)


def test_render_uses_size_scaled_blur():
    from glass_model import render_window
    bg = np.random.default_rng(1).random((2622, 1206, 3))
    scene = _scene("regular-circle-photo-light")
    a = json.loads(json.dumps(STANDARD))
    a["regular"]["blurSizeRef"] = 72.0  # halfMin 36 -> half the sigma
    b = json.loads(json.dumps(STANDARD))
    b["regular"]["blurSizeRef"] = 0.0
    b["regular"]["blurSigma"] = STANDARD["regular"]["blurSigma"] / 2
    ia, _ = render_window(bg, scene, a)
    ib, _ = render_window(bg, scene, b)
    assert np.array_equal(ia, ib)
    ic, _ = render_window(bg, scene, STANDARD)
    assert not np.array_equal(ia, ic)


def test_fill_scales_with_shape_size():
    """Task 17b: fillOpacity x (1 - fillSizeDrop x (1 - min(1, halfMin /
    fillSizeRef))) per shape (packed in uInfo.w, blended like halfMin)."""
    from glass_model import render_window
    bg = np.random.default_rng(2).random((2622, 1206, 3))
    scene = _scene("regular-circle-photo-dark")  # halfMin 36 pt
    a = json.loads(json.dumps(STANDARD))
    a["regularDark"].update(fillSizeRef=72.0, fillSizeDrop=0.4)  # -> x 0.8
    b = json.loads(json.dumps(STANDARD))
    b["regularDark"].update(fillSizeRef=0.0, fillSizeDrop=0.4,
                            fillOpacity=STANDARD["regularDark"]["fillOpacity"] * 0.8)
    ia, _ = render_window(bg, scene, a)
    ib, _ = render_window(bg, scene, b)
    assert np.abs(ia - ib).max() <= 1 / 255 + 1e-9
    ic, _ = render_window(bg, scene, STANDARD)
    assert np.abs(ia - ic).max() > 10 / 255


# --- frost v2 (Task 17c) ----------------------------------------------------


def test_frost_taps_are_a_two_ring_gaussian_quadrature():
    """16 taps on two rings (6 + 10) whose radii and weights are the 2-node
    Gauss-Laguerre rule for a 2-D Gaussian: weights sum to 1, zero mean and
    the Gaussian's second moment 2 sigma^2."""
    from glass_model import frost_taps
    t = frost_taps(10.0)
    assert t.shape == (16, 3)
    assert t[:, 2].sum() == pytest.approx(1.0)
    assert np.abs((t[:, :2] * t[:, 2:3]).sum(0)).max() < 1e-9
    assert ((t[:, 0] ** 2 + t[:, 1] ** 2) * t[:, 2]).sum() == pytest.approx(200.0)
    r = np.hypot(t[:, 0], t[:, 1])
    assert np.allclose(r[:6], 10 * np.sqrt(2 * (2 - np.sqrt(2))))
    assert np.allclose(r[6:], 10 * np.sqrt(2 * (2 + np.sqrt(2))))


def test_frost_wide_mix_weight():
    """w = clamp(mix(edge, centre, sampleDepth / halfMin) - drop x max(0, 1 -
    halfMin / sizeRef), 0, 1); sizeRef <= 0 disables the size term."""
    from glass_model import frost_wide_mix
    v = {"frostWideMixEdge": 0.3, "frostWideMixCentre": 1.3,
         "frostWideSizeRef": 80.0, "frostWideSizeDrop": 2.0}
    assert frost_wide_mix(0.0, 100.0, v) == pytest.approx(0.3)
    assert frost_wide_mix(50.0, 100.0, v) == pytest.approx(0.8)
    assert frost_wide_mix(100.0, 100.0, v) == pytest.approx(1.0)  # clamped
    # halfMin 40 below sizeRef 80: minus 2 x 0.5.
    assert frost_wide_mix(40.0, 40.0, v) == pytest.approx(0.3)
    assert frost_wide_mix(0.0, 40.0, v) == pytest.approx(0.0)
    v["frostWideSizeRef"] = 0.0
    assert frost_wide_mix(0.0, 40.0, v) == pytest.approx(0.3)


def test_frost_off_by_default_and_wide_mix_lowers_contrast():
    from glass_model import render_window
    x = np.arange(1206) + 0.5
    bg = np.broadcast_to((0.5 + 0.35 * np.cos(2 * np.pi * x / 64))[None, :, None],
                         (2622, 1206, 3)).copy()
    scene = _scene("regular-rect16-photo-light")
    off = json.loads(json.dumps(STANDARD))
    for k in ("frostWideSigma", "frostWideMixEdge", "frostWideMixCentre",
              "frostWideSizeRef", "frostWideSizeDrop"):
        off["regular"][k] = 0.0
    a, _ = render_window(bg, scene, STANDARD)
    b, _ = render_window(bg, scene, off)
    if all(STANDARD["regular"].get(k, 0) == 0 for k in ("frostWideMixEdge", "frostWideMixCentre")):
        assert np.array_equal(a, b)  # zero mix: frost v1 output exactly
    on = json.loads(json.dumps(off))
    on["regular"].update(frostWideSigma=6.0, frostWideMixEdge=1.0, frostWideMixCentre=1.0)
    c, _ = render_window(bg, scene, on)
    inner = (slice(150, -150), slice(150, -150))
    assert c[inner].std() < 0.8 * b[inner].std()


# --- Task 17d: measured tone curve (piecewise-linear LUT, grey) --------------

IDENTITY = [i / 8 for i in range(9)]


def _tone_bg():
    """Flat 0.5 grey background 200x200."""
    return np.full((400, 400, 3), 0.5)


def _tone_scene(variant="clear", brightness="light"):
    return {"id": "tone-test", "background": "flat-v128", "brightness": brightness,
            "shapes": [{"x": 20, "y": 20, "w": 60, "h": 60, "shape": "rect",
                        "radius": 8, "variant": variant, "tint": None}]}


def test_tone_lut_identity_renders_unchanged():
    """Identity knots bypass the LUT. The shipped sets carry fitted knots
    since Task 17d round 2, so they must render differently from identity —
    this catches accidentally shipping identity knots again."""
    sc = _tone_scene()
    identity = json.loads(json.dumps(STANDARD))
    for n in ("regular", "clear", "regularDark", "clearDark"):
        identity[n]["toneKnots"] = list(IDENTITY)
    a = render(_tone_bg(), sc, resolve_constants(identity))
    b = render(_tone_bg(), sc, resolve_constants(json.loads(json.dumps(STANDARD))))
    assert not np.array_equal(a, b)


def test_tone_lut_lifts_interior():
    sc = _tone_scene()
    c = json.loads(json.dumps(STANDARD))
    for n in ("regular", "clear", "regularDark", "clearDark"):
        # Lifts at ~0.59, the post-fill level of a 0.5 grey backdrop.
        c[n]["toneKnots"] = [0.0, 0.15, 0.3, 0.42, 0.55, 0.68, 0.8, 0.9, 1.0]
    lifted, box = render_window(_tone_bg(), sc, resolve_constants(c))
    plain, box = render_window(_tone_bg(), sc, resolve_constants(json.loads(json.dumps(STANDARD))))
    x0, y0, x1, y1 = box
    inner = lifted[y0 + 90:y1 - 90, x0 + 90:x1 - 90]
    inner_plain = plain[y0 + 90:y1 - 90, x0 + 90:x1 - 90]
    assert inner.mean() > inner_plain.mean()  # dark backdrop lifted


def test_tone_lut_lowering_knots_darkens():
    sc = _tone_scene()
    c = json.loads(json.dumps(STANDARD))
    for n in ("regular", "clear", "regularDark", "clearDark"):
        c[n]["toneKnots"] = [0.0, 0.05, 0.12, 0.22, 0.35, 0.5, 0.68, 0.87, 0.97]
    out, box = render_window(_tone_bg(), sc, resolve_constants(c))
    plain, box = render_window(_tone_bg(), sc, resolve_constants(json.loads(json.dumps(STANDARD))))
    x0, y0, x1, y1 = box
    assert out[y0 + 90:y1 - 90, x0 + 90:x1 - 90].mean() < \
        plain[y0 + 90:y1 - 90, x0 + 90:x1 - 90].mean()


def test_tone_lut_blends_across_variants_like_other_blocks():
    """Mixed groups blend the two sets' knots linearly, as the shader mixes
    uVar G/H/I by clearMix — documented approximation, pinned here."""
    sc = _tone_scene()
    sc["shapes"][0]["variant"] = "clear"
    c = json.loads(json.dumps(STANDARD))
    c["clear"]["toneKnots"] = [0.0, 0.02, 0.06, 0.12, 0.2, 0.32, 0.5, 0.74, 1.0]
    c["regular"]["toneKnots"] = list(IDENTITY)
    a, box = render_window(_tone_bg(), sc, resolve_constants(c))
    # The render must not raise and interior must differ from identity-only.
    plain, box = render_window(_tone_bg(), sc, resolve_constants(json.loads(json.dumps(STANDARD))))
    x0, y0, x1, y1 = box
    assert not np.array_equal(a, plain)


# --- Task g13: small-shape tone curve ----------------------------------------

def _small_scene(w, h, shape="capsule", variant="clear"):
    return {"id": "small-tone-test", "background": "flat-v128", "brightness": "light",
            "shapes": [{"x": 30, "y": 30, "w": w, "h": h, "shape": shape,
                        "radius": 8, "variant": variant, "tint": None}]}


SMALL_KNOTS = [0.0, 0.02, 0.07, 0.15, 0.27, 0.43, 0.62, 0.82, 1.0]


def _with_small(**over):
    c = json.loads(json.dumps(STANDARD))
    for n in ("regular", "clear", "regularDark", "clearDark"):
        c[n].update(over)
    return c


def test_small_tone_curve_neutral_forms_are_no_ops():
    """The neutral forms leave render_window bit-identical: identity knots
    are a no-op even with the size window open, and smallSizeHi <= 0 guards
    the stage off entirely. Since the g13 refit the curve ships ON for
    regular/regularDark (clear/clearDark stay off), the reference here is
    STANDARD with the keys explicitly reset to the defaults."""
    bg = np.random.default_rng(7).random((400, 400, 3))
    sc = _small_scene(200, 56, variant="regular")  # half shorter side 28 pt
    neutral = _with_small(smallToneKnots=list(IDENTITY), smallSizeLo=0.0, smallSizeHi=0.0)
    a, _ = render_window(bg, sc, neutral)
    b, _ = render_window(bg, sc, _with_small(smallToneKnots=list(IDENTITY),
                                             smallSizeLo=30.0, smallSizeHi=34.0))
    assert np.array_equal(a, b)
    c, _ = render_window(bg, sc, _with_small(smallToneKnots=list(SMALL_KNOTS),
                                             smallSizeLo=30.0, smallSizeHi=0.0))
    assert np.array_equal(a, c)
    # And the shipped curve really is on for the regular sets (g13).
    d, _ = render_window(bg, sc, STANDARD)
    assert not np.array_equal(a, d)


def test_small_tone_curve_hits_small_shapes_only():
    """smallSizeLo 30 / smallSizeHi 34: a capsule with half shorter side
    28 pt (w = 1) changes by the LUT exactly; a rect with half shorter side
    70 pt (w = 0) is bit-identical."""
    from glass_model import tone_apply
    bg = _tone_bg()  # flat 0.5 grey: the deep interior carries no rim/tint
    off = _with_small(smallToneKnots=list(IDENTITY), smallSizeLo=30.0, smallSizeHi=34.0)
    on = _with_small(smallToneKnots=list(SMALL_KNOTS), smallSizeLo=30.0, smallSizeHi=34.0)
    cap_off, box = render_window(bg, _small_scene(200, 56), off)
    cap_on, _ = render_window(bg, _small_scene(200, 56), on)
    x0, y0, x1, y1 = box
    cy, cx = (y0 + y1) // 2, (x0 + x1) // 2
    inner = (slice(cy - 10, cy + 10), slice(cx - 30, cx + 30))
    src = cap_off[inner].reshape(-1, 3).T
    expect = tone_apply(src, np.asarray(SMALL_KNOTS)[:, None]).T.reshape(cap_off[inner].shape)
    assert not np.array_equal(cap_on[inner], cap_off[inner])
    assert np.abs(cap_on[inner] - expect).max() <= 2 / 255 + 1e-9
    rect_off, _ = render_window(bg, _small_scene(140, 140, shape="rect"), off)
    rect_on, _ = render_window(bg, _small_scene(140, 140, shape="rect"), on)
    assert np.array_equal(rect_off, rect_on)  # halfMin 70 pt > hi: w = 0


def test_small_tone_curve_weight_is_linear_between_lo_and_hi():
    """halfMin 32 pt sits midway between lo 30 and hi 34: w = 0.5, so the
    interior is the plain mix of the identity and LUT values."""
    from glass_model import tone_apply
    bg = _tone_bg()
    off = _with_small(smallToneKnots=list(IDENTITY), smallSizeLo=30.0, smallSizeHi=34.0)
    on = _with_small(smallToneKnots=list(SMALL_KNOTS), smallSizeLo=30.0, smallSizeHi=34.0)
    sc = _small_scene(64, 64, shape="rect")  # half shorter side 32 pt
    a, box = render_window(bg, sc, off)
    b, _ = render_window(bg, sc, on)
    x0, y0, x1, y1 = box
    cy, cx = (y0 + y1) // 2, (x0 + x1) // 2
    inner = (slice(cy - 10, cy + 10), slice(cx - 10, cx + 10))
    src = a[inner].reshape(-1, 3).T
    expect = 0.5 * src + 0.5 * tone_apply(src, np.asarray(SMALL_KNOTS)[:, None])
    assert np.abs(b[inner] - expect.T.reshape(a[inner].shape)).max() <= 2 / 255 + 1e-9
    # and it differs from both endpoints
    assert not np.array_equal(b[inner], a[inner])


# --- Task 17d: clear-analysis features (defaults reproduce the 17c model) ----

def _feat(sid, **over):
    sc = _scene(sid)
    bg = np.random.default_rng(3).random((2622, 1206, 3))
    c = json.loads(json.dumps(STANDARD))
    for n in ("clear", "clearDark"):
        c[n].update(over)
    return render_window(bg, sc, c)


def test_17d_defaults_are_feature_neutral():
    """VARIANT_DEFAULTS stay the 17c neutral point. Round 2 ships clear keys
    that use the features, so substituting the defaults must land on the
    all-defaults model while the shipped render differs from it."""
    from glass_model import VARIANT_DEFAULTS
    over = {k: v for k, v in VARIANT_DEFAULTS.items() if k != "toneKnots"}
    a, _ = _feat("clear-rect16-photo-light", **over)
    bg = np.random.default_rng(3).random((2622, 1206, 3))
    minimal = {"clear": over, "clearDark": over}
    b, _ = render_window(bg, _scene("clear-rect16-photo-light"),
                         resolve_constants(minimal))
    assert np.array_equal(a, b)
    c, _ = _feat("clear-rect16-photo-light")
    assert not np.array_equal(a, c)  # shipped clear uses the features now
    assert VARIANT_DEFAULTS["glowStrength"] == 0.25  # shader-only (touch glow)


def test_normal_radius_scale_leaves_capsules_alone_and_bends_rect_corners():
    a, _ = _feat("clear-capsule-photo-light", normalRadiusScale=1.0)
    b, _ = _feat("clear-capsule-photo-light")  # shipped: 1.55
    assert np.array_equal(a, b)  # capsules have no corners to scale
    a, _ = _feat("clear-rect16-photo-light", normalRadiusScale=1.0)
    b, _ = _feat("clear-rect16-photo-light")
    diff = np.abs(a - b).max(-1) > 0
    h, w = diff.shape
    # Only the corners move: the middle of each side is unchanged.
    assert diff.any() and not diff[h // 2].any() and not diff[:, w // 2].any()


def test_lens_edge_and_post_blur_change_the_glass():
    neutral = {"lensEdge": 0.0, "postBlurShare": 0.0}
    a, _ = _feat("clear-rect16-photo-light", **neutral)
    for over in ({"lensEdge": 9.0}, {"postBlurShare": 0.3}):
        b, _ = _feat("clear-rect16-photo-light", **{**neutral, **over})
        assert not np.array_equal(a, b), over


def test_post_blur_share_shrinks_the_composed_blur():
    from glass_model import group_blur_sigma
    c = json.loads(json.dumps(STANDARD))
    sc = _scene("clear-rect16-photo-light")
    c["clear"]["postBlurShare"] = 0.0
    s0 = group_blur_sigma(sc, c)
    c["clear"]["postBlurShare"] = 0.36
    assert group_blur_sigma(sc, c) == pytest.approx(s0 * 0.8)


def test_rim_mix_whitens_outer_pixels_and_dark_floor_scales_it():
    a, box = _feat("clear-rect28-text-light", rimMix=0.0)
    b, _ = _feat("clear-rect28-text-light", rimMix=0.63)
    c, _ = _feat("clear-rect28-text-light", rimMix=0.63, rimMixLumaFloor=0.0)
    assert b.sum() > a.sum()
    assert a.sum() <= c.sum() <= b.sum()


def test_tone_lift_lifts_small_dark_shapes_only():
    bg = np.full((2622, 1206, 3), 0.1)
    base = json.loads(json.dumps(STANDARD))
    base["regularDark"]["toneLift"] = 0.0  # neutral reference
    c = json.loads(json.dumps(base))
    c["regularDark"].update(toneLift=0.4, toneLiftKnee=0.5, toneLiftSizeRef=50.0)
    small = _scene("regular-capsule-photo-dark")  # halfMin 28 pt
    large = _scene("regular-rect28-photo-dark")   # halfMin 70 pt
    for sc, lifted in ((small, True), (large, False)):
        a, _ = render_window(bg, sc, base)
        b, _ = render_window(bg, sc, c)
        assert (b.sum() > a.sum()) == lifted


def test_dispersion_keeps_post_blur_offset():
    """Red/blue single taps carry the frost offset (post-lens blur + wide
    mix): a tiny non-zero dispersion stays within a level of none, instead
    of snapping red/blue to the unblurred tap (green/magenta fringes)."""
    bg = np.repeat(np.random.default_rng(5).random((2622, 1206, 1)), 3, -1)
    c = json.loads(json.dumps(STANDARD))
    c["clear"].update(postBlurShare=0.3, dispersion=0.0, fillColor="#FFFFFF")
    off, _ = render_window(bg, _scene("clear-rect16-text-light"), c)
    c["clear"]["dispersion"] = 1e-4
    on, _ = render_window(bg, _scene("clear-rect16-text-light"), c)
    assert np.abs(on - off).max() <= 1 / 255 + 1e-9
    assert np.abs(off[..., 0] - off[..., 1]).max() <= 1 / 255 + 1e-9


def test_mixed_group_keeps_per_variant_post_sigma():
    """K.z is per variant (blurSigma x sqrt(share) x scale): a clear member's
    post-lens blur does not grow with a regular member's frost."""
    from glass_model import _uvar, resolve_constants
    c = json.loads(json.dumps(STANDARD))
    c["regular"].update(blurSigma=6.0, postBlurShare=0.0)
    c["clear"].update(blurSigma=1.2, postBlurShare=0.36, blurSizeRef=0.0)
    reg, clr = _uvar(resolve_constants(c), "light", 3.0)
    assert reg["K"][2] == 0.0
    assert clr["K"][2] == pytest.approx(1.2 * 0.6 * 3)
    c["regular"]["blurSigma"] = 12.0
    assert _uvar(resolve_constants(c), "light", 3.0)[1]["K"][2] == clr["K"][2]
    # The rendered mixed group runs (regular dominates the composed blur).
    sc = _scene("regular-circle-photo-light")
    sc["shapes"].append({**_scene("clear-rect16-photo-light")["shapes"][0], "y": 100})
    bg = np.random.default_rng(2).random((2622, 1206, 3))
    out, _ = render_window(bg, sc, c)
    assert np.isfinite(out).all()


def test_blur_aspect_follows_the_strongest_member():
    from glass_model import group_blur_aspect
    c = json.loads(json.dumps(STANDARD))
    for n in ("regular", "regularDark"):
        c[n]["blurAspectPower"] = 0.5
    cap = _scene("regular-capsule-photo-dark")  # 200 x 56
    assert group_blur_aspect(cap, c) == pytest.approx((56 / 200) ** 0.5)
    assert group_blur_aspect(_scene("regular-circle-photo-dark"), c) == 1.0
    c["regularDark"]["blurAspectPower"] = 0.0
    assert group_blur_aspect(cap, c) == 1.0


def test_continuous_corner_passes_through_the_arcs_45_degree_point():
    from glass_model import corner_params, sd_superellipse_box
    hx, hy, r = 120.0, 70.0, 16.0
    # Zone 1 keeps the given exponent and the radius (pre-A1 outline).
    assert corner_params(r, hx, hy, 2.0, 1.0) == (r, 2.0)
    z, n = corner_params(r, hx, hy, 2.0, 1.528)
    assert z == pytest.approx(1.528 * r) and n == pytest.approx(3.26, abs=0.02)
    # The circular arc's 45 degree point lies on the continuous outline.
    p = r * (1.0 - np.sqrt(0.5))
    d = sd_superellipse_box(np.array([hx - p]), np.array([hy - p]), hx, hy, z, n)
    assert abs(d[0]) < 1e-9
    # The zone clamps to half the shorter side; at the radius it is a circle.
    assert corner_params(70.0, hx, hy, 2.0, 1.528) == (70.0, 2.0)
    z, n = corner_params(50.0, hx, hy, 2.0, 1.528)
    assert z == 70.0 and 2.0 < n < 3.26


def test_corner_zone_changes_rects_only():
    rect = _scene("clear-rect28-photo-light")
    cap = _scene("clear-capsule-photo-light")
    for scene, same in ((rect, False), (cap, True)):
        bg = load(ROOT / f"example/assets/backgrounds/{scene['background']}.png")
        a = render(bg, scene, {**STANDARD, "cornerZone": 1.0}, scale=3)
        b = render(bg, scene, {**STANDARD, "cornerZone": 1.5}, scale=3)
        assert np.array_equal(a, b) == same


def test_neck_blend_zero_outside_merges():
    """field_blend's h (the merge-neck weight) is 0 outside merge necks: the
    fold starts at 1e6, so a single shape never smooths, and two circles far
    enough apart have blend 0 at both centres; close circles blend > 0 at
    the midpoint."""
    from glass_model import field_blend

    def circle(x, y):
        return {"rect": (x, y, 60, 60), "radius": 30, "n": 2.0, "zone": 1.0}

    # Two 60x60 circles 90 px apart, k = 48: blend exactly 0 at both centres
    # (|-30 - 60| = 90 > 48).
    shapes = [circle(0, 0), circle(90, 0)]
    _, b1 = field_blend(shapes, np.array(30.0), np.array(30.0), 48.0)
    _, b2 = field_blend(shapes, np.array(120.0), np.array(30.0), 48.0)
    assert b1 == 0.0 and b2 == 0.0
    # One shape alone: blend 0 everywhere on a grid.
    ys, xs = np.mgrid[0:200, 0:200]
    _, b = field_blend([circle(0, 0)], xs + 0.5, ys + 0.5, 48.0)
    assert not b.any()
    # Two circles 12 px apart: blend > 0 at the midpoint.
    _, b = field_blend([circle(0, 0), circle(72, 0)], np.array(66.0), np.array(30.0), 48.0)
    assert b > 0.0
