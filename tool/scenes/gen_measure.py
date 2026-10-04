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

BASES = [(v, s, "light") for v in ("regular", "clear") for s in SHAPES] + \
    [("regular", "capsule", "dark"), ("clear", "capsule", "dark")]

scenes = []
for variant, shape, brightness in BASES:
    for bg in CODES:
        scenes.append({
            "id": f"{variant}-{shape}-{brightness}--{bg}",
            "background": bg,
            "brightness": brightness,
            "spacing": None,
            "shapes": [{**centred(SHAPES[shape], 560), "variant": variant, "tint": None}],
        })

if __name__ == "__main__":
    OUT.write_text(json.dumps(
        {"device": {"width": W, "height": 874, "scale": 3}, "scenes": scenes, "motion": []},
        indent=2) + "\n")
    print(len(scenes), "scenes")
