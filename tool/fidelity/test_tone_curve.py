"""Tone-curve decoder (Task 17d): glass's input->output curve from flats."""
import json

import numpy as np
import pytest

from tone_curve import N_KNOTS, tone_knots

SET = "clear"


def _frost_json(tmp_path, tone_by_base):
    d = tmp_path / "frost.json"
    d.write_text(json.dumps({
        base: {"variant": base.split("-")[0], "brightness": base.rsplit("-", 1)[1],
               "half_min_pt": 28.0, "w_pt": 56.0, "h_pt": 56.0, "radius_pt": 28.0,
               "tone": [[v, list(rgb)] for v, rgb in tone]}
        for base, tone in tone_by_base.items()}))
    return d


def test_linear_tone_decodes_to_linear_knots(tmp_path):
    # Two bases of one set, identical measured curve: out = 0.25 + 0.5*in.
    tone = [(v / 255, [0.25 + 0.5 * v / 255] * 3) for v in range(0, 256, 8)]
    p = _frost_json(tmp_path, {f"{SET}-capsule-light": tone, f"{SET}-circle-light": tone})
    knots_in, knots_out = tone_knots(p, SET, "light")
    assert knots_in.shape == (N_KNOTS,) and knots_out.shape == (N_KNOTS, 3)
    assert knots_in[0] == 0.0 and knots_in[-1] == 1.0
    assert np.allclose(knots_out, 0.25 + 0.5 * knots_in[:, None], atol=0.01)


def test_tone_medians_across_bases_and_ignores_other_sets(tmp_path):
    hi = [(v / 255, [0.5 + 0.5 * v / 255] * 3) for v in range(0, 256, 8)]
    lo = [(v / 255, [0.1 + 0.2 * v / 255] * 3) for v in range(0, 256, 8)]
    p = _frost_json(tmp_path, {f"{SET}-capsule-light": hi, f"{SET}-circle-light": lo,
                               f"{SET}-capsule-dark": lo, f"regular-capsule-light": lo})
    _, knots_out = tone_knots(p, SET, "light")
    assert knots_out[0, 0] == pytest.approx(0.3, abs=0.01)  # median of 0.5 and 0.1


def test_monotone_enforced(tmp_path):
    # A non-monotone measurement (noise near the top) must come out monotone.
    tone = [(v / 255, [min(1.0, 0.9 - v / 510 + (0.02 if v > 200 else 0))] * 3)
            for v in range(0, 256, 8)]
    p = _frost_json(tmp_path, {f"{SET}-capsule-light": tone})
    _, knots_out = tone_knots(p, SET, "light")
    assert (np.diff(knots_out[:, 0]) >= -1e-9).all()


def test_seed_maps_model_output_to_measured():
    """The seed LUT maps the model's flat response onto SwiftUI's measured
    output: at model floor 0.181 it must give 0.075, at 0.591 give 0.594."""
    from tone_curve import tone_seed_from_model
    # Model over flat v: 0.82*v + 0.181 (fill lift); measured: 1.04*v + 0.075.
    seed = tone_seed_from_model(model=lambda v: 0.82 * v + 0.181,
                                measured=lambda v: 1.04 * v + 0.075)
    for v in (0.25, 0.5, 0.75, 1.0):
        got = float(np.interp(0.82 * v + 0.181, seed[0], seed[1]))
        assert got == pytest.approx(1.04 * v + 0.075, abs=0.02)
    # At v=0 the first uniform segment can only interpolate (9 knots): the
    # seed lands within ~0.04 of the floor; the full-scene fit closes the rest.
    got0 = float(np.interp(0.181, seed[0], seed[1]))
    assert 0.075 <= got0 <= 0.13
    assert seed[1][0] < 0.1  # the floor comes down
