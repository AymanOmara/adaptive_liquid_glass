"""Decodes SwiftUI's frost transfer function and tone curve (Task 17c).

Frost. Every measurement base scene in tool/scenes/measure.json is captured
over x codes (gen_backgrounds.CODES and FROST_CODES): grey sinusoids along x
with periods 32, 48, 80, 128 and 160 px, four phase steps each. The 128/160
pair gives each pixel's sampled x coordinate s (measure_lens.decode_axis);
with it, the four steps of any period P give the modulation coherently,

    A_P = ((I0 - I2) cos(2 pi s / P) + (I3 - I1) sin(2 pi s / P)) / 2,

which is gain x |MTF(P)| of whatever blur ran before the lens, and unbiased
by 8-bit noise (the magnitude hypot() is not, at the 1-2 level amplitudes the
32 px code keeps under regular frost). Dividing by CODE_AMP gives the
transfer per period; several periods per depth bin separate a single
Gaussian from a sharp core plus a wide tail.

Tone. Uniform greys (gen_backgrounds.FLATS) pass any blur and lens
unchanged, so the glass interior shows the pure input -> output curve per
channel.

Usage:
    measure_frost.py <run-dir> --out DIR [--renderer swiftui|flutter]
writes <out>/frost-<renderer>.json: per base scene, depth bins (pixel depth
and lens sampled depth, pt) with the per-period modulation and mean level,
and the tone curve where flats were captured.
"""
import argparse
import json
import pathlib
import sys

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool/scenes"))
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from gen_backgrounds import CODE_AMP, FLATS  # noqa: E402
import measure_lens as ml  # noqa: E402

PERIODS = (32, 48, 80, 128, 160)
SCALE = 3
# Depth bin edges (pt) for the transfer function.
DEPTH_EDGES = (0, 3, 6, 10, 15, 20, 25, 30, 40, 50, 70, 100, 150)


def modulation(images, period, s):
    """Per-pixel (and channel) coherent modulation and mean of the four phase
    steps `images` (k = 0..3) of the x code of `period`, given the sampled
    coordinate `s` (pixel-centre units, HxW or HxWx3)."""
    i0, i1, i2, i3 = images
    phi = 2 * np.pi * np.asarray(s, np.float64) / period
    if phi.ndim == i0.ndim - 1:
        phi = phi[..., None]
    amp = 0.5 * ((i0 - i2) * np.cos(phi) + (i3 - i1) * np.sin(phi))
    return amp, 0.25 * (i0 + i1 + i2 + i3)


def gaussian_mtf(period, sigma):
    """Transfer of a continuous Gaussian (sigma px) at `period` px."""
    return float(np.exp(-0.5 * (2 * np.pi * sigma / period) ** 2))


def taps_mtf(taps, period):
    """Transfer along x of a kernel given as (x offset px, weight) taps."""
    return float(sum(w * np.cos(2 * np.pi * x / period) for x, w in taps))


def tone_curve(images, interior):
    """`images`: 8-bit level -> HxWx3 capture over that flat grey. Returns
    [(level / 255, median rgb inside `interior`)] sorted by level."""
    return [(v / 255, np.median(images[v][interior], 0).tolist()) for v in sorted(images)]


# --- analysis -------------------------------------------------------------------


def _window(shape, pad_pt=16):
    x0 = int(round((shape["x"] - pad_pt) * SCALE))
    y0 = int(round((shape["y"] - pad_pt) * SCALE))
    x1 = int(round((shape["x"] + shape["w"] + pad_pt) * SCALE))
    y1 = int(round((shape["y"] + shape["h"] + pad_pt) * SCALE))
    return x0, y0, x1, y1


def analyse_base(run_dir, renderer, scene, caps, lens):
    """Transfer per depth bin (and tone curve) of one base scene. `lens`:
    measured lens_v3 parameters in px for the sampled depth."""
    from glass_model import lens_v3
    sh = scene["shapes"][0]
    x0, y0, x1, y1 = _window(sh)
    load = lambda bg: ml.load(pathlib.Path(run_dir) / f"{caps[bg]}.{renderer}.png")[y0:y1, x0:x1]
    py, px = np.mgrid[y0:y1, x0:x1] + 0.5
    g = ml.shape_geometry(sh, SCALE, px, py)
    depth = g["depth"]
    half_min = min(sh["w"], sh["h"]) * SCALE / 2
    out = {"variant": sh["variant"], "brightness": scene["brightness"],
           "half_min_pt": half_min / SCALE, "w_pt": sh["w"], "h_pt": sh["h"],
           "radius_pt": ml.shape_radius(sh)}
    have = lambda p: all(f"code-x-p{p}-k{k}" in caps for k in range(4))
    if have(128) and have(160):
        codes = {f"code-x-p{p}-k{k}": load(f"code-x-p{p}-k{k}")
                 for p in PERIODS if have(p) for k in range(4)}
        dec = ml.decode_axis(codes, "x", (x0, y0))
        s = dec["s"][..., 1]  # sampled x (green; grey codes)
        dn = lens_v3(depth, half_min, lens["amp"], lens["decay"], lens["band"],
                     lens["size_ref"])
        sample_depth = (depth - dn) / SCALE
        amps, mean = {}, None
        for p in PERIODS:
            if have(p):
                a, m = modulation([codes[f"code-x-p{p}-k{k}"] for k in range(4)], p, s)
                amps[p] = a / CODE_AMP
                if p == 128:
                    mean = m
        bins = []
        dpt = depth / SCALE
        for lo, hi in zip(DEPTH_EDGES[:-1], DEPTH_EDGES[1:]):
            m = (dpt >= lo) & (dpt < hi)
            if m.sum() < 30:
                continue
            bins.append({"depth": [lo, hi], "n": int(m.sum()),
                         "sample_depth": float(np.median(sample_depth[m])),
                         "amp": {str(p): np.median(a[m], 0).tolist() for p, a in amps.items()},
                         "mean": np.median(mean[m], 0).tolist()})
        out["bins"] = bins
    flats = {v: bg for bg, v in FLATS.items() if bg in caps}
    if flats:
        interior = depth >= min(20 * SCALE, 0.6 * half_min)
        out["tone"] = tone_curve({v: load(bg) for v, bg in flats.items()}, interior)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("run_dir", type=pathlib.Path)
    ap.add_argument("--renderer", default="swiftui")
    ap.add_argument("--out", type=pathlib.Path, required=True)
    ap.add_argument("--lens", type=pathlib.Path,
                    default=ROOT / "build/fidelity/measure-v2/an/lens-fit-swiftui.json",
                    help="measure_lens.py lens fit (px) for the sampled depth")
    ap.add_argument("--only", default="", help="base scene id prefix")
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    lens = json.loads(args.lens.read_text())
    result = {}
    for base, (scene, caps) in ml.base_scenes(ml.load_measure_spec()).items():
        if not base.startswith(args.only):
            continue
        caps = {bg: c for bg, c in caps.items()
                if (args.run_dir / f"{c}.{args.renderer}.png").exists()}
        if not caps:
            continue
        variant = scene["shapes"][0]["variant"]
        result[base] = analyse_base(args.run_dir, args.renderer, scene, caps, lens[variant])
        r = result[base]
        line = f"{base:28s} halfMin {r['half_min_pt']:5.1f}"
        if "bins" in r:
            c = r["bins"][-1]
            line += "  centre " + " ".join(f"A{p} {v[1]:.3f}" for p, v in c["amp"].items())
            line += f"  mean {c['mean'][1] * 255:.1f}"
        if "tone" in r:
            line += f"  tone {len(r['tone'])} levels"
        print(line)
    (args.out / f"frost-{args.renderer}.json").write_text(json.dumps(result, indent=1))


if __name__ == "__main__":
    main()
