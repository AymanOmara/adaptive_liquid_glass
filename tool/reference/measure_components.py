"""Measures the SwiftUI component reference screenshots (build/reference/)
into the "components" section of tool/reference/controls.json. Usage:
tool/fidelity/.venv/bin/python tool/reference/measure_components.py build/reference [--dry]

Captures (iPhone 17 Pro, iOS 26.4, simulator appearance light), from
example/ios/Runner/ControlScenes.swift (see README.md):
  controls.png            -controls controls
  toolbar.png             -controls toolbar
  accessory.png           -controls accessory
  sheet.png               -controls sheet
  menu.png                -controls menu, after tapping the ellipsis
  search.png              -controls search
  swipe_trailing.png      -controls swipe, row 1 swiped left until open
  swipe_leading.png       -controls swipe, row 1 swiped right until open
  swipetall_trailing.png  -controls swipetall, row 1 swiped left until open

Each value is read along a row or column through a known point of the
scene (pixel runs of one colour class), not by whole-image heuristics.
"""
import json, pathlib, sys
import numpy as np
from PIL import Image

S = 3.0  # px per pt
W, H = 402, 874


def load(d, name):
    return np.asarray(Image.open(d / name).convert("RGB"), dtype=np.int32)


def r(v):
    return round(float(v), 2)


def hexc(c):
    return "#%02X%02X%02X" % tuple(int(v) for v in c)


def at(img, x, y):
    return img[int(y * S), int(x * S)]


def run(img, axis, at_, start, step, pred):
    """From `start` (pt) along a row (axis 'x', at y = at_) or a column
    (axis 'y', at x = at_), moving by `step` px, the pt where `pred` stops
    holding."""
    line = img[int(at_ * S)] if axis == "x" else img[:, int(at_ * S)]
    i = int(start * S)
    while 0 <= i < len(line) and pred(line[i]):
        i += step
    return (i + (1 if step < 0 else 0)) / S


def extent(img, axis, at_, inside, pred):
    """The run of `pred` through `inside` (pt): (start, end)."""
    return run(img, axis, at_, inside, -1, pred), run(img, axis, at_, inside, 1, pred)


def span(img, axis, at_, a, b, pred):
    """First and last pt in [a, b) along a row ('x', at y = at_) or a
    column ('y', at x = at_) where `pred` holds: text inside a shape
    does not cut it short."""
    line = img[int(at_ * S), int(a * S):int(b * S)] if axis == "x" \
        else img[int(a * S):int(b * S), int(at_ * S)]
    idx = np.where(np.asarray(pred(line)))[0]
    return a + idx.min() / S, a + (idx.max() + 1) / S


def ink_box(img, x0, y0, x1, y1, pred):
    c = img[int(y0 * S):int(y1 * S), int(x0 * S):int(x1 * S)]
    m = pred(c)
    ys, xs = np.where(m)
    return (x0 + xs.min() / S, y0 + ys.min() / S,
            x0 + (xs.max() + 1) / S, y0 + (ys.max() + 1) / S)


def near(colour, tol):
    colour = np.array(colour)
    return lambda c: np.abs(np.asarray(c) - colour).max(axis=-1) <= tol


def circle_radius(depth, inset):
    """Radius of a circular corner that is `inset` in from its side at
    `depth` below its top."""
    lo, hi = depth, 200.0
    for _ in range(60):
        mid = (lo + hi) / 2
        got = mid - np.sqrt(max(mid * mid - (mid - depth) ** 2, 0))
        lo, hi = (mid, hi) if got < inset else (lo, mid)
    return lo


def controls(d):
    a = load(d, "controls.png")
    white = lambda c: np.asarray(c).min(axis=-1) >= 250
    not_white = lambda c: np.asarray(c).min(axis=-1) < 250
    green = near((0x34, 0xC7, 0x59), 14)
    # Toggle on (centre 201, 100): the green track, the white thumb in it.
    tx0, tx1 = span(a, "x", 100, 150, 260, not_white)
    ty0, ty1 = span(a, "y", 190, 70, 130, not_white)
    hx0, hx1 = extent(a, "x", 100, 215, lambda c: not green(c))
    hy0, hy1 = extent(a, "y", 215, 100, lambda c: not green(c))
    # Toggle off (centre 201, 200): the thumb sits at the start.
    fx0, fx1 = extent(a, "x", 200, 190, white)
    off = at(a, 225, 200)
    toggle = {
        "width": r(tx1 - tx0), "height": r(ty1 - ty0),
        "thumb_width": r(hx1 - hx0), "thumb_height": r(hy1 - hy0),
        "thumb_inset": r(ty1 - hy1),
        "thumb_off_start": r(fx0 - tx0),
        "on_colour": hexc(at(a, tx0 + 6, 100)), "off_colour": hexc(off),
    }
    # Slider (300 wide at x 51, value 0.5, y 300).
    blue = near((0x00, 0x88, 0xFF), 20)
    fy0, fy1 = extent(a, "y", 100, 300, blue)
    sx0 = run(a, "x", 300, 100, -1, blue)
    sx1 = run(a, "x", 300, 300, 1, not_white)
    # The white thumb on a white page: its edges are where its shadow
    # starts.
    th_x0 = run(a, "x", 300, 150, 1, blue)
    th_x1 = run(a, "x", 300, th_x0 + 2, 1, white)
    th_y0, th_y1 = extent(a, "y", 201, 300, white)
    slider = {
        "track_height": r(fy1 - fy0), "track_x0": r(sx0), "track_x1": r(sx1),
        "thumb_width": r(th_x1 - th_x0), "thumb_height": r(th_y1 - th_y0),
        "fill_colour": hexc(at(a, 100, 300)), "rest_colour": hexc(at(a, 320, 300)),
    }
    # Segmented (300 wide at x 51, y 400): track, thumb on "Week".
    gy0, gy1 = extent(a, "y", 120, 400, not_white)
    my0, my1 = span(a, "y", 180, gy0 + 0.5, gy1 - 0.5, white)
    day = ink_box(a, 55, 388, 148, 414, lambda c: c.max(axis=-1) < 110)
    week = ink_box(a, 156, 388, 248, 414, lambda c: c.max(axis=-1) < 110)
    segmented = {
        "height": r(gy1 - gy0), "thumb_inset": r(my0 - gy0),
        "thumb_height": r(my1 - my0),
        "track_colour": hexc(at(a, 120, 400)), "thumb_colour": hexc(at(a, 160, 400)),
        "dark_track_colour": hexc(at(a, 120, 500)),
        "dark_thumb_colour": hexc(at(a, 165, 500)),
        # "Week" is the k ascender (~0.74 em); "Day" adds the y descender:
        # both read as 13 pt SF Pro.
        "week_ink": r(week[3] - week[1]), "day_ink": r(day[3] - day[1]),
    }
    toggle["dark_off_colour"] = hexc(at(a, 225, 640))
    slider["dark_fill_colour"] = hexc(at(a, 100, 740))
    slider["dark_rest_colour"] = hexc(at(a, 320, 740))
    return {"toggle": toggle, "slider": slider, "segmented": segmented}


def rim(c):
    # Bar glass on a white page has a 1-px white rim inside a soft shadow.
    return np.asarray(c).min(axis=-1) < 255


def glass_edges(a, cx, cy):
    """A glass bar on a white page: its pure-white 1-px rim is the edge.
    Walks out from (cx, cy) to the rim."""
    pure = lambda c: np.asarray(c).min(axis=-1) == 255
    out = []
    for axis, at_, start in (("x", cy, cx), ("y", cx, cy)):
        for step in (-1, 1):
            inner = run(a, axis, at_, start, step, lambda c: not pure(c))
            # The rim (pure white) belongs to the glass: walk across it.
            nxt = inner - 1 / S if step < 0 else inner
            out.append(run(a, axis, at_, nxt, step, pure))
    x0, x1, y0, y1 = out
    return x0, y0, x1, y1


def toolbar(d):
    a = load(d, "toolbar.png")
    lx0, ly0, lx1, ly1 = glass_edges(a, 80, 822)  # the two-item group
    rx0, _, rx1, _ = glass_edges(a, 330, 822)  # the single item
    return {
        "height": r(ly1 - ly0), "bottom_gap": r(H - ly1),
        "edge_inset": r(lx0), "edge_inset_trailing": r(W - rx1),
        "single_width": r(rx1 - rx0), "pair_width": r(lx1 - lx0),
    }


def accessory(d):
    a = load(d, "accessory.png")
    ax0, ay0, ax1, ay1 = glass_edges(a, 300, 760)
    bx0, by0, bx1, by1 = glass_edges(a, 300, 822)
    return {
        "height": r(ay1 - ay0), "inset": r(ax0), "gap": r(by0 - ay1),
        "tab_bar_height": r(by1 - by0), "tab_bar_bottom_gap": r(H - by1),
        "tab_bar_inset": r(bx0),
    }


def sheet(d):
    a = load(d, "sheet.png")
    page = at(a, 201, 200)
    sheet_c = at(a, 201, 600)
    is_sheet = lambda c: np.abs(np.asarray(c) - page).max(axis=-1) > 20
    y0 = run(a, "y", 201, 600, -1, is_sheet)
    y1 = run(a, "y", 201, 600, 1, is_sheet)
    x0 = run(a, "x", 600, 201, -1, is_sheet)
    grab = near(at(a, 201, y0 + 7), 12)
    gx0, gx1 = extent(a, "x", y0 + 7, 201, grab)
    gy0, gy1 = extent(a, "y", 201, y0 + 7, grab)
    corner = run(a, "x", y0 + 1, 201, -1, is_sheet) - x0
    return {
        "inset": r(x0), "bottom_gap": r(H - y1),
        "grabber_width": r(gx1 - gx0), "grabber_height": r(gy1 - gy0),
        "grabber_top": r(gy0 - y0),
        "corner_inset_at_1": r(corner),
        "corner_radius_circle": r(circle_radius(1, corner)),
        # The page is mid-grey (128) before dimming.
        "barrier_alpha": r(1 - float(page.mean()) / 128),
        "colour": hexc(sheet_c),
    }


def menu(d):
    a = load(d, "menu.png")
    light = lambda c: np.asarray(c).mean(axis=-1) > 170
    y0, y1 = extent(a, "y", 300, 150, light)
    x0, x1 = extent(a, "x", 150, 300, light)
    dark = lambda c: c.max(axis=-1) < 140
    red = lambda c: (c[..., 0] > 200) & (c[..., 1] < 90)
    rows = []
    for k in range(3):
        c = y0 + 31 + 42 * k
        rows.append(ink_box(a, x0 + 55, c - 15, x1 - 10, c + 15,
                            lambda c: dark(c) | red(c)))
    share = rows[1]
    icon = ink_box(a, x0 + 20, y0 + 58, x0 + 60, y0 + 88, dark)
    # Label tops (cap or ascender) are steadier than ink centres, which
    # move with descenders.
    pitch = (rows[2][1] - rows[0][1]) / 2
    corner = run(a, "x", y0 + 1, 300, -1, light) - x0
    return {
        "width": r(x1 - x0), "height": r(y1 - y0), "right_inset": r(W - x1),
        "top": r(y0), "row_pitch": r(pitch),
        "padding": r((y1 - y0 - 3 * pitch) / 2),
        "label_start": r(share[0] - x0),
        # "Share": the h ascender, ~0.74 em: 17 pt.
        "label_ink": r(share[3] - share[1]),
        "icon_centre": r((icon[0] + icon[2]) / 2 - x0),
        "corner_inset_at_1": r(corner),
        "corner_radius_circle": r(circle_radius(1, corner)),
        "colour": hexc(at(a, x0 + 30, y1 - 6)),
    }


def search(d):
    a = load(d, "search.png")
    x0, y0, x1, y1 = glass_edges(a, 300, 822)
    icon = ink_box(a, x0 + 4, y0 + 8, x0 + 40, y1 - 8, lambda c: c.max(axis=-1) < 110)
    text = ink_box(a, x0 + 40, y0 + 8, x0 + 200, y1 - 8,
                   lambda c: c.max(axis=-1) < 200)
    return {
        "height": r(y1 - y0), "inset": r(x0), "bottom_gap": r(H - y1),
        "icon_start": r(icon[0] - x0), "icon_height": r(icon[3] - icon[1]),
        "placeholder_start": r(text[0] - x0), "placeholder_ink": r(text[3] - text[1]),
    }


PLATTER = near((0xE5, 0xE5, 0xEA), 6)
BLUE = lambda c: (np.asarray(c)[..., 2] > 200) & (np.asarray(c)[..., 0] < 60)
RED = lambda c: (np.asarray(c)[..., 0] > 220) & (np.asarray(c)[..., 1] < 90)
ORANGE = lambda c: (np.asarray(c)[..., 0] > 220) & (np.asarray(c)[..., 1] > 120) & (np.asarray(c)[..., 1] < 170) & (np.asarray(c)[..., 2] < 80)


def capsule(a, y, x_inside, pred, labels=True):
    """A tinted capsule's horizontal extent at row y, through white text."""
    tint_or_text = lambda c: bool(pred(c)) or (labels and np.asarray(c).min() > 235)
    x0 = run(a, "x", y, x_inside, -1, tint_or_text)
    x1 = run(a, "x", y, x_inside, 1, tint_or_text)
    return x0, x1


def swipe(d):
    out = {}
    # Compact (one-line, 54-pt rows): icon and label inside the capsule.
    a = load(d, "swipe_trailing.png")
    py0, py1 = extent(a, "y", 100, 143, PLATTER)
    p_end = run(a, "x", 143, 100, 1, PLATTER)
    bx0 = run(a, "x", 143, 208, 1, lambda c: not BLUE(c))
    bx1 = run(a, "x", 143, 293, 1, BLUE)
    rx0 = run(a, "x", 143, 300, 1, lambda c: not RED(c))
    rx1 = run(a, "x", 143, 390, 1, RED)
    cy0, cy1 = span(a, "y", 240, 100, 190, BLUE)
    dl = ink_box(a, 336, 131, 385, 155, lambda c: c.min(axis=-1) > 235)
    di = ink_box(a, 312, 131, 334, 155, lambda c: c.min(axis=-1) > 235)
    depth = 9
    p_end_d = run(a, "x", py0 + depth, 100, 1, PLATTER)
    out["compact"] = {
        "row_height": r(py1 - py0), "capsule_height": r(cy1 - cy0),
        "capsule_inset_y": r(cy0 - py0),
        "share_width": r(bx1 - bx0), "delete_width": r(rx1 - rx0),
        "gap_row": r(bx0 - p_end), "gap_between": r(rx0 - bx1),
        "gap_edge": r(W - rx1), "row_offset": r(W - p_end),
        "delete_content": r(dl[2] - di[0]), "icon_label_gap": r(dl[0] - di[2]),
        "label_ink": r(dl[3] - dl[1]), "icon_height": r(di[3] - di[1]),
        "platter_colour": hexc(at(a, 100, 143)),
        "platter_corner_radius_circle": r(circle_radius(depth, p_end - p_end_d)),
    }
    b = load(d, "swipe_leading.png")
    ox0 = run(b, "x", 143, 5, 1, lambda c: not ORANGE(c))
    ox1 = run(b, "x", 143, 70, 1, ORANGE)
    pin = ink_box(b, ox0 + 4, 131, ox1 - 4, 155, lambda c: c.min(axis=-1) > 235)
    p_start = run(b, "x", 143, 95, -1, PLATTER)
    out["compact_leading"] = {
        "pin_width": r(ox1 - ox0), "gap_edge": r(ox0), "gap_row": r(p_start - ox1),
        "pin_padding": r(((ox1 - ox0) - (pin[2] - pin[0])) / 2),
    }
    # Stacked (two-line, ~71-pt rows): icon-only capsule, label below.
    t = load(d, "swipetall_trailing.png")
    py0, py1 = extent(t, "y", 100, 168, PLATTER)
    p_end = run(t, "x", 168, 100, 1, PLATTER)
    p_end_d = run(t, "x", py0 + 4.33, 100, 1, PLATTER)
    rcy0, rcy1 = span(t, "y", 362, 100, 200, RED)
    rx0, rx1 = span(t, "x", 157, 326, 402, RED)
    bx0, bx1 = span(t, "x", 157, 255, 326, BLUE)
    lab = ink_box(t, rx0 - 5, rcy1 + 2, rx1 + 5, rcy1 + 26, lambda c: c.max(axis=-1) < 200)
    out["stacked"] = {
        "row_height": r(py1 - py0), "capsule_width": r(rx1 - rx0),
        "capsule_height": r(rcy1 - rcy0), "capsule_inset_y": r(rcy0 - py0),
        "gap_row": r(bx0 - p_end), "gap_between": r(rx0 - bx1), "gap_edge": r(W - rx1),
        "label_gap": r(lab[1] - rcy1), "label_ink": r(lab[3] - lab[1]),
        "label_colour": hexc(t[int((lab[1] + 5) * S), int((lab[0] + 1) * S):int(lab[2] * S)].min(axis=0)),
        "platter_corner_radius_circle": r(circle_radius(4.33, p_end - p_end_d)),
    }
    return out


def new_components(d):
    """The components added after the first round (alert, dialog,
    popover, stepper, date picker, search tab, large sheet), from the
    captures in d (see capture_components.sh: swiftui/<scene>.png)."""
    out = {}
    grey_page = lambda c: np.abs(np.asarray(c) - 102).max(axis=-1) <= 3

    # Large sheet: top edge, side inset, corner insets one point in.
    a = load(d, "sheetlarge.png")
    top = run(a, "y", 201, 10, 1, lambda c: np.asarray(c).min(axis=-1) < 250)
    out["sheet_large"] = {
        "top": r(top),
        "inset": r(run(a, "x", 400, 1, -1, lambda c: np.asarray(c).min(axis=-1) >= 250)),
        "top_corner_inset_at_1": r(run(a, "x", top + 1, 100, -1, lambda c: np.asarray(c).min(axis=-1) >= 240)),
        "top_radius_circle": r(circle_radius(1, run(a, "x", top + 1, 100, -1, lambda c: np.asarray(c).min(axis=-1) >= 240))),
    }

    # Alert and dialog: the card's rectangle (it is lighter than the page).
    for name, scene in (("alert", "alert.png"), ("dialog", "dialog.png")):
        a = load(d, scene)
        page = at(a, 201, 120)
        card = lambda c, p=page: np.abs(np.asarray(c) - p).max(axis=-1) > 30
        x0, x1 = span(a, "x", 450, 0, W, card)
        y0, y1 = span(a, "y", 120, 250, 650, card)
        out[name] = {"width": r(x1 - x0), "height": r(y1 - y0),
                     "centre_y": r((y0 + y1) / 2),
                     "corner_inset_at_1": r(run(a, "x", y0 + 1, 201, -1, card) - x0),
                     "radius_circle": r(circle_radius(1, run(a, "x", y0 + 1, 201, -1, card) - x0))}
    # Alert buttons: their fill is darker than the card.
    a = load(d, "alert.png")
    btn = lambda c: (np.asarray(c).max(axis=-1) < 200) & (np.asarray(c).max(axis=-1) > 170)
    bx0, bx1 = span(a, "x", 500, 41, 201, btn)
    by0, by1 = span(a, "y", 100, 440, 540, btn)
    out["alert"].update({"button_height": r(by1 - by0), "button_width": r(bx1 - bx0),
                         "button_inset": r(bx0 - 41)})

    # Popover: the bubble by the toolbar button.
    a = load(d, "popover.png")
    page = at(a, 100, 300)
    bub = lambda c, p=page: np.abs(np.asarray(c) - p).max(axis=-1) > 30
    px0, px1 = span(a, "x", 105, 150, W, bub)
    py0, py1 = span(a, "y", 300, 40, 200, bub)
    out["popover"] = {"top": r(py0), "height": r(py1 - py0), "right_inset": r(W - px1)}

    # Stepper and date picker capsules.
    a = load(d, "stepper.png")
    sx0, sx1 = span(a, "x", 100, 100, 300, lambda c: np.asarray(c).max(axis=-1) < 245)
    sy0, sy1 = span(a, "y", 170, 70, 130, lambda c: np.asarray(c).max(axis=-1) < 245)
    out["stepper"] = {"width": r(sx1 - sx0), "height": r(sy1 - sy0),
                      "fill": hexc(at(a, 165, 100)), "dark_fill": hexc(at(a, 165, 200))}
    a = load(d, "datepicker.png")
    dy0, dy1 = span(a, "y", 201, 270, 330, lambda c: np.asarray(c).max(axis=-1) < 245)
    out["date_picker"] = {"height": r(dy1 - dy0), "fill": hexc(at(a, 150, 300))}

    # Search tab: the circle at the bar's right.
    a = load(d, "searchtab.png")
    edge = lambda c: np.asarray(c).min(axis=-1) == 255
    cx1 = run(a, "x", 822, 395, -1, lambda c: not edge(c))
    cx0 = run(a, "x", 822, 352, -1, lambda c: not edge(c))
    out["search_tab"] = {"circle_right_inset": r(W - cx1)}
    return out


def main():
    d = pathlib.Path(sys.argv[1])
    comp = {
        **controls(d),
        "toolbar": toolbar(d),
        "accessory": accessory(d),
        "sheet": sheet(d),
        "menu": menu(d),
        "search": search(d),
        "swipe": swipe(d),
    }
    if (d / "alert.png").exists():
        comp.update(new_components(d))
    print(json.dumps(comp, indent=1))
    if "--dry" in sys.argv:
        return
    dst = pathlib.Path(__file__).with_name("controls.json")
    data = json.loads(dst.read_text())
    data["components"] = comp
    dst.write_text(json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    main()
