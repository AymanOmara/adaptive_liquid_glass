"""Writes tool/scenes/measure.json: lens measurement scenes (Task 15c).

Each base scene (shape x variant x brightness, one shape at the fidelity
matrix position) is repeated over the 16 coordinate-code backgrounds of
gen_backgrounds.CODES; ids are "<variant>-<shape>-<brightness>--<background>".
Kept apart from scenes.json so the 75-scene fidelity set is unchanged.
"""
import json
import pathlib

from gen_backgrounds import CODES, FLATS, FROST_CODES, PROBE_FLATS
from gen_scenes import SHAPES, W, centred

OUT = pathlib.Path(__file__).with_name("measure.json")

# Size series (Task 17b): radius-16 rectangles whose half shorter side is
# 20, 50, 100 and 150 pt, to measure frost blur and lens against shape size.
SIZES = {f"rect16-s{h}": {"w": w, "h": 2 * h, "shape": "rect", "radius": 16}
         for h, w in ((20, 200), (50, 240), (100, 300), (150, 360))}
# Task 17c class probes: where small regular glass switches to its own
# (adaptive) material, by size and by backdrop luminance.
PROBES = {**{f"circle{d}": {"w": d, "h": d, "shape": "circle", "radius": 0}
             for d in (56, 60, 64, 68)},
          **{f"capsule{h}": {"w": 200, "h": h, "shape": "capsule", "radius": 0}
             for h in (60, 64, 68, 72)},
          "rect16-124x60": {"w": 124, "h": 60, "shape": "rect", "radius": 16}}
ALL_SHAPES = {**SHAPES, **SIZES, **PROBES}

BASES = [(v, s, "light") for v in ("regular", "clear") for s in SHAPES] + \
    [("regular", "capsule", "dark"), ("clear", "capsule", "dark")] + \
    [(v, s, "light") for v in ("regular", "clear") for s in SIZES]

# Task 17c: a dark size series (frost, fill level and contrast against size;
# x codes only, which is all the frost and tone analysis needs) ...
DARK_SERIES = [(v, s, "dark") for v in ("regular", "clear")
               for s in ("circle", "rect16", *SIZES)]
X_CODES = [bg for bg in CODES if bg.startswith("code-x-")]
# ... and uniform greys for the tone curve on a large and a small shape.
TONE_BASES = [(v, s, b) for v in ("regular", "clear") for b in ("light", "dark")
              for s in ("rect16", "capsule")]


def scene(variant, shape, brightness, bg):
    spec = ALL_SHAPES[shape]
    # Keep the decode window (shape + 16 pt) on screen for the tall shapes.
    y = min(560, 874 - 34 - spec["h"])
    return {
        "id": f"{variant}-{shape}-{brightness}--{bg}",
        "background": bg,
        "brightness": brightness,
        "spacing": None,
        "shapes": [{**centred(spec, y), "variant": variant, "tint": None}],
    }


# Ids of earlier tasks keep their order; Task 17c scenes are appended.
scenes = [scene(*b, bg) for b in BASES for bg in CODES]
scenes += [scene(*b, bg) for b in BASES for bg in FROST_CODES]
scenes += [scene(*b, bg) for b in DARK_SERIES for bg in [*X_CODES, *FROST_CODES]]
scenes += [scene(*b, bg) for b in TONE_BASES for bg in FLATS]
# Class probes over mid grey: every probe shape plus the circle, in both
# appearances; the luminance switch on the capsule (fine levels); whether a
# large-class circle switches at the extremes; and the merge pairs of
# scenes.json (two 60 pt circles, spacing 20).
scenes += [scene("regular", s, b, "flat-v128") for s in PROBES for b in ("light", "dark")]
scenes += [scene("regular", "capsule", b, bg) for b in ("light", "dark") for bg in PROBE_FLATS]
scenes += [scene("regular", "circle", "light", "flat-v000"),
           scene("regular", "circle", "light", "flat-v038"),
           scene("regular", "circle", "dark", "flat-v255"),
           scene("regular", "circle", "dark", "flat-v230")]
for gap in (4, 16, 30):
    for b in ("light", "dark"):
        a = {"x": W / 2 - 60 - gap / 2, "y": 600, "w": 60, "h": 60, "shape": "circle",
             "radius": 0, "variant": "regular", "tint": None}
        scenes.append({"id": f"regular-merge{gap}-{b}--flat-v128", "background": "flat-v128",
                       "brightness": b, "spacing": 20, "shapes": [a, {**a, "x": W / 2 + gap / 2}]})

if __name__ == "__main__":
    OUT.write_text(json.dumps(
        {"device": {"width": W, "height": 874, "scale": 3}, "scenes": scenes, "motion": []},
        indent=2) + "\n")
    print(len(scenes), "scenes")
