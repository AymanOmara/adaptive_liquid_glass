"""Aligns press/morph recordings (record_motion.sh) and scores them frame by
frame against the static bars; fits SwiftUI-style springs and press
amplitudes for each renderer.

Usage: compare_motion.py <run-dir> [--prefix ID] [--no-fail] [--strips DIR]
       compare_motion.py <run-a> --noise-ref <run-b>

Frames come from record_motion.sh: lossless screen captures by default, or
h264 recordings (DUMP=0; the codec alone costs about 0.04 SSIM). Read the
bars against the measurement floor: `--noise-ref` scores each renderer's
clips of one run against the same renderer's clips of another
(noise_report.json).
"""
import argparse
import json
import pathlib
import sys
import warnings

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.optimize import OptimizeWarning, curve_fit

from compare import DELTA_E_MAX, INFLATE_PT, SSIM_MIN, load, score

ROOT = pathlib.Path(__file__).resolve().parents[2]
FPS = 60
FRAMES = 96          # scored window after the onset (1.6 s)
# Onset: the ONSET_PERCENTILE of the σ = ONSET_SIGMA blurred |Δ| map exceeds
# ONSET_THRESHOLD. A mean over the crop is fooled by the encoder re-sending a
# static frame at higher quality (measured: mean 0.005 everywhere, peaks on
# the thin stripes) long before anything moves.
ONSET_THRESHOLD = 0.08
ONSET_PERCENTILE = 99.5
ONSET_SIGMA = 2.0
# Glass pixels: mean |frame − background| above this after a Gaussian blur.
# Measured on the photo background: h264 errors outside the glass reach 0.35
# raw but stay below 0.08 at σ = 4 px, while the glass interior's median is
# about 0.3, so 0.12 sits near the edge's half level (little blur bias).
BBOX_THRESHOLD = 0.12
BBOX_SIGMA = 4.0
SHIFT = 2            # ± frames searched to refine the onset alignment (plus a phase)
GLOW_INSET_PT = 8    # glow fit ignores this rim of the resting shape
UNSETTLED_PX = 4     # press bbox drift between first and last frame

def first_change(frames, threshold=ONSET_THRESHOLD):
    """Index of the first frame that differs from frame 0 locally: the
    ONSET_PERCENTILE of its blurred |Δ| map exceeds `threshold`."""
    base = frames[0]
    for i, f in enumerate(frames):
        d = ndimage.gaussian_filter(np.abs(f - base).mean(axis=2), ONSET_SIGMA)
        if np.percentile(d, ONSET_PERCENTILE) > threshold:
            return i
    return len(frames)


def spring(t, response, zeta):
    """SwiftUI `.spring(response:dampingFraction:)` step response, 0 → 1."""
    t = np.asarray(t, dtype=np.float64)
    w0 = 2 * np.pi / response
    if zeta < 0.9999:
        wd = w0 * np.sqrt(1 - zeta**2)
        return 1 - np.exp(-zeta * w0 * t) * (np.cos(wd * t) + zeta * w0 / wd * np.sin(wd * t))
    if zeta <= 1.0001:
        return 1 - np.exp(-w0 * t) * (1 + w0 * t)
    s = np.sqrt(zeta**2 - 1)
    r1, r2 = -w0 * (zeta - s), -w0 * (zeta + s)
    return 1 - (r2 * np.exp(r1 * t) - r1 * np.exp(r2 * t)) / (r2 - r1)


MAX_HIDDEN_S = 0.4   # a spring may start this long before its first visible frame


def fit_spring(t, x, full=False, floor=False):
    """Fits `x[0] + amp·spring(t − t0)` to the moving part of a curve and
    returns (response, dampingFraction) (plus base, amp, t0 and the RMS
    residual when `full`).

    Only samples from the first moving one are fitted, and t0 may lie up to
    MAX_HIDDEN_S before it: Flutter (debug build on the simulator) can stall
    after a morph starts, so its first displayed frame is already far along,
    while the free sub-frame t0 also absorbs an onset that falls between
    frames. The base is the resting value x[0].

    `floor`: the curve is clipped from below at its lower end value, as a
    group's union width is while a member grows out of (or shrinks into)
    another member (SwiftUI morphs from the source's centre); the unclipped
    base is then free."""
    t = np.asarray(t, np.float64)
    x = np.asarray(x, np.float64)
    tail = np.median(x[-max(3, len(x) // 10):])
    lo = min(x[0], tail)
    moving = np.nonzero(np.abs(x - x[0]) > max(1.0, 0.02 * abs(tail - x[0])))[0]
    k = int(moving[0]) if moving.size else 1
    tk, xk = t[k:], x[k:]
    t_lo, t_hi = t[k] - MAX_HIDDEN_S, t[k]

    def model(t, response, zeta, base, amp, t0):
        y = (base if floor else x[0]) + amp * spring(np.clip(t - t0, 0, None), response, zeta)
        return np.maximum(lo, y) if floor else y

    best = None
    amp_guesses = [tail - x[0]] if not floor else [(tail - x[0]) * f for f in (1, 1.5, 2.5)]
    for r0 in (0.2, 0.4, 0.7):
        for z0 in (0.5, 0.8, 1.0):
            for a0 in amp_guesses:
                for t00 in (t[k] - 1 / FPS, t[k] - 0.15):
                    try:
                        with warnings.catch_warnings():
                            # Flat or short segments: covariance is not needed.
                            warnings.simplefilter("ignore", OptimizeWarning)
                            p, _ = curve_fit(model, tk, xk, p0=(r0, z0, tail - a0, a0, t00),
                                             bounds=([0.05, 0.05, -np.inf, -np.inf, t_lo],
                                                     [2.0, 2.0, np.inf, np.inf, t_hi]),
                                             maxfev=20000)
                    except (RuntimeError, ValueError):
                        continue
                    rms = float(np.sqrt(np.mean((model(tk, *p) - xk) ** 2)))
                    if best is None or rms < best[1]:
                        best = (p, rms)
    p, rms = best
    if full:
        return {"response": float(p[0]), "damping": float(p[1]),
                "base": float(p[2] if floor else x[0]), "amp": float(p[3]),
                "t0": float(p[4] - t[k]), "rms": rms}
    return float(p[0]), float(p[1])


def glass_bbox(frame, bg, threshold=BBOX_THRESHOLD, sigma=BBOX_SIGMA):
    """(x0, y0, x1, y1), exclusive, of pixels that differ from the background:
    the difference map is blurred by `sigma` px (codec error on thin
    stripes), thresholded, and cleaned of speckles by a 3×3 opening."""
    d = np.abs(frame - bg).mean(axis=2)
    if sigma:
        d = ndimage.gaussian_filter(d, sigma)
    mask = ndimage.binary_opening(d > threshold, structure=np.ones((3, 3)))
    ys, xs = np.nonzero(mask)
    if not xs.size:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def press_amplitudes(rest, pressed, dx, dy):
    """(pressScale, pressStretch) of Flutter's press model from two bboxes:
    sx = 1 + S + T|dx|, sy = 1 + S + T|dy| (dx, dy: touch offset over the
    half size). A touch with |dx| = |dy| cannot separate T: returns (S, None)
    with the mean scale."""
    sx = (pressed[2] - pressed[0]) / (rest[2] - rest[0])
    sy = (pressed[3] - pressed[1]) / (rest[3] - rest[1])
    ax, ay = abs(dx), abs(dy)
    if abs(ax - ay) < 1e-6:
        return float((sx + sy) / 2 - 1), None
    t = (sx - sy) / (ax - ay)
    return float(sx - 1 - t * ax), float(t)


def fit_glow(lift, mask, touch):
    """Fits `c + amp·exp(−d²/2σ²)` (d from `touch`, in px) to the luminance
    lift inside `mask`; returns (σ px, amp)."""
    yy, xx = np.nonzero(mask)
    d2 = (xx - touch[0]) ** 2 + (yy - touch[1]) ** 2
    v = lift[yy, xx]

    def g(d2, sigma, amp, c):
        return c + amp * np.exp(-d2 / (2 * sigma**2))

    p, _ = curve_fit(g, d2, v, p0=(30.0, float(v.max() - np.median(v)), float(np.median(v))),
                     bounds=([1.0, -np.inf, -np.inf], [2000.0, np.inf, np.inf]), maxfev=20000)
    return float(p[0]), float(p[1])


def _luma(img):
    return img @ np.array([0.2126, 0.7152, 0.0722])


def _load_frames(d):
    return [load(f) for f in sorted(d.glob("*.png"))]


def _asset_background(m, crop):
    img = load(ROOT / f"example/assets/backgrounds/{m['background']}.png")
    return img[crop["y"]:crop["y"] + crop["h"], crop["x"]:crop["x"] + crop["w"]]


PHASES = 10  # sub-frame phase steps searched per segment


def _frame(raw, k, f):
    """Clip frame k, or the linear interpolation k + f toward frame k + 1."""
    return raw[k] if f == 0 else (1 - f) * raw[k] + f * raw[k + 1]


def _align(idx, raw, a, b):
    """Aligns the window positions `idx` ({label: [(clip index, phase)]},
    first entries aligned at the onsets) of a and b: b is shifted by
    s ± SHIFT frames plus a sub-frame phase f in [0, 1), its frames
    interpolated between neighbours, to the best mean match over the
    segment. The touch lands at a random point between two display frames
    and SwiftUI animates from the touch time (measured: SwiftUI takes of
    one press differ by up to half a frame after integer alignment), so a
    whole-frame shift leaves a sampling error the renderers do not make.
    One phase per segment, not per frame. Returns the trimmed lists and the
    shift s + f of b."""
    ia, ib = idx[a], idx[b]
    n = min(len(ia), len(ib))
    best = (None, 0, 0.0)
    if n:
        sub = (slice(None, None, 2), slice(None, None, 2))  # search on every 2nd pixel
        sa = [raw[a][k][sub] for k, _ in ia[:n]]
        for sh in range(-SHIFT, SHIFT + 1):
            for f in np.arange(PHASES) / PHASES:
                pairs = [(i, i + sh) for i in range(n)
                         if 0 <= i + sh and i + sh + (f > 0) < len(ib)]
                if not pairs:
                    continue
                err = np.mean([np.abs(sa[i] - _frame(raw[b], ib[j][0], f)[sub]).mean()
                               for i, j in pairs])
                if best[0] is None or err < best[0] - 1e-9:
                    best = (err, sh, float(f))
    _, sh, f = best
    out = dict(idx)
    if sh >= 0:
        out[b] = [(k, f) for k, _ in ib[sh:]]
    else:
        out[a] = ia[-sh:]
        out[b] = [(k, f) for k, _ in ib]
    if f > 0:  # the last frame has no successor to interpolate toward
        out[b] = [(k, g) for k, g in out[b] if k + 1 < len(raw[b])]
    return {**out, "shift": sh + f}


def _press_meta(m, scale, crop):
    s = m["shape"]
    dx = (m["touch"]["x"] - (s["x"] + s["w"] / 2)) / (s["w"] / 2)
    dy = (m["touch"]["y"] - (s["y"] + s["h"] / 2)) / (s["h"] / 2)
    touch = (m["touch"]["x"] * scale - crop["x"], m["touch"]["y"] * scale - crop["y"])
    return dx, dy, touch


def _analyse(m, frames, bg, scale, crop):
    """Per-renderer widths, springs and (press) amplitudes."""
    boxes = [glass_bbox(f, bg) for f in frames]
    widths = [b[2] - b[0] if b else 0 for b in boxes]
    t = np.arange(len(frames)) / FPS
    out = {"widths": widths}
    if max(widths) - min(widths) <= 2:
        return out
    if m["kind"] != "press":
        out["spring"] = fit_spring(t, widths, full=True, floor=True)
        return out
    rel = min(int(round(m.get("hold_ms", 0) / 1000 * FPS)) + 1, len(frames) - 4)
    out["spring_in"] = fit_spring(t[:rel], widths[:rel], full=True)
    out["spring_out"] = fit_spring(t[rel:] - t[rel], widths[rel:], full=True)
    dx, dy, touch = _press_meta(m, scale, crop)
    held = [b for b in boxes[max(1, rel - 6):rel] if b]
    plateau = tuple(np.median(np.array(held), axis=0)) if held else None
    if boxes[0] and plateau:
        sc, st = press_amplitudes(boxes[0], plateau, dx, dy)
        out["pressScale"], out["pressStretch"] = sc, st
        # Glow: luminance lift over the resting shape's interior.
        s = m["shape"]
        inset = GLOW_INSET_PT * scale
        mask = np.zeros(bg.shape[:2], bool)
        y0 = int(s["y"] * scale - crop["y"] + inset)
        y1 = int((s["y"] + s["h"]) * scale - crop["y"] - inset)
        x0 = int(s["x"] * scale - crop["x"] + inset)
        x1 = int((s["x"] + s["w"]) * scale - crop["x"] - inset)
        mask[y0:y1, x0:x1] = True
        lift = _luma(frames[rel - 2]) - _luma(frames[0])
        try:
            if not mask.any():
                raise RuntimeError("shape too small for the glow fit")
            sigma, amp = fit_glow(lift, mask, touch)
            out["glowRadius"], out["glowAmp"] = sigma / scale, amp
        except RuntimeError:
            pass
    out["peak_frame"] = int(np.argmax(widths))
    return out


def _held(d):
    """Grid indices of a lossless capture that repeat the previous frame
    because the capture missed a display frame (record_motion.sh lists them
    in <run>/<id>.<renderer>.times.json); empty for h264."""
    f = d.parent.parent / f"{d.name}.times.json"
    return set(json.loads(f.read_text()).get("held", [])) if f.exists() else set()


RELEASE_LOOKBACK = 8  # frames before the nominal touch-up taken as the plateau


def _release_onsets(m, seqs):
    """Window position of each clip's first release frame: the first change
    from its held plateau (RELEASE_LOOKBACK frames before the nominal
    touch-up). None when either clip shows no release."""
    nominal = int(round(m.get("hold_ms", 0) / 1000 * FPS)) + 1
    p = max(1, nominal - RELEASE_LOOKBACK)
    out = {}
    for r, s in seqs.items():
        if p >= len(s):
            return None
        k = first_change(s[p:])
        if p + k >= len(s):
            return None
        out[r] = p + k
    return out


def _score_pair(m, dirs, bg, scale, crop, frames):
    """Aligns and scores the two clips of `dirs` ({label: frame dir}, the
    first label is scored against the second) and analyses each."""
    a, b = dirs
    raw = {r: _load_frames(d) for r, d in dirs.items()}
    onset = {r: first_change(f) for r, f in raw.items()}
    # Window starts one frame before the onset (the last resting frame).
    start = {r: max(0, onset[r] - 1) for r in raw}
    seqs = {r: raw[r][start[r]:] for r in raw}
    # Springs and amplitudes come from each clip's own window (its first
    # frame is its last resting frame); the alignment below only pairs the
    # frames that are scored against each other.
    own = {r: (s + [s[-1]] * (frames - len(s)))[:frames] for r, s in seqs.items()}
    # Window positions as indices into each clip (held frames are mapped
    # through them).
    idx = {r: [(k, 0.0) for k in range(start[r], len(raw[r]))] for r in raw}
    # A press is aligned in two segments: the touch-up comes from the touch
    # injector's hold timer, whose jitter (measured: up to 2 frames between
    # SwiftUI takes) is independent of the touch-down's.
    rel = _release_onsets(m, {r: seqs[r] for r in raw}) if m["kind"] == "press" else None
    if rel:
        p_idx = _align({r: idx[r][:rel[r]] for r in raw}, raw, a, b)
        r_idx = _align({r: idx[r][rel[r]:] for r in raw}, raw, a, b)
        shift, release_shift = p_idx.pop("shift"), r_idx.pop("shift")
        cut = min(len(p_idx[a]), len(p_idx[b]))
        idx = {r: p_idx[r][:cut] + r_idx[r] for r in raw}
    else:
        idx = _align(idx, raw, a, b)
        shift, release_shift = idx.pop("shift"), None
    # An h264 recording stops at its last changed frame (variable frame
    # rate), so a renderer that settles sooner has a shorter clip: hold its
    # last frame, which is what the screen showed.
    n = min(frames, max(len(v) for v in idx.values()))
    idx = {r: (v + [v[-1]] * (n - len(v)))[:n] for r, v in idx.items()}
    seqs = {r: [_frame(raw[r], k, f) for k, f in v] for r, v in idx.items()}
    # Scored region: everything either clip's glass covers in the window,
    # inflated like the static region (INFLATE_PT).
    boxes = [bx for s in seqs.values() for f in s if (bx := glass_bbox(f, bg))]
    h, w = bg.shape[:2]
    pad = INFLATE_PT * scale
    if boxes:
        x0 = int(max(0, min(bx[0] for bx in boxes) - pad))
        y0 = int(max(0, min(bx[1] for bx in boxes) - pad))
        x1 = int(min(w, max(bx[2] for bx in boxes) + pad))
        y1 = int(min(h, max(bx[3] for bx in boxes) + pad))
    else:
        x0, y0, x1, y1 = 0, 0, w, h
    per = [score(seqs[a][i][y0:y1, x0:x1], seqs[b][i][y0:y1, x0:x1]) for i in range(n)]
    # A frame either capture held over a missed display frame shows the
    # previous frame, not the screen: reported, but not scored.
    held = {r: _held(d) for r, d in dirs.items()}
    skip = sorted(i for i in range(n) if any(
        k in held[r] or (f > 0 and k + 1 in held[r]) for r in dirs for k, f in [idx[r][i]]))
    scored = [i for i in range(n) if i not in skip]
    worst = min(scored, key=lambda i: per[i]["ssim"]) if scored else None
    analysis = {r: _analyse(m, s, bg, scale, crop) for r, s in own.items()}
    # A press must start at rest: a lost touch-up (seen once with idb)
    # leaves the first frame pressed. The recording's last frame is the
    # settled rest, unlike the window's, which a slow release may not reach.
    # Flag it; re-record.
    unsettled = []
    if m["kind"] == "press":
        for r, s in own.items():
            p, q = glass_bbox(s[0], bg), glass_bbox(raw[r][-1], bg)
            if p and q and max(abs(u - v) for u, v in zip(p, q)) > UNSETTLED_PX:
                unsettled.append(r)
    return {
        "id": m["id"], "kind": m["kind"], "frames": n, "onset": onset,
        # Frames from the second clip's first change to the first clip's.
        # Each take starts its capture PRE before the touch, so this is the
        # touch-to-pixels latency difference (plus touch-injection jitter).
        "onset_offset": onset[a] - onset[b],
        "shift": shift,
        # Press: the same for the touch-up, and the release segment's shift.
        "release_offset": (rel[a] + start[a] - rel[b] - start[b]) if rel else None,
        "release_shift": release_shift,
        "region": [x0, y0, x1, y1],
        "pass": bool(scored and all(per[i]["pass"] for i in scored) and not unsettled),
        "unsettled": unsettled,
        "held_frames": skip,
        # Clip frame shown at each scored position (the phase-interpolated
        # neighbour's lower index), for strips.
        "clip_index": {r: [k for k, _ in v] for r, v in idx.items()},
        "passed_frames": sum(per[i]["pass"] for i in scored),
        "worst_frame": worst,
        "worst": per[worst] if worst is not None else None,
        "mean_ssim": float(np.mean([per[i]["ssim"] for i in scored])) if scored else None,
        "mean_delta_e": float(np.mean([per[i]["delta_e"] for i in scored])) if scored else None,
        "per_frame": [{"ssim": p["ssim"], "delta_e": p["delta_e"], "pass": p["pass"]}
                      for p in per],
        "analysis": analysis,
    }


def _has_frames(d):
    return d.is_dir() and any(d.glob("*.png"))


def run(run_dir, spec=None, prefix="", background=_asset_background,
        no_fail=False, frames=FRAMES, noise_ref=None):
    """Scores Flutter against SwiftUI per motion into motion_report.json.

    `noise_ref`: another run dir; each renderer's clips of `run_dir` ("a")
    are scored against the same renderer's clips there ("b") instead, into
    `run_dir`/noise_report.json: the measurement floor the Flutter scores
    are read against."""
    run_dir = pathlib.Path(run_dir)
    spec = spec or json.loads((ROOT / "tool/scenes/motion.json").read_text())
    scale = spec["device"]["scale"]
    crops = json.loads((run_dir / "crop.json").read_text())
    out = []
    for m in (m for m in spec["motion"] if m["id"].startswith(prefix)):
        if noise_ref is None:
            pairs = [(None, {r: run_dir / "frames" / f"{m['id']}.{r}"
                             for r in ("flutter", "swiftui")})]
        else:
            pairs = [(r, {"a": run_dir / "frames" / f"{m['id']}.{r}",
                          "b": pathlib.Path(noise_ref) / "frames" / f"{m['id']}.{r}"})
                     for r in ("flutter", "swiftui")]
        pairs = [(r, d) for r, d in pairs if all(_has_frames(x) for x in d.values())]
        if not pairs or m["id"] not in crops:
            out.append({"id": m["id"], "missing": True, "pass": False})
            continue
        crop = crops[m["id"]]
        bg = background(m, crop)
        for r, dirs in pairs:
            o = _score_pair(m, dirs, bg, scale, crop, frames)
            if r is not None:
                o = {"id": o.pop("id"), "renderer": r, **o}
            out.append(o)
    name = "motion_report.json" if noise_ref is None else "noise_report.json"
    (run_dir / name).write_text(json.dumps(out, indent=2))
    for o in out:
        if o.get("missing"):
            print("MISSING", o["id"])
            continue
        label = o["id"] + (f" ({o['renderer']} A vs B)" if "renderer" in o else "")
        if o["unsettled"]:
            print(f"WARNING {label}: not at rest at the start ({o['unsettled']}); re-record")
        held = f" ({len(o['held_frames'])} held, unscored)" if o["held_frames"] else ""
        print(f"{label}: {'PASS' if o['pass'] else 'FAIL'} "
              f"{o['passed_frames']}/{o['frames'] - len(o['held_frames'])} frames{held}, worst #{o['worst_frame']} SSIM {o['worst']['ssim']:.4f} "
              f"ΔE {o['worst']['delta_e']:.2f} (bars {SSIM_MIN}/{DELTA_E_MAX}), "
              f"mean {o['mean_ssim']:.4f}/{o['mean_delta_e']:.2f}, "
              f"onset offset {o['onset_offset']:+d}, shift {o['shift']:+.1f}"
              + (f", release offset {o['release_offset']:+d} shift {o['release_shift']:+.1f}"
                 if o.get("release_offset") is not None else ""))
        for r, a in o["analysis"].items():
            sp = {k: (round(v["response"], 3), round(v["damping"], 3))
                  for k, v in a.items() if k.startswith("spring")}
            amps = {k: round(a[k], 4) for k in ("pressScale", "pressStretch", "glowRadius",
                                                "glowAmp") if a.get(k) is not None}
            print(f"  {r}: {sp} {amps}")
    bad = any(not o["pass"] for o in out) or not out
    return 1 if bad and not no_fail else 0


def strips(run_dir, out_dir):
    """Flutter | SwiftUI pairs at the onset, the peak and the settle frame."""
    run_dir, out_dir = pathlib.Path(run_dir), pathlib.Path(out_dir)
    report = json.loads((run_dir / "motion_report.json").read_text())
    for o in report:
        if o.get("missing"):
            continue
        rows = []
        peak = o["analysis"]["swiftui"].get("peak_frame", o["worst_frame"])
        picks = [1, peak, o["frames"] - 1]
        for r in ("flutter", "swiftui"):
            files = sorted((run_dir / "frames" / f"{o['id']}.{r}").glob("*.png"))
            index = o["clip_index"][r]
            imgs = []
            for i in picks:
                img = load(files[index[min(len(index) - 1, i)]])
                x0, y0, x1, y1 = o["region"]
                imgs.append(img[y0:y1, x0:x1])
            rows.append(np.hstack(imgs))
        Image.fromarray((np.vstack(rows) * 255).round().astype(np.uint8)).save(
            out_dir / f"{o['id']}.strip.png")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("run_dir", type=pathlib.Path)
    ap.add_argument("--prefix", default="")
    ap.add_argument("--no-fail", action="store_true")
    ap.add_argument("--strips", type=pathlib.Path, help="write <id>.strip.png here")
    ap.add_argument("--noise-ref", type=pathlib.Path, metavar="DIR",
                    help="score each renderer's clips against the same renderer's in DIR "
                         "(noise_report.json)")
    args = ap.parse_args()
    code = run(args.run_dir, prefix=args.prefix, no_fail=args.no_fail,
               noise_ref=args.noise_ref)
    if args.strips and not args.noise_ref:
        args.strips.mkdir(parents=True, exist_ok=True)
        strips(args.run_dir, args.strips)
    sys.exit(code)


if __name__ == "__main__":
    main()
