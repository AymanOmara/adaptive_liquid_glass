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
def _blurred_cached(bg_id, sigma_px, box):
    bg = _BG[bg_id]
    return _blur_box(bg, sigma_px, box)


_BG = {}


def _blur_box(bg, sigma_px, box):
    """Blurs `bg` (edge clamped) with impeller_kernel and returns the window
    `box`."""
    x0, y0, x1, y1 = box
    h, w = bg.shape[:2]
    k = impeller_kernel(sigma_px) if sigma_px > 0 else np.ones(1)
    m = k.size // 2 + 2
    ys = np.clip(np.arange(y0 - m, y1 + m), 0, h - 1)
    xs = np.clip(np.arange(x0 - m, x1 + m), 0, w - 1)
    win = bg[np.ix_(ys, xs)]
    if sigma_px > 0:
        win = convolve1d(convolve1d(win, k, axis=0, mode="nearest"), k, axis=1, mode="nearest")
    return win[m:m + (y1 - y0), m:m + (x1 - x0)]


def blurred_window(bg, sigma_px, box):
    key = id(bg)
    _BG[key] = bg
    return _blurred_cached(key, round(float(sigma_px), 4), tuple(int(v) for v in box))


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
        res.append({
            "A": np.array([v["lensDecay"] * scale, v["lensBand"] * scale,
                           v["lensStrength"], v["dispersion"]]),
            "B": np.array([v["rimWidth"] * scale, v["rimIntensity"],
                           v["fillOpacity"], v["dim"]]),
            "C": np.array([v["shadowRadius"] * scale, v["shadowOpacity"],
                           v["tintStrength"], v["lensSizeRef"] * scale]),
            "D": np.concatenate([parse_hex(v["fillColor"]), [v["saturation"]]]),
        })
    return res


def _work_box(scene, scale, W, H, pad):
    x0 = min(s["x"] for s in scene["shapes"]) - pad
    y0 = min(s["y"] for s in scene["shapes"]) - pad
    x1 = max(s["x"] + s["w"] for s in scene["shapes"]) + pad
    y1 = max(s["y"] + s["h"] for s in scene["shapes"]) + pad
    return (max(0, int(round(x0 * scale))), max(0, int(round(y0 * scale))),
            min(W, int(round(x1 * scale))), min(H, int(round(y1 * scale))))


@functools.lru_cache(maxsize=256)
def _geometry(scene_json, corner_exponent, merge_factor, scale, W, H, pad):
    """Everything that depends only on the shapes, cornerExponent and
    mergeFactor: field, normals, attribute weights."""
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

    # Normals by +-1 px central differences of the field.
    nx = field(shapes, px + 1, py, k) - field(shapes, px - 1, py, k) + 1e-6
    ny = field(shapes, px, py + 1, k) - field(shapes, px, py - 1, k) + 1e-6
    nl = np.sqrt(nx * nx + ny * ny)
    return {"box": (bx0, by0, bx1, by1), "px": px, "py": py, "d": d,
            "nx": nx / nl, "ny": ny / nl, "weights": weights, "shapes": shapes,
            "half_min": half_min}


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
    g = _geometry(json.dumps(scene, sort_keys=True), float(constants["cornerExponent"]),
                  merge_factor, float(scale), W, H, float(pad_pt))
    bx0, by0, bx1, by1 = g["box"]
    shapes, weights = g["shapes"], g["weights"]

    # Tint strength per shape uses that shape's variant set (as the packer).
    tint = 0.0
    clear_mix = 0.0
    for w, s, src in zip(weights, shapes, scene["shapes"]):
        v = constants[variant_key(src, brightness)]
        if s["tint"] is not None:
            rgb, a = s["tint"]
            tint = tint + w[..., None] * np.concatenate([rgb, [v["tintStrength"] * a]])
        clear_mix = clear_mix + w * s["clear"]
    tint = np.broadcast_to(tint, g["d"].shape + (4,)) if np.ndim(tint) else np.zeros(g["d"].shape + (4,))

    uv = _uvar(constants, brightness, scale)
    if np.all(clear_mix == 0) or np.all(clear_mix == 1):
        u = uv[1] if np.all(clear_mix == 1) else uv[0]
        A, B, C, D = u["A"], u["B"], u["C"], u["D"]
    else:
        cm = np.asarray(clear_mix)[..., None]
        A, B, C, D = (uv[0][n] * (1 - cm) + uv[1][n] * cm for n in "ABCD")
    A, B, C, D = (np.broadcast_to(x, g["d"].shape + (4,)) for x in (A, B, C, D))

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
    spx = px + nx * lens_amt
    spy = py + ny * lens_amt
    dxp = nx * lens_amt * A[..., 3]
    dyp = ny * lens_amt * A[..., 3]

    sigma = max(constants[variant_key(s, brightness)]["blurSigma"] for s in scene["shapes"])
    if blur_scale is None:
        blur_scale = 1.0
    reach = float(np.max(np.abs(lens_amt) * (1.0 + np.abs(A[..., 3])))) + 2.0
    reach = int(np.ceil(reach / TAP_BUCKET_PX)) * TAP_BUCKET_PX
    tx0, ty0 = bx0 - reach, by0 - reach
    tex = blurred_window(bg, sigma * scale * blur_scale,
                         (tx0, ty0, bx1 + reach, by1 + reach))

    sharp = bg[by0:by1, bx0:bx1]
    m = inside > 0  # the shader returns the shadow only where inside <= 0
    col = _sample(tex, tx0, ty0, spx[m], spy[m])
    tm = t[m]
    r2 = _sample(tex, tx0, ty0, spx[m] + dxp[m], spy[m] + dyp[m])[:, 0]
    b2 = _sample(tex, tx0, ty0, spx[m] - dxp[m], spy[m] - dyp[m])[:, 2]
    col[:, 0] += (r2 - col[:, 0]) * tm
    col[:, 2] += (b2 - col[:, 2]) * tm

    Dm, Bm, tim = D[m], B[m], tint[m]
    luma = (col * LUMA).sum(-1, keepdims=True)
    col = luma + (col - luma) * Dm[:, 3:4]
    col = col + (Dm[:, :3] - col) * Bm[:, 2:3]
    col = col * (1.0 - Bm[:, 3:4])
    col = col + (tim[:, :3] - col) * tim[:, 3:4]

    lx, ly = np.cos(light_angle), np.sin(light_angle)
    rim_w = np.maximum(Bm[:, 0], 0.5)
    rim = 1.0 - _smoothstep(0.0, rim_w, depth[m])
    ndl = nx[m] * lx + ny[m] * ly
    spec = rim * (np.maximum(ndl, 0.0) + 0.35 * np.maximum(-ndl, 0.0))
    col = np.clip(col + (Bm[:, 1] * spec)[:, None], 0.0, 1.0)

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
