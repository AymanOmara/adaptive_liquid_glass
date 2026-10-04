"""Writes tool/scenes/measure.json: lens measurement scenes (Task 15c).

Each base scene (shape x variant x brightness, one shape at the fidelity
matrix position) is repeated over the 16 coordinate-code backgrounds of
gen_backgrounds.CODES; ids are "<variant>-<shape>-<brightness>--<background>".
Kept apart from scenes.json so the 75-scene fidelity set is unchanged.
"""
import json
import pathlib

from gen_backgrounds import CODES
from gen_scenes import SHAPES, W, centred

OUT = pathlib.Path(__file__).with_name("measure.json")

# Size series (Task 17b): radius-16 rectangles whose half shorter side is
# 20, 50, 100 and 150 pt, to measure frost blur and lens against shape size.
SIZES = {f"rect16-s{h}": {"w": w, "h": 2 * h, "shape": "rect", "radius": 16}
         for h, w in ((20, 200), (50, 240), (100, 300), (150, 360))}
ALL_SHAPES = {**SHAPES, **SIZES}

BASES = [(v, s, "light") for v in ("regular", "clear") for s in SHAPES] + \
    [("regular", "capsule", "dark"), ("clear", "capsule", "dark")] + \
    [(v, s, "light") for v in ("regular", "clear") for s in SIZES]

scenes = []
for variant, shape, brightness in BASES:
    spec = ALL_SHAPES[shape]
    # Keep the decode window (shape + 16 pt) on screen for the tall shapes.
    y = min(560, 874 - 34 - spec["h"])
    for bg in CODES:
        scenes.append({
            "id": f"{variant}-{shape}-{brightness}--{bg}",
            "background": bg,
            "brightness": brightness,
            "spacing": None,
            "shapes": [{**centred(spec, y), "variant": variant, "tint": None}],
        })

if __name__ == "__main__":
    OUT.write_text(json.dumps(
        {"device": {"width": W, "height": 874, "scale": 3}, "scenes": scenes, "motion": []},
        indent=2) + "\n")
    print(len(scenes), "scenes")
