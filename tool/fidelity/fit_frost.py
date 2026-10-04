"""Fits the frost wide tail (Task 17c) to the measured transfer curves.

Input is `measure_frost.py`'s output (`frost-<renderer>.json`): per base
scene, depth bins with the per-period modulation A_P (gain x |MTF(P)| of
whatever blur ran before the lens). The model per bin is

    g x core_MTF(P; sigma) x ((1 - w) + w x wide_MTF(P; sigma_wide)),

where `sigma` is the composed core blur (with the Task 17b size factor
min(1, halfMin / blurSizeRef)), `sigma_wide` is the 16-tap wide component of
`frost_taps`, and w = edge + slope x sampleDepth / halfMin - drop x
max(0, 1 - halfMin / sizeRef) clamped to [0, 1] — the same weight the shader
and `glass_model.frost_wide_mix` compute, with centre = edge + slope. `g` is
a free per-base gain absorbing capture gain and the code amplitude.

The core sigma and size ref are fitted along with the tail; Task 17c shipped
the tail only (the 17b core, fitted jointly with fill and rim, beats the
jointly refitted core on full-scene bars — see docs/superpowers/notes/
fidelity-status.md).

Usage:
    fit_frost.py <frost.json> <variant regular|clear> <light|dark>
                 [--start s0,ref,sx,a,b,c,R] [--out DIR]
writes <out>/frostfit-<variant>-<brightness>.json (`x` = the 7 parameters in
the order above; `bases` = the fitted per-base gains).
"""
import argparse
import json
import pathlib
import sys

import numpy as np
from scipy.optimize import least_squares

ROOT = pathlib.Path(__file__).resolve().parents[2]
SQ = np.sqrt(2)
# The 16-tap two-ring Gauss-Laguerre rule, as frost_taps places it.
R1, R2 = np.sqrt(2 * (2 - SQ)), np.sqrt(2 * (2 + SQ))
W1, W2 = (2 + SQ) / 4, (2 - SQ) / 4
ANG1 = np.arange(6) * np.pi / 3
ANG2 = np.pi / 10 + np.arange(10) * np.pi / 5


def taps_mtf(period, sigma_px):
    """Transfer along x of `frost_taps(sigma_px)` at `period` px."""
    c1 = np.mean(np.cos(2 * np.pi * R1 * sigma_px * np.cos(ANG1) / period))
    c2 = np.mean(np.cos(2 * np.pi * R2 * sigma_px * np.cos(ANG2) / period))
    return W1 * c1 + W2 * c2


def imp_mtf(period, sigma_px):
    """Transfer along x of `impeller_kernel(sigma_px)` at `period` px."""
    if sigma_px <= 0.05:
        return 1.0
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
    from glass_model import impeller_kernel
    k = impeller_kernel(sigma_px)
    x = np.arange(-(k.size // 2), k.size // 2 + 1)
    return float(np.sum(k * np.cos(2 * np.pi * x / period)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("frost_json", type=pathlib.Path)
    ap.add_argument("variant", choices=["regular", "clear"])
    ap.add_argument("brightness", choices=["light", "dark"])
    ap.add_argument("--start", default="6,60,5.6,0.28,1.06,2,76",
                    help="s0, core ref, wide sigma, edge, slope, drop, size ref")
    ap.add_argument("--out", type=pathlib.Path,
                    default=ROOT / "build/fidelity/fit17c")
    args = ap.parse_args()

    d = json.loads(args.frost_json.read_text())
    rows = []
    for base, r in sorted(d.items()):
        if (not base.startswith(args.variant + "-") or "bins" not in r
                or (args.brightness == "dark") != ("dark" in base)):
            continue
        for b in r["bins"]:
            if len(b["amp"]) < 5:
                continue
            periods = np.array([int(p) for p in b["amp"]])
            amp = np.array([b["amp"][str(p)][1] for p in periods])
            rows.append((base, r["half_min_pt"], b["sample_depth"], periods, amp))
    if not rows:
        sys.exit(f"fit_frost: no bins for {args.variant}-{args.brightness} in {args.frost_json}")
    bases = sorted(set(r[0] for r in rows))

    def wfun(p, half_min, sample_depth):
        a, b, c, ref = p
        w = a + b * sample_depth / half_min - c * np.maximum(0.0, 1.0 - half_min / ref)
        return np.clip(w, 0.0, 1.0)

    def res(x):
        s0, ref, sx, a, b, c, size_ref = x[:7]
        out = []
        for base, hm, sd, periods, amp in rows:
            g = x[7 + bases.index(base)]
            core = s0 * min(1.0, hm / ref) * 3 if ref > 0 else s0 * 3
            w = wfun((a, b, c, size_ref), hm, sd)
            core_mtf = np.array([imp_mtf(P, core) for P in periods])
            wide_mtf = np.array([taps_mtf(P, sx * 3) for P in periods])
            out.append((g * core_mtf * ((1 - w) + w * wide_mtf) - amp) / 0.004)
        return np.concatenate(out)

    x0 = [float(v) for v in args.start.split(",")] + [0.27 if args.variant == "regular" else 1.0] * len(bases)
    lo = [0, 1, 0, -1, -2, 0, 1] + [0.0] * len(bases)
    hi = [20, 300, 30, 2, 5, 10, 400] + [3.0] * len(bases)
    q = least_squares(res, x0, bounds=(lo, hi))
    rr = res(q.x).reshape(len(rows), -1)
    print(f"{args.variant}-{args.brightness}: core s0 {q.x[0]:.3f} pt ref {q.x[1]:.1f} | "
          f"wide sx {q.x[2]:.3f} pt | w edge {q.x[3]:.3f} slope {q.x[4]:.3f} "
          f"drop {q.x[5]:.3f} ref {q.x[6]:.1f} | rms "
          f"{np.sqrt(np.mean(rr ** 2)):.2f} over {len(rows)} bins, {len(bases)} bases")
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / f"frostfit-{args.variant}-{args.brightness}.json").write_text(json.dumps({
        "x": list(q.x[:7]),
        "bases": {b: q.x[7 + i] for i, b in enumerate(bases)},
    }, indent=1) + "\n")


if __name__ == "__main__":
    main()
