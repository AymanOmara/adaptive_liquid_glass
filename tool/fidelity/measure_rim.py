"""Decodes the rim highlight's azimuthal profile (Task 9).

Question: does SwiftUI's rim highlight follow the backdrop content behind
the glass (a `rimContent` mixing term would be needed), or is it a fixed
light, the same in every screen direction (the model already matches)?

Scenes (tool/scenes/measure.json): rect16 (240x140 pt, radius 16, at the
fidelity matrix position) over the four rotated gradients
`gradient-r{000,090,180,270}` — the fidelity `gradient` ramp on the four
screen axes (r000 dark top -> light bottom; r090 dark left -> light right;
r180/r270 the reverses) — for regular and clear, light and dark. Regular is
the failing rect band's variant; clear is the control (its rim measured
isotropic in the model-only clear analysis, M5).

Method. Outside the glass the captures reproduce the background PNG
pixel-exactly (README "Capture format and alignment"), so the no-glass
reference is the background itself. Per rotation, around the shape:
  * ring "rim": the outer RIM_PX physical px inside the outline — where a
    rim highlight lives (the clear analysis put the white mix within ~1 pt
    of the edge); split into rim0 (outer half) and rim1 (inner half);
  * ring "control": CONTROL_PT pt deep — inside the 18 pt band but past the
    rim, where the lens, frost and fill still couple to content but no rim
    highlight is. Its azimuthal content structure is the non-rim floor;
  * per azimuth bin (the direction the rim FACES: 0 deg = screen-up, 90 deg
    = screen-right, clockwise), the median capture-minus-background
    difference (mean over RGB, per channel kept too) and the backdrop's own
    relative luminance over the same pixels.

Verdict per variant-brightness set, from the four rim-ring profiles A_r and
luminance profiles L_r:
  * fixed-light: the A_r are the same function of screen azimuth — high
    pairwise correlation at zero shift, most of the azimuthal variance in
    the rotation-mean profile, no correlation with L_r beyond the control
    ring's;
  * content-following: each A_r tracks L_r and rotates with the gradient —
    high corr(A_r, L_r), pairwise profiles aligning once shifted by the
    gradient's angle offset, first-harmonic phase advancing 90 deg per step.
With --model the same decode runs on glass_model.render (the shipped
constants; fixed directional rim + lens/frost/fill). The model's rim-ring
content fraction is the non-rim floor: excess in the device is the rim's
content coupling. Also writes per-scene model SSIM/deltaE (whole glass
region and its band/interior split, compare.py convention).

Usage:
    measure_rim.py <run-dir> [--renderer swiftui] [--out FILE] [--model]
"""
import argparse
import itertools
import json
import pathlib
import sys

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool/scenes"))
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import measure_lens as ml  # noqa: E402

SCALE = 3
BG_DIR = ROOT / "example/assets/backgrounds"
ROTATIONS = (0, 90, 180, 270)
# Ring "rim" (physical px inside the outline) and its halves; the task's
# outer ~4 px. Control ring in pt (past the rim, inside the 18 pt band).
RIM_PX = 4.0
CONTROL_PT = (4.0, 12.0)
AZ_BINS = 36  # 10-deg bins
# A rect corner arc (radius 48 px) gives ~8.4 px per 10 deg of ring depth
# 1 px; 12 keeps the rim0/rim1 halves populated on the diagonals.
MIN_PIX_PER_BIN = 12
LUMA = np.array([0.2126, 0.7152, 0.0722])

RINGS = {
    "rim": (0.0, RIM_PX),
    "rim0": (0.0, RIM_PX / 2),
    "rim1": (RIM_PX / 2, RIM_PX),
    "control": (CONTROL_PT[0] * SCALE, CONTROL_PT[1] * SCALE),
}


def assert_not_magenta(img, name):
    """The reference app fails loud (solid magenta + label) on an
    unsupported host or unknown scene/background; never score such a
    capture (work-package rule)."""
    m = (img[..., 0] > 0.9) & (img[..., 1] < 0.15) & (img[..., 2] > 0.9)
    if m.mean() > 0.02:
        raise SystemExit(f"{name}: capture is magenta (unsupported host or unknown scene) — not scoring")


def azimuth_deg(nx, ny):
    """Direction the rim faces: 0 = screen-up, 90 = screen-right,
    clockwise (screen y is down)."""
    return np.degrees(np.arctan2(nx, -ny)) % 360.0


def profile(values, az, mask, bins=AZ_BINS):
    """Median of `values` per azimuth bin (NaN where a bin is empty)."""
    out = []
    for k in range(bins):
        m = mask & (az >= k * 360.0 / bins) & (az < (k + 1) * 360.0 / bins)
        out.append(float(np.median(values[m])) if m.sum() >= MIN_PIX_PER_BIN else float("nan"))
    return out


def corr(a, b):
    a, b = np.asarray(a, np.float64), np.asarray(b, np.float64)
    ok = np.isfinite(a) & np.isfinite(b)
    if ok.sum() < 3:
        return float("nan")
    a, b = a[ok] - a[ok].mean(), b[ok] - b[ok].mean()
    den = np.sqrt((a * a).sum() * (b * b).sum())
    return float((a * b).sum() / den) if den > 0 else float("nan")


def best_shift(a, b):
    """(shift in bins, correlation) of the best-aligned circular shift of
    `a` against `b`; positive = the pattern moved forward in azimuth."""
    cs = [(k, corr(np.roll(a, k), b)) for k in range(len(a))]
    cs = [c for c in cs if np.isfinite(c[1])]
    return max(cs, key=lambda c: c[1]) if cs else (0, float("nan"))


def first_harmonic(prof):
    """(a1, b1, amplitude, phase deg) of prof ~ mean + a1 cos + b1 sin
    over valid bins; phase in the azimuth convention above."""
    p = np.asarray(prof, np.float64)
    n = len(p)
    th = np.radians((np.arange(n) + 0.5) * 360.0 / n)
    ok = np.isfinite(p)
    if ok.sum() < 4:
        return float("nan"), float("nan"), float("nan"), float("nan")
    xs = np.stack([np.ones(ok.sum()), np.cos(th[ok]), np.sin(th[ok])], 1)
    c = np.linalg.lstsq(xs, p[ok], rcond=None)[0]
    a1, b1 = float(c[1]), float(c[2])
    return a1, b1, float(np.hypot(a1, b1)), float(np.degrees(np.arctan2(b1, a1)) % 360.0)


def _window(shape, pad_pt=16):
    x0 = int(round((shape["x"] - pad_pt) * SCALE))
    y0 = int(round((shape["y"] - pad_pt) * SCALE))
    x1 = int(round((shape["x"] + shape["w"] + pad_pt) * SCALE))
    y1 = int(round((shape["y"] + shape["h"] + pad_pt) * SCALE))
    return x0, y0, x1, y1


def rim_profiles(frame, shape):
    """Azimuth-binned ring profiles of one rendered frame vs the background.
    `frame`: full-screen float image (the capture or a model render)."""
    bg = ml.load(BG_DIR / f"{shape['_background']}.png")
    x0, y0, x1, y1 = _window(shape)
    c, b = frame[y0:y1, x0:x1], bg[y0:y1, x0:x1]
    diff = c - b
    # Alignment guard: outside the glass the capture must equal the
    # background pixel-exactly (measured, README). Warn if not.
    py, px = np.mgrid[y0:y1, x0:x1] + 0.5
    g = ml.shape_geometry(shape, SCALE, px, py)
    outside = g["depth"] < -8 * SCALE
    if outside.any():
        md = float(np.abs(diff[outside]).max())
        if md > 1.0 / 255.0:
            frac = float((np.abs(diff[outside]) > 0.5 / 255.0).mean())
            print(f"  note: max |diff| {md * 255:.1f}/255 on {frac * 100:.2f}% of pixels just "
                  f"outside the glass (the glass's own outer shadow); bin medians unaffected")
    az = azimuth_deg(g["nx"], g["ny"])
    dmean = diff.mean(-1)
    bluma = (b * LUMA).sum(-1)
    out = {}
    for name, (lo, hi) in RINGS.items():
        m = (g["depth"] > lo) & (g["depth"] <= hi)
        out[name] = {"n": int(m.sum()), "diff": profile(dmean, az, m),
                     "diff_rgb": [profile(diff[..., c_], az, m) for c_ in range(3)],
                     "bg_luma": profile(bluma, az, m)}
    return out


def _scene_for(spec, variant, brightness, rotation):
    sid = f"{variant}-rect16-{brightness}--gradient-r{rotation:03d}"
    s = next(s for s in spec["scenes"] if s["id"] == sid)
    s["shapes"][0]["_background"] = s["background"]
    return sid, s


def _med(x):
    """NaN-safe median (a flat all-equal profile has undefined correlations)."""
    x = np.asarray(x, np.float64)
    x = x[np.isfinite(x)]
    return float(np.median(x)) if x.size else float("nan")


def compare_rotations(per_rotation, ring="rim"):
    """Cross-rotation statistics of one ring's diff profiles. Keys may be
    int or str degrees."""
    A = {int(r): np.asarray(v[ring]["diff"], np.float64) for r, v in per_rotation.items()}
    L = {int(r): np.asarray(v[ring]["bg_luma"], np.float64) for r, v in per_rotation.items()}
    pairs = list(itertools.combinations(sorted(A), 2))
    zero = [corr(A[a], A[b]) for a, b in pairs]
    content = [corr(A[r], L[r]) for r in sorted(A)]
    adj = [(a, b) for a, b in pairs if (a - b) % 360 in (90, 270)]
    shift = [{"pair": [a, b], **dict(zip(("shift_bins", "corr"), best_shift(A[a], A[b])))}
             for a, b in adj]
    # Variance decomposition: fixed = rotation-mean profile, content = the
    # rest (both in units of squared levels; NaN bins dropped pairwise).
    allv = np.concatenate([A[r] for r in sorted(A)])
    mean_prof = np.nanmean(np.stack([A[r] for r in sorted(A)]), 0)
    fixed_var = float(np.nanvar(mean_prof))
    total_var = float(np.nanvar(allv))
    res = {"ring": ring,
           "pair_corr_zero_shift": dict(zip([f"{a}-{b}" for a, b in pairs], zero)),
           "median_pair_corr_zero_shift": _med(zero),
           "corr_with_backdrop": dict(zip(sorted(A), content)),
           "median_corr_with_backdrop": _med(content),
           "adjacent_pair_best_shift": shift,
           "fixed_var": fixed_var, "total_var": total_var,
           "fixed_fraction": fixed_var / total_var if total_var > 0 else float("nan"),
           "harmonics": {r: dict(zip(("a1", "b1", "amp", "phase_deg"), first_harmonic(A[r])))
                         for r in sorted(A)},
           "bg_harmonics": {r: dict(zip(("a1", "b1", "amp", "phase_deg"), first_harmonic(L[r])))
                            for r in sorted(L)}}
    return res


def verdict(device, model=None, ring="rim", residual=False):
    """fixed-light / content-following / mixed. On raw device profiles the
    statistics conflate the rim with the (content-coupled) lens/frost/fill
    machinery; with `residual=True` they run on device-minus-model, which
    the model's fixed rim cannot explain at all — that is the rim verdict.
    Thresholds stated; the numbers are reported either way."""
    d = device[ring]
    dz, dc, df = d["median_pair_corr_zero_shift"], d["median_corr_with_backdrop"], d["fixed_fraction"]
    if residual:
        v = "fixed-light" if dz >= 0.85 and abs(dc) <= 0.3 else \
            "content-following" if abs(dc) >= 0.75 and df <= 0.5 else "mixed"
        return {"verdict": v, "ring": ring, "basis": "residual (device - model)",
                "median_pair_corr_zero_shift": dz, "median_corr_with_backdrop": dc,
                "fixed_fraction": df,
                "thresholds": "fixed-light: pair corr >= 0.85 and |backdrop corr| <= 0.3; "
                              "content-following: |backdrop corr| >= 0.75 and fixed fraction <= 0.5"}
    # The control ring is the non-rim floor for backdrop correlation.
    ctrl = device["control"]["median_corr_with_backdrop"]
    floor = None
    if model is not None and ring in model and "fixed_fraction" in model[ring]:
        floor = model[ring]["fixed_fraction"]
    if dz >= 0.9 and (df >= 0.8 or dc <= ctrl + 0.1):
        v = "fixed-light"
    elif dc >= 0.75 and df <= 0.5:
        v = "content-following"
    else:
        v = "mixed"
    return {"verdict": v, "ring": ring, "basis": "raw device profiles",
            "median_pair_corr_zero_shift": dz, "median_corr_with_backdrop": dc,
            "control_corr_with_backdrop": ctrl, "fixed_fraction": df,
            "model_fixed_fraction": floor,
            "thresholds": "fixed-light: pair corr >= 0.9 and (fixed fraction >= 0.8 or "
                          "backdrop corr <= control + 0.1); content-following: backdrop "
                          "corr >= 0.75 and fixed fraction <= 0.5"}


def analyse(run_dir, renderer, spec, variant, brightness, model_constants=None):
    """Per-rotation ring profiles (+ model renders) for one variant set."""
    out = {"variant": variant, "brightness": brightness, "rotations": {}, "model": {}}
    for r in ROTATIONS:
        sid, scene = _scene_for(spec, variant, brightness, r)
        cap = ml.load(pathlib.Path(run_dir) / f"{sid}.{renderer}.png")
        assert_not_magenta(cap, sid)
        out["rotations"][str(r)] = rim_profiles(cap, scene["shapes"][0])
        if model_constants is not None:
            from glass_model import render
            out["model"][str(r)] = rim_profiles(
                render(ml.load(BG_DIR / f"{scene['background']}.png"), scene, model_constants),
                scene["shapes"][0])
    out["comparison"] = {ring: compare_rotations(out["rotations"], ring) for ring in RINGS}
    if model_constants is not None:
        out["model_comparison"] = {ring: compare_rotations(out["model"], ring) for ring in RINGS}
        # The decisive test. The model's rim is fixed (no content coupling),
        # and its lens/frost/fill content coupling matches the device. The
        # residual device - model is therefore what a rimContent term would
        # have to explain: rotation-invariant residual => fixed-light
        # (retune the fixed rim), rotating with the gradient => the device
        # has a content rim the model lacks.
        out["residual"] = {ring: {str(r): (
            np.asarray(out["rotations"][str(r)][ring]["diff"])
            - np.asarray(out["model"][str(r)][ring]["diff"])).tolist()
            for r in ROTATIONS} for ring in RINGS}
        out["residual_comparison"] = {
            ring: compare_rotations(
                {str(r): {ring: {"diff": out["residual"][ring][str(r)],
                                 "bg_luma": out["rotations"][str(r)][ring]["bg_luma"]}}
                 for r in ROTATIONS}, ring)
            for ring in RINGS}
        out["residual_depth"] = _residual_depth(run_dir, renderer, spec, variant,
                                                brightness, model_constants)
    out["verdict"] = verdict(out["comparison"], out.get("model_comparison"))
    if "residual_comparison" in out:
        out["verdict_residual"] = verdict(out["residual_comparison"], None, residual=True)
    return out


DEPTH_BINS_PX = ((0, 1), (1, 2), (2, 3), (3, 4), (4, 6), (6, 9), (9, 14), (14, 24))


def _residual_depth(run_dir, renderer, spec, variant, brightness, constants):
    """Median device-minus-model difference vs depth (physical px), straight
    edges vs corners, median over rotations (/255) — where the fixed
    residual lives."""
    from glass_model import render
    rows = {"straight": [], "corner": []}
    for r in ROTATIONS:
        sid, scene = _scene_for(spec, variant, brightness, r)
        sh = scene["shapes"][0]
        cap = ml.load(pathlib.Path(run_dir) / f"{sid}.{renderer}.png")
        mod = render(ml.load(BG_DIR / f"{scene['background']}.png"), scene, constants)
        x0, y0, x1, y1 = _window(sh)
        diff = (cap - mod)[y0:y1, x0:x1].mean(-1)
        py, px = np.mgrid[y0:y1, x0:x1] + 0.5
        g = ml.shape_geometry(sh, SCALE, px, py)
        for corner in (False, True):
            rows["corner" if corner else "straight"].append((diff, g, corner))
    out = {"bins_px": [list(b) for b in DEPTH_BINS_PX]}
    for key, vals in rows.items():
        out[key] = []
        for lo, hi in DEPTH_BINS_PX:
            med = []
            for d, g_, c in vals:
                mm = (g_["depth"] > lo) & (g_["depth"] <= hi) & (c == g_["corner"])
                med.append(float(np.median(d[mm])) if mm.any() else float("nan"))
            out[key].append(float(np.nanmedian(med)) * 255.0)
    return out


def model_scores(run_dir, renderer, spec, variant, brightness, constants):
    """Model vs capture per scene: SSIM / deltaE over the glass region and
    its band/interior split (compare.py conventions, pt vs px kept apart)."""
    from compare import load, region_for, region_masks, score
    from glass_model import render
    res = {}
    for r in ROTATIONS:
        sid, scene = _scene_for(spec, variant, brightness, r)
        cap = load(pathlib.Path(run_dir) / f"{sid}.{renderer}.png")
        mod = render(ml.load(BG_DIR / f"{scene['background']}.png"), scene, constants)
        h, w = cap.shape[:2]
        x0, y0, x1, y1 = region_for(scene, SCALE, w, h)
        a, b = mod[y0:y1, x0:x1], cap[y0:y1, x0:x1]
        interior, band = region_masks(scene, SCALE, w, h)
        res[sid] = score(a, b, interior[y0:y1, x0:x1], band[y0:y1, x0:x1])
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("run_dir", type=pathlib.Path)
    ap.add_argument("--renderer", default="swiftui")
    ap.add_argument("--out", type=pathlib.Path)
    ap.add_argument("--model", action="store_true",
                    help="also decode model renders (fixed rim; lens/frost/fill floor) "
                         "and write per-scene model SSIM/deltaE")
    ap.add_argument("--variants", default="regular,clear")
    ap.add_argument("--brightnesses", default="light,dark")
    args = ap.parse_args()

    spec = ml.load_measure_spec()
    constants = None
    if args.model:
        constants = json.loads((pathlib.Path(__file__).parent / "standard_constants.json").read_text())
    out = {}
    for variant in args.variants.split(","):
        for brightness in args.brightnesses.split(","):
            r = analyse(args.run_dir, args.renderer, spec, variant, brightness, constants)
            out[f"{variant}-{brightness}"] = r
            c, v = r["comparison"]["rim"], r["verdict"]
            print(f"{variant:8s} {brightness:5s}  pair corr(0) {c['median_pair_corr_zero_shift']:+.3f}  "
                  f"backdrop corr {c['median_corr_with_backdrop']:+.3f} (control "
                  f"{r['comparison']['control']['median_corr_with_backdrop']:+.3f})  "
                  f"fixed fraction {c['fixed_fraction']:.2f}  "
                  f"-> {v['verdict']}")
            for rot, h in c["harmonics"].items():
                print(f"  r{rot}: 1st harmonic amp {h['amp'] * 255:6.2f}/255 phase {h['phase_deg']:6.1f} deg")
            if "model_comparison" in r:
                m = r["model_comparison"]["rim"]
                print(f"  model: pair corr(0) {m['median_pair_corr_zero_shift']:+.3f}  "
                      f"backdrop corr {m['median_corr_with_backdrop']:+.3f}  "
                      f"fixed fraction {m['fixed_fraction']:.2f}")
            if "residual_comparison" in r:
                x = r["residual_comparison"]["rim"]
                vr = r["verdict_residual"]
                print(f"  residual: pair corr(0) {x['median_pair_corr_zero_shift']:+.3f}  "
                      f"backdrop corr {x['median_corr_with_backdrop']:+.3f}  "
                      f"fixed fraction {x['fixed_fraction']:.2f}  "
                      f"-> {vr['verdict'].upper()}")
                rd = r["residual_depth"]
                print("  residual vs depth (/255): "
                      + " ".join(f"{a}-{b}px s {s:+.1f} c {c:+.1f}"
                                 for (a, b), s, c in zip(rd["bins_px"], rd["straight"],
                                                         rd["corner"])))
    if args.model:
        scores = {k: model_scores(args.run_dir, args.renderer, spec, *k.split("-"), constants)
                  for k in out}
        for k, sc in scores.items():
            print(f"{k}: model vs capture  " + "  ".join(
                f"{sid.split('--')[0][-12:]}: SSIM {v['ssim']:.4f} dE {v['delta_e']:.2f} "
                f"(band dE {v.get('delta_e_band', float('nan')):.2f})"
                for sid, v in sc.items()))
        out["model_scores"] = scores
    dest = args.out or (args.run_dir / f"rim-{args.renderer}.json")
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(out, indent=1))
    print("wrote", dest)


if __name__ == "__main__":
    main()
