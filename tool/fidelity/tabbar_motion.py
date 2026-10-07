"""Frame-by-frame tab bar motion, SwiftUI TabView against the package
(recordings from record_tabbar_motion.sh, tabbardark).

Usage: tabbar_motion.py <run-dir> [gesture ...] [--every N]

Per frame (60 fps, frame 0 = the first frame that changed after the touch):
  bar   left / right / top edge (pt) on the black page;
  lens  centre x / width / overhang above the bar's top (pt);
  tint  centroid x of the selected blue (pt).
Prints the per-frame table and a summary per take: SwiftUI spring fits
(response, damping, start) of the lens's travel and the bar's growth, and
for a drag the lens's mean position mid-drag (its lag behind the finger).
"""
import argparse
import glob
import pathlib

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.optimize import minimize

from compare_motion import spring

SCALE = 3
MID = 180           # crop row through the bar's middle (crop y 2280 px)
INK = 8             # grey level that counts as glass on the black page
ONSET = 0.3         # mean |Δ| against the first frame: the touch's first frame


def load(d):
    fs = sorted(glob.glob(f"{d}/*.png"))
    return [np.asarray(Image.open(f).convert("RGB")).astype(np.int16) for f in fs]


def geometry(frame):
    """Bar (left, right, top) and lens (centre, width, overhang) in pt."""
    g = frame.mean(axis=2)
    lit = g > INK
    row = np.where(lit[MID])[0]
    if len(row) == 0:
        return None, None
    left, right = row[0], row[-1] + 1
    cols = np.arange(left, right)
    tops = np.array([np.argmax(lit[:, c]) for c in cols])
    bar_top = float(np.median(tops))
    over = bar_top - tops
    lens_cols = cols[ndimage.median_filter(over, 5) >= 3]
    bar = (left / SCALE, right / SCALE, bar_top / SCALE)
    if len(lens_cols) < 10:
        return bar, None
    lab, n = ndimage.label(ndimage.binary_closing(np.isin(cols, lens_cols), iterations=4))
    k = int(np.argmax(ndimage.sum(np.ones(len(cols)), lab, range(1, n + 1)))) + 1
    xs = cols[lab == k]
    o = over[lab == k]
    return bar, ((xs[0] + xs[-1] + 1) / 2 / SCALE, (xs[-1] + 1 - xs[0]) / SCALE,
                 float(o.max()) / SCALE)


def tint(frame):
    f = frame[MID - 90:]
    m = (f[..., 2] > 180) & (f[..., 0] < 110) & (f[..., 1] > 100)
    n = int(m.sum())
    if n < 40:
        return None, n
    return float(np.where(m)[1].mean()) / SCALE, n


def track(d):
    fr = load(d)
    out = [(*geometry(f), *tint(f)) for f in fr]
    onset = next((i for i, f in enumerate(fr) if np.abs(f - fr[0]).mean() > ONSET), None)
    return out, onset


def fit(ts, xs, x0, x1):
    """(response, dampingFraction, t0 in frames, rms) of a SwiftUI spring
    from x0 to x1 through the samples; t0 is free, so a renderer's late
    first frame (a debug-mode stall) does not bias the curve."""
    ts, xs = np.asarray(ts, float), np.asarray(xs, float)

    def err(p):
        r, z, t0 = p
        if r < 0.05 or z < 0.1 or z > 1.5:
            return 1e9
        m = x0 + (x1 - x0) * spring(np.maximum((ts - t0) / 60, 0), r, z)
        return float(np.sqrt(np.mean((m - xs) ** 2)))

    best = min((minimize(err, [r, z, t0], method="Nelder-Mead")
                for r in (0.2, 0.35, 0.5) for z in (0.6, 0.9) for t0 in (-3, 0, 3)),
               key=lambda q: q.fun)
    return (*best.x, best.fun)


def fits(g, o, u):
    """Spring fits for the gesture's moving parts."""
    out = []
    if g in ("press", "tap"):
        # The lens travelling (centre, while it is seen whole: 50 pt wide
        # or more, before it settles).
        s = [(i - u, x[1][0]) for i, x in enumerate(o)
             if x[1] is not None and x[1][1] >= 50 and 0 <= i - u <= 16]
        dest = 201.0 if g == "press" else 201 + 1.06 * (287 - 201)
        if len(s) >= 4:
            out.append(("travel", fit(*zip(*s), 115.0, dest)))
    if g in ("press", "drag"):
        # The bar's growth (left edge, first 24 frames).
        s = [(i - u, x[0][0]) for i, x in enumerate(o) if x[0] and 0 <= i - u <= 24]
        out.append(("grow", fit(*zip(*s), 64.0, 57.0)))
    return out


def fmt(o):
    bar, l, tx, n = o
    bs = " " * 17 if bar is None else f"{bar[0]:5.1f} {bar[1]:5.1f} {bar[2]:4.1f}"
    ls = " " * 16 if l is None else f"{l[0]:5.1f} {l[1]:5.1f} {l[2]:4.1f}"
    ts = "  —  " if tx is None else f"{tx:5.1f}"
    return f"{bs}|{ls}|{ts}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("run")
    ap.add_argument("gestures", nargs="*", default=["press", "tap", "drag"])
    ap.add_argument("--every", type=int, default=2)
    ap.add_argument("--takes", default="ref,native,shader")
    a = ap.parse_args()
    takes = a.takes.split(",")
    for g in a.gestures:
        tr = {}
        for t in takes:
            p = pathlib.Path(a.run) / f"{g}.{t}"
            if p.exists():
                tr[t] = track(p)
        print(f"== {g}: frame (0 = first changed frame) | bar left right top | lens centre width overhang | tint x (pt)")
        print("     " + "".join(f"{t:^47s}" for t in tr))
        n = max(len(o) - u for o, u in tr.values() if u is not None)
        for k in range(-2, n, a.every):
            cells = []
            for t, (o, u) in tr.items():
                i = (u or 0) + k
                cells.append(fmt(o[i]) if 0 <= i < len(o) else " " * 45)
            print(f"{k:4d} " + "  ".join(cells))
        for t, (o, u) in tr.items():
            seen = [i for i, x in enumerate(o) if x[1] is not None]
            if u is None or not seen:
                print(f"  {t}: no lens")
                continue
            w = max(o[i][1][1] for i in seen)
            h = max(o[i][1][2] for i in seen)
            grow = max(o[0][0][0] - x[0][0] for x in o if x[0])
            print(f"  {t}: lens frames {seen[0] - u}..{seen[-1] - u}, max width {w:.1f}, "
                  f"max overhang {h:.1f}, bar grows {grow:.1f} pt at the start")
            for name, (r, z, t0, rms) in fits(g, o, u):
                print(f"    {name}: response {r:.3f} damping {z:.2f} t0 {t0:+.1f} fr (rms {rms:.2f} pt)")
            if g == "drag":
                mid = [x[1][0] for i, x in enumerate(o) if x[1] and 20 <= i - u <= 50]
                print(f"    lens centre over frames 20-50: mean {np.mean(mid):.1f} pt")

if __name__ == "__main__":
    main()
