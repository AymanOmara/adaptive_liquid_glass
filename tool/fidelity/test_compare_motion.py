import json

import numpy as np
import pytest

from compare_motion import (fit_glow, fit_spring, first_change, glass_bbox,
                            press_amplitudes, run, spring)


def _spring(t, response, zeta):
    w0 = 2 * np.pi / response
    wd = w0 * np.sqrt(1 - zeta**2)
    return 1 - np.exp(-zeta * w0 * t) * (np.cos(wd * t) + zeta * w0 / wd * np.sin(wd * t))


def test_first_change_finds_the_onset():
    frames = [np.zeros((10, 10, 3))] * 5 + [np.ones((10, 10, 3))] * 5
    assert first_change(frames, threshold=0.05) == 5


def test_first_change_ignores_noise_below_threshold():
    rng = np.random.default_rng(0)
    frames = [rng.normal(0, 0.005, (10, 10, 3)) for _ in range(6)] + [np.ones((10, 10, 3))]
    assert first_change(frames, threshold=0.05) == 6


def test_first_change_ignores_codec_refinement_but_sees_local_motion():
    # The encoder later re-sends a static frame at higher quality: a small
    # change everywhere (mean 0.005, peaks on thin stripes). Then glass moves.
    rng = np.random.default_rng(2)
    base = np.zeros((60, 80, 3))
    refined = base + rng.normal(0, 0.006, base.shape)
    refined[:, ::6] += 0.06
    moved = refined.copy()
    moved[20:40, 30:50] += 0.3
    frames = [base] * 4 + [refined] * 4 + [moved] * 2
    assert first_change(frames) == 8


def test_fit_spring_recovers_parameters():
    t = np.arange(0, 1.2, 1 / 60)
    response, zeta = 0.4, 0.7
    r, z = fit_spring(t, _spring(t, response, zeta))
    assert abs(r - response) < 0.02
    assert abs(z - zeta) < 0.03


def test_fit_spring_ignores_amplitude_baseline_and_sub_frame_delay():
    # A real curve: pixel widths from 600 to 660 with the onset 7 ms after
    # the first sampled frame, plus measurement noise.
    t = np.arange(0, 1.0, 1 / 60)
    x = 600 + 60 * spring(np.clip(t - 0.007, 0, None), 0.5, 0.6)
    x += np.random.default_rng(1).normal(0, 0.3, x.shape)
    r, z = fit_spring(t, x)
    assert abs(r - 0.5) < 0.02
    assert abs(z - 0.6) < 0.03


def test_fit_spring_recovers_a_spring_whose_start_was_not_displayed():
    # Flutter (debug, simulator) stalls ~170 ms after a morph starts: the first
    # displayed frame is already far along. Frame 0 is the last resting frame.
    t = np.arange(0, 1.2, 1 / 60)
    x = 100 + 200 * spring(t + 0.17, 0.45, 0.75)
    x[0] = 100
    r, z = fit_spring(t, x)
    assert abs(r - 0.45) < 0.03
    assert abs(z - 0.75) < 0.04


def test_fit_spring_handles_a_decreasing_curve():
    t = np.arange(0, 1.0, 1 / 60)
    r, z = fit_spring(t, 1 - _spring(t, 0.3, 0.8))
    assert abs(r - 0.3) < 0.02
    assert abs(z - 0.8) < 0.03


def test_fit_spring_with_floor_recovers_a_member_growing_out_of_another():
    # Union width while g1 grows from g0's centre: flat until g1 passes g0.
    t = np.arange(0, 1.2, 1 / 60)
    x = np.maximum(180, 90 + 300 * spring(t, 0.5, 0.7))
    r, z = fit_spring(t, x, floor=True)
    assert abs(r - 0.5) < 0.02
    assert abs(z - 0.7) < 0.03


def test_fit_spring_with_floor_handles_a_shrinking_member():
    t = np.arange(0, 1.0, 1 / 60)
    x = np.maximum(180, 390 - 300 * spring(t, 0.3, 0.8))
    r, z = fit_spring(t, x, floor=True)
    assert abs(r - 0.3) < 0.02
    assert abs(z - 0.8) < 0.03


def test_glass_bbox_finds_the_changed_block():
    bg = np.zeros((40, 60, 3))
    f = bg.copy()
    f[10:20, 5:45] = 0.5
    assert glass_bbox(f, bg, sigma=0) == (5, 10, 45, 20)


def test_glass_bbox_ignores_isolated_noise():
    bg = np.zeros((40, 60, 3))
    f = bg.copy()
    f[10:20, 5:45] = 0.5
    f[35, 58] = 1.0  # one hot pixel (codec speckle)
    assert glass_bbox(f, bg, sigma=0) == (5, 10, 45, 20)


def test_glass_bbox_blur_ignores_codec_error_on_thin_stripes():
    # h264 smears 1 px white stripes: errors up to 0.35 outside the glass.
    bg = np.zeros((80, 120, 3))
    f = bg.copy()
    f[:, ::6] = 0.35
    f[30:50, 20:100] = 0.5
    x0, y0, x1, y1 = glass_bbox(f, bg)
    # Within the blur radius (the bias is the same in every frame).
    assert abs(x0 - 20) <= 4 and abs(x1 - 100) <= 4
    assert abs(y0 - 30) <= 4 and abs(y1 - 50) <= 4


def test_press_amplitudes_separates_scale_and_stretch():
    # Flutter's model: sx = 1 + S + T|dx|, sy = 1 + S + T|dy|.
    S, T, dx, dy = 0.1, 0.08, 0.79, 0.0
    rest = (0, 0, 200, 56)
    w, h = 200 * (1 + S + T * dx), 56 * (1 + S + T * dy)
    s, t = press_amplitudes(rest, (0, 0, w, h), dx, dy)
    assert s == pytest.approx(S)
    assert t == pytest.approx(T)


def test_press_amplitudes_centre_touch_gives_scale_only():
    s, t = press_amplitudes((0, 0, 72, 72), (0, 0, 79.2, 79.2), 0, 0)
    assert s == pytest.approx(0.1)
    assert t is None


def test_fit_glow_recovers_gaussian_radius():
    h, w = 120, 200
    yy, xx = np.mgrid[0:h, 0:w]
    d2 = (xx - 150.0) ** 2 + (yy - 60.0) ** 2
    lift = 0.02 + 0.2 * np.exp(-d2 / (2 * 25.0**2))
    mask = np.ones((h, w), bool)
    sigma, amp = fit_glow(lift, mask, (150, 60))
    assert sigma == pytest.approx(25, rel=0.03)
    assert amp == pytest.approx(0.2, rel=0.03)


def _write_frames(d, frames):
    from PIL import Image
    d.mkdir(parents=True)
    for i, f in enumerate(frames):
        Image.fromarray((f * 255).astype(np.uint8)).save(d / f"{i + 1:04d}.png")


def test_run_scores_aligned_identical_recordings(tmp_path):
    # Same motion, recorded with different lead-in: alignment makes them equal.
    bg = np.full((30, 40, 3), 0.2)
    frames = []
    for k in range(20):
        f = bg.copy()
        half = 5 + min(k, 8)
        f[10:20, 20 - half:20 + half] = 0.8
        frames.append(f)
    still = [bg]  # nothing drawn yet: the first glass frame is the onset
    # Recordings stop at the last change: Flutter's ends early (padded).
    _write_frames(tmp_path / "frames/m.flutter", still * 3 + frames[:12])
    _write_frames(tmp_path / "frames/m.swiftui", still * 7 + frames)
    (tmp_path / "crop.json").write_text(json.dumps({"m": {"x": 0, "y": 0, "w": 40, "h": 30}}))
    spec = {"device": {"scale": 1},
            "motion": [{"id": "m", "kind": "morph", "background": "x",
                        "before": [{"x": 15, "y": 10, "w": 10, "h": 10}],
                        "after": [{"x": 7, "y": 10, "w": 26, "h": 10}],
                        "touch": {"x": 0, "y": 0}}]}
    code = run(tmp_path, spec=spec, background=lambda m, crop: bg)
    rep = json.loads((tmp_path / "motion_report.json").read_text())[0]
    assert rep["onset"] == {"flutter": 3, "swiftui": 7}
    assert rep["frames"] == 21
    assert rep["pass"] is True
    assert rep["worst"]["ssim"] == pytest.approx(1.0)
    assert rep["unsettled"] == []
    assert code == 0


def test_run_flags_a_recording_that_does_not_start_at_rest(tmp_path):
    # A press that starts already pressed (a lost touch-up) ends narrower.
    bg = np.full((30, 40, 3), 0.2)

    def frame(half):
        f = bg.copy()
        f[10:20, 20 - half:20 + half] = 0.8
        return f

    seq = [frame(12)] * 3 + [frame(h) for h in (11, 10, 9, 8, 7, 6)] * 1 + [frame(6)] * 8
    _write_frames(tmp_path / "frames/m.flutter", seq)
    _write_frames(tmp_path / "frames/m.swiftui", seq)
    (tmp_path / "crop.json").write_text(json.dumps({"m": {"x": 0, "y": 0, "w": 40, "h": 30}}))
    spec = {"device": {"scale": 1},
            "motion": [{"id": "m", "kind": "press", "background": "x", "hold_ms": 50,
                        "shape": {"x": 14, "y": 10, "w": 12, "h": 10},
                        "touch": {"x": 20, "y": 15}}]}
    assert run(tmp_path, spec=spec, background=lambda m, crop: bg) == 1
    rep = json.loads((tmp_path / "motion_report.json").read_text())[0]
    assert rep["unsettled"] == ["flutter", "swiftui"]
    assert rep["pass"] is False


def test_run_analyses_each_renderer_from_its_own_resting_frame(tmp_path):
    # Different speeds make the scoring alignment shift one renderer; the
    # spring/amplitude analysis must still start at each one's rest.
    bg = np.full((30, 40, 3), 0.2)

    def frame(half):
        f = bg.copy()
        f[10:20, 20 - half:20 + half] = 0.8
        return f

    fast = [frame(6)] * 3 + [frame(h) for h in (9, 12)] + [frame(12)] * 15
    slow = [frame(6)] * 3 + [frame(h) for h in (7, 8, 9, 10, 11, 12)] + [frame(12)] * 11
    _write_frames(tmp_path / "frames/m.flutter", fast)
    _write_frames(tmp_path / "frames/m.swiftui", slow)
    (tmp_path / "crop.json").write_text(json.dumps({"m": {"x": 0, "y": 0, "w": 40, "h": 30}}))
    spec = {"device": {"scale": 1},
            "motion": [{"id": "m", "kind": "press", "background": "x", "hold_ms": 200,
                        "shape": {"x": 14, "y": 10, "w": 12, "h": 10},
                        "touch": {"x": 20, "y": 15}}]}
    run(tmp_path, spec=spec, background=lambda m, crop: bg)
    rep = json.loads((tmp_path / "motion_report.json").read_text())[0]
    assert rep["shift"] != 0
    rest = glass_bbox(frame(6), bg)
    for r in ("flutter", "swiftui"):
        assert rep["analysis"][r]["widths"][0] == rest[2] - rest[0]


def test_run_does_not_flag_a_release_still_moving_when_the_window_ends(tmp_path):
    # Rest → press → release; the scored window (8 frames) ends while still
    # pressed, but the recording itself ends back at rest.
    bg = np.full((30, 40, 3), 0.2)

    def frame(half):
        f = bg.copy()
        f[10:20, 20 - half:20 + half] = 0.8
        return f

    seq = [frame(6)] * 3 + [frame(h) for h in (8, 10, 12)] + [frame(12)] * 6 + \
          [frame(h) for h in (10, 8, 6)] + [frame(6)] * 3
    _write_frames(tmp_path / "frames/m.flutter", seq)
    _write_frames(tmp_path / "frames/m.swiftui", seq)
    (tmp_path / "crop.json").write_text(json.dumps({"m": {"x": 0, "y": 0, "w": 40, "h": 30}}))
    spec = {"device": {"scale": 1},
            "motion": [{"id": "m", "kind": "press", "background": "x", "hold_ms": 50,
                        "shape": {"x": 14, "y": 10, "w": 12, "h": 10},
                        "touch": {"x": 20, "y": 15}}]}
    run(tmp_path, spec=spec, background=lambda m, crop: bg, frames=8)
    rep = json.loads((tmp_path / "motion_report.json").read_text())[0]
    assert rep["unsettled"] == []


def test_run_reports_missing_recordings(tmp_path):
    spec = {"device": {"scale": 1},
            "motion": [{"id": "m", "kind": "morph", "background": "x", "before": [],
                        "after": [], "touch": {"x": 0, "y": 0}}]}
    (tmp_path / "crop.json").write_text("{}")
    assert run(tmp_path, spec=spec, background=lambda m, c: None) == 1
    rep = json.loads((tmp_path / "motion_report.json").read_text())[0]
    assert rep["missing"] is True


def _growing(bg, lead):
    frames = [bg] * lead
    for k in range(12):
        f = bg.copy()
        half = 5 + min(k, 8)
        f[10:20, 20 - half:20 + half] = 0.8
        frames.append(f)
    return frames


_MORPH_SPEC = {"device": {"scale": 1},
               "motion": [{"id": "m", "kind": "morph", "background": "x",
                           "before": [{"x": 15, "y": 10, "w": 10, "h": 10}],
                           "after": [{"x": 7, "y": 10, "w": 26, "h": 10}],
                           "touch": {"x": 0, "y": 0}}]}


def test_run_reports_the_onset_offset_in_frames(tmp_path):
    bg = np.full((30, 40, 3), 0.2)
    _write_frames(tmp_path / "frames/m.flutter", _growing(bg, 5))
    _write_frames(tmp_path / "frames/m.swiftui", _growing(bg, 3))
    (tmp_path / "crop.json").write_text(json.dumps({"m": {"x": 0, "y": 0, "w": 40, "h": 30}}))
    run(tmp_path, spec=_MORPH_SPEC, background=lambda m, crop: bg)
    rep = json.loads((tmp_path / "motion_report.json").read_text())[0]
    assert rep["onset_offset"] == 2  # Flutter's first change, frames after SwiftUI's


def test_run_noise_ref_scores_each_renderer_against_the_other_run(tmp_path):
    # Run A has both renderers, run B only SwiftUI: the noise report pairs
    # A's SwiftUI clip with B's, and writes noise_report.json only.
    bg = np.full((30, 40, 3), 0.2)
    a, b = tmp_path / "a", tmp_path / "b"
    _write_frames(a / "frames/m.swiftui", _growing(bg, 2))
    _write_frames(a / "frames/m.flutter", _growing(bg, 2)[:-6])
    _write_frames(b / "frames/m.swiftui", _growing(bg, 6))
    for d in (a, b):
        (d / "crop.json").write_text(json.dumps({"m": {"x": 0, "y": 0, "w": 40, "h": 30}}))
    code = run(a, spec=_MORPH_SPEC, background=lambda m, crop: bg, noise_ref=b)
    assert code == 0
    assert not (a / "motion_report.json").exists()
    rep = json.loads((a / "noise_report.json").read_text())
    assert [(o["id"], o["renderer"]) for o in rep] == [("m", "swiftui")]
    assert rep[0]["onset"] == {"a": 2, "b": 6}
    assert rep[0]["pass"] is True
    assert set(rep[0]["analysis"]) == {"a", "b"}


def test_run_noise_ref_reports_a_motion_with_no_common_renderer(tmp_path):
    bg = np.full((30, 40, 3), 0.2)
    a, b = tmp_path / "a", tmp_path / "b"
    _write_frames(a / "frames/m.flutter", _growing(bg, 2))
    _write_frames(b / "frames/m.swiftui", _growing(bg, 2))
    for d in (a, b):
        (d / "crop.json").write_text(json.dumps({"m": {"x": 0, "y": 0, "w": 40, "h": 30}}))
    assert run(a, spec=_MORPH_SPEC, background=lambda m, crop: bg, noise_ref=b) == 1
    rep = json.loads((a / "noise_report.json").read_text())
    assert rep == [{"id": "m", "missing": True, "pass": False}]
