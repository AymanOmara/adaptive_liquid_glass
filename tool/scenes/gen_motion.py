"""Writes tool/scenes/motion.json: press and morph recordings (Task 16).

Each entry is rendered by `-motion <id>` in both renderers and driven by one
idb touch at `touch` (logical points). `press` holds that touch for
`hold_ms` on an interactive glass shape; `morph` taps the background, which
toggles the group's members from `before` to `after` (SwiftUI:
`withAnimation(.bouncy)` inside a `GlassEffectContainer`; Flutter: `setState`
inside a `GlassGroup`, whose own morph spring animates the change). Morph
shapes carry `glassId`.
"""
import json
import pathlib

OUT = pathlib.Path(__file__).with_name("motion.json")
W, H = 402, 874

CAPSULE = {"w": 200, "h": 56, "shape": "capsule", "radius": 0}
CIRCLE = {"w": 72, "h": 72, "shape": "circle", "radius": 0}


def centred(spec, y):
    return {**spec, "x": (W - spec["w"]) / 2, "y": y, "variant": "regular", "tint": None}


def press(id_, brightness, shape, touch):
    return {"id": id_, "kind": "press", "background": "photo", "brightness": brightness,
            "shape": centred(shape, 560), "touch": touch, "hold_ms": 700}


# Touch near the capsule's right end (dx = 0.79 of the half width, dy = 0)
# separates uniform scale (height) from stretch (width); the circle is
# pressed at its centre, so it shows pure scale.
CAPSULE_TOUCH = {"x": 280, "y": 588}
motion = [
    press("press-capsule-photo-light", "light", CAPSULE, CAPSULE_TOUCH),
    press("press-capsule-photo-dark", "dark", CAPSULE, CAPSULE_TOUCH),
    press("press-circle-photo-light", "light", CIRCLE, {"x": 201, "y": 596}),
]


def centre_touch(shape):
    return {"x": W // 2, "y": 560 + shape["h"] // 2}


# Task 16b: press growth against size. Centre touches show pure scale; with
# the 72 pt circle above, three sizes per shape.
for shape in ({"w": 44, "h": 44, "shape": "circle", "radius": 0},
              {"w": 120, "h": 120, "shape": "circle", "radius": 0},
              {"w": 120, "h": 44, "shape": "capsule", "radius": 0},
              {"w": 200, "h": 56, "shape": "capsule", "radius": 0},
              {"w": 300, "h": 72, "shape": "capsule", "radius": 0}):
    motion.append(press(f"press-size-{shape['shape']}{shape['w']}x{shape['h']}-photo-light",
                        "light", shape, centre_touch(shape)))

# One 60 pt circle g0; expanding adds g1 70 pt to its right (a 10 pt gap,
# inside the 20 pt spacing, so the two merge). Contract is the reverse.
g0 = {"x": W / 2 - 65, "y": 600, "w": 60, "h": 60, "shape": "circle", "radius": 0,
      "variant": "regular", "tint": None, "glassId": "g0"}
g1 = {**g0, "x": g0["x"] + 70, "glassId": "g1"}
for name, before, after in [("expand", [g0], [g0, g1]), ("contract", [g0, g1], [g0])]:
    motion.append({"id": f"morph-{name}-photo-light", "kind": "morph", "background": "photo",
                   "brightness": "light", "spacing": 20, "before": before, "after": after,
                   "touch": {"x": 30, "y": 30}})

if __name__ == "__main__":
    OUT.write_text(json.dumps(
        {"device": {"width": W, "height": H, "scale": 3}, "motion": motion}, indent=2) + "\n")
    print(len(motion), "motions")
