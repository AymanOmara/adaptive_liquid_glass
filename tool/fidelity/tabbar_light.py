"""The tab bar's light (brightness over black) frame by frame, SwiftUI's
TabView against the package, averaged over several takes.

Usage: tabbar_light.py <run-dir> [<run-dir> ...] [--gestures press tap drag]
       [--frames 0,2,4,8,12,20,30,40] [--row 55]

Each run dir is a record_tabbar_motion.sh recording (tabbardark). Per
gesture and take (ref, shader), every run is aligned on its first changed
frame, then each frame's row (`--row` px above the bar's middle, clear of
the glyphs) is cut into 31 bins of 30 px; a bin's value is its median, so
glyph strokes do not count. Bins are averaged over the runs. Prints the
averaged ref and shader rows at the chosen frames, their difference, and
per gesture the mean |diff| over the bar for frames 0-10 and 10-60.
"""
import argparse

import numpy as np

import tabbar_motion as tm

X0, X1, BIN = 150, 1080, 30


def rows(run, gesture, take, dy, n=61):
    out, onset = tm.track(f"{run}/{gesture}.{take}")
    frames = tm.load(f"{run}/{gesture}.{take}")
    res = []
    for k in range(n):
        i = min(onset + k, len(frames) - 1)
        row = frames[i].mean(axis=2)[tm.MID - dy]
        res.append([float(np.median(row[x:x + BIN])) for x in range(X0, X1, BIN)])
    return np.array(res)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("runs", nargs="+")
    ap.add_argument("--gestures", nargs="+", default=["press", "tap", "drag"])
    ap.add_argument("--frames", default="0,2,4,8,12,20,30,40")
    ap.add_argument("--row", type=int, default=55)
    a = ap.parse_args()
    ks = [int(k) for k in a.frames.split(",")]
    for g in a.gestures:
        avg = {t: np.mean([rows(r, g, t, a.row) for r in a.runs], axis=0)
               for t in ("ref", "shader")}
        sd = np.mean([np.std([rows(r, g, "ref", a.row) for r in a.runs], axis=0)])
        d = avg["shader"] - avg["ref"]
        print(f"== {g}: {len(a.runs)} runs; ref run-to-run sd {sd:.1f}")
        for k in ks:
            for t in ("ref", "shader"):
                print(f"  {t:6s}{k:3d} " + " ".join(f"{v:3.0f}" for v in avg[t][k]))
            print(f"  {'diff':6s}{k:3d} " + " ".join(f"{v:+3.0f}" for v in d[k]))
        inside = slice(2, 28)  # the bar, not its ends
        print(f"  mean |diff| frames 0-10: {np.abs(d[:11, inside]).mean():.1f}, "
              f"10-60: {np.abs(d[10:, inside]).mean():.1f}; "
              f"mean diff 0-10: {d[:11, inside].mean():+.1f}, "
              f"10-60: {d[10:, inside].mean():+.1f}")


if __name__ == "__main__":
    main()
