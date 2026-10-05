"""Deterministic backgrounds shared by the Flutter and SwiftUI renderers."""
import math
import pathlib
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1206, 2622  # iPhone 17 Pro @3x
OUT = pathlib.Path(__file__).resolve().parents[2] / "example/assets/backgrounds"


def photo() -> Image.Image:
    rnd = random.Random(7)
    img = Image.new("RGB", (W, H))
    px = img.load()
    for y in range(H):
        for x in range(W):
            u, v = x / W, y / H
            px[x, y] = (
                int(127 + 120 * math.sin(6.0 * u + 2.0 * v)),
                int(127 + 120 * math.sin(4.0 * v + 1.3)),
                int(127 + 120 * math.cos(5.0 * u * v + 0.5)),
            )
    d = ImageDraw.Draw(img)
    for _ in range(180):
        x, y, r = rnd.randrange(W), rnd.randrange(H), rnd.randrange(6, 90)
        c = tuple(rnd.randrange(256) for _ in range(3))
        d.ellipse((x - r, y - r, x + r, y + r), fill=c)
    for i in range(0, W, 48):  # thin bars make lensing measurable
        d.rectangle((i, 0, i + 6, H), fill=(250, 250, 250))
    return img.filter(ImageFilter.GaussianBlur(0.6))


def text() -> Image.Image:
    img = Image.new("RGB", (W, H), (255, 255, 255))
    d = ImageDraw.Draw(img)
    font = ImageFont.load_default(size=42)
    words = "liquid glass refracts light and colour from the content behind it ".split()
    rnd = random.Random(3)
    y = 20
    while y < H:
        line = " ".join(rnd.choice(words) for _ in range(9))
        d.text((24, y), line, fill=(20, 20, 20), font=font)
        y += 56
    return img


# --- coordinate-coded measurement backgrounds (Task 15c) -------------------
#
# Grey (R = G = B) sinusoids along one axis: 0.5 + CODE_AMP * cos(2 pi u / P +
# step * pi / 2), with u the pixel-centre coordinate (x + 0.5). Four phase
# steps per period cancel any per-pixel affine colour change (out = a*src + b)
# and any symmetric shift-invariant blur (a sinusoid stays a sinusoid, only
# its amplitude shrinks); the phase atan2(I3 - I1, I0 - I2) is the sampled
# position modulo P. Two periods (128, 160 px) beat at 640 px, which unwraps
# the fringe order. Grey keeps saturation from mixing channels. See
# tool/fidelity/measure_lens.py and the Task 15c report.
CODE_AMP = 0.35
CODE_PERIODS = (128, 160)
CODES = {
    f"code-{axis}-p{period}-k{step}": (axis, period, step)
    for axis in ("x", "y") for period in CODE_PERIODS for step in range(4)
}


# Task 17c: shorter periods (x only) for the frost transfer function. The
# phase steps cancel the mean and the sampled coordinate is already known
# from the 128/160 pair, so each gives the modulation |MTF(P)| per pixel.
FROST_PERIODS = (32, 48, 80)
FROST_CODES = {
    f"code-x-p{period}-k{step}": ("x", period, step)
    for period in FROST_PERIODS for step in range(4)
}

# Task 17c: uniform greys (8-bit code values) for the tone response; a flat
# field is unchanged by any blur or lens, so the glass interior shows the
# pure input -> output curve.
FLAT_LEVELS = (0, 8, 16, 26, 38, 51, 64, 77, 128, 179, 191, 204, 217, 230, 242, 255)
FLATS = {f"flat-v{v:03d}": v for v in FLAT_LEVELS}
# Finer levels around the luminance where small regular glass switches between
# its light and dark material (Task 17c class probes).
PROBE_FLAT_LEVELS = (41, 44, 47, 220, 223, 226, 229)
PROBE_FLATS = {f"flat-v{v:03d}": v for v in PROBE_FLAT_LEVELS}


def flat(value: int, w: int = W, h: int = H) -> Image.Image:
    return Image.new("RGB", (w, h), (value, value, value))


def code(axis: str, period: int, step: int, w: int = W, h: int = H) -> Image.Image:
    n = w if axis == "x" else h
    u = np.arange(n) + 0.5
    v = 0.5 + CODE_AMP * np.cos(2 * np.pi * u / period + step * np.pi / 2)
    row = np.round(v * 255).astype(np.uint8)
    grid = np.broadcast_to(row[None, :], (h, w)) if axis == "x" else \
        np.broadcast_to(row[:, None], (h, w))
    return Image.fromarray(np.repeat(grid[..., None], 3, -1).copy(), "RGB")


def gradient() -> Image.Image:
    img = Image.new("RGB", (W, H))
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        c = (int(30 + 200 * t), int(80 + 100 * (1 - t)), int(200 - 150 * t))
        for x in range(W):
            px[x, y] = c
    return img


# Task 9 (rim direction): the gradient ramp on the four screen axes — the
# same palette as `gradient`, rotation only, canvas unrotated. r000 is
# `gradient` itself (dark top -> light bottom); r090 runs the ramp left ->
# right; r180 and r270 are those two reversed (a 180-deg rotation of each).
GRADIENT_DEGREES = (0, 90, 180, 270)


def gradient_rotated(degrees: int, w: int = W, h: int = H) -> Image.Image:
    horizontal = degrees % 180 == 90
    n = w if horizontal else h
    t = np.arange(n, dtype=np.float64) / (n - 1)
    if degrees in (180, 270):
        t = 1.0 - t
    ramp = np.stack([np.floor(30 + 200 * t), np.floor(80 + 100 * (1 - t)),
                     np.floor(200 - 150 * t)], -1).astype(np.uint8)
    grid = np.broadcast_to(ramp[None, :, :], (h, n, 3)) if horizontal \
        else np.broadcast_to(ramp[:, None, :], (n, w, 3))
    return Image.fromarray(grid.copy(), "RGB")


if __name__ == "__main__":
    import sys

    # `gen_backgrounds.py codes` writes only the measurement codes and flats.
    only_codes = sys.argv[1:] == ["codes"]
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in [] if only_codes else [("photo", photo), ("text", text), ("gradient", gradient)]:
        fn().save(OUT / f"{name}.png", optimize=True)
        print("wrote", OUT / f"{name}.png")
    for deg in GRADIENT_DEGREES:
        gradient_rotated(deg).save(OUT / f"gradient-r{deg:03d}.png", optimize=True)
        print("wrote", OUT / f"gradient-r{deg:03d}.png")
    for name, (axis, period, step) in {**CODES, **FROST_CODES}.items():
        code(axis, period, step).save(OUT / f"{name}.png", optimize=True)
        print("wrote", OUT / f"{name}.png")
    for name, value in {**FLATS, **PROBE_FLATS}.items():
        flat(value).save(OUT / f"{name}.png", optimize=True)
        print("wrote", OUT / f"{name}.png")
