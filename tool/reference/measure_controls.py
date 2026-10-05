"""Measures SwiftUI reference screenshots (build/reference/) into
tool/reference/controls.json. Usage:
tool/fidelity/.venv/bin/python tool/reference/measure_controls.py build/reference
"""
import json, pathlib, sys
import numpy as np
from PIL import Image

S = 3.0  # px per pt
SIZES = ["mini", "small", "regular", "large", "extraLarge"]


def grey(p):
    return np.asarray(Image.open(p).convert("L"), dtype=np.float32)


def bbox(mask):
    ys, xs = np.where(mask)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def buttons(img):
    bg = float(np.median(img))
    out = {}
    for i, name in enumerate(SIZES):
        cy = int((80 + i * 120) * S)
        band = img[cy - 150:cy + 150]
        # Glass is lighter than the grey; its drop shadow is darker, so
        # only the lighter side counts. Dark text sits inside the glass.
        glass = (band > bg + 12) | (band < 60)
        lx0, ly0, lx1, ly1 = bbox(glass[:, : int(215 * S)])
        ix0, iy0, ix1, iy1 = bbox(glass[:, int(250 * S):])
        tx0, ty0, tx1, ty1 = bbox(band[ly0:ly1, lx0:lx1] < 60)
        out[name] = {
            "height": round((ly1 - ly0) / S, 2),
            "padding": round(((lx1 - lx0) - (tx1 - tx0)) / 2 / S, 2),
            # "Button" has no descender: ink height is the cap height
            # (SF Pro 0.705 em).
            "font": round((ty1 - ty0) / S / 0.705, 1),
            "icon_only": round((iy1 - iy0) / S, 2),
            "icon_only_width": round((ix1 - ix0) / S, 2),
        }
    return out


def ink(img, x0, y0, x1, y1, thr=110):
    m = img[int(y0 * S):int(y1 * S), int(x0 * S):int(x1 * S)] < thr
    if not m.any():
        return None
    bx0, by0, bx1, by1 = bbox(m)
    return (x0 + bx0 / S, y0 + by0 / S, x0 + bx1 / S, y0 + by1 / S, int(m.sum()))


def navbar(d):
    rest = grey(d / "navbar_0.png")
    # Trailing action capsule: the white glass with a soft shadow on the
    # white page — find it by its icons, then by the shadow ring around it.
    icons = ink(rest, 250, 40, 402, 130)
    cy = (icons[1] + icons[3]) / 2
    # White glass on a white page: its edge is where its soft shadow
    # starts. Walk out from the icons until the shadow (< 252) begins.
    def edge(line, start, step):
        i = start
        while 0 <= i < len(line) and line[i] >= 252:
            i += step
        return i
    cxp = int(((icons[0] + icons[2]) / 2) * S)
    cyp = int(cy * S)
    col = rest[:, cxp]
    gap = int((icons[3] - icons[1]) / 2 * S) + 3
    cap_y0 = (edge(col, cyp - gap, -1) + 1) / S
    cap_y1 = edge(col, cyp + gap, 1) / S
    row = rest[cyp]
    cap_x0 = (edge(row, int(icons[0] * S) - 3, -1) + 1) / S
    cap_x1 = edge(row, int(icons[2] * S) + 3, 1) / S
    large = ink(rest, 0, cap_y1 + 4, 300, cap_y1 + 60, thr=80)
    # First list row (44-pt rows, text centred): its ink centre minus 22
    # is where the content starts below the large title.
    row0 = ink(rest, 0, large[3] + 8, 300, large[3] + 60)
    content_top = (row0[1] + row0[3]) / 2 - 22
    # Inline title fade: ink in the bar's centre per scroll offset.
    ys_, mass = [], []
    for p in sorted(d.glob("navbar_*.png"), key=lambda p: int(p.stem.split("_")[1])):
        y = int(p.stem.split("_")[1])
        b = ink(grey(p), 150, cap_y0, 252, cap_y1)
        ys_.append(y)
        mass.append(0 if b is None else b[4])
    full = max(mass) or 1
    frac = [m / full for m in mass]
    start = max([y for y, f in zip(ys_, frac) if f < 0.05], default=0)
    end = min([y for y, f in zip(ys_, frac) if f > 0.95], default=ys_[-1])
    safe_top = 62.0  # iPhone 17 Pro status bar
    bar_height = 2 * (cy - safe_top)
    return {
        "safe_top": safe_top,
        "bar_height": round(bar_height, 2),
        "bar_centre": round(cy, 2),
        "item_width": round((cap_x1 - cap_x0) / 2, 2),
        "large_title_baseline_below_bar": round(large[3] - safe_top - bar_height, 2),
        "large_title_area": round(content_top - safe_top - bar_height, 2),
        "inline_threshold": (start + end) / 2,
        "button": round(cap_y1 - cap_y0, 2),
        "group_width": round(cap_x1 - cap_x0, 2),
        "edge_inset": round(402 - cap_x1, 2),
        "large_title_top": round(large[1], 2),
        "large_title_bottom": round(large[3], 2),
        "large_title_inset": round(large[0], 2),
        "inline_fade_start": start,
        "inline_fade_end": end,
        "inline_fade": [[y, round(f, 3)] for y, f in zip(ys_, frac)],
    }


def main():
    d = pathlib.Path(sys.argv[1])
    out = {"buttons": buttons(grey(d / "buttons.png")), "navbar": navbar(d)}
    dst = pathlib.Path(__file__).with_name("controls.json")
    dst.write_text(json.dumps(out, indent=2) + "\n")
    print(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
