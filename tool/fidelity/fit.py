"""Fits the glass constants against SwiftUI screenshots on the NumPy model.

Stages (spec §15 / Task 17 v2), each fed with the previous one's output:

    fit.py corner        --start S --out O   # 1-D scan of cornerExponent
    fit.py regular       --start S --out O   # regular-*-light (no tinted)
    fit.py regularDark   --start S --out O   # regular-*-dark
    fit.py clear         --start S --out O   # clear-*-light
    fit.py clearDark     --start S --out O   # clear-*-dark
    fit.py tinted        --start S --out O   # tintStrength of regular/regularDark
    fit.py merge         --start S --out O   # 1-D scan of mergeFactor
    fit.py polishRegular --start S --out O   # regular + regularDark (all keys) on
                                             # regular-*, tinted-*, merge-*
    fit.py polishClear   --start S --out O   # clear + clearDark on clear-*
    fit.py polishRegularDark --start S --out O  # regularDark on every dark
                                             # regular-*, tinted-*, merge-*
    fit.py score         --start S [--scenes PREFIX]   # per-scene numbers only

Loss: mean over the stage's scenes of (1 - SSIM) * 10 + ΔE / 2, scored in
compare.py's region against build/fidelity/baseline-v2/<id>.swiftui.png.
"""
import argparse
import json
import multiprocessing as mp
import pathlib
import sys
import time

import numpy as np
from scipy.optimize import minimize

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from compare import load, region_for  # noqa: E402
from glass_model import render_window, resolve_constants  # noqa: E402
from skimage.color import deltaE_ciede2000, rgb2lab  # noqa: E402
from skimage.metrics import structural_similarity  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = json.loads((ROOT / "tool/scenes/scenes.json").read_text())
REF = ROOT / "build/fidelity/baseline-v2"
SCALE = SPEC["device"]["scale"]

KEYS = ["blurSigma", "blurSizeRef", "frostWideSigma", "frostWideMixEdge", "frostWideMixCentre",
        "frostWideSizeRef", "frostWideSizeDrop",
        "lensBand", "lensStrength", "lensDecay", "lensSizeRef", "dispersion",
        "rimWidth", "rimIntensity", "fillOpacity", "fillSizeRef", "fillSizeDrop", "fillR", "fillG", "fillB", "saturation", "dim",
        "shadowRadius", "shadowOpacity", "tintStrength",
        "tone0", "tone1", "tone2", "tone3", "tone4", "tone5", "tone6", "tone7", "tone8",
        "postBlurShare", "normalRadiusScale", "lensEdge", "lensEdgeDecay",
        "rimMix", "rimMixWidth", "rimMixCut", "rimMixLumaFloor",
        "toneLift", "toneLiftKnee", "toneLiftSizeRef"]
TONE_KEYS = [f"tone{i}" for i in range(9)]
BOUNDS = {"blurSigma": (0, 30), "lensBand": (1, 40), "lensStrength": (-3, 3),
          # Task 17b: frost sigma x min(1, halfMin / blurSizeRef) (pt); 0 = off.
          "blurSizeRef": (0, 200),
          # Task 17c wide frost tail (pt / weights / pt), measured by
          # measure_frost.py + jointfit: sigma of the 16-tap wide component and
          # the weight w = mix(edge, centre, sampleDepth / halfMin) minus the
          # size term; sigma 0 disables the tail.
          "frostWideSigma": (0, 30), "frostWideMixEdge": (-1, 2),
          "frostWideMixCentre": (-1, 2), "frostWideSizeRef": (0, 200),
          "frostWideSizeDrop": (0, 5),
          # Task 17d tone LUT knots (grey, inputs i/8).
          **{k: (0, 1) for k in TONE_KEYS},
          # Task 17d clear-analysis features (measured shapes, fitted sizes):
          # post-lens blur share of the frost variance, lens normals from a
          # rounder rect (radius x scale), lens edge term (pt, pt) and the
          # isotropic rim mix toward white (alpha, pt, pt, luma floor).
          "postBlurShare": (0, 0.9), "normalRadiusScale": (1, 2.5),
          "lensEdge": (0, 20), "lensEdgeDecay": (0.1, 3),
          "rimMix": (0, 1), "rimMixWidth": (0.3, 4), "rimMixCut": (0.3, 4),
          "rimMixLumaFloor": (0, 1),
          # Task 8b small-shape shadow lift (amount, knee, size ref pt).
          "toneLift": (0, 1), "toneLiftKnee": (0.05, 1), "toneLiftSizeRef": (0, 200),
          # Lens v3 (pt); Task 15c measured 6.4-6.5 and 38.4 (regular) / 0 (clear).
          "lensDecay": (0.5, 20), "lensSizeRef": (0, 100),
          "dispersion": (0, 0.6), "rimWidth": (0.3, 4), "rimIntensity": (0, 1.5),
          "fillOpacity": (0, 1),
          # Task 17b: fillOpacity x (1 - drop x (1 - min(1, halfMin / ref))).
          "fillSizeRef": (0, 200), "fillSizeDrop": (0, 0.8),
          "fillR": (0, 1), "fillG": (0, 1), "fillB": (0, 1),
          "saturation": (0, 2.5), "dim": (0, 0.6), "shadowRadius": (0, 40),
          "shadowOpacity": (0, 0.5),
          # The shader mixes toward the tint by tintStrength x alpha; SwiftUI's
          # mix is ~0.6 at alpha 0.6 (Task 17b), so allow > 1.
          "tintStrength": (0, 1.6)}
# Keys that cannot change the score of a family (no tinted shape in it).
NO_TINT = [k for k in KEYS if k != "tintStrength"]


def scenes_for(stage):
    s = SPEC["scenes"]
    if stage == "corner":
        return [x for x in s if x["id"].startswith(("regular-rect16", "regular-rect28"))
                and x["brightness"] == "light"]
    if stage in ("regular", "regularDark", "clear", "clearDark"):
        base = "clear" if stage.startswith("clear") else "regular"
        br = "dark" if stage.endswith("Dark") else "light"
        return [x for x in s if x["id"].startswith(base + "-") and x["brightness"] == br]
    if stage == "tinted":
        return [x for x in s if x["id"].startswith("tinted-")]
    if stage == "merge":
        return [x for x in s if x["id"].startswith("merge-gap")]
    if stage == "polishRegular":  # every scene drawn with the regular sets
        return [x for x in s if x["id"].startswith(("regular-", "tinted-", "merge-"))]
    if stage == "polishRegularDark":  # every dark scene drawn with regularDark
        return [x for x in s if x["id"].startswith(("regular-", "tinted-", "merge-"))
                and x["brightness"] == "dark"]
    if stage == "polishClear":
        return [x for x in s if x["id"].startswith("clear-")]
    raise ValueError(stage)


# --- worker pool with a fixed scene partition (keeps per-process caches warm) --

_DATA = {}


def _load(scene_ids):
    bgs = {}
    for sid in scene_ids:
        sc = next(x for x in SPEC["scenes"] if x["id"] == sid)
        if sc["background"] not in bgs:
            bgs[sc["background"]] = load(ROOT / f"example/assets/backgrounds/{sc['background']}.png")
        ref = load(REF / f"{sid}.swiftui.png")
        x0, y0, x1, y1 = region_for(sc, SCALE, ref.shape[1], ref.shape[0])
        r = ref[y0:y1, x0:x1]
        _DATA[sid] = (sc, bgs[sc["background"]], r, rgb2lab(r), (x0, y0, x1, y1))


def score_one(sid, constants):
    sc, bg, ref, ref_lab, box = _DATA[sid]
    win, wbox = render_window(bg, sc, constants, SCALE)
    assert tuple(wbox) == tuple(box), (wbox, box)
    ssim = structural_similarity(win, ref, channel_axis=2, data_range=1.0)
    de = float(deltaE_ciede2000(rgb2lab(win), ref_lab).mean())
    return float(ssim), de


def _worker(conn, scene_ids):
    _load(scene_ids)
    while True:
        msg = conn.recv()
        if msg is None:
            return
        conn.send([(sid, *score_one(sid, msg)) for sid in scene_ids])


class Pool:
    def __init__(self, scene_ids, procs):
        procs = max(1, min(procs, len(scene_ids)))
        parts = [scene_ids[i::procs] for i in range(procs)]
        ctx = mp.get_context("fork")
        self.conns, self.procs = [], []
        for part in parts:
            a, b = ctx.Pipe()
            p = ctx.Process(target=_worker, args=(b, part), daemon=True)
            p.start()
            self.conns.append(a)
            self.procs.append(p)
        self.order = scene_ids

    def scores(self, constants):
        for c in self.conns:
            c.send(constants)
        out = {}
        for c in self.conns:
            for sid, ssim, de in c.recv():
                out[sid] = (ssim, de)
        return [(sid, *out[sid]) for sid in self.order]

    def close(self):
        for c in self.conns:
            c.send(None)


# Task 17d: optional worst-case term (`--ssim-floor`): every scene below the
# floor adds 100 x its shortfall, so the fit cannot trade one scene's SSIM for
# the mean (the user's target is the minimum).
SSIM_FLOOR = [None]


def loss_of(rows):
    base = float(np.mean([(1 - s) * 10 + d / 2 for _, s, d in rows]))
    if SSIM_FLOOR[0] is not None:
        base += 100.0 * float(np.mean([max(0.0, SSIM_FLOOR[0] - s) for _, s, _ in rows]))
    return base


# --- parameter access ---------------------------------------------------------


def get(c, set_name, key):
    v = c[set_name]
    if key in ("fillR", "fillG", "fillB"):
        h = v["fillColor"].lstrip("#")
        rgb = v.get("_fill") or [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
        return rgb["RGB".index(key[-1])]
    if key.startswith("tone") and key[4:].isdigit():
        return float(v["toneKnots"][int(key[4:])])
    return float(v[key])


def put(c, set_name, key, value):
    v = c[set_name]
    if key in ("fillR", "fillG", "fillB"):
        h = v["fillColor"].lstrip("#")
        rgb = list(v.get("_fill") or [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])
        rgb["RGB".index(key[-1])] = float(value)
        v["_fill"] = rgb
        v["fillColor"] = "#" + "".join(f"{int(round(x * 255)):02X}" for x in rgb)
    elif key.startswith("tone") and key[4:].isdigit():
        v.setdefault("toneKnots", [i / 8 for i in range(9)])[int(key[4:])] = float(value)
    else:
        v[key] = float(value)


def model_constants(c):
    """Constants for the model: the fill keeps its unrounded value while fitting."""
    out = json.loads(json.dumps(c))
    for name in ("regular", "clear", "regularDark", "clearDark"):
        f = out[name].pop("_fill", None)
        if f is not None:
            out[name]["fillColor"] = int(sum(int(round(x * 255)) << s for x, s in zip(f, (16, 8, 0))))
    return out


def clean(c):
    out = json.loads(json.dumps(c))
    for name in ("regular", "clear", "regularDark", "clearDark"):
        out[name].pop("_fill", None)
        for k, v in list(out[name].items()):
            if isinstance(v, float):
                out[name][k] = round(v, 4)
    for k in ("cornerExponent", "mergeFactor"):
        out[k] = round(float(out[k]), 4)
    return out


# --- stages ---------------------------------------------------------------------


def report(rows, label):
    print(f"\n{label}: loss {loss_of(rows):.4f}")
    for sid, s, d in rows:
        ok = "PASS" if s >= 0.97 and d <= 2.0 else "    "
        print(f"  {ok} {sid:36s} SSIM {s:.4f}  ΔE {d:6.2f}")
    print(f"  median SSIM {np.median([r[1] for r in rows]):.4f}  "
          f"median ΔE {np.median([r[2] for r in rows]):.2f}")
    sys.stdout.flush()


def scan(pool, c, key, values):
    best = None
    for v in values:
        c2 = json.loads(json.dumps(c))
        c2[key] = float(v)
        lo = loss_of(pool.scores(model_constants(c2)))
        print(f"  {key}={v:.2f} loss {lo:.4f}")
        sys.stdout.flush()
        if best is None or lo < best[1]:
            best = (float(v), lo)
    c[key] = round(best[0], 4)
    return c


CHECKPOINT = [None]
FTOL = [1e-4]  # path: best-so-far constants, rewritten as the fit improves


def fit_sets(pool, c, targets, keys, restarts, maxfev, seed=0):
    """Powell over `keys` of every set in `targets`, normalised to [0, 1]."""
    params = [(t, k) for t in targets for k in keys]
    lo = np.array([BOUNDS[k][0] for _, k in params], float)
    hi = np.array([BOUNDS[k][1] for _, k in params], float)
    x0 = np.array([np.clip(get(c, t, k), BOUNDS[k][0], BOUNDS[k][1]) for t, k in params])
    n = len(params)
    evals = [0]
    t0 = time.time()

    def apply(u):
        c2 = json.loads(json.dumps(c))
        for (t, k), v in zip(params, lo + np.clip(u, 0, 1) * (hi - lo)):
            put(c2, t, k, v)
        return c2

    best = [np.inf, None]

    def f(u):
        evals[0] += 1
        lo_ = loss_of(pool.scores(model_constants(apply(u))))
        if lo_ < best[0]:
            best[0], best[1] = lo_, np.array(u)
        if CHECKPOINT[0] is not None and evals[0] % 10 == 0:
            CHECKPOINT[0].write_text(json.dumps(clean(apply(best[1])), indent=2) + "\n")
        if evals[0] % 50 == 0:
            print(f"  eval {evals[0]} loss {lo_:.4f} ({time.time() - t0:.0f}s)")
            sys.stdout.flush()
        return lo_

    u0 = (x0 - lo) / (hi - lo)
    best_u, best_f = u0, f(u0)
    print(f"  start loss {best_f:.4f}")
    rng = np.random.default_rng(seed)
    for _ in range(restarts):  # coarse random restarts around the start
        u = np.clip(u0 + rng.normal(0, 0.15, n), 0, 1)
        fu = f(u)
        if fu < best_f:
            best_u, best_f = u, fu
    print(f"  after {restarts} random starts: {best_f:.4f}")
    res = minimize(f, best_u, method="Powell", bounds=[(0, 1)] * n,
                   options={"maxfev": maxfev, "xtol": 1e-3, "ftol": FTOL[0]})
    u = res.x if res.fun < best_f else best_u
    print(f"  Powell: loss {min(res.fun, best_f):.4f}, {evals[0]} evals, {time.time() - t0:.0f}s")
    return apply(u)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("stage", choices=["corner", "regular", "regularDark", "clear", "clearDark",
                                      "tinted", "merge", "polishRegular", "polishClear",
                                      "polishRegularDark",
                                      "score"])
    ap.add_argument("--start", type=pathlib.Path,
                    default=ROOT / "tool/fidelity/standard_constants.json")
    ap.add_argument("--out", type=pathlib.Path)
    ap.add_argument("--only", help="comma-separated keys to free (default: all for the stage)")
    ap.add_argument("--scenes", default="", help="score: scene id prefix")
    ap.add_argument("--restarts", type=int, default=0)
    ap.add_argument("--maxfev", type=int, default=3000)
    ap.add_argument("--procs", type=int, default=8)
    ap.add_argument("--seed", type=int, default=0, help="random-restart seed")
    ap.add_argument("--ssim-floor", type=float,
                    help="add 100 x mean shortfall below this SSIM to the loss")
    ap.add_argument("--ftol", type=float, default=1e-4, help="Powell ftol")
    ap.add_argument("--checkpoint", type=pathlib.Path,
                    help="rewrite best-so-far constants here during the fit")
    ap.add_argument("--lo", type=float, help="corner: scan start (default 2.0)")
    ap.add_argument("--hi", type=float, help="corner: scan end (default 6.0)")
    args = ap.parse_args()

    # Missing keys (e.g. Task 17 stage files without the lens v3 keys) come
    # from standard_constants.json, as GlassConstants.fromJson does.
    SSIM_FLOOR[0] = args.ssim_floor
    CHECKPOINT[0] = args.checkpoint
    FTOL[0] = args.ftol
    c = resolve_constants(json.loads(args.start.read_text()))
    if args.stage == "score":
        scenes = [s for s in SPEC["scenes"] if s["id"].startswith(args.scenes)]
    else:
        scenes = scenes_for(args.stage)
    pool = Pool([s["id"] for s in scenes], args.procs)
    try:
        report(pool.scores(model_constants(c)), "before")
        if args.stage == "corner":
            c = scan(pool, c, "cornerExponent", np.arange(args.lo if args.lo is not None else 2.0, (args.hi or 6.0) + 1e-4, 0.1))
        elif args.stage == "merge":
            c = scan(pool, c, "mergeFactor", np.arange(0.2, 3.0001, 0.1))
        elif args.stage == "tinted":
            keys = ["tintStrength"]
            # Light and dark tinted scenes depend on different sets; fit each.
            if args.only:
                keys = args.only.split(",")
            for t, br in (("regular", "light"), ("regularDark", "dark")):
                sub = Pool([s["id"] for s in scenes if s["brightness"] == br], args.procs)
                c = fit_sets(sub, c, [t], keys, args.restarts, args.maxfev, seed=args.seed)
                sub.close()
        elif args.stage == "polishRegularDark":
            keys = args.only.split(",") if args.only else KEYS
            c = fit_sets(pool, c, ["regularDark"], keys, args.restarts, args.maxfev,
                         seed=args.seed)
        elif args.stage in ("polishRegular", "polishClear"):
            base = "regular" if args.stage == "polishRegular" else "clear"
            keys = args.only.split(",") if args.only else (KEYS if base == "regular" else NO_TINT)
            c = fit_sets(pool, c, [base, base + "Dark"], keys, args.restarts, args.maxfev,
                         seed=args.seed)
        elif args.stage != "score":
            keys = args.only.split(",") if args.only else NO_TINT
            c = fit_sets(pool, c, [args.stage], keys, args.restarts, args.maxfev, seed=args.seed)
        report(pool.scores(model_constants(c)), "after")
    finally:
        pool.close()
    out = clean(c)
    if args.out:
        args.out.write_text(json.dumps(out, indent=2) + "\n")
    print(json.dumps(out))


if __name__ == "__main__":
    main()
