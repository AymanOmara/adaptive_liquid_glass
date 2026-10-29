"""Fit a native press-light correction against held SwiftUI frames.

Usage: python tool/native/fit_press_light.py RUN --prefix press-clear

This fits only the low-frequency white light (uniform lift + a Gaussian),
not native glass's refraction or press geometry. Corrections are in rendered
8-bit pixel values, not SwiftUI opacity: a fresh native capture must validate
any corresponding runtime coefficients. Training and validation use disjoint
held-frame windows after each renderer's independently detected onset.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter
from scipy.optimize import least_squares

ROOT = Path(__file__).resolve().parents[2]


def fit_correction(residual, mask, distance_squared):
    """Fit a uniform lift, Gaussian peak and sigma (in points)."""
    values = residual[mask].mean(axis=-1)
    d2 = distance_squared[mask]
    if values.size < 3 or not np.isfinite(values).all():
        raise ValueError("at least three finite interior pixels are required")

    def error(p):
        return p[0] + p[1] * np.exp(-d2 / (2 * p[2] ** 2)) - values

    best = least_squares(error, [0, 1, 41],
                         bounds=([-64, -64, 4], [64, 64, 160]))
    lift, peak, sigma = map(float, best.x)
    correction = lift + peak * np.exp(-distance_squared / (2 * sigma ** 2))
    return {"lift_px": lift, "peak_px": peak, "sigma_pt": sigma}, correction


def load(path):
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)


def onset(paths):
    """Same 0.08/255, 99.5th-percentile onset as compare_motion.py."""
    base = load(paths[0])
    for i, path in enumerate(paths[1:], 1):
        delta = gaussian_filter(np.abs(load(path) - base).mean(axis=2), 2)
        if np.percentile(delta, 99.5) > 0.08:
            return i
    raise ValueError("recording contains no press onset")


def measure(run, motion, scale, crop):
    shape = motion["shape"]
    sequences = {}
    onsets = {}
    for renderer in ("flutter", "swiftui"):
        paths = sorted((run / "frames" / f"{motion['id']}.{renderer}").glob("*.png"))
        if not paths:
            raise ValueError(f"no frames for {motion['id']}.{renderer}")
        start = onset(paths)
        if start + 38 > len(paths) or motion["hold_ms"] < 650:
            raise ValueError("recording must include at least 650 ms of held press")
        onsets[renderer] = start
        sequences[renderer] = [
            np.mean([load(p) for p in paths[start + lo:start + hi]], axis=0)
            for lo, hi in ((18, 28), (28, 38))
        ]
    h, w = sequences["flutter"][0].shape[:2]
    yy, xx = np.indices((h, w))
    x = (xx + crop["x"]) / scale
    y = (yy + crop["y"]) / scale
    cx = shape["x"] + shape["w"] / 2
    cy = shape["y"] + shape["h"] / 2
    halfw, halfh = shape["w"] / 2 - 8, shape["h"] / 2 - 8
    radius = (min(shape["w"], shape["h"]) / 2 if shape["shape"] in
              ("capsule", "circle") else shape["radius"]) - 8
    radius = max(0, min(radius, halfw, halfh))
    if halfw <= 0 or halfh <= 0:
        raise ValueError("shape is too small for the 8 pt interior inset")
    dx = np.maximum(np.abs(x - cx) - halfw + radius, 0)
    dy = np.maximum(np.abs(y - cy) - halfh + radius, 0)
    mask = (np.abs(x - cx) < halfw) & (np.abs(y - cy) < halfh)
    if radius > 0:
        mask &= dx * dx + dy * dy < radius * radius
    d2 = (x - motion["touch"]["x"]) ** 2 + (y - motion["touch"]["y"]) ** 2
    residuals = [s - f for s, f in zip(sequences["swiftui"], sequences["flutter"])]
    parameters, correction = fit_correction(residuals[0], mask, d2)
    errors = [{"before_mae": float(np.abs(r[mask]).mean()),
               "predicted_mae": float(np.abs((r - correction[..., None])[mask]).mean())}
              for r in residuals]
    return {"id": motion["id"], "onset": onsets, "correction": parameters,
            "training": errors[0], "validation": errors[1]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run", type=Path)
    parser.add_argument("--prefix", default="press-clear")
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    spec = json.loads((ROOT / "tool/scenes/motion.json").read_text())
    crops = json.loads((args.run / "crop.json").read_text())
    motions = [m for m in spec["motion"] if m["id"].startswith(args.prefix)
               and m["kind"] == "press"]
    if not motions:
        parser.error("no matching press scenes")
    report = [measure(args.run, m, spec["device"]["scale"], crops[m["id"]])
              for m in motions]
    output = json.dumps(report, indent=2) + "\n"
    if args.out:
        args.out.write_text(output)
    sys.stdout.write(output)


if __name__ == "__main__":
    main()
