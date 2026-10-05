"""Tone-curve decoder (Task 17d): glass's input->output curve from flats.

`measure_frost.py` records, per base scene, the median colour inside the
glass over each flat grey (`tone`: [(level/255, rgb)]). Uniform greys pass
any blur and lens unchanged, so this is the pure input->output curve of
SwiftUI's glass — including below the 0.15 code floor where the sinusoid
codes cannot reach and where SwiftUI visibly lifts black strokes.

`tone_knots` aggregates the matching bases of one variant set (median
across scenes per level), resamples to `N_KNOTS` evenly spaced inputs and
enforces monotonicity — the knots are the fitted constants' starting
values and the model's/shader's piecewise-linear LUT.
"""
import json
import pathlib

import numpy as np

N_KNOTS = 9


def tone_knots(frost_json, variant, brightness):
    """(knots_in (N,), knots_out (N, 3)) for one variant set."""
    d = json.loads(pathlib.Path(frost_json).read_text())
    per_level = {}
    for base, r in d.items():
        if not base.startswith(variant + "-") or "tone" not in r:
            continue
        if r.get("brightness") != brightness:
            continue
        for v, rgb in r["tone"]:
            per_level.setdefault(round(v, 4), []).append(rgb)
    if not per_level:
        raise ValueError(f"tone_curve: no tone entries for {variant}-{brightness}")
    levels = sorted(per_level)
    vin = np.array(levels)
    vout = np.median(np.array([per_level[l] for l in levels], np.float64), axis=1)
    knots_in = np.linspace(0.0, 1.0, N_KNOTS)
    out = np.stack([np.interp(knots_in, vin, vout[:, c]) for c in range(3)], axis=1)
    # The flats stop short of 1.0 (last captured level ≈ 0.97): np.interp
    # clamps there, which would flatten the top of the curve. Extend the last
    # measured segment linearly instead, bounded to the previous knot and 1.
    if vin[-1] < 1.0 and len(vin) >= 2:
        slope = (vout[-1] - vout[-2]) / max(vin[-1] - vin[-2], 1e-9)
        top = np.clip(vout[-1] + slope * (1.0 - vin[-1]), out[-2] if N_KNOTS > 1 else 0.0, 1.0)
        out[-1] = top
    return knots_in, np.maximum.accumulate(out, axis=0)


def tone_seed_from_model(model, measured, samples=257):
    """Seed knots mapping the model's flat response onto the measurement.

    Over a flat grey v the model's interior output is `model(v)` (monotone)
    and SwiftUI's measured output is `measured(v)`; the LUT that makes the
    model match on every flat is therefore x = model(v) -> y = measured(v).
    Returns (knots_in (N,), out (N,)) for one grey channel.
    """
    vs = np.linspace(0.0, 1.0, samples)
    x = np.asarray([model(v) for v in vs], np.float64)
    y = np.maximum.accumulate([measured(v) for v in vs])
    x = np.maximum.accumulate(x)
    knots_in = np.linspace(0.0, 1.0, N_KNOTS)
    out = np.interp(knots_in, x, y)
    # Below the black-flat response (x[0]) the measurement constrains nothing;
    # clamping there would collapse every darker pixel to one value. Extend
    # the first measured segment's slope instead, floored at 0.
    if len(x) >= 2 and x[0] > 0.0:
        slope = (y[1] - y[0]) / max(x[1] - x[0], 1e-9)
        lo = np.clip(y[0] + slope * (knots_in - x[0]), 0.0, 1.0)
        out = np.where(knots_in < x[0], lo, out)
    return knots_in, np.maximum.accumulate(out)
