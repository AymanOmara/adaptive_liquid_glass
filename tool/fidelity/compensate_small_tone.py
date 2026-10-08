"""Generate research seeds that preserve small shapes' composite grey response.

The large-shape tone LUT precedes the fill wash, dim and small-shape LUT.
Changing it therefore changes small shapes even when their ambient contribution
is disabled. This script fits the *existing* nine smallToneKnots to compensate
that composition. It renders no scenes and starts no workers or simulator.

This is a seed generator, not a fidelity score: preserving flat grey response
does not preserve coloured backdrops when saturation changes, and nine uniformly
spaced knots cannot exactly invert every composed piecewise-linear curve.

Example (from the repository root):
  tool/fidelity/.venv/bin/python tool/fidelity/compensate_small_tone.py \
      --p1 /path/to/main/build/g8/p1.json
"""
import argparse
import copy
import json
from pathlib import Path

import numpy as np
from scipy.optimize import Bounds, LinearConstraint, minimize

ROOT = Path(__file__).resolve().parents[2]
GRID = np.linspace(0.0, 1.0, 9)
HALF_MINIMA = (28.0, 30.0)

# Saved in build/g8/large40b.log. Those numbers describe a fitted interior
# pasted into a captured rim; they are not full-render predicted-device scores.
LARGE40B = {
    "saturation": 1.7717,
    "toneKnots": [.06, .1609, .2964, .4257, .5338, .6681, .7445, .8888, .9743],
    "ambientMix": .1755,
    "ambientReach": 40.0,
}


def hats(values):
    """Shader toneLut basis, including its constant endpoint extension."""
    return np.maximum(1.0 - np.abs(np.clip(values, 0.0, 1.0)[..., None] * 8
                                   - np.arange(9)), 0.0)


def fill_rgb(value):
    if isinstance(value, int):
        value &= 0xffffff
        return np.array([(value >> 16) & 255, (value >> 8) & 255,
                         value & 255], dtype=float) / 255
    value = value.lstrip("#")[-6:]
    return np.array([int(value[i:i + 2], 16) for i in (0, 2, 4)]) / 255


def small_weight(v, half_min):
    hi = v.get("smallSizeHi", 0.0)
    if hi <= 0:
        return 0.0
    return float(np.clip((hi - half_min) /
                         max(hi - v.get("smallSizeLo", 0.0), 1e-3), 0, 1))


def pre_small(grey, v, half_min):
    """RGB entering the small LUT, matching shader order in encoded sRGB.

    Saturation is a no-op on grey input. Fill uses the actual packer factor
    1 - drop * (1 - min(1, halfMin / ref)), not min(1, halfMin/ref) alone.
    Current regular fillSizeDrop is zero. Ambient is applied later and is
    disabled for these fully-small sizes, so it cannot enter this composition.
    """
    col = hats(grey) @ np.asarray(v["toneKnots"])
    lift_ref = v.get("toneLiftSizeRef", 0.0)
    lift_size = max(0.0, 1.0 - half_min / lift_ref) if lift_ref > 0 else 0.0
    knee = max(v.get("toneLiftKnee", .5), 1e-3)
    col = col + v.get("toneLift", 0.0) * lift_size * np.maximum(0, 1-col/knee)**2
    ref = v.get("fillSizeRef", 0.0)
    fill_scale = (1-v.get("fillSizeDrop", 0.0)*(1-min(1, half_min/ref))
                  if ref > 0 else 1.0)
    opacity = v["fillOpacity"] * fill_scale
    return ((1-opacity)*col[:, None] + opacity*fill_rgb(v["fillColor"])[None, :]) * (1-v["dim"])


def compensation(base, changed, samples=4097):
    """Constrained least-squares compensation and diagnostics in 8-bit levels.

    Grey samples cover [0,1], equally weighting R/G/B and half-minima 28/30.
    A tiny tie-break toward existing knots makes unreachable lower knots
    deterministic without materially changing the fit.
    """
    grey = np.linspace(0.0, 1.0, samples)
    prior = np.asarray(base["smallToneKnots"], dtype=float)
    rows, targets = [], []
    for half_min in HALF_MINIMA:
        if small_weight(base, half_min) != 1 or small_weight(changed, half_min) != 1:
            raise ValueError(f"halfMin={half_min:g} must be fully in the small LUT class")
        rows.append(hats(pre_small(grey, changed, half_min)).reshape(-1, 9))
        targets.append((hats(pre_small(grey, base, half_min)) @ prior).ravel())
    a = np.concatenate(rows)
    target = np.concatenate(targets)
    ata, atb = a.T @ a / len(a), a.T @ target / len(a)
    tie = 1e-10

    def objective(k):
        # Constant target norm is irrelevant to the optimizer.
        return float(k @ ata @ k - 2*k @ atb + tie*np.sum((k-prior)**2))

    def gradient(k):
        return 2*(ata @ k-atb+tie*(k-prior))

    ordered = np.diff(np.eye(9), axis=0)
    result = minimize(objective, prior.copy(), jac=gradient, method="SLSQP",
                      bounds=Bounds(0.0, 1.0),
                      constraints=[LinearConstraint(ordered, 0.0, np.inf)],
                      options={"ftol": 1e-14, "maxiter": 1000})
    if not result.success:
        raise RuntimeError(f"Small LUT compensation failed: {result.message}")
    knots = np.round(np.maximum.accumulate(np.clip(result.x, 0, 1)), 8)
    before, after = a @ prior-target, a @ knots-target
    diagnostics = {
        "grey_samples_per_size": samples,
        "half_minima_pt": list(HALF_MINIMA),
        "uncompensated_rmse_levels": float(np.sqrt(np.mean(before**2))*255),
        "compensated_rmse_levels": float(np.sqrt(np.mean(after**2))*255),
        "compensated_max_abs_levels": float(np.max(np.abs(after))*255),
        "smallToneKnots": knots.tolist(),
        "iterations": int(result.nit),
    }
    return knots.tolist(), diagnostics


def generate(base, p1, samples, isolate_small_colour=False):
    seeds = []
    saturations = (1.85, 1.897) if isolate_small_colour else (1.80, 1.85, 1.897)
    for saturation in saturations:
        patch = copy.deepcopy(p1["L40"]["regular"])
        patch["saturation"] = saturation
        seeds.append((f"L40-comp-sat{saturation:g}", patch, "build/g8/p1.json:L40"))
    seeds.append(("large40b-comp", copy.deepcopy(LARGE40B), "build/g8/large40b.log"))
    # Tinting is downstream of the small LUT. 0.9906 is independently motivated
    # by the joint tint fit recorded in large40lab.log (standard is 1.024).
    # Test it only on two seeds to avoid multiplying the full scene sweep.
    for name, patch, source in list(seeds):
        tint_seeds = (("L40-comp-sat1.897",) if isolate_small_colour else
                      ("L40-comp-sat1.85", "large40b-comp"))
        if name in tint_seeds:
            tint_patch = {**patch, "tintStrength": .9906}
            seeds.append((name+"-tint0.9906", tint_patch,
                          source+"; tint from build/g8/large40lab.log"))
    candidates, reports = [], []
    for name, patch, source in seeds:
        changed = {**base, **patch}
        if isolate_small_colour:
            # The model-only probe bypasses the *main* LUT for fully-small
            # regular-light shapes and restores their standard saturation.
            # Keep the actual patch's main LUT intact for large shapes; fit
            # only against the effective small path used by that probe.
            changed["toneKnots"] = GRID.tolist()
            changed["saturation"] = base["saturation"]
            name = name.replace("-comp", "-isolated")
        knots, diagnostics = compensation(base, changed, samples)
        candidate = {"regular": {**patch, "smallToneKnots": knots}}
        if isolate_small_colour:
            candidate["_isolateSmallColour"] = True
        candidates.append([name, candidate])
        reports.append({"name": name, "source": source, "source_parameters": patch,
                        "model_only_isolated_small_colour": isolate_small_colour,
                        "effective_small_main_tone": changed["toneKnots"],
                        "effective_small_saturation": changed["saturation"],
                        "base_fill": {k: base.get(k, 0.0) for k in
                                      ("fillColor", "fillOpacity", "fillSizeRef", "fillSizeDrop", "dim")},
                        **diagnostics})
    return candidates, reports


def self_test(base):
    knots, report = compensation(base, base, samples=257)
    assert report["compensated_max_abs_levels"] < 1e-5, report
    assert np.all(np.diff(knots) >= 0)
    # Endpoint clamp agrees with the shader, and a nonzero fillSizeDrop uses
    # the real size formula (half/ref=.5, drop=.4 => factor=.8).
    assert np.array_equal(hats(np.array([-1., 2.])), np.eye(9)[[0, 8]])
    probe = {**base, "toneKnots": GRID.tolist(), "fillOpacity": .5,
             "fillColor": "#FFFFFF", "fillSizeRef": 56., "fillSizeDrop": .4,
             "dim": 0., "toneLift": 0.}
    assert np.allclose(pre_small(np.array([0.]), probe, 28.), .4)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--p1", type=Path, default=ROOT/"build/g8/p1.json")
    parser.add_argument("--standard", type=Path,
                        default=ROOT/"tool/fidelity/standard_constants.json")
    parser.add_argument("--out", type=Path,
                        help="Candidate list destination (default depends on probe mode).")
    parser.add_argument("--diagnostics", type=Path,
                        help="Optional diagnostics JSON; defaults beside isolated candidates.")
    parser.add_argument("--isolate-small-colour", action="store_true",
                        help="Model-only identity-main-LUT/standard-saturation small-class probe.")
    parser.add_argument("--samples", type=int, default=4097)
    args = parser.parse_args()
    if args.samples < 17:
        parser.error("--samples must be at least 17")
    base = json.loads(args.standard.read_text())["regular"]
    self_test(base)
    candidates, reports = generate(base, json.loads(args.p1.read_text()), args.samples,
                                   args.isolate_small_colour)
    if args.out is None:
        filename = ("isolated-colour-candidates.json" if args.isolate_small_colour
                    else "regular-colour-candidates.json")
        args.out = ROOT/"build/astra-clear-edge"/filename
    if args.isolate_small_colour and args.diagnostics is None:
        args.diagnostics = args.out.with_name(args.out.stem+"-diagnostics.json")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(candidates, indent=2)+"\n")
    report = {"output": str(args.out), "candidates": reports,
              "scope": "Model research and grey response compensation only; full-scene and device verification required."}
    if args.diagnostics is not None:
        args.diagnostics.parent.mkdir(parents=True, exist_ok=True)
        args.diagnostics.write_text(json.dumps(report, indent=2)+"\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
