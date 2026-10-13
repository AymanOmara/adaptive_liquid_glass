"""Fits models of SwiftUI's swipe-action motion to the native (ref) takes
measured by swipe_motion.py.

Usage: swipe_fit.py <swipe_motion.json> <run-dir>

Input per frame: the row's offset (swipe_motion.py `off_any`) and each
action's measured box and strength. Per action k (0 = outermost):
  target T_k(reveal) = clamp((reveal - start_k) / (slotFull_k - start_k)),
  start_k = k(w+g) + g + 38, slotFull_k = (k+1)(w+g) + g, g = 10.33;
  measured size s = box height / natural height (the width stretches past
  rest; the height is the scale).
A) size models, driven by T over each take's frames (60 fps), fitted
   jointly to every opening take (slow, open, leading, full before the
   takeover); then the fitted models are run on the close takes.
B) alpha (strength / the action's strongest in the take) as a + b·x with
   x = T (unlagged), the measured size s, or the offset's own ramp.
C) the destructive full swipe after release: the takeover capsule's
   leading edge per frame (unclipped red), the row offset it implies, and
   a spring fit of that glide.
D) the finger speed near the reveal (row speed while reveal is 40-110 pt).
"""
import json
import math
import sys

import numpy as np
from PIL import Image
from scipy.optimize import minimize

G = 10.33
W = 402.0
SCALE = 3
TOP = 14.0
# Scene: (edge, natural width, natural height) of its actions.
SCENES = {
    "swipeonedark": ("trailing", 50, 50), "swipeone": ("trailing", 50, 50),
    "swipe": ("trailing", 87, 46), "swipetall": ("trailing", 60, 40),
}
LEADING = (67, 46)   # swipe's Pin
OPENING = ("slow", "open", "leading", "full")


def ramp(x, a, b):
    return np.clip((x - a) / (b - a), 0, 1)


def take_series(it, frames):
    """Per action k: arrays (reveal, s or nan, alpha or nan) over frames."""
    scene, g = it.split(".")
    edge, w, h = SCENES[scene]
    if g == "leading":
        edge, (w, h) = "leading", LEADING
    n_act = 1 if scene.startswith("swipeone") or g == "leading" else 2
    reveal = np.array([abs(f["off_any"]) for f in frames])
    # Full swipe: only until the row's content is lost (the takeover).
    end = len(frames)
    if g == "full":
        last = max(i for i, f in enumerate(frames) if f["off"] is not None)
        end = last + 1
    s = np.full((n_act, len(frames)), np.nan)
    a = np.full((n_act, len(frames)), np.nan)
    for i, f in enumerate(frames[:end]):
        acts = f["actions"]
        if edge == "trailing":
            acts = sorted(acts, key=lambda q: -q["cx"])
            rest = [W - G - w / 2 - k * (w + G) for k in range(n_act)]
        else:
            acts = sorted(acts, key=lambda q: q["cx"])
            rest = [G + w / 2 + k * (w + G) for k in range(n_act)]
        acts = [q for q in acts if q["h"] > 1.0]
        if len(acts) == n_act:
            ks = range(n_act)
        else:
            ks = [int(np.argmin([abs(q["cx"] - r) for r in rest])) for q in acts]
        for k, q in zip(ks, acts):
            s[k, i] = q["h"] / h
            a[k, i] = q["strength"]
    for k in range(n_act):
        seen = np.where(~np.isnan(s[k]))[0]
        if len(seen) == 0:
            continue
        # Unseen before the first sighting (opening) or after the last
        # (closing) is size 0.
        if g == "close":
            s[k, seen[-1] + 1:end] = 0
        else:
            s[k, :seen[0]] = 0
        a[k] /= np.nanmax(a[k])
    return {"edge": edge, "w": w, "n": n_act, "reveal": reveal[:end],
            "s": s[:, :end], "a": a[:, :end], "g": g}


def targets(ser, lead=38.0, endx=0.0):
    w = ser["w"]
    out = []
    for k in range(ser["n"]):
        st = k * (w + G) + G + lead
        sf = (k + 1) * (w + G) + G + endx
        out.append(ramp(ser["reveal"], st, sf))
    return out


def simulate(T, model, p, s0):
    """Frame-by-frame response of size to target series T."""
    dt, sub = 1 / 60, 8
    h = dt / sub
    s, v, out = s0, 0.0, []
    for t in T:
        for _ in range(sub):
            if model == "lag":
                s += (t - s) * (1 - math.exp(-h / max(p[0], 1e-4)))
            elif model in ("crit", "spring"):
                r = max(p[0], 0.02)
                z = 1.0 if model == "crit" else max(p[1], 0.05)
                om = 2 * math.pi / r
                acc = om * om * (t - s) - 2 * z * om * v
                v += acc * h
                s += v * h
            elif model in ("rate", "ratelag"):
                tgt = t
                if model == "ratelag":
                    v += (t - v) * (1 - math.exp(-h / max(p[1], 1e-4)))  # v = lagged target
                    tgt = v
                step = max(p[0], 0.01) * h
                s += max(-step, min(step, tgt - s))
        out.append(s)
    return np.array(out)


def rms_size(series, model, p, lead=38.0, endx=0.0):
    errs = []
    for ser in series:
        Ts = targets(ser, lead, endx)
        for k in range(ser["n"]):
            m = ser["s"][k]
            ok = ~np.isnan(m)
            if ok.sum() < 3:
                continue
            if model == "none":
                pred = Ts[k]
            else:
                pred = simulate(Ts[k], model, p, 1.0 if ser["g"] == "close" else 0.0)
            errs.append((pred[ok] - m[ok]) ** 2)
    if not errs:
        return float("nan"), 0
    e = np.concatenate(errs)
    return float(np.sqrt(e.mean())), len(e)


def fit(series, model, x0, joint=False):
    def f(q):
        if joint:
            return rms_size(series, model, q[:-2], q[-2], q[-1])[0]
        if model == "none":
            return rms_size(series, model, [], q[0], q[1])[0]
        return rms_size(series, model, q)[0]
    best = minimize(f, x0, method="Nelder-Mead", options={"maxiter": 800, "xatol": 1e-4, "fatol": 1e-6})
    return best.x, best.fun


def alpha_fit(series, size_p):
    """alpha = clip(a + b x) for x = T, measured s, own offset ramp."""
    def collect(xfun):
        xs, ys = [], []
        for ser in series:
            for k in range(ser["n"]):
                x = xfun(ser, k)
                ok = ~np.isnan(ser["a"][k]) & ~np.isnan(x)
                xs.append(x[ok]); ys.append(ser["a"][k][ok])
        return np.concatenate(xs), np.concatenate(ys)

    def lsq(x, y):
        f = lambda q: np.sqrt(np.mean((np.clip(q[0] + q[1] * x, 0, 1) - y) ** 2))
        b = minimize(f, [0.2, 0.8], method="Nelder-Mead")
        return b.x, b.fun
    out = {}
    x, y = collect(lambda ser, k: targets(ser)[k])
    out["T (unlagged)"] = lsq(x, y)
    x, y = collect(lambda ser, k: ser["s"][k])
    out["s (measured)"] = lsq(x, y)
    x, y = collect(lambda ser, k: simulate(targets(ser)[k], "lag", [size_p], 0.0))
    out["s (lag model)"] = lsq(x, y)

    def own(q):
        def xf(ser, k):
            return targets(ser, q[0], q[1])[k]
        x, y = collect(xf)
        return np.sqrt(np.mean((x - y) ** 2))
    b = minimize(own, [30.0, 0.0], method="Nelder-Mead")
    out[f"own ramp (lead {b.x[0]:.1f}, end {b.x[1]:+.1f})"] = ((0.0, 1.0), b.fun)
    return out


def red_edge(run, it, k):
    im = np.asarray(Image.open(f"{run}/{it}.ref/{k + 1:04d}.png").convert("RGB")).astype(int)
    red = (im[..., 0] > 200) & (im[..., 1] < 110) & (im[..., 2] < 110)
    ys, xs = np.where(red)
    if len(xs) < 50:
        return None
    return xs.min() / SCALE, (xs.max() + 1) / SCALE, (ys.max() + 1) / SCALE - TOP


def full_swipe(d, run):
    for it in ("swipeonedark.full", "swipe.full"):
        fr = d[it]["ref"]["frames"]
        u = d[it]["ref"]["summary"]["onset_frame"]
        # The takeover: the capsule's leading edge jumps (row gone); the
        # frame before it is the last one with the row.
        e = [red_edge(run, it, k) for k in range(u, u + 20)]
        x0 = [q[0] if q else np.nan for q in e]
        jumps = [x0[i - 1] - x0[i] for i in range(1, len(x0))]
        rel = u + int(np.nanargmax(jumps))
        print(f"  {it}: drag onset frame {u}; last frame with the row: +{rel - u} "
              f"(offset {fr[rel]['off_any']:.0f})")
        xs, ts = [], []
        for k in range(rel, rel + 12):
            e = red_edge(run, it, k)
            if e is None:
                break
            xs.append(e[0]); ts.append(k - rel)
            print(f"    +{k - rel}: capsule x {e[0]:.1f}-{e[1]:.1f}, bottom {e[2]:.1f}"
                  + (f"  (implied row offset {e[0] - G - W:.0f})" if it.startswith("swipeone") else ""))
        # Spring glide of the leading edge after the row goes: from the
        # first takeover frame (1 after rel) to its minimum.
        xs, ts = np.array(xs[1:]), np.array(ts[1:], float)
        stop = int(np.argmin(xs)) + 1
        xs, ts = xs[:stop], ts[:stop]
        if len(xs) >= 4:
            def err(q):
                x1, r, z, v0 = q
                # The glide ends at (or a little past) the edge's minimum.
                if r <= 0.02 or z <= 0.3 or not xs.min() - 10 <= x1 <= xs.min():
                    return 1e9
                om = 2 * math.pi / r
                t = (ts - ts[0]) / 60
                d0 = xs[0] - x1
                if z < 1:
                    wd = om * math.sqrt(1 - z * z)
                    m = x1 + np.exp(-z * om * t) * (d0 * np.cos(wd * t) + (v0 + z * om * d0) / wd * np.sin(wd * t))
                else:
                    m = x1 + np.exp(-om * t) * (d0 + (v0 + om * d0) * t)
                return float(np.sqrt(np.mean((m - xs) ** 2)))
            b = min((minimize(err, [xs.min() - 1, r, z, v], method="Nelder-Mead")
                     for r in (0.15, 0.3, 0.5) for z in (0.8, 1.0) for v in (0, -1500)),
                    key=lambda q: q.fun)
            print(f"    glide fit: to x {b.x[0]:.1f}, response {b.x[1]:.3f}, damping {b.x[2]:.2f}, "
                  f"v0 {b.x[3]:.0f} pt/s (rms {b.fun:.2f} pt over {len(xs)} frames)")


def finger(d):
    for it in sorted(d):
        fr = d[it]["ref"]["frames"]
        g = it.split(".")[1]
        if g == "close":
            continue
        rv = np.array([abs(f["off_any"]) for f in fr])
        u = d[it]["ref"]["summary"]["onset_frame"]
        top = int(np.argmax(rv))
        idx = [i for i in range(u, top) if 40 <= rv[i] <= 110]
        if len(idx) >= 2:
            sp = (rv[idx[-1]] - rv[idx[0]]) / (idx[-1] - idx[0]) * 60
            print(f"  {it}: {sp:.0f} pt/s (reveal 40-110 over {len(idx)} frames)")


def main():
    d = json.load(open(sys.argv[1]))
    run = sys.argv[2]
    items = [it for it in d if it.split(".")[0] in SCENES and "ref" in d[it]]
    opening = [take_series(it, d[it]["ref"]["frames"]) for it in items
               if it.split(".")[1] in OPENING]
    closing = [take_series(it, d[it]["ref"]["frames"]) for it in items
               if it.split(".")[1] == "close"]
    print("A) size against T (rms in scale units; opening takes; then the same params on close takes)")
    res = {}
    for name, model, x0 in [("1 first-order lag tau", "lag", [0.08]),
                            ("2 critically damped spring r", "crit", [0.3]),
                            ("3 spring r, zeta", "spring", [0.3, 0.8]),
                            ("4a rate limit R (1/s)", "rate", [6.0]),
                            ("4b rate limit R + lag tau", "ratelag", [6.0, 0.05])]:
        p, e = fit(opening, model, x0)
        res[name] = (p, e)
        ec = rms_size(closing, model, p)[0]
        print(f"  {name}: {np.round(p, 4)} rms {e:.4f}; on close {ec:.4f}")
    for name in ("1 first-order lag tau", "4b rate limit R + lag tau"):
        p, _ = res[name]
        model = "lag" if name.startswith("1") else "ratelag"
        per = ", ".join(f"{ser_name}: {rms_size([ser], model, p)[0]:.3f}"
                        for ser_name, ser in zip([it for it in items if it.split(".")[1] in OPENING], opening))
        print(f"    per take ({name.split()[0]}): {per}")
    p, e = fit(opening, "none", [38.0, 0.0])
    print(f"  5 no lag, start lead {p[0]:.1f}, end {p[1]:+.1f}: rms {e:.4f}; "
          f"(fixed 38/0: {rms_size(opening, 'none', [])[0]:.4f})")
    for name, model, x0 in [("1+ramp lag tau, lead, end", "lag", [0.08, 38.0, 0.0]),
                            ("2+ramp crit r, lead, end", "crit", [0.3, 38.0, 0.0])]:
        p, e = fit(opening, model, x0, joint=True)
        print(f"  {name}: {np.round(p, 3)} rms {e:.4f}")
    print("B) alpha = clip(a + b x)")
    for k, ((a, b), e) in alpha_fit(opening, res["1 first-order lag tau"][0][0]).items():
        print(f"  x = {k}: a {a:.3f} b {b:.3f} rms {e:.4f}")
    print("C) destructive full swipe after release")
    full_swipe(d, run)
    print("D) finger (row) speed near the reveal")
    finger(d)


if __name__ == "__main__":
    main()
