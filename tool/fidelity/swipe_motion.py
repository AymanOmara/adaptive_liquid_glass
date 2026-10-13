"""Frame-by-frame list swipe actions, SwiftUI `.swipeActions` against the
package's GlassSwipeActions (recordings from record_swipe_motion.sh).

Usage: swipe_motion.py <run-dir> [scene.gesture ...] [--every N] [--json out]

Per frame (60 fps; frame 0 = the first frame the row moved):
  off     the row content's x offset (pt; edge-map match against the rest
          frame, the row's own area only), and the platter's trailing (or
          leading) edge as a check;
  platter colour (hex), vertical extent and corner radius (circle fit of
          the trailing corner);
  actions each tinted component beyond the row: box (x0, x1, y0, y1 pt,
          y from the row's top), shape (circle when |w - h| < 1.5 pt),
          fill hex and its strength against the take's strongest (an
          opacity proxy), the white ink (icon) inside it and the label
          ink outside it (box and colour).
Summary per take: when the first action appears (offset), how its size
and strength grow with the offset (scale / fade / uncover), the resting
open geometry, the full-swipe stretch, the rubber band (row speed against
the finger's) and SwiftUI-spring fits of the settle after release.
"""
import argparse
import glob
import json
import math
import pathlib

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.optimize import minimize

S = 3
W = 402.0
TOP = 14.0          # the row's top inside the crop (record_swipe_motion.sh)
EDGE = 12           # grey step that counts as an edge for the offset match
GESTURE_S = {"slow": 2.0, "open": 0.3, "leading": 0.3, "full": 0.2, "close": 0.0}
FINGER = {"slow": 260 / 2.0, "open": 120 / 0.3, "leading": 120 / 0.3, "full": 345 / 0.2}


def load(d):
    return [np.asarray(Image.open(f).convert("RGB")).astype(np.int16)
            for f in sorted(glob.glob(f"{d}/*.png"))]


def hexc(c):
    return "#%02X%02X%02X" % tuple(int(round(v)) for v in c)


class Take:
    def __init__(self, d, row_h, ref_last=False):
        self.fr = load(d)
        self.ref_last = ref_last
        self.h = row_h
        f0 = self.fr[0]
        self.bg = np.median(f0[2:8, 2:40].reshape(-1, 3), axis=0)
        self.dark = self.bg.mean() < 128
        y0, y1 = int((TOP + 2) * S), int((TOP + row_h - 2) * S)
        self.band = slice(y0, y1, 2)
        # The rest frame: the first, or the last for a take that starts open.
        self.e0 = self.edges(self.fr[-1] if ref_last else f0)

    def edges(self, f):
        g = f[self.band].mean(axis=2)
        return np.abs(np.diff(g, axis=1)) > EDGE

    def match(self, e, s):
        """Mismatch of frame edges e against the rest frame shifted by s px."""
        n = e.shape[1]
        m = 6
        if s <= 0:
            a, b = 0, n + s - m
        else:
            a, b = s + m, n
        if b - a < 60:
            return 1.0, 0
        ek = e[:, a:b]
        er = self.e0[:, a - s:b - s]
        union = np.logical_or(ek, er).sum()
        if union < 40:
            return 1.0, int(union)
        return float(np.logical_xor(ek, er).sum() / union), int(union)

    def offset(self, f, prev, wide=False):
        e = self.edges(f)
        p = int(round(prev * S))
        best = (2.0, 0, p)
        for s in (range(-1100, 1101, 3) if wide else range(p - 150, p + 151, 3)):
            sc, u = self.match(e, s)
            if sc < best[0]:
                best = (sc, u, s)
        for s in range(best[2] - 3, best[2] + 4):
            sc, u = self.match(e, s)
            if sc < best[0]:
                best = (sc, u, s)
        if best[0] > 0.55:
            return None, best[0]
        return best[2] / S, best[0]

    def platter(self, f, off):
        """Colour, vertical extent, edge x and corner radius of the swiped
        row's platter (None while it does not differ from the page)."""
        lead = off > 0
        xs = (off + 200) if lead else (W - 30 + off)
        if not (2 < xs < W - 2):
            return None
        x = int(xs * S)
        y = int((TOP + 5) * S)
        c = f[y - 2:y + 3, x - 2:x + 3].reshape(-1, 3).mean(axis=0)
        if np.abs(c - self.bg).max() < 4:
            return None
        close = lambda p: np.abs(p - c).max(axis=-1) <= 6
        col = close(f[:, x])
        ys = np.where(col)[0]
        if len(ys) == 0:
            return None
        # The run through the row's top.
        lab, _ = ndimage.label(col)
        k = lab[y]
        if k == 0:
            return None
        run = np.where(lab == k)[0]
        top, bot = run[0], run[-1] + 1
        # Edge on rows below the top; the row's middle sets the straight side.

        def edge_at(yy):
            r = close(f[yy])
            if lead:
                i = x
                while i > 0 and r[i - 1]:
                    i -= 1
                return i
            i = x
            while i + 1 < r.shape[0] and r[i + 1]:
                i += 1
            return i + 1
        mid = edge_at(int((top + bot) / 2))
        pts = []
        for dy in range(1, 60):
            yy = top + dy
            if yy >= bot:
                break
            e = edge_at(yy)
            ins = (e - mid) if lead else (mid - e)
            pts.append((dy / S, ins / S))
        rad = None
        good = [(d, i) for d, i in pts if i > 0.3]
        if len(good) >= 3:
            def err(r):
                r = r[0]
                m = [r - math.sqrt(max(r * r - (r - d) ** 2, 0)) if d < r else 0 for d, _ in pts]
                return sum((a - b[1]) ** 2 for a, b in zip(m, pts))
            rad = float(minimize(err, [20.0], method="Nelder-Mead").x[0])
        edge = mid / S
        return {"colour": hexc(c), "top": top / S - TOP, "bottom": bot / S - TOP,
                "edge": edge, "radius": rad}

    def actions(self, f, off):
        """Tinted components outside the row."""
        g = f
        sat = (g.max(axis=2) - g.min(axis=2) > 50) & (g.max(axis=2) > 70)
        xx = np.arange(g.shape[1]) / S
        if off < 0:
            allowed = xx > W + off + 0.5
        elif off > 0:
            allowed = xx < off - 0.5
        else:
            return []
        sat &= allowed[None, :]
        lab, n = ndimage.label(sat)
        out = []
        for i, sl in enumerate(ndimage.find_objects(lab)):
            m = lab[sl] == i + 1
            if m.sum() < 15:
                continue
            ys, xs = sl
            x0, x1, y0, y1 = xs.start / S, xs.stop / S, ys.start / S - TOP, ys.stop / S - TOP
            px = g[sl][m]
            sat_px = px[(px.max(axis=1) - px.min(axis=1)) > 80]
            fill = np.median(sat_px if len(sat_px) else px, axis=0)
            strength = float(np.abs(fill - self.bg).sum())
            # White ink inside the component's box (icon, compact label).
            box = g[sl]
            white = (box.min(axis=2) > 190) & ~m
            wy, wx = np.where(white)
            icon = None
            if len(wx) > 3:
                icon = ((xs.start + wx.min()) / S, (xs.start + wx.max() + 1) / S,
                        (ys.start + wy.min()) / S - TOP, (ys.start + wy.max() + 1) / S - TOP)
            # Label ink below it, within 45 pt of its centre, outside the row.
            cx = (x0 + x1) / 2
            lx0, lx1 = int(max(0, cx - 45) * S), int(min(W, cx + 45) * S)
            ly0 = ys.stop + 1
            sub = g[ly0:, lx0:lx1]
            ink = (np.abs(sub - self.bg).max(axis=2) > 40) & (sub.max(axis=2) - sub.min(axis=2) < 40)
            ink &= allowed[None, lx0:lx1]
            label = None
            ly, lxx = np.where(ink)
            if len(lxx) > 6:
                lab2, n2 = ndimage.label(ndimage.binary_dilation(ink, iterations=3))
                sizes = ndimage.sum(ink, lab2, range(1, n2 + 1))
                k = int(np.argmax(sizes)) + 1
                ly, lxx = np.where(ink & (lab2 == k))
                vals = sub[ly, lxx]
                d = np.abs(vals - self.bg).sum(axis=1)
                colour = vals[d >= np.percentile(d, 90)].mean(axis=0)
                label = ((lx0 + lxx.min()) / S, (lx0 + lxx.max() + 1) / S,
                         (ly0 + ly.min()) / S - TOP, (ly0 + ly.max() + 1) / S - TOP, hexc(colour))
            w, h = x1 - x0, y1 - y0
            out.append({"x0": x0, "x1": x1, "y0": y0, "y1": y1, "w": w, "h": h,
                        "cx": cx, "cy": (y0 + y1) / 2,
                        "shape": "circle" if abs(w - h) < 1.5 else "capsule",
                        "fill": hexc(fill), "strength": strength, "icon": icon, "label": label})
        # Drop pieces inside another component's box (icon strokes).
        out = [a for a in out if not any(
            b is not a and b["w"] * b["h"] > a["w"] * a["h"] and b["x0"] <= a["x0"] + 0.5
            and a["x1"] <= b["x1"] + 0.5 and b["y0"] <= a["y0"] + 0.5 and a["y1"] <= b["y1"] + 0.5
            for b in out)]
        return sorted(out, key=lambda a: a["x0"])

    def platter_edge(self, f, sign):
        """The platter's trailing (sign < 0) or leading edge on the row's
        middle line: the end of the run of grey (unsaturated, off-page)
        pixels from the screen edge, gaps under 2 pt bridged."""
        y = int((TOP + self.h / 2) * S)
        line = f[y - 1:y + 2].mean(axis=0)
        grey = (np.abs(line - self.bg).max(axis=1) > 3) & (line.max(axis=1) - line.min(axis=1) < 14)
        sat = line.max(axis=1) - line.min(axis=1) > 50
        if sign > 0:
            grey, sat = grey[::-1], sat[::-1]
        if not grey[:6].any():
            return None
        i, gap = 0, 0
        last = 0
        while i < len(grey) and not sat[i]:
            if grey[i]:
                last, gap = i, 0
            else:
                gap += 1
                if gap > 6:
                    break
            i += 1
        e = (last + 1) / S
        return e if sign < 0 else W - e

    def track(self):
        rows, prev = [], 0.0
        for k, f in enumerate(self.fr):
            off, sc = self.offset(f, prev, wide=self.ref_last and k == 0)
            if off is not None:
                prev = off
            use = off if off is not None else prev
            if (off is None or sc > 0.3 or (self.ref_last and k == 0)) and (abs(use or 0) > 0.5 or self.ref_last):
                # Row content gone or weak: the platter's edge carries the offset.
                if self.ref_last and k == 0:
                    e = self.platter_edge(f, -1)
                    use = -1 if e is not None else 1
                    if e is None:
                        e = self.platter_edge(f, 1)
                else:
                    e = self.platter_edge(f, use)
                if e is not None:
                    use = (e - W) if use < 0 else e
                    prev = use
                    off = None
            p = self.platter(f, use) if abs(use) > 0.2 else None
            acts = self.actions(f, use) if abs(use) > 0.5 else []
            rows.append({"off": off, "off_any": use, "score": sc, "platter": p, "actions": acts})
        mx = max([a["strength"] for r in rows for a in r["actions"]] or [1])
        for r in rows:
            for a in r["actions"]:
                a["alpha"] = a["strength"] / mx
        return rows


def spring_free(t, d, v0, response, zeta):
    """Displacement from target of a spring released at d with velocity v0."""
    w0 = 2 * np.pi / response
    t = np.asarray(t, float)
    if zeta < 0.999:
        wd = w0 * math.sqrt(1 - zeta ** 2)
        return np.exp(-zeta * w0 * t) * (d * np.cos(wd * t) + (v0 + zeta * w0 * d) / wd * np.sin(wd * t))
    if zeta < 1.001:
        return np.exp(-w0 * t) * (d + (v0 + w0 * d) * t)
    s = math.sqrt(zeta ** 2 - 1)
    r1, r2 = -w0 * (zeta - s), -w0 * (zeta + s)
    a = (v0 - r2 * d) / (r1 - r2)
    return a * np.exp(r1 * t) + (d - a) * np.exp(r2 * t)


def fit_spring(ts, xs, target):
    """(response, damping, v0 pt/s, rms) for samples (frames) settling on target."""
    ts = (np.asarray(ts, float) - ts[0]) / 60
    xs = np.asarray(xs, float) - target
    d = xs[0]

    def err(p):
        r, z, v = p
        if r < 0.05 or r > 2 or z < 0.1 or z > 2:
            return 1e9
        return float(np.sqrt(np.mean((spring_free(ts, d, v, r, z) - xs) ** 2)))
    v_est = (xs[1] - xs[0]) * 60 if len(xs) > 1 else 0
    best = min((minimize(err, [r, z, v], method="Nelder-Mead")
                for r in (0.25, 0.4, 0.6) for z in (0.7, 0.9, 1.0) for v in (0, v_est)),
               key=lambda q: q.fun)
    return (*best.x, best.fun)


def onset(rows, eps=0.7):
    base = rows[0]["off_any"]
    return next((i for i, r in enumerate(rows) if abs(r["off_any"] - base) > eps), None)


def fmt_row(r):
    o = r["off_any"]
    s = f"{o:7.1f}{'' if r['off'] is not None else '*'}"
    p = r["platter"]
    s += f" {p['colour']} r{p['radius'] or 0:4.1f} y{p['top']:4.1f}-{p['bottom']:5.1f}" if p else " " * 27
    for a in r["actions"][:2]:
        lab = a["label"]
        s += (f" | {a['shape'][:3]} {a['w']:5.1f}x{a['h']:4.1f} c{a['cx']:5.1f},{a['cy']:4.1f}"
              f" a{a['alpha']:.2f} {a['fill']}")
        if lab:
            s += f" L{(lab[0] + lab[1]) / 2:5.1f},{lab[2]:4.1f} w{lab[1] - lab[0]:4.1f} {lab[4]}"
    return s


def summary(name, g, rows):
    u = onset(rows)
    out = {"onset_frame": u}
    if u is None:
        return out
    offs = [r["off_any"] for r in rows]
    # First action appearance.
    first = next((i for i, r in enumerate(rows) if r["actions"]), None)
    if first is not None:
        a = rows[first]["actions"]
        out["first_action"] = {"frame": first - u, "offset": round(offs[first], 2),
                               "w": round(a[0]["w"], 2), "h": round(a[0]["h"], 2),
                               "alpha": round(a[0]["alpha"], 2)}
    # Growth: the outermost action's size / alpha / label width against |offset|.
    grow = []
    for i, r in enumerate(rows):
        if r["actions"]:
            a = r["actions"][-1] if offs[i] < 0 else r["actions"][0]
            lab = a["label"]
            grow.append((round(abs(offs[i]), 1), round(a["w"], 1), round(a["h"], 1),
                         round(a["cx"], 1), round(a["cy"], 1), round(a["alpha"], 2),
                         round(lab[1] - lab[0], 1) if lab else None, a["shape"],
                         round(a["icon"][1] - a["icon"][0], 1) if a["icon"] else None))
    out["growth"] = grow
    # Rest: the last frame.
    last = rows[-1]
    out["rest"] = {"offset": round(offs[-1], 2), "platter": last["platter"],
                   "actions": last["actions"]}
    # Settle after release.
    if g in GESTURE_S:
        rel = u + max(1, round(GESTURE_S[g] * 60) - (2 if g != "close" else 0))
        if g == "close":
            rel = u - 1
        tgt = float(np.median(offs[-8:]))
        seg = [(i, offs[i]) for i in range(rel, len(rows))]
        if len(seg) > 8 and abs(seg[0][1] - tgt) > 2:
            r_, z_, v_, e_ = fit_spring(*zip(*seg), tgt)
            out["settle"] = {"from": round(seg[0][1], 1), "to": round(tgt, 1),
                             "response": round(r_, 3), "damping": round(z_, 3),
                             "v0": round(v_, 0), "rms": round(e_, 2)}
        # Settle time to within 0.5 pt.
        st = next((i for i in range(len(rows) - 1, rel, -1) if abs(offs[i] - tgt) > 0.5), None)
        if st is not None:
            out["settle_frames"] = st + 1 - rel
    # Rubber band / gain: the row's speed over the finger's.
    if g in FINGER:
        fpf = FINGER[g] / 60
        gain = []
        end = u + round(GESTURE_S[g] * 60) - 3
        for i in range(u + 1, min(end, len(rows) - 1)):
            gain.append((round(abs(offs[i]), 1), round(abs(offs[i + 1] - offs[i - 1]) / 2 / fpf, 2)))
        out["gain"] = gain
    out["max_offset"] = round(max(offs, key=abs), 1)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("run")
    ap.add_argument("items", nargs="*")
    ap.add_argument("--every", type=int, default=3)
    ap.add_argument("--takes", default="ref,shader")
    ap.add_argument("--json")
    ap.add_argument("--table", action="store_true", help="print the per-frame table")
    a = ap.parse_args()
    run = pathlib.Path(a.run)
    crops = json.load(open(run / "crop.json"))
    items = a.items or sorted(crops)
    takes = a.takes.split(",")
    dump = {}
    for it in items:
        g = it.split(".")[1]
        h = crops[it]["row_h"]
        res = {}
        for t in takes:
            p = run / f"{it}.{t}"
            if p.exists():
                res[t] = Take(p, h, ref_last=(g == "close")).track()
        print(f"== {it} (offset pt, * = from the platter | platter | action: shape w x h, centre, alpha, label centre/top/width/colour)")
        us = {t: onset(rows) or 0 for t, rows in res.items()}
        n = max(len(rows) - us[t] for t, rows in res.items())
        for k in (range(-2, n, a.every) if a.table else []):
            for t, rows in res.items():
                i = us[t] + k
                if 0 <= i < len(rows):
                    print(f"{k:4d} {t[:3]} {fmt_row(rows[i])}")
        dump[it] = {}
        for t, rows in res.items():
            s = summary(it, g, rows)
            dump[it][t] = {"summary": s, "frames": rows}
            print(f"  {t}: onset {s.get('onset_frame')}, max offset {s.get('max_offset')}, "
                  f"first action {s.get('first_action')}")
            if "settle" in s:
                print(f"    settle {s['settle']} ({s.get('settle_frames')} frames to 0.5 pt)")
    if a.json:
        json.dump(dump, open(a.json, "w"), default=float)


if __name__ == "__main__":
    main()
