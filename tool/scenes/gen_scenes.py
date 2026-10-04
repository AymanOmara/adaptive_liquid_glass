"""Writes tool/scenes/scenes.json: the static fidelity matrix (spec §10)."""
import json
import pathlib

OUT = pathlib.Path(__file__).with_name("scenes.json")
W, H = 402, 874

SHAPES = {
    "capsule": {"w": 200, "h": 56, "shape": "capsule", "radius": 0},
    "circle": {"w": 72, "h": 72, "shape": "circle", "radius": 0},
    "rect16": {"w": 240, "h": 140, "shape": "rect", "radius": 16},
    "rect28": {"w": 240, "h": 140, "shape": "rect", "radius": 28},
}
VARIANTS = {
    "regular": ("regular", None),
    "clear": ("clear", None),
    "tinted": ("regular", "#0A84FF99"),
}


def centred(spec, y):
    return {**spec, "x": (W - spec["w"]) / 2, "y": y}


scenes = []
for bg in ["photo", "text", "gradient"]:
    for vname, (variant, tint) in VARIANTS.items():
        for sname, spec in SHAPES.items():
            for brightness in ["light", "dark"]:
                scenes.append({
                    "id": f"{vname}-{sname}-{bg}-{brightness}",
                    "background": bg,
                    "brightness": brightness,
                    "spacing": None,
                    "shapes": [{**centred(spec, 560), "variant": variant, "tint": tint}],
                })

for gap in [4, 16, 30]:
    a = {"x": W / 2 - 60 - gap / 2, "y": 600, "w": 60, "h": 60, "shape": "circle",
         "radius": 0, "variant": "regular", "tint": None}
    b = {**a, "x": W / 2 + gap / 2}
    scenes.append({
        "id": f"merge-gap{gap}-photo-light",
        "background": "photo",
        "brightness": "light",
        "spacing": 20,
        "shapes": [a, b],
    })

OUT.write_text(json.dumps(
    {"device": {"width": W, "height": H, "scale": 3}, "scenes": scenes, "motion": []},
    indent=2) + "\n")
print(len(scenes), "scenes")
