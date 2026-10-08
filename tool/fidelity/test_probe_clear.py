"""Guard experiment verdicts against model/device score confusion."""
import numpy as np
import pytest

from glass_model import render_window, resolve_constants
from probe_clear import apply_candidate, evaluate


def test_reference_cache_releases_full_screenshot(monkeypatch):
    import fit
    frame = np.ones((200, 200, 3))
    scene = {"id": "cache-probe", "background": "test", "shapes": [
        {"x": 20, "y": 20, "w": 20, "h": 20}]}
    monkeypatch.setattr(fit, "SPEC", {"scenes": [scene]})
    monkeypatch.setattr(fit, "_DATA", {})
    monkeypatch.setattr(fit, "load", lambda path: frame)
    fit._load(["cache-probe"])
    _, _, crop, _, box = fit._DATA["cache-probe"]
    x0, y0, x1, y1 = box
    assert np.array_equal(crop, frame[y0:y1, x0:x1])
    assert not np.shares_memory(crop, frame)


def test_baseline_prediction_reproduces_captured_verdict():
    baseline = {"a": (0.975, 1.9), "b": (0.982, 1.0)}
    captured = {"a": {"ssim": 0.968, "delta_e": 2.02, "pass": False},
                "b": {"ssim": 0.978, "delta_e": 1.1, "pass": True}}
    out = evaluate([("a", 0.975, 1.9), ("b", 0.982, 1.0)], baseline, captured)
    assert out["model_passed"] == 2
    assert out["predicted_device_passed"] == 1
    assert not out["worth_device_validation"]


def test_lost_pass_disqualifies_candidate_even_with_new_gain():
    baseline = {"a": (0.965, 1.0), "b": (0.98, 1.0)}
    captured = {"a": {"ssim": 0.965, "delta_e": 1.0, "pass": False},
                "b": {"ssim": 0.98, "delta_e": 1.0, "pass": True}}
    out = evaluate([("a", 0.975, 1.0), ("b", 0.969, 1.0)], baseline, captured)
    assert out["safe_gains"] == 1 and out["lost_passes"] == 1
    assert not out["worth_device_validation"]


def test_marginal_crossing_does_not_count_as_safe_gain():
    captured = {"a": {"ssim": 0.969, "delta_e": 1.99, "pass": False}}
    out = evaluate([("a", 0.9702, 1.99)], {"a": (0.969, 1.99)}, captured)
    assert out["predicted_device_passed"] == 1 and out["safe_gains"] == 0


def test_candidate_never_mutates_regular_or_source_constants():
    base = resolve_constants({})
    patch = {"both": {"blurSigma": 2.1}}
    out = apply_candidate(base, patch)
    assert out["regular"] == base["regular"]
    assert out["clear"]["blurSigma"] == out["clearDark"]["blurSigma"] == 2.1
    assert base["clear"]["blurSigma"] != 2.1
    with pytest.raises(ValueError, match="Unsupported"):
        apply_candidate(base, {"regular": {"blurSigma": 2.1}})


def test_disabled_research_flags_preserve_shipped_render():
    scene = {"id": "probe", "brightness": "light", "shapes": [
        {"shape": "rect", "x": 20, "y": 20, "w": 60, "h": 50,
         "radius": 12, "variant": "clear"}]}
    bg = np.random.default_rng(13).random((100, 100, 3))
    base = resolve_constants({})
    actual, box = render_window(bg, scene, base, scale=1)
    neutral = apply_candidate(base, {"_frostDepthMix": 0, "_postIsotropic": 0,
                                     "_postSecondOrder": False, "_wideGH": 0,
                                     "_wideExact": False, "_lensDepthField": False,
                                     "_wideAspectPower": 0, "_postGH": 3,
                                     "_capsuleLensExponent": 2,
                                     "_curvedLensCorrection": 0})
    other, other_box = render_window(bg, scene, neutral, scale=1)
    assert box == other_box
    assert np.array_equal(actual, other)


@pytest.mark.parametrize("patch", [{"_postGH": 2}, {"_postGH": True},
                                   {"_wideAspectPower": 1.1},
                                   {"_capsuleLensExponent": 1.4},
                                   {"_curvedLensCorrection": 1.6}])
def test_research_sampling_parameters_reject_invalid_values(patch):
    with pytest.raises(ValueError):
        apply_candidate(resolve_constants({}), patch)


def test_geometry_cache_shares_backdrops_but_preserves_tint():
    import copy
    import glass_model as gm
    scene = {"id": "one", "background": "photo", "brightness": "light", "shapes": [
        {"shape": "rect", "x": 20, "y": 20, "w": 60, "h": 50,
         "radius": 12, "variant": "clear"}]}
    bg = np.random.default_rng(4).random((100, 100, 3))
    gm._geometry.cache_clear()
    first, _ = render_window(bg, scene, {}, scale=1)
    other = copy.deepcopy(scene)
    other.update(id="two", background="text")
    second, _ = render_window(bg, other, {}, scale=1)
    assert gm._geometry.cache_info().misses == 1
    assert gm._geometry.cache_info().hits == 1
    assert np.array_equal(first, second)
    other["shapes"][0]["tint"] = "#FF000080"
    tinted, _ = render_window(bg, other, {}, scale=1)
    assert gm._geometry.cache_info().misses == 2
    assert not np.array_equal(tinted, second)


def test_consistent_field_probe_preserves_circular_geometry():
    scene = {"id": "circle", "brightness": "light", "shapes": [
        {"shape": "circle", "x": 20, "y": 20, "w": 50, "h": 50,
         "variant": "clear"}]}
    bg = np.random.default_rng(5).random((100, 100, 3))
    base, box = render_window(bg, scene, {}, scale=1)
    candidate, other_box = render_window(bg, scene, {"_lensDepthField": True}, scale=1)
    assert box == other_box and np.array_equal(base, candidate)
    capsule_probe, probe_box = render_window(bg, scene, {"_capsuleLensExponent": 2.4}, scale=1)
    assert box == probe_box and np.array_equal(base, capsule_probe)
    correction, correction_box = render_window(bg, scene, {"_curvedLensCorrection": 1}, scale=1)
    assert box == correction_box and np.array_equal(base, correction)


@pytest.mark.parametrize("patch", [
    {"_wideGH": 4}, {"_wideGH": -1}, {"_postIsotropic": 1.5},
    {"_frostDepthMix": float("nan")}, {"_postSecondOrder": "true"},
])
def test_invalid_research_settings_fail_before_worker_start(patch):
    with pytest.raises(ValueError):
        apply_candidate(resolve_constants({}), patch)
