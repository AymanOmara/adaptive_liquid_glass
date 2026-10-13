"""Side-by-side sheets of a tab bar gesture, SwiftUI's TabView against the
package, with 4x zooms of the lens and a per-frame lens-region score.

Usage: tabbar_sheet.py <run-dir> <gesture> <out.png> [--frames 2,4,...]
       [--takes ref,native,shader] [--zoom 4]

<run-dir> is a record_tabbar_motion.sh recording. Frames are aligned on
each take's first changed frame (as tabbar_motion.py). Per frame the sheet
shows the bar (2x, from the 3x dumps) of every take side by side, then the
lens region zoomed: the region is iOS's lens box (tabbar_motion.geometry,
padded 6 pt; once it is gone, its last box), cut at the same place from every take, so a lens that is
placed, sized or lit differently shows as such. Each of our takes is
labelled with the region's SSIM (grey, 7 px window) and mean |diff| (grey
levels) against iOS; the same numbers are printed per frame.
"""
import argparse
import glob

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from skimage.metrics import structural_similarity

import tabbar_motion as tm

PAD = 6 * tm.SCALE


def onset(frames):
    return next(i for i, f in enumerate(frames) if np.abs(f - frames[0]).mean() > tm.ONSET)


def lens_box(frame):
    """iOS's lens box in px (x0, y0, x1, y1), or the bar's middle third."""
    bar, lens = tm.geometry(frame)
    h, w = frame.shape[:2]
    if lens is None:
        return None
    cx, lw, over = (v * tm.SCALE for v in lens)
    top = bar[2] * tm.SCALE - over
    x0, x1 = int(cx - lw / 2 - PAD), int(cx + lw / 2 + PAD)
    y0 = int(max(top - PAD, 0))
    y1 = int(min(h, 2 * tm.MID - top + PAD))
    return max(x0, 0), y0, min(x1, w), y1


def region_scores(a, b):
    ga, gb = a.mean(axis=2), b.mean(axis=2)
    ssim = structural_similarity(ga, gb, data_range=255, win_size=7)
    return ssim, float(np.abs(a - b).mean())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("run")
    ap.add_argument("gesture")
    ap.add_argument("out")
    ap.add_argument("--frames", default="2,4,6,8,10,12,14,20")
    ap.add_argument("--takes", default="ref,native,shader")
    ap.add_argument("--zoom", type=int, default=4)
    ap.add_argument("--zoom-only", action="store_true",
                    help="only the zoomed lens regions, one row per frame")
    a = ap.parse_args()
    takes = a.takes.split(",")
    ks = [int(k) for k in a.frames.split(",")]
    files, frames, onsets = {}, {}, {}
    for t in takes:
        files[t] = sorted(glob.glob(f"{a.run}/{a.gesture}.{t}/*.png"))
        frames[t] = tm.load(f"{a.run}/{a.gesture}.{t}")
        onsets[t] = onset(frames[t])
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 24)
    bw, bh = 804, 228          # the 3x crop at 2x
    zh = 300                   # zoom band height
    label = 30
    names = {"ref": "iOS SwiftUI", "native": "ours native", "shader": "ours shader"}
    rows = []
    last = None
    print(f"{a.gesture}: frame | lens-region SSIM / mean |diff| per take vs iOS")
    for k in ks:
        fr = {t: frames[t][min(onsets[t] + k, len(frames[t]) - 1)] for t in takes}
        box = lens_box(fr["ref"]) or last
        last = box
        top = 0 if a.zoom_only else bh
        row = Image.new("RGB", ((bw + 10) * len(takes), label + top + zh + 10), (60, 60, 60))
        d = ImageDraw.Draw(row)
        cells = []
        for c, t in enumerate(takes):
            x = c * (bw + 10)
            im = Image.open(files[t][min(onsets[t] + k, len(files[t]) - 1)]).convert("RGB")
            if not a.zoom_only:
                row.paste(im.resize((bw, bh), Image.LANCZOS), (x, label))
            text = f"{names.get(t, t)}  frame {k}"
            if box is not None:
                x0, y0, x1, y1 = box
                crop = im.crop(box)
                s = min(bw / crop.width, zh / crop.height, a.zoom)
                z = crop.resize((int(crop.width * s), int(crop.height * s)), Image.NEAREST)
                row.paste(z, (x + (bw - z.width) // 2, label + top + 6))
                if t != "ref":
                    ssim, mad = region_scores(fr["ref"][y0:y1, x0:x1], fr[t][y0:y1, x0:x1])
                    text += f"   lens SSIM {ssim:.3f}  |d| {mad:.1f}"
                    cells.append(f"{t} {ssim:.3f}/{mad:4.1f}")
            d.text((x + 8, 3), text, fill=(255, 230, 120), font=font)
        print(f"  {k:3d}  " + ("  ".join(cells) if cells else "no iOS lens"))
        rows.append(row)
    sheet = Image.new("RGB", (rows[0].width, sum(r.height for r in rows)), (60, 60, 60))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y))
        y += r.height
    sheet.save(a.out)
    print(a.out)


if __name__ == "__main__":
    main()
