"""Max-min grid search of constants on the NumPy model.

    grid.py <constants.json> <set> <stage> key=v1,v2,... [key=...]

Scores every combination over fit.py's scenes for <stage> (e.g. clear,
clearDark, polishRegularDark) with <set>'s keys changed, and prints the min
SSIM (and its scene), mean SSIM and pass count; the best is the largest min.
Use it where Powell stalls: the clear lens band mirrors text lines, so SSIM
is a phase match with sharp, narrow optima (Task 17d round 4).
"""
import copy
import itertools
import json
import pathlib
import sys

import numpy as np

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import fit  # noqa: E402


def main():
    c0 = fit.resolve_constants(json.loads(pathlib.Path(sys.argv[1]).read_text()))
    st = sys.argv[2]
    ids = [s["id"] for s in fit.scenes_for(sys.argv[3])]
    axes = [(a.split("=")[0], [float(v) for v in a.split("=")[1].split(",")])
            for a in sys.argv[4:]]
    pool = fit.Pool(ids, 4)
    best = None
    try:
        for vals in itertools.product(*[v for _, v in axes]):
            c = copy.deepcopy(c0)
            for (k, _), v in zip(axes, vals):
                fit.put(c, st, k, v)
            rows = pool.scores(fit.model_constants(c))
            s = [r[1] for r in rows]
            worst = min(rows, key=lambda r: r[1])
            npass = sum(1 for r in rows if r[1] >= .97 and r[2] <= 2)
            print(" ".join(f"{k}={v}" for (k, _), v in zip(axes, vals)),
                  f"min {min(s):.4f} ({worst[0]}) mean {np.mean(s):.4f} pass {npass}", flush=True)
            if best is None or min(s) > best[0]:
                best = (min(s), vals)
    finally:
        pool.close()
    print("best", best)


if __name__ == "__main__":
    main()
