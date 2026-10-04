"""Decodes SwiftUI's edge refraction from coordinate-coded captures (Task 15c).

Each measurement scene (tool/scenes/measure.json) is captured over the 16
code backgrounds of tool/scenes/gen_backgrounds.py: grey sinusoids along x or
y, periods 128 and 160 px, four phase steps each. For every pixel and channel
the four steps give

    I_k = B + A cos(phi + k pi / 2)
    phi = atan2(I3 - I1, I0 - I2)        (B and A cancel: affine-invariant)

phi is the sampled coordinate modulo the period. Blur only scales A (a
sinusoid through any symmetric shift-invariant filter stays a sinusoid), so
the phase still gives the blur-centre of what was sampled. The 128/160 pair
beats at 640 px, which picks the fringe order; the pixel's own position is the
prior for the beat order (displacements are far below 320 px).

By-products per pixel:
  * sigma: blur from the two periods' modulation ratio,
    A128 / A160 = exp(-(2 pi sigma)^2 (1/128^2 - 1/160^2) / 2);
  * resid: (I0 + I2 - I1 - I3) / (4 A), zero for a pipeline that is affine in
    the encoded value (a second harmonic, e.g. a gamma step, shows up here).

Usage:
    measure_lens.py <run-dir> [--renderer swiftui|flutter] [--out DIR]
writes <out>/lens-<renderer>.json (profiles per scene) and PNG charts.
"""
import argparse
import json
import pathlib
import sys

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool/scenes"))
from gen_backgrounds import CODE_AMP, CODE_PERIODS, CODES  # noqa: E402

P1, P2 = CODE_PERIODS
BEAT = P1 * P2 / (P2 - P1)  # 640 px
_K = (2 * np.pi) ** 2 * (1 / P1 ** 2 - 1 / P2 ** 2)


def _gain(period, sigma):
    return np.exp(-0.5 * (2 * np.pi * sigma / period) ** 2)


def _phase(images, axis, period):
    i0, i1, i2, i3 = (images[f"code-{axis}-p{period}-k{k}"] for k in range(4))
    c, s = i0 - i2, i3 - i1
    amp = 0.5 * np.hypot(c, s)
    phi = np.mod(np.arctan2(s, c), 2 * np.pi)
    resid = (i0 + i2 - i1 - i3) / 4.0
    mean = (i0 + i1 + i2 + i3) / 4.0
    return phi, amp, resid, mean


def decode_axis(images, axis, origin=(0, 0)):
    """Sampled coordinate (pixel-centre units) along `axis` for every pixel
    and channel, plus blur sigma, linearity residual, gain and mean.
    `origin` is the screen position (x, y) of the images' top-left pixel."""
    phi1, a1, r1, m1 = _phase(images, axis, P1)
    phi2, a2, r2, m2 = _phase(images, axis, P2)
    h, w = phi1.shape[:2]
    py, px = np.mgrid[0:h, 0:w] + 0.5
    ref = (px + origin[0] if axis == "x" else py + origin[1])[..., None]
    ub = np.mod(phi1 - phi2, 2 * np.pi) / (2 * np.pi) * BEAT
    ub = ub + BEAT * np.round((ref - ub) / BEAT)
    u1 = phi1 / (2 * np.pi) * P1
    u1 = u1 + P1 * np.round((ub - u1) / P1)
    u2 = phi2 / (2 * np.pi) * P2
    u2 = u2 + P2 * np.round((ub - u2) / P2)
    w1, w2 = (a1 / P1) ** 2, (a2 / P2) ** 2
    s = (w1 * u1 + w2 * u2) / np.maximum(w1 + w2, 1e-12)
    ratio = np.clip(np.median(a1, -1) / np.maximum(np.median(a2, -1), 1e-9), 1e-6, 1.0)
    sigma = np.sqrt(np.maximum(-2 * np.log(ratio) / _K, 0.0))
    gain = a2 / (CODE_AMP * _gain(P2, sigma)[..., None])
    resid = 0.5 * (r1 / np.maximum(a1, 1e-9) + r2 / np.maximum(a2, 1e-9))
    return {"s": s, "sigma": sigma, "resid": np.median(resid, -1), "gain": gain,
            "mean": 0.5 * (m1 + m2), "amp": np.minimum(a1, a2), "fringe_gap": np.abs(u1 - u2)}


def decode(images, origin=(0, 0)):
    """`images`: background name -> HxWx3 float capture. Returns sx, sy
    (HxWx3), sigma_x/y, resid_x/y, gain_x/y, mean_x/y, amp_x/y."""
    out = {}
    for axis in ("x", "y"):
        d = decode_axis(images, axis, origin)
        out["s" + axis] = d["s"]
        for k in ("sigma", "resid", "gain", "mean", "amp", "fringe_gap"):
            out[f"{k}_{axis}"] = d[k]
    return out


# --- shape geometry -------------------------------------------------------------


def shape_radius(shape):
    if shape["shape"] in ("capsule", "circle"):
        return min(shape["w"], shape["h"]) / 2
    return float(shape["radius"])


def shape_geometry(shape, scale, px, py):
    """Depth inside the outline (positive inward, px) and the outward unit
    normal at fragment coordinates (px, py), for a rounded box with circular
    corners."""
    hx, hy = shape["w"] * scale / 2, shape["h"] * scale / 2
    cx, cy = shape["x"] * scale + hx, shape["y"] * scale + hy
    r = min(shape_radius(shape) * scale, hx, hy)
    lx, ly = np.asarray(px) - cx, np.asarray(py) - cy
    qx, qy = np.abs(lx) - hx + r, np.abs(ly) - hy + r
    mx, my = np.maximum(qx, 0), np.maximum(qy, 0)
    ml = np.hypot(mx, my)
    sdf = ml + np.minimum(np.maximum(qx, qy), 0) - r
    corner = (qx > 0) & (qy > 0)
    gx = np.where(corner, mx / np.maximum(ml, 1e-9), (qx >= qy).astype(float))
    gy = np.where(corner, my / np.maximum(ml, 1e-9), (qx < qy).astype(float))
    nx, ny = gx * np.sign(lx + 1e-12), gy * np.sign(ly + 1e-12)
    return {"depth": -sdf, "nx": nx, "ny": ny, "corner": corner,
            "half": (hx, hy), "radius": r}


# --- analysis -------------------------------------------------------------------


def load(path):
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float64) / 255.0


def load_measure_spec():
    return json.loads((ROOT / "tool/scenes/measure.json").read_text())


def base_scenes(spec):
    """Base id -> (scene with the shape, {background: capture id})."""
    out = {}
    for s in spec["scenes"]:
        base = s["id"].split("--")[0]
        out.setdefault(base, (s, {}))[1][s["background"]] = s["id"]
    return out


WINDOW_PAD_PT = 16  # decode the shape bounds inflated by this much


def scene_field(run_dir, renderer, scene, captures, scale=3):
    """Decodes one base scene; returns per-pixel arrays in the window around
    the shape (screen px), flattened, plus the window box."""
    sh = scene["shapes"][0]
    x0 = int(round((sh["x"] - WINDOW_PAD_PT) * scale))
    y0 = int(round((sh["y"] - WINDOW_PAD_PT) * scale))
    x1 = int(round((sh["x"] + sh["w"] + WINDOW_PAD_PT) * scale))
    y1 = int(round((sh["y"] + sh["h"] + WINDOW_PAD_PT) * scale))
    imgs = {bg: load(pathlib.Path(run_dir) / f"{cid}.{renderer}.png")[y0:y1, x0:x1]
            for bg, cid in captures.items()}
    clipped = np.zeros((y1 - y0, x1 - x0), bool)
    for im in imgs.values():
        clipped |= (im <= 1 / 255).any(-1) | (im >= 254 / 255).any(-1)
    dec = decode(imgs, (x0, y0))
    py, px = np.mgrid[y0:y1, x0:x1] + 0.5
    g = shape_geometry(sh, scale, px, py)
    return {"box": (x0, y0, x1, y1), "px": px, "py": py, "dec": dec, "geo": g,
            "clipped": clipped, "shape": sh}


def _bins(depth, values, mask, edges):
    idx = np.digitize(depth[mask], edges) - 1
    v = values[mask]
    out = []
    for i in range(len(edges) - 1):
        sel = v[idx == i]
        out.append((float(np.median(sel)), float(np.percentile(sel, 25)),
                    float(np.percentile(sel, 75)), int(sel.size)) if sel.size >= 5
                   else (np.nan, np.nan, np.nan, int(sel.size)))
    return out


def profile(f, region="side", step=1.0, max_depth=None):
    """Depth-binned profile of the decoded displacement for `region`:
    'side' (straight edges), 'cap' (circular arcs: capsule ends, circle,
    rect corners) or 'all'. Depth and displacement in physical px."""
    g, dec = f["geo"], f["dec"]
    depth = g["depth"]
    nx, ny = g["nx"], g["ny"]
    ok = ~f["clipped"] & (dec["amp_x"].min(-1) > 0.01) & (dec["amp_y"].min(-1) > 0.01)
    if region == "side":
        ok &= ~g["corner"]
    elif region == "cap":
        ok &= g["corner"]
    dx = dec["sx"] - f["px"][..., None]
    dy = dec["sy"] - f["py"][..., None]
    dn = dx * nx[..., None] + dy * ny[..., None]  # + = samples further out
    dt = -dx * ny[..., None] + dy * nx[..., None]
    if max_depth is None:
        max_depth = float(min(g["half"]))
    edges = np.arange(0.0, max_depth + step, step)
    inside = ok & (depth > 0)
    res = {"depth": ((edges[:-1] + edges[1:]) / 2).tolist()}
    for c, name in enumerate("rgb"):
        res["dn_" + name] = _bins(depth, dn[..., c], inside, edges)
        res["dt_" + name] = _bins(depth, dt[..., c], inside, edges)
    res["disp"] = _bins(depth, dn[..., 0] - dn[..., 2], inside, edges)
    res["sigma"] = _bins(depth, 0.5 * (dec["sigma_x"] + dec["sigma_y"]), inside, edges)
    res["gain"] = _bins(depth, dec["gain_x"][..., 1], inside, edges)
    res["mean"] = _bins(depth, dec["mean_x"][..., 1], inside, edges)
    res["resid"] = _bins(depth, np.abs(dec["resid_x"]), inside, edges)
    # Sampled point's own depth (negative: sampled outside the outline).
    res["sample_depth"] = _bins(depth, depth - dn[..., 1], inside, edges)
    out = ok & (depth < -3 * 12)  # well outside the shape and its rim
    res["outside_err"] = (float(np.median(np.hypot(dx[..., 1], dy[..., 1])[out]))
                          if out.any() else np.nan,
                          float(np.percentile(np.hypot(dx[..., 1], dy[..., 1])[out], 99))
                          if out.any() else np.nan, int(out.sum()))
    res["clipped_frac"] = float((f["clipped"] & (depth > 0)).sum() / max((depth > 0).sum(), 1))
    return res


def summarise(prof):
    """Band width, peak displacement and mirroring from a profile."""
    d = np.array(prof["depth"])
    dn = np.array([v[0] for v in prof["dn_g"]])
    good = ~np.isnan(dn)
    d, dn = d[good], dn[good]
    if not d.size:
        return None
    ipk = int(np.argmax(np.abs(dn)))
    big = np.where(np.abs(dn) >= 0.5)[0]
    band = float(d[big.max()]) if big.size else 0.0
    sdep = np.array([v[0] for v in prof["sample_depth"]])[good]
    mirror = d[sdep < 0]
    disp = np.array([v[0] for v in prof["disp"]])[good]
    return {"peak_dn": float(dn[ipk]), "peak_depth": float(d[ipk]), "band_0p5": band,
            "mirror_to_depth": float(mirror.max()) if mirror.size else 0.0,
            "disp_peak": float(disp[np.nanargmax(np.abs(disp))]) if disp.size else 0.0,
            "disp_peak_depth": float(d[np.nanargmax(np.abs(disp))]) if disp.size else 0.0}


# --- lens fit -----------------------------------------------------------------

FIT_MIN_DEPTH = 2.0  # px; the outer two pixels are the rim (low modulation)


def fit_lens(samples, x0=(140.0, 19.0, 55.0, 100.0)):
    """Least squares of glass_model.lens_v3 on the decoded field itself.
    `samples`: list of (depth px, half-min px, normal displacement px) arrays.
    Returns amp, decay, band, size_ref (px) and the residual rms."""
    from scipy.optimize import least_squares
    from glass_model import lens_v3
    d = np.concatenate([s[0] for s in samples])
    h = np.concatenate([s[1] for s in samples])
    y = np.concatenate([s[2] for s in samples])
    f = lambda p: lens_v3(d, h, *p) - y
    r = least_squares(f, x0, bounds=([0, 0.5, 2, 1], [600, 200, 400, 2000]),
                      loss="soft_l1", f_scale=2.0)
    res = f(r.x)
    return {"amp": float(r.x[0]), "decay": float(r.x[1]), "band": float(r.x[2]),
            "size_ref": float(r.x[3]), "rms": float(np.sqrt(np.mean(res ** 2))),
            "median_abs": float(np.median(np.abs(res))), "n": int(d.size)}


def field_samples(npz, half_min, exclude_corners, stride=5):
    """(depth, half_min, normal displacement) from a saved field, green
    channel, depth >= FIT_MIN_DEPTH, unclipped and modulated pixels only."""
    z = np.load(npz)
    dn = (z["sx"][..., 1] - z["px"]) * z["nx"] + (z["sy"][..., 1] - z["py"]) * z["ny"]
    m = (z["depth"] >= FIT_MIN_DEPTH) & ~z["clipped"] & (z["amp"] > 0.01)
    if exclude_corners:
        m &= ~z["corner"]
    idx = np.flatnonzero(m)[::stride]
    return z["depth"].flat[idx], np.full(idx.size, half_min), dn.flat[idx]


# --- charts (PIL, no matplotlib dependency) -------------------------------------

PALETTE = [(31, 119, 180), (255, 127, 14), (44, 160, 44), (214, 39, 40), (148, 103, 189),
           (140, 86, 75), (227, 119, 194), (127, 127, 127), (188, 189, 34), (23, 190, 207)]


def line_chart(path, series, title, xlabel, ylabel, xlim=None, ylim=None, size=(1100, 650)):
    """series: list of (label, xs, ys[, colour]). Writes a PNG."""
    from PIL import ImageDraw, ImageFont
    Wc, Hc = size
    L, R, T, B = 80, 230, 40, 60
    img = Image.new("RGB", size, "white")
    d = ImageDraw.Draw(img)
    font = ImageFont.load_default(size=14)
    xs_all = np.concatenate([np.asarray(s[1], float) for s in series])
    ys_all = np.concatenate([np.asarray(s[2], float) for s in series])
    ys_all = ys_all[np.isfinite(ys_all)]
    x_lo, x_hi = xlim or (float(np.nanmin(xs_all)), float(np.nanmax(xs_all)))
    y_lo, y_hi = ylim or (float(ys_all.min()), float(ys_all.max()))
    if y_hi - y_lo < 1e-9:
        y_hi = y_lo + 1
    fx = lambda x: L + (x - x_lo) / (x_hi - x_lo) * (Wc - L - R)
    fy = lambda y: Hc - B - (y - y_lo) / (y_hi - y_lo) * (Hc - T - B)
    for t in np.linspace(x_lo, x_hi, 9):
        d.line([(fx(t), T), (fx(t), Hc - B)], fill=(232, 232, 232))
        d.text((fx(t) - 12, Hc - B + 6), f"{t:.0f}", fill="black", font=font)
    for t in np.linspace(y_lo, y_hi, 9):
        d.line([(L, fy(t)), (Wc - R, fy(t))], fill=(232, 232, 232))
        d.text((8, fy(t) - 7), f"{t:.1f}", fill="black", font=font)
    if y_lo < 0 < y_hi:
        d.line([(L, fy(0)), (Wc - R, fy(0))], fill=(120, 120, 120))
    d.rectangle([L, T, Wc - R, Hc - B], outline="black")
    for i, s in enumerate(series):
        col = s[3] if len(s) > 3 else PALETTE[i % len(PALETTE)]
        pts = [(fx(x), fy(y)) for x, y in zip(s[1], s[2])
               if np.isfinite(y) and x_lo <= x <= x_hi and y_lo <= y <= y_hi]
        if len(pts) > 1:
            d.line(pts, fill=col, width=2)
        d.line([(Wc - R + 10, T + 10 + 18 * i), (Wc - R + 30, T + 10 + 18 * i)], fill=col, width=3)
        d.text((Wc - R + 36, T + 3 + 18 * i), s[0], fill="black", font=font)
    d.text((L, 10), title, fill="black", font=ImageFont.load_default(size=17))
    d.text(((L + Wc - R) / 2 - 60, Hc - 25), xlabel, fill="black", font=font)
    d.text((8, T - 22), ylabel, fill="black", font=font)
    img.save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("run_dir", type=pathlib.Path)
    ap.add_argument("--renderer", default="swiftui")
    ap.add_argument("--out", type=pathlib.Path)
    ap.add_argument("--only", default="", help="base scene id prefix (skips the fit)")
    ap.add_argument("--charts", type=pathlib.Path, help="write PNG charts here")
    args = ap.parse_args()
    out = args.out or args.run_dir
    out.mkdir(parents=True, exist_ok=True)
    spec = load_measure_spec()
    result = {}
    for base, (scene, caps) in base_scenes(spec).items():
        if not base.startswith(args.only):
            continue
        if not all((args.run_dir / f"{c}.{args.renderer}.png").exists() for c in caps.values()):
            print("MISSING", base)
            continue
        f = scene_field(args.run_dir, args.renderer, scene, caps)
        np.savez_compressed(out / f"field-{base}.{args.renderer}.npz",
                            px=f["px"], py=f["py"], sx=f["dec"]["sx"], sy=f["dec"]["sy"],
                            depth=f["geo"]["depth"], nx=f["geo"]["nx"], ny=f["geo"]["ny"],
                            corner=f["geo"]["corner"], clipped=f["clipped"],
                            amp=np.minimum(f["dec"]["amp_x"].min(-1), f["dec"]["amp_y"].min(-1)),
                            sigma=0.5 * (f["dec"]["sigma_x"] + f["dec"]["sigma_y"]),
                            gain=f["dec"]["gain_x"], resid=f["dec"]["resid_x"],
                            mean=f["dec"]["mean_x"])
        result[base] = {}
        for region in ("side", "cap", "all"):
            prof = profile(f, region)
            result[base][region] = {"profile": prof, "summary": summarise(prof)}
        region = "side" if result[base]["side"]["summary"] else "cap"
        s = result[base][region]["summary"]
        p = result[base][region]["profile"]
        print(f"{base:24s} {region:4s} peak Δn {s['peak_dn']:+6.2f} px @ {s['peak_depth']:4.1f}  "
              f"band {s['band_0p5']:5.1f}  mirror≤{s['mirror_to_depth']:4.1f}  "
              f"disp {s['disp_peak']:+5.2f}  outside err {p['outside_err'][0]:.2f}/"
              f"{p['outside_err'][1]:.2f}  clipped {p['clipped_frac']:.3f}")
    (out / f"lens-{args.renderer}.json").write_text(json.dumps(result, indent=1))
    if args.only:
        return
    fits = fit_variants(out, args.renderer, spec)
    (out / f"lens-fit-{args.renderer}.json").write_text(json.dumps(fits, indent=1))
    for v, p in fits.items():
        print(f"fit {v:8s} amp {p['amp']:.2f} decay {p['decay']:.2f} band {p['band']:.2f} "
              f"size_ref {p['size_ref']:.2f} px  rms {p['rms']:.2f} (n={p['n']})")
    if args.charts:
        args.charts.mkdir(parents=True, exist_ok=True)
        charts(result, fits, spec, args.charts, args.renderer)


def _half_min_px(scene, scale=3):
    sh = scene["shapes"][0]
    return min(sh["w"], sh["h"]) * scale / 2


def fit_variants(out, renderer, spec):
    """One lens_v3 fit per variant over every measured shape and brightness
    (rectangle corners excluded: SwiftUI's continuous corners are not arcs)."""
    fits = {}
    bases = base_scenes(spec)
    for variant in ("regular", "clear"):
        samples = []
        for base, (scene, _) in bases.items():
            npz = out / f"field-{base}.{renderer}.npz"
            if base.startswith(variant + "-") and npz.exists():
                samples.append(field_samples(npz, _half_min_px(scene),
                                             scene["shapes"][0]["shape"] == "rect"))
        if samples:
            fits[variant] = fit_lens(samples)
    return fits


def charts(result, fits, spec, cdir, renderer):
    from glass_model import lens_v3
    bases = base_scenes(spec)
    tag = "" if renderer == "swiftui" else f"-{renderer}"

    def series(key, region_pref=("side", "cap"), transform=None):
        out = []
        for base, v in result.items():
            reg = next(r for r in region_pref if v[r]["summary"])
            p = v[reg]["profile"]
            d = np.array(p["depth"])
            y = np.array([q[0] for q in p[key]])
            if transform:
                d, y = transform(base, d, y)
            out.append((f"{base} ({reg})", d, y))
        return out

    line_chart(cdir / f"profile-normal{tag}.png", series("dn_g"),
               f"{renderer}: normal displacement vs depth (green; negative = samples inward)",
               "depth inside the outline (physical px)", "dn (px)", xlim=(0, 90),
               ylim=(-160, 20))
    line_chart(cdir / f"profile-tangent{tag}.png", series("dt_g"),
               f"{renderer}: tangential displacement vs depth", "depth (px)", "dt (px)",
               xlim=(0, 90), ylim=(-3, 3))
    line_chart(cdir / f"sampled-depth{tag}.png", series("sample_depth"),
               f"{renderer}: depth of the sampled point vs pixel depth (mirroring)",
               "pixel depth (px)", "sampled depth (px)", xlim=(0, 90), ylim=(-40, 160))
    line_chart(cdir / f"dispersion{tag}.png", series("disp"),
               f"{renderer}: dn red - dn blue vs depth", "depth (px)", "R - B (px)",
               xlim=(0, 90), ylim=(-3, 3))
    for variant, p in fits.items():
        ser = []
        for i, (base, v) in enumerate((b, v) for b, v in result.items()
                                      if b.startswith(variant + "-")):
            reg = "side" if v["side"]["summary"] else "cap"
            prof = v[reg]["profile"]
            d = np.array(prof["depth"])
            y = np.array([q[0] for q in prof["dn_g"]])
            col = PALETTE[i % len(PALETTE)]
            ser.append((f"{base}", d, y, col))
            hm = _half_min_px(bases[base][0])
            ser.append((f"  fit", d, lens_v3(d, hm, p["amp"], p["decay"], p["band"],
                                               p["size_ref"]), tuple(c // 2 for c in col)))
        line_chart(cdir / f"fit-{variant}{tag}.png", ser,
                   f"{renderer} {variant}: measured dn (bright) vs lens v3 fit (dark); "
                   f"amp {p['amp']:.1f} decay {p['decay']:.1f} band {p['band']:.1f} "
                   f"size_ref {p['size_ref']:.1f} px",
                   "depth (px)", "dn (px)", xlim=(0, 90), ylim=(-160, 20))


if __name__ == "__main__":
    main()
