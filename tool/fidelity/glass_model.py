"""NumPy port of shaders/liquid_glass.frag (shader model v2, spec §15, with lens v3 from Task 15c).

`render(background, scene, constants, scale)` returns what the Flutter renderer
draws for a static fidelity scene: the background blurred by the composed
`ImageFilter.blur`, run through the glass shader, and composited
(premultiplied srcOver) onto the sharp background inside the backdrop clip.

All maths is in the encoded (gamma) sRGB values the engine works in, on the
physical-pixel grid, with FlutterFragCoord at pixel centres (x + 0.5).
"""
import functools
import json
import pathlib

import numpy as np
from scipy.ndimage import convolve1d, map_coordinates

# Impeller's blur kernel (measured in Task 15c by least squares on device
# captures): a Gaussian of the requested sigma, truncated at radius
# round((sigma - 0.5) * sqrt(3)) px and renormalised. The truncation is what
# made the effective blur look 0.81-0.95x narrower (the Task 17 blurScale
# table, now retired). `render(..., blur_scale=k)` still scales sigma for
# experiments; the default is 1.


def impeller_kernel(sigma_px):
    r = max(1, int(round((sigma_px - 0.5) * np.sqrt(3))))
    x = np.arange(-r, r + 1)
    k = np.exp(-0.5 * (x / sigma_px) ** 2)
    return k / k.sum()


_STANDARD_PATH = pathlib.Path(__file__).with_name("standard_constants.json")


@functools.lru_cache(maxsize=1)
def _standard():
    return json.loads(_STANDARD_PATH.read_text())


# Task 17d keys added after the 17c constants files; files without them
# render exactly as before (GlassVariantConstants' Dart defaults).
VARIANT_DEFAULTS = {
    "toneKnots": [i / 8 for i in range(9)],
    "glowStrength": 0.25,
    "postBlurShare": 0.0,
    "normalRadiusScale": 1.0,
    "lensEdge": 0.0,
    "lensEdgeDecay": 0.6,
    "rimMix": 0.0,
    "rimMixWidth": 1.5,
    "rimMixCut": 1.0,
    "rimMixLumaFloor": 1.0,
    "toneLift": 0.0,
    "blurAspectPower": 0.0,
    "toneLiftKnee": 0.5,
    "toneLiftSizeRef": 0.0,
}


def resolve_constants(constants):
    """`constants` with every missing key filled from standard_constants.json,
    with GlassConstants.fromJson's partial-override semantics (per variant set,
    per motion key, and top-level scalars)."""
    std = _standard()
    out = {}
    for k, v in std.items():
        given = constants.get(k)
        if isinstance(v, dict):
            out[k] = {**v, **(given or {})}
            if k in ("regular", "clear", "regularDark", "clearDark"):
                out[k] = {**VARIANT_DEFAULTS, **out[k]}
        else:
            out[k] = v if given is None else given
    return out


LIGHT_ANGLE = -3 * np.pi / 4  # LiquidGlassThemeData default (up-left)
LUMA = np.array([0.2126, 0.7152, 0.0722])


def variant_key(shape, brightness):
    base = "clear" if shape["variant"] == "clear" else "regular"
    return base + ("Dark" if brightness == "dark" else "")


def parse_hex(v):
    if isinstance(v, (int, np.integer)):
        v = int(v) & 0xFFFFFF
        return np.array([(v >> 16) & 255, (v >> 8) & 255, v & 255]) / 255.0
    h = v.lstrip("#")[-6:]
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)]) / 255.0


def parse_tint(v):
    """Scene tint "#RRGGBBAA" -> (rgb, alpha)."""
    if v is None:
        return None
    h = v.lstrip("#")
    rgba = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4, 6)]
    return np.array(rgba[:3]), rgba[3]


def shape_radius(s):
    if s["shape"] in ("capsule", "circle"):
        return min(s["w"], s["h"]) / 2
    return float(s["radius"])


# --- SDF ------------------------------------------------------------------


def sd_superellipse_box(px, py, hx, hy, r, n):
    r = min(r, hx, hy)
    qx = np.abs(px) - hx + r
    qy = np.abs(py) - hy + r
    mx = np.maximum(qx, 0.0)
    my = np.maximum(qy, 0.0)
    corner = (mx ** n + my ** n) ** (1.0 / n)
    return corner + np.minimum(np.maximum(qx, qy), 0.0) - r


def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.minimum(a, b) - h * h * k * 0.25


def shape_dists(shapes, x, y):
    out = []
    for s in shapes:
        rx, ry, rw, rh = s["rect"]
        hx, hy = rw * 0.5, rh * 0.5
        out.append(sd_superellipse_box(x - (rx + hx), y - (ry + hy), hx, hy,
                                       s["radius"], s["n"]))
    return out


def field(shapes, x, y, k):
    d = np.full(np.shape(x), 1e6)
    for di in shape_dists(shapes, x, y):
        d = smin(d, di, k)
    return d


# --- lens v3 (measured, Task 15c) ---------------------------------------------


def lens_v3(depth, half_min, amp, decay, band, size_ref):
    """Normal displacement (px, negative = samples inward) at `depth` px inside
    the outline, as decoded from SwiftUI (tool/fidelity/measure_lens.py):

        s  = min(1, half_min / size_ref)   (1 when size_ref <= 0)
        v  = max(exp(-depth / (decay s)) - exp(-band / decay), 0) / (1 - exp(-band / decay))
        dn = -amp * s * v

    i.e. an exponential falloff cut to zero at `band`, and a geometrically
    similar (uniformly scaled) profile on shapes whose half of the shorter
    side is below `size_ref`. All lengths in the same unit (px here)."""
    depth = np.maximum(np.asarray(depth, dtype=np.float64), 0.0)  # as the shader
    half_min = np.asarray(half_min, dtype=np.float64)
    if np.ndim(size_ref) == 0 and size_ref <= 0:
        s = np.ones_like(half_min)
    else:
        s = np.where(np.asarray(size_ref) > 0,
                     np.minimum(1.0, half_min / np.maximum(size_ref, 1e-6)), 1.0)
    ls = np.maximum(decay * s, 1e-3)
    e = np.exp(-np.maximum(band, 1e-3) / np.maximum(decay, 1e-3))
    v = np.maximum(np.exp(-depth / ls) - e, 0.0) / np.maximum(1.0 - e, 1e-6)
    return -amp * s * v


# --- blur -------------------------------------------------------------------


@functools.lru_cache(maxsize=64)
def _blurred_cached(bg_id, sigma_px, box, aspect=1.0):
    bg = _BG[bg_id]
    return _blur_box(bg, sigma_px, box, aspect)


_BG = {}


def _blur_box(bg, sigma_px, box, aspect=1.0):
    """Blurs `bg` (edge clamped) with impeller_kernel (sigma x aspect along x,
    sigma / aspect along y) and returns the window `box`."""
    x0, y0, x1, y1 = box
    h, w = bg.shape[:2]
    kx = impeller_kernel(sigma_px * aspect) if sigma_px > 0 else np.ones(1)
    ky = impeller_kernel(sigma_px / aspect) if sigma_px > 0 else np.ones(1)
    m = max(kx.size, ky.size) // 2 + 2
    ys = np.clip(np.arange(y0 - m, y1 + m), 0, h - 1)
    xs = np.clip(np.arange(x0 - m, x1 + m), 0, w - 1)
    win = bg[np.ix_(ys, xs)]
    if sigma_px > 0:
        win = convolve1d(convolve1d(win, ky, axis=0, mode="nearest"), kx, axis=1, mode="nearest")
    return win[m:m + (y1 - y0), m:m + (x1 - x0)]


def blurred_window(bg, sigma_px, box, aspect=1.0):
    key = id(bg)
    _BG[key] = bg
    return _blurred_cached(key, round(float(sigma_px), 4), tuple(int(v) for v in box),
                           round(float(aspect), 6))


# --- frost v2 (Task 17c) -------------------------------------------------------
#
# SwiftUI's frost is a sharp core plus a wide tail whose weight grows with the
# sampled point's depth (measure_frost.py): (1 - w) G(core) + w G(core (+) wide).
# The composed ImageFilter.blur is the core; the shader adds the wide part as
# 16 taps of the already blurred texture on two rings, the 2-node
# Gauss-Laguerre rule for a 2-D Gaussian of sigma `frostWideSigma`.

_SQ2 = np.sqrt(2.0)
FROST_RINGS = ((6, 0.0, np.sqrt(2 * (2 - _SQ2)), (2 + _SQ2) / 4),
               (10, np.pi / 10, np.sqrt(2 * (2 + _SQ2)), (2 - _SQ2) / 4))


def frost_taps(sigma_px):
    """(16, 3) array of tap (dx, dy, weight) for a wide Gaussian of
    `sigma_px`, exactly as the shader's two loops place them."""
    out = []
    for n, phase, radius, weight in FROST_RINGS:
        for i in range(n):
            a = phase + i * 2 * np.pi / n
            out.append((radius * sigma_px * np.cos(a), radius * sigma_px * np.sin(a), weight / n))
    return np.array(out)


# 3-point Gauss-Hermite rule for a unit Gaussian: nodes 0, +-sqrt(3).
POST_JMAX = 4.0  # Jacobian clamp of the post-lens taps
POST_TAPS = ((-np.sqrt(3.0), 1.0 / 6.0), (0.0, 2.0 / 3.0), (np.sqrt(3.0), 1.0 / 6.0))


def frost_wide_mix(sample_depth, half_min, v):
    """Weight of the wide frost at a pixel whose lens sample lies
    `sample_depth` inside a shape of half shorter side `half_min` (same
    unit): mix(edge, centre, sample_depth / half_min) minus
    frostWideSizeDrop x (1 - half_min / frostWideSizeRef) below the size ref,
    clamped to [0, 1]."""
    e, c = float(v["frostWideMixEdge"]), float(v["frostWideMixCentre"])
    ref, drop = float(v["frostWideSizeRef"]), float(v["frostWideSizeDrop"])
    hm = np.maximum(half_min, 1.0)
    w = e + (c - e) * sample_depth / hm
    if ref > 0:
        w = w - drop * np.maximum(0.0, 1.0 - hm / ref)
    return np.clip(w, 0.0, 1.0)


def fill_size_factor(shape, v):
    """Per-shape fillOpacity factor as packGlassUniforms writes uInfo.w
    (Task 17b): 1 - fillSizeDrop * (1 - min(1, halfMin / fillSizeRef)), 1 when
    fillSizeRef <= 0. `shape` in logical px (scene units)."""
    ref = float(v["fillSizeRef"])
    if ref <= 0:
        return 1.0
    half_min = 0.5 * min(shape["w"], shape["h"])
    return 1.0 - float(v["fillSizeDrop"]) * (1.0 - min(1.0, half_min / ref))


POST_SHARE_MAX = 0.9


def group_blur_sigma(scene, constants):
    """Frost sigma (pt) of the group's one composed blur, as the renderer
    picks it (Task 17b): per drawn shape `blurSigma * min(1, halfMin /
    blurSizeRef)` (halfMin = half the shorter side; blurSizeRef <= 0 means no
    scaling) times sqrt(1 - postBlurShare) (Task 17d: that share of the
    variance is applied by the shader after the lens), and the largest of
    those."""
    out = 0.0
    for s in scene["shapes"]:
        v = constants[variant_key(s, scene["brightness"])]
        ref = float(v["blurSizeRef"])
        k = min(1.0, 0.5 * min(s["w"], s["h"]) / ref) if ref > 0 else 1.0
        share = min(max(float(v.get("postBlurShare", 0.0)), 0.0), POST_SHARE_MAX)
        out = max(out, float(v["blurSigma"]) * k * np.sqrt(1.0 - share))
    return out


def group_blur_aspect(scene, constants):
    """sigmaX / sigma of the group's blur: (h / w) ^ blurAspectPower of the
    member with the largest sigma (first on ties), as the renderer picks it
    (Task 17d)."""
    best, aspect = -1.0, 1.0
    for s in scene["shapes"]:
        v = constants[variant_key(s, scene["brightness"])]
        sig = group_blur_sigma({"shapes": [s], "brightness": scene["brightness"]}, constants)
        if sig > best:
            best = sig
            p = float(v.get("blurAspectPower", 0.0))
            aspect = (s["h"] / s["w"]) ** p if p != 0 else 1.0
    return aspect


# --- render -----------------------------------------------------------------

# The fit scores only compare.py's region (shape bounds + 12 pt), so it renders
# just that window; `render` pads by 3 x the shadow radius instead.
SCORE_PAD_PT = 12
# Blurred texture kept around the window for lens/dispersion taps, rounded up
# to this many px so the blur cache survives small lens changes.
TAP_BUCKET_PX = 64


def _sample(tex, x0, y0, sx, sy):
    """Bilinear, edge-clamped sample of window `tex` (origin x0, y0) at
    physical fragment coordinates (sx, sy)."""
    cy = sy - 0.5 - y0
    cx = sx - 0.5 - x0
    return np.stack([map_coordinates(tex[..., c], [cy, cx], order=1, mode="nearest")
                     for c in range(3)], -1)


def scene_shapes(scene, constants, scale):
    out = []
    for s in scene["shapes"]:
        circular = s["shape"] in ("capsule", "circle")
        out.append({
            "rect": (s["x"] * scale, s["y"] * scale, s["w"] * scale, s["h"] * scale),
            "radius": shape_radius(s) * scale,
            "n": 2.0 if circular else float(constants["cornerExponent"]),
            "clear": 1.0 if s["variant"] == "clear" else 0.0,
            "tint": parse_tint(s.get("tint")),
        })
    return out


def _uvar(constants, brightness, scale):
    """Per-variant uniform blocks exactly as packGlassUniforms writes them."""
    res = []
    for base in ("regular", "clear"):
        v = constants[base + ("Dark" if brightness == "dark" else "")]
        knots = np.asarray(v["toneKnots"], np.float64)
        res.append({
            "A": np.array([v["lensDecay"] * scale, v["lensBand"] * scale,
                           v["lensStrength"], v["dispersion"]]),
            "B": np.array([v["rimWidth"] * scale, v["rimIntensity"],
                           v["fillOpacity"], v["dim"]]),
            "C": np.array([v["shadowRadius"] * scale, v["shadowOpacity"],
                           v["tintStrength"], v["lensSizeRef"] * scale]),
            "D": np.concatenate([parse_hex(v["fillColor"]), [v["saturation"]]]),
            "E": np.array([v["frostWideSigma"] * scale, v["frostWideMixEdge"],
                           v["frostWideMixCentre"], v["frostWideSizeRef"] * scale]),
            "F": np.array([v["frostWideSizeDrop"], v["glowStrength"],
                           min(max(v["postBlurShare"], 0.0), POST_SHARE_MAX),
                           v["normalRadiusScale"]]),
            # Tone LUT: grey, output values at inputs i/8 (Task 17d).
            "G": knots[0:4].copy(),
            "H": knots[4:8].copy(),
            "I": np.array([knots[8], v["lensEdge"] * scale,
                           v["lensEdgeDecay"] * scale, v["toneLift"]]),
            "J": np.array([v["rimMix"], v["rimMixWidth"] * scale,
                           v["rimMixCut"] * scale, v["rimMixLumaFloor"]]),
            "K": np.array([v["toneLiftKnee"], v["toneLiftSizeRef"] * scale,
                           v["blurSigma"] * np.sqrt(min(max(v["postBlurShare"], 0.0),
                                                        POST_SHARE_MAX)) * scale,
                           v["blurSizeRef"] * scale]),
        })
    return res


def tone_apply(col, k):
    """Piecewise-linear tone LUT with inputs at i/8 and per-pixel knot
    values `k` (9, N): the hat-sum form of the shader's `Tone()`.
    `col` is (3, N); returns (3, N)."""
    seg = (k[1:] - k[:-1])[:, None, :]                                    # (8,1,N)
    x = np.clip(col * 8.0 - np.arange(8).reshape(8, 1, 1), 0.0, 1.0)      # (8,3,N)
    return k[0] + (seg * x).sum(0)


def _work_box(scene, scale, W, H, pad):
    x0 = min(s["x"] for s in scene["shapes"]) - pad
    y0 = min(s["y"] for s in scene["shapes"]) - pad
    x1 = max(s["x"] + s["w"] for s in scene["shapes"]) + pad
    y1 = max(s["y"] + s["h"] for s in scene["shapes"]) + pad
    return (max(0, int(round(x0 * scale))), max(0, int(round(y0 * scale))),
            min(W, int(round(x1 * scale))), min(H, int(round(y1 * scale))))


@functools.lru_cache(maxsize=256)
def _geometry(scene_json, corner_exponent, merge_factor, scale, W, H, pad,
              nrs_regular=1.0, nrs_clear=1.0):
    """Everything that depends only on the shapes, cornerExponent,
    mergeFactor and the per-variant normalRadiusScale: field, lens normals,
    lens-field curvature, attribute weights."""
    scene = json.loads(scene_json)
    shapes = scene_shapes(scene, {"cornerExponent": corner_exponent}, scale)
    spacing = scene.get("spacing")
    k = (merge_factor * spacing * scale) if spacing else 0.0
    bx0, by0, bx1, by1 = _work_box(scene, scale, W, H, pad)
    ys, xs = np.mgrid[by0:by1, bx0:bx1]
    px = xs + 0.5
    py = ys + 0.5

    # Attribute blend (the shader's online softmax equals a plain softmax).
    dists = shape_dists(shapes, px, py)
    d = np.full(px.shape, 1e6)
    for di in dists:
        d = smin(d, di, k)
    wk = k * 0.5 + 1.0
    es = [np.maximum(di, 0.0) for di in dists]
    emin = np.minimum.reduce(es)
    ws = [np.exp(-(e - emin) / wk) for e in es]
    wsum = sum(ws)
    weights = [w / wsum for w in ws]

    # Half the shorter side, blended like the other attributes (lens size).
    half_min = sum(w * 0.5 * min(s["rect"][2], s["rect"][3]) for w, s in zip(weights, shapes))

    # Lens normals (Task 17d, measured: SwiftUI displaces along the normals
    # of a rounder rect): +-1 px central differences of the lens field, the
    # smooth union of each shape with its radius x normalRadiusScale (capped
    # at half the shorter side). Scale 1 is the outline's own field.
    lens = [{**s_, "radius": min(s_["radius"] * (nrs_clear if s_["clear"] else nrs_regular),
                                 0.5 * min(s_["rect"][2], s_["rect"][3]))}
            for s_ in shapes]
    fxp, fxm = field(lens, px + 1, py, k), field(lens, px - 1, py, k)
    fyp, fym = field(lens, px, py + 1, k), field(lens, px, py - 1, k)
    nx = fxp - fxm + 1e-6
    ny = fyp - fym + 1e-6
    nl = np.sqrt(nx * nx + ny * ny)
    # Curvature of the lens field's level set: Laplacian / |grad| (px^-1).
    lap = fxp + fxm + fyp + fym - 4.0 * field(lens, px, py, k)
    kappa = lap / np.maximum(0.5 * nl, 1e-3)
    return {"box": (bx0, by0, bx1, by1), "px": px, "py": py, "d": d,
            "nx": nx / nl, "ny": ny / nl, "kappa": kappa, "weights": weights,
            "shapes": shapes, "half_min": half_min}


def _smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def render_window(background, scene, constants, scale=3.0, blur_scale=None,
                  light_angle=LIGHT_ANGLE, pad_pt=SCORE_PAD_PT):
    """Renders the shapes' bounds inflated by `pad_pt`; returns
    (image, (x0, y0, x1, y1)) in screen px."""
    constants = resolve_constants(constants)
    bg = background
    H, W = bg.shape[:2]
    brightness = scene["brightness"]
    spacing = scene.get("spacing")
    merge_factor = float(constants["mergeFactor"])
    br_ = "Dark" if brightness == "dark" else ""
    g = _geometry(json.dumps(scene, sort_keys=True), float(constants["cornerExponent"]),
                  merge_factor, float(scale), W, H, float(pad_pt),
                  float(constants["regular" + br_]["normalRadiusScale"]),
                  float(constants["clear" + br_]["normalRadiusScale"]))
    bx0, by0, bx1, by1 = g["box"]
    shapes, weights = g["shapes"], g["weights"]

    # Tint strength per shape uses that shape's variant set (as the packer).
    tint = 0.0
    clear_mix = 0.0
    fill_scale = 0.0  # uInfo.w: per-shape fill size factor, blended
    for w, s, src in zip(weights, shapes, scene["shapes"]):
        v = constants[variant_key(src, brightness)]
        fill_scale = fill_scale + w * fill_size_factor(src, v)
        if s["tint"] is not None:
            rgb, a = s["tint"]
            tint = tint + w[..., None] * np.concatenate([rgb, [v["tintStrength"] * a]])
        clear_mix = clear_mix + w * s["clear"]
    tint = np.broadcast_to(tint, g["d"].shape + (4,)) if np.ndim(tint) else np.zeros(g["d"].shape + (4,))

    uv = _uvar(constants, brightness, scale)
    if np.all(clear_mix == 0) or np.all(clear_mix == 1):
        u = uv[1] if np.all(clear_mix == 1) else uv[0]
        A, B, C, D, E, F, G, H, I, J, K = (u[n] for n in "ABCDEFGHIJK")
    else:
        cm = np.asarray(clear_mix)[..., None]
        A, B, C, D, E, F, G, H, I, J, K = (uv[0][n] * (1 - cm) + uv[1][n] * cm for n in "ABCDEFGHIJK")
    A, B, C, D, E, F, I, J, K = (np.broadcast_to(x, g["d"].shape + (4,))
                                 for x in (A, B, C, D, E, F, I, J, K))

    d, nx, ny, px, py = g["d"], g["nx"], g["ny"], g["px"], g["py"]
    inside = 1.0 - _smoothstep(-0.75, 0.75, d)
    sr = np.maximum(C[..., 0] * 0.5, 1.0)
    d_out = np.maximum(d, 0.0)
    sh = C[..., 1] * np.exp(-(d_out * d_out) / (2.0 * sr * sr))
    shadow_a = sh * (1.0 - inside)

    # Lens v3 (shader: "Lens v3"); lens_v3 returns strength x band x s x v.
    depth = -d
    band = np.maximum(A[..., 1], 1.0)
    decay = np.maximum(A[..., 0], 1e-3)
    size_ref = C[..., 3]
    sc = np.where(size_ref > 0, np.minimum(1.0, g["half_min"] / np.maximum(size_ref, 1e-6)), 1.0)
    cut = np.exp(-band / decay)
    t = np.maximum(np.exp(-np.maximum(depth, 0.0) / np.maximum(decay * sc, 1e-3)) - cut,
                   0.0) / np.maximum(1.0 - cut, 1e-6)  # profile weight v (also weights dispersion)
    lens_amt = A[..., 2] * band * sc * t  # == lens_v3(depth, half_min, -strength*band, ...)
    # d(lens_amt)/d(depth), for the post-lens blur's Jacobian.
    dlens = np.where(t > 0, -A[..., 2] * band * sc * np.exp(
        -np.maximum(depth, 0.0) / np.maximum(decay * sc, 1e-3)) / np.maximum(
        decay * sc, 1e-3) / np.maximum(1.0 - cut, 1e-6), 0.0)
    # Lens edge term (Task 17d, measured: SwiftUI's lens is steeper in the
    # outer 1-2 pt): an extra inward offset lensEdge x exp(-depth / decay).
    le = I[..., 1] * np.exp(-np.maximum(depth, 0.0) / np.maximum(I[..., 2], 1e-3))
    lens_amt = lens_amt - le
    dlens = dlens + le / np.maximum(I[..., 2], 1e-3)
    spx = px + nx * lens_amt
    spy = py + ny * lens_amt
    dxp = nx * lens_amt * A[..., 3]
    dyp = ny * lens_amt * A[..., 3]

    sigma = group_blur_sigma(scene, constants)
    if blur_scale is None:
        blur_scale = 1.0
    # Frost v2: weight of the wide taps from the sampled point's depth.
    hm = np.maximum(g["half_min"], 1.0)
    wide_w = E[..., 1] + (E[..., 2] - E[..., 1]) * (depth - lens_amt) / hm
    wide_w = wide_w - np.where(E[..., 3] > 0, F[..., 0] * np.maximum(
        0.0, 1.0 - hm / np.maximum(E[..., 3], 1e-6)), 0.0)
    wide_w = np.where(E[..., 0] > 0, np.clip(wide_w, 0.0, 1.0), 0.0)
    wide_r = FROST_RINGS[1][2] * float(np.max(E[..., 0]))
    reach = float(np.max(np.abs(lens_amt) * (1.0 + np.abs(A[..., 3])))) + wide_r + 2.0
    reach = int(np.ceil(reach / TAP_BUCKET_PX)) * TAP_BUCKET_PX
    tx0, ty0 = bx0 - reach, by0 - reach
    tex = blurred_window(bg, sigma * scale * blur_scale,
                         (tx0, ty0, bx1 + reach, by1 + reach),
                         group_blur_aspect(scene, constants))

    sharp = bg[by0:by1, bx0:bx1]
    m = inside > 0  # the shader returns the shadow only where inside <= 0
    # Post-lens blur (Task 17d): the share of the frost variance that SwiftUI
    # applies after refraction. The composed blur is sigma x sqrt(1 - share);
    # here a 3x3 Gauss-Hermite rule of the per-variant K.z = blurSigma x
    # sqrt(share) (x the frost size scale when K.w > 0) in screen space,
    # mapped through the lens's Jacobian (normal: 1 - dL/ddepth, tangent:
    # 1 + L x curvature); skipped below 0.25 px. The centre tap is `base`.
    base = _sample(tex, tx0, ty0, spx[m], spy[m])
    col = base.copy()
    Km = K[m]
    hm_ = np.broadcast_to(g["half_min"], g["d"].shape)[m]
    sp_post = Km[:, 2] * np.where(Km[:, 3] > 0, np.minimum(
        1.0, hm_ / np.maximum(Km[:, 3], 1e-6)), 1.0) * blur_scale
    pm = sp_post >= 0.25
    if np.any(pm):
        sp_ = sp_post[pm]
        ja = np.clip(1.0 - dlens[m][pm], -POST_JMAX, POST_JMAX)
        jb = np.clip(1.0 + lens_amt[m][pm] * g["kappa"][m][pm], -POST_JMAX, POST_JMAX)
        nxm, nym = nx[m][pm], ny[m][pm]
        sxm, sym = spx[m][pm], spy[m][pm]
        acc = base[pm] * (4.0 / 9.0)
        for i, (on, wn) in enumerate(POST_TAPS):
            for j, (ot, wt) in enumerate(POST_TAPS):
                if i == 1 and j == 1:
                    continue
                a_ = ja * on * sp_
                b_ = jb * ot * sp_
                acc = acc + (wn * wt) * _sample(tex, tx0, ty0, sxm + nxm * a_ - nym * b_,
                                                sym + nym * a_ + nxm * b_)
        col[pm] = acc
    wm = wide_w[m]
    if np.any(wm > 0):
        unit = frost_taps(1.0)
        sxm = E[..., 0][m]
        wide = 0.0
        for dx, dy, wt in unit:
            wide = wide + wt * _sample(tex, tx0, ty0, spx[m] + dx * sxm, spy[m] + dy * sxm)
        col = col + (wide - col) * wm[:, None]
    # Dispersion replaces red/blue by single taps; carry the core channel's
    # full frost offset (post-lens blur + wide mix) over to them, so
    # dispersion 0 is an exact no-op and a grey backdrop stays grey. The
    # offset is measured after the wide mix, matching the shader.
    core_off = col - base
    tm = t[m]
    r2 = _sample(tex, tx0, ty0, spx[m] + dxp[m], spy[m] + dyp[m])[:, 0]
    b2 = _sample(tex, tx0, ty0, spx[m] - dxp[m], spy[m] - dyp[m])[:, 2]
    col[:, 0] += (r2 + core_off[:, 0] - col[:, 0]) * tm
    col[:, 2] += (b2 + core_off[:, 2] - col[:, 2]) * tm

    Dm, Bm, tim = D[m], B[m], tint[m]
    luma = (col * LUMA).sum(-1, keepdims=True)
    col = luma + (col - luma) * Dm[:, 3:4]
    # Tone LUT (Task 17d): grey knots blended across variants like the other
    # uniform blocks. Physically Apple's tone sits on the blurred backdrop
    # before the fill wash (flat-exact placement; the post-fill placement
    # distorted content contrast).
    kr = np.concatenate([uv[0]["G"][:4], uv[0]["H"][:4], uv[0]["I"][:1]])
    kc = np.concatenate([uv[1]["G"][:4], uv[1]["H"][:4], uv[1]["I"][:1]])
    cm1 = np.broadcast_to(np.asarray(clear_mix), g["d"].shape)[m]
    col = tone_apply(col.T, kr[:, None] * (1 - cm1) + kc[:, None] * cm1).T
    # Small-shape shadow lift (Task 17d / 8b, fitted: SwiftUI lifts the dark
    # end behind small dark glass): + toneLift x size x max(0, 1 - c/knee)^2,
    # size = max(0, 1 - halfMin / toneLiftSizeRef).
    Km = K[m]
    hmm = np.broadcast_to(g["half_min"], g["d"].shape)[m]
    lsz = np.where(Km[:, 1] > 0, np.maximum(0.0, 1.0 - hmm / np.maximum(Km[:, 1], 1e-3)), 0.0)
    lk = np.maximum(1.0 - col / np.maximum(Km[:, 0:1], 1e-3), 0.0)
    col = col + (I[..., 3][m] * lsz)[:, None] * lk * lk
    fsm = np.broadcast_to(fill_scale, g["d"].shape)[m][:, None]
    col = col + (Dm[:, :3] - col) * (Bm[:, 2:3] * fsm)
    col = col * (1.0 - Bm[:, 3:4])
    col = col + (tim[:, :3] - col) * tim[:, 3:4]

    lx, ly = np.cos(light_angle), np.sin(light_angle)
    rim_w = np.maximum(Bm[:, 0], 0.5)
    rim = 1.0 - _smoothstep(0.0, rim_w, depth[m])
    ndl = nx[m] * lx + ny[m] * ly
    spec = rim * (np.maximum(ndl, 0.0) + 0.35 * np.maximum(-ndl, 0.0))
    col = col + (Bm[:, 1] * spec)[:, None]
    # Isotropic rim (Task 17d, measured on clear glass): a mix toward white,
    # alpha rimMix ramping to 0 at rimMixWidth, cut at rimMixCut; scaled by
    # backdrop luminance down to rimMixLumaFloor (dark mode).
    Jm = J[m]
    dm = depth[m]
    ra = Jm[:, 0] * np.clip(1.0 - dm / np.maximum(Jm[:, 1], 1e-3), 0.0, 1.0) * (
        1.0 - _smoothstep(Jm[:, 2] - 0.5, Jm[:, 2] + 0.5, dm))
    lum = (col * LUMA).sum(-1)
    ra = ra * (Jm[:, 3] + (1.0 - Jm[:, 3]) * np.clip(lum / 0.5, 0.0, 1.0))
    col = np.clip(col + (1.0 - col) * ra[:, None], 0.0, 1.0)

    out_rgb = np.zeros(sharp.shape)
    out_rgb[m] = col * inside[m][:, None]  # premultiplied glass
    out_a = inside + shadow_a  # black shadow, alpha sh, outside the shape
    comp = out_rgb + sharp * (1.0 - out_a)[..., None]

    # Backdrop clip (RenderGlassBackdrop): union inflated by the margin; the
    # sharp background shows outside it.
    sets = [constants[n] for n in ("regular", "clear", "regularDark", "clearDark")]
    margin = max(v["shadowRadius"] for v in sets) * 2 + \
        max(1.0, merge_factor) * (spacing or 0.0) + 2
    cx0 = int(round((min(s["x"] for s in scene["shapes"]) - margin) * scale)) - bx0
    cy0 = int(round((min(s["y"] for s in scene["shapes"]) - margin) * scale)) - by0
    cx1 = int(round((max(s["x"] + s["w"] for s in scene["shapes"]) + margin) * scale)) - bx0
    cy1 = int(round((max(s["y"] + s["h"] for s in scene["shapes"]) + margin) * scale)) - by0
    clipped = sharp.copy()
    sl = (slice(max(cy0, 0), max(cy1, 0)), slice(max(cx0, 0), max(cx1, 0)))
    clipped[sl] = comp[sl]
    # The engine stores 8-bit colour.
    return np.round(np.clip(clipped, 0, 1) * 255.0) / 255.0, g["box"]


def render(background, scene, constants, scale=3.0, blur_scale=None, light_angle=LIGHT_ANGLE):
    """Returns `background` with the scene's glass drawn as Flutter does."""
    constants = resolve_constants(constants)
    sets = [constants[n] for n in ("regular", "clear", "regularDark", "clearDark")]
    pad = max(SCORE_PAD_PT, 3 * max(v["shadowRadius"] for v in sets))
    win, (x0, y0, x1, y1) = render_window(background, scene, constants, scale,
                                          blur_scale, light_angle, pad)
    out = background.copy()
    out[y0:y1, x0:x1] = win
    return out
