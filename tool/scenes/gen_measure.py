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

# Task 9 (rim direction): rect16 over the four rotated gradients
# (gen_backgrounds.gradient_rotated), both appearances and brightnesses.
# Regular is the failing rect band's variant; clear is the control (its rim
# measured isotropic in the model-only clear analysis, M5). measure_rim.py
# decodes the rim ring's azimuthal profile per rotation.
for v in ("regular", "clear"):
    for b in ("light", "dark"):
        for deg in (0, 90, 180, 270):
            scenes.append(scene(v, "rect16", b, f"gradient-r{deg:03d}"))

# Task 17d held-out robustness set (review fix round 1): scenes the fit never
# saw, to catch over-fitting of the size- and phase-sensitive constants
# (lensSizeRef, blurAspectPower, the clear lens grid). Ids "holdout-...".
#  - capsules 200 pt wide at 50/60/64 pt height (the 56 pt capsule is in-set);
#  - the worst in-set text scenes with the glass moved down 3 px and 7 px
#    (equivalent to shifting the text background; the band mirrors text
#    lines, so this changes their phase);
#  - one wide rect 350 x 64 (radius 16): an aspect ratio outside the set.
HOLDOUT = []
for v in ("regular", "clear"):
    for b in ("light", "dark"):
        for bg in ("text", "photo"):
            for h in (50, 60, 64):
                spec = {"w": 200, "h": h, "shape": "capsule", "radius": 0}
                HOLDOUT.append({"id": f"holdout-{v}-capsule{h}-{bg}-{b}", "background": bg,
                                "brightness": b, "spacing": None,
                                "shapes": [{**centred(spec, 560), "variant": v, "tint": None}]})
            spec = {"w": 350, "h": 64, "shape": "rect", "radius": 16}
            HOLDOUT.append({"id": f"holdout-{v}-rect350x64-{bg}-{b}", "background": bg,
                            "brightness": b, "spacing": None,
                            "shapes": [{**centred(spec, 560), "variant": v, "tint": None}]})
        for sname in ("capsule", "rect28"):
            for px in (3, 7):
                HOLDOUT.append({"id": f"holdout-{v}-{sname}-text-{b}-dy{px}", "background": "text",
                                "brightness": b, "spacing": None,
                                "shapes": [{**centred(SHAPES[sname], 560 + px / 3), "variant": v,
                                            "tint": None}]})
scenes += HOLDOUT

if __name__ == "__main__":
    OUT.write_text(json.dumps(
        {"device": {"width": W, "height": 874, "scale": 3}, "scenes": scenes, "motion": []},
        indent=2) + "\n")
    print(len(scenes), "scenes")
