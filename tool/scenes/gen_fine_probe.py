"""Generate independent high-frequency clear-glass measurements.

Writes a separate asset set; it never changes the official 75-scene matrix.
Low-amplitude sinusoids keep tone response locally linear while probing detail
at 8-32 pixel periods, on both axes, with four quadrature phase steps.
"""
import argparse
import copy
import json
import pathlib

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
PERIODS = (8, 12, 16, 24, 32, 128, 160)


def code(axis, period, phase, width, height, amplitude=0.2):
    size = width if axis == "x" else height
    coord = np.arange(size) + 0.5
    value = np.round((0.5 + amplitude * np.cos(
        2 * np.pi * coord / period + phase * np.pi / 2)) * 255).astype(np.uint8)
    grid = np.broadcast_to(value[None, :], (height, width)) if axis == "x" else \
        np.broadcast_to(value[:, None], (height, width))
    return Image.fromarray(np.repeat(grid[..., None], 3, -1))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", type=pathlib.Path, required=True)
    ap.add_argument("--brightness", choices=("light", "dark"), default="light")
    args = ap.parse_args()
    spec = json.loads((ROOT / "tool/scenes/scenes.json").read_text())
    width, height = 1206, 2622
    backgrounds = args.out / "backgrounds"
    backgrounds.mkdir(parents=True, exist_ok=True)
    scenes = []
    for axis in ("x", "y"):
        for period in PERIODS:
            for phase in range(4):
                name = f"fine-{axis}-p{period}-k{phase}"
                code(axis, period, phase, width, height).save(backgrounds / f"{name}.png")
                for shape in ("capsule", "rect28"):
                    source = next(s for s in spec["scenes"] if
                                  s["id"] == f"clear-{shape}-text-{args.brightness}")
                    scene = copy.deepcopy(source)
                    scene.update(id=f"fine-{shape}-{axis}-p{period}-k{phase}", background=name)
                    scenes.append(scene)
    out = {"device": spec["device"], "scenes": scenes,
           "probe": {"mean": 0.5, "amplitude": 0.2, "periods": PERIODS,
                     "brightness": args.brightness}}
    (args.out / "fine.json").write_text(json.dumps(out, indent=2) + "\n")
    print(f"Prepared {len(scenes)} independent measurement scenes in {args.out}")


if __name__ == "__main__":
    main()
