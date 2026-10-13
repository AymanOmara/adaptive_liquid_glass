"""The tab lens's interior fill, every frame of a gesture: SwiftUI's TabView
against the package (record_tabbar_motion.sh recordings, black page).

Usage: tabbar_fill.py <out-dir> <gesture> <run-dir> [<run-dir> ...]
       [--takes ref,native,shader] [--frames 70]

Per take and frame (aligned on the first changed frame, as
tabbar_motion.py), each take's own lens (tabbar_motion.geometry) is masked:
inset 4 pt from its outline, glyph pixels removed (saturated or brighter
than 90), and split into the part over the bar ("bar") and the part above
it ("over", the overhang on the black page). Records mean RGB and the grey
std of each; frames without a lens are left empty. Runs are averaged per
frame. Writes <gesture>.csv and <gesture>.png (grey mean over time per take
and part, drawn with PIL) to <out-dir>, and prints per take the max and mean per-frame
|RGB error| against iOS (largest channel) for each part.
"""
import argparse
import csv
import pathlib

import numpy as np

import tabbar_motion as tm

INSET = 4 * tm.SCALE


def onset(frames):
    return next(i for i, f in enumerate(frames) if np.abs(f - frames[0]).mean() > tm.ONSET)


def fill(frame):
    """{'bar': (rgb, std), 'over': (rgb, std)} of the lens interior."""
    bar, lens = tm.geometry(frame)
    if lens is None or lens[1] < 30:
        return None
    h, w = frame.shape[:2]
    cx, lw, over = (v * tm.SCALE for v in lens)
    top = bar[2] * tm.SCALE - over
    bot = 2 * tm.MID - top
    yy, xx = np.mgrid[0:h, 0:w]
    # A capsule inset by INSET.
    r = (bot - top) / 2 - INSET
    half = lw / 2 - INSET
    cy = (top + bot) / 2
    dx = np.maximum(np.abs(xx - cx) - (half - r), 0)
    inside = dx ** 2 + (yy - cy) ** 2 <= r ** 2
    f = frame.astype(float)
    sat = f.max(axis=2) - f.min(axis=2)
    plain = (sat < 25) & (f.mean(axis=2) < 90)
    bar_top = bar[2] * tm.SCALE
    out = {}
    for name, m in (("bar", inside & plain & (yy >= bar_top + 2 * tm.SCALE) & (yy <= 2 * tm.MID - bar_top - 2 * tm.SCALE)),
                    ("over", inside & plain & (yy < bar_top - 1 * tm.SCALE))):
        if m.sum() < 30:
            out[name] = None
            continue
        px = f[m]
        out[name] = (px.mean(axis=0), float(px.mean(axis=1).std()))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("gesture")
    ap.add_argument("runs", nargs="+")
    ap.add_argument("--takes", default="ref,native,shader")
    ap.add_argument("--frames", type=int, default=70)
    a = ap.parse_args()
    takes = a.takes.split(",")
    n = a.frames
    # data[take][part][k] = list of (rgb, std) over runs
    data = {t: {p: [[] for _ in range(n)] for p in ("bar", "over")} for t in takes}
    for run in a.runs:
        for t in takes:
            frames = tm.load(f"{run}/{a.gesture}.{t}")
            if not frames:
                continue
            u = onset(frames)
            for k in range(n):
                if u + k >= len(frames):
                    break
                res = fill(frames[u + k])
                if res is None:
                    continue
                for p in ("bar", "over"):
                    if res[p] is not None:
                        data[t][p][k].append(res[p])
    out = pathlib.Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    mean = {t: {p: [None] * n for p in ("bar", "over")} for t in takes}
    with open(out / f"{a.gesture}.csv", "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["frame", "take", "part", "r", "g", "b", "grey_std", "runs"])
        for t in takes:
            for p in ("bar", "over"):
                for k in range(n):
                    v = data[t][p][k]
                    if not v:
                        continue
                    rgb = np.mean([x[0] for x in v], axis=0)
                    sd = float(np.mean([x[1] for x in v]))
                    mean[t][p][k] = rgb
                    w.writerow([k, t, p, *(f"{c:.1f}" for c in rgb), f"{sd:.1f}", len(v)])
    print(f"{a.gesture}: lens fill vs iOS, per-frame |RGB error| (largest channel), frames where both show a lens")
    for t in takes:
        if t == "ref":
            continue
        for p in ("bar", "over"):
            errs = [(k, float(np.abs(mean[t][p][k] - mean["ref"][p][k]).max()))
                    for k in range(n) if mean[t][p][k] is not None and mean["ref"][p][k] is not None]
            if errs:
                e = np.array([x[1] for x in errs])
                kmax = errs[int(e.argmax())][0]
                print(f"  {t:6s} {p:4s}: max {e.max():5.1f} (frame {kmax}), mean {e.mean():4.1f}, frames {len(e)}")
    chart(out / f"{a.gesture}.png", a.gesture, takes, mean, n)


def chart(path, gesture, takes, mean, n):
    """Grey mean per frame, one panel per part (PIL, no plotting library)."""
    from PIL import Image, ImageDraw, ImageFont
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 14)
    pw, ph, m = 520, 260, 40
    im = Image.new("RGB", (pw * 2, ph + 30), "white")
    d = ImageDraw.Draw(im)
    colors = {"ref": (30, 30, 30), "native": (217, 130, 43), "shader": (43, 123, 217)}
    for c, p in enumerate(("bar", "over")):
        x0 = c * pw
        vals = [mean[t][p][k].mean() for t in takes for k in range(n) if mean[t][p][k] is not None]
        lo, hi = (0, 60) if not vals else (0, max(60, max(vals) + 5))
        d.text((x0 + m, 4), f"{gesture}: lens fill over the {'bar' if p == 'bar' else 'page (overhang)'} (grey)", fill="black", font=font)
        d.rectangle([x0 + m, 24, x0 + pw - 10, ph - 10], outline=(180, 180, 180))
        for gy in range(0, int(hi) + 1, 10):
            y = ph - 10 - (gy - lo) / (hi - lo) * (ph - 34)
            d.text((x0 + 8, y - 7), str(gy), fill=(120, 120, 120), font=font)
        for t in takes:
            pts = [(x0 + m + k / max(n - 1, 1) * (pw - m - 10), ph - 10 - (mean[t][p][k].mean() - lo) / (hi - lo) * (ph - 34))
                   for k in range(n) if mean[t][p][k] is not None]
            if len(pts) > 1:
                d.line(pts, fill=colors.get(t, (0, 0, 0)), width=2)
            for q in pts:
                d.ellipse([q[0] - 2, q[1] - 2, q[0] + 2, q[1] + 2], fill=colors.get(t, (0, 0, 0)))
        d.text((x0 + m, ph + 6), f"frame 0..{n - 1}", fill="black", font=font)
    for i, t in enumerate(takes):
        d.text((pw * 2 - 260 + i * 80, ph + 6), t, fill=colors.get(t, (0, 0, 0)), font=font)
    im.save(path)

if __name__ == "__main__":
    main()
