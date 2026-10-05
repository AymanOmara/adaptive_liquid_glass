"""Model vs Flutter parity and both vs SwiftUI, per scene, for a capture run.

    parity.py <run-dir> [--constants C.json] [--scenes S.json] [--prefix P]
              [--ref-dir D]

For every scene with a `<id>.flutter.png` in the run dir: renders the NumPy
model with the constants (default standard_constants.json, i.e. what the
shipped Dart build draws) and scores, in compare.py's region,
model vs Flutter (parity: bar SSIM >= 0.99, dE <= 1.0), Flutter vs SwiftUI
(the device result) and model vs SwiftUI. SwiftUI references come from the
run dir, else from --ref-dir (default build/fidelity/final; SwiftUI is
deterministic, so references can be reused across runs).
Prints a table sorted by device SSIM and a summary line.
"""
import argparse
import json
import multiprocessing as mp
import pathlib
import sys

import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
from compare import load, region_for, score  # noqa: E402
from glass_model import render  # noqa: E402

_A = {}


def one(sid):
    a = _A
    sc = next(s for s in a["spec"]["scenes"] if s["id"] == sid)
    bg = load(ROOT / f"example/assets/backgrounds/{sc['background']}.png")
    fl = load(a["run"] / f"{sid}.flutter.png")
    ref = a["run"] / f"{sid}.swiftui.png"
    sw = load(ref if ref.exists() else a["ref"] / f"{sid}.swiftui.png")
    m = render(bg, sc, a["constants"], scale=3)
    x0, y0, x1, y1 = region_for(sc, 3, bg.shape[1], bg.shape[0])
    r = lambda img: img[y0:y1, x0:x1]  # noqa: E731
    p, f, mm = score(r(m), r(fl)), score(r(fl), r(sw)), score(r(m), r(sw))
    return sid, p["ssim"], p["delta_e"], f["ssim"], f["delta_e"], mm["ssim"], mm["delta_e"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("run_dir", type=pathlib.Path)
    ap.add_argument("--constants", type=pathlib.Path, default=HERE / "standard_constants.json")
    ap.add_argument("--scenes", type=pathlib.Path, default=ROOT / "tool/scenes/scenes.json")
    ap.add_argument("--prefix", default="")
    ap.add_argument("--ref-dir", type=pathlib.Path, default=ROOT / "build/fidelity/final")
    ap.add_argument("--procs", type=int, default=5)
    args = ap.parse_args()
    _A.update(spec=json.loads(args.scenes.read_text()), run=args.run_dir, ref=args.ref_dir,
              constants=json.loads(args.constants.read_text()))
    ids = [s["id"] for s in _A["spec"]["scenes"] if s["id"].startswith(args.prefix)
           and (args.run_dir / f"{s['id']}.flutter.png").exists()]
    if not ids:
        sys.exit("parity.py: no Flutter captures match")
    with mp.get_context("fork").Pool(args.procs) as pool:
        rows = sorted(pool.map(one, ids), key=lambda r: r[3])
    print(f"{'scene':40s} parSSIM parDE | devSSIM devDE | modSSIM modDE")
    for r in rows:
        flag = "" if (r[1] >= 0.99 and r[2] <= 1.0) else "  PARITY-FAIL"
        print(f"{r[0]:40s} {r[1]:.4f} {r[2]:5.2f} | {r[3]:.4f} {r[4]:5.2f} | "
              f"{r[5]:.4f} {r[6]:5.2f}{flag}")
    dev = [r[3] for r in rows]
    print(f"device: pass {sum(1 for r in rows if r[3] >= 0.97 and r[4] <= 2.0)}/{len(rows)} "
          f"min {min(dev):.4f} below95 {sum(1 for x in dev if x < 0.95)} "
          f"median {np.median(dev):.4f}/{np.median([r[4] for r in rows]):.2f}; "
          f"parity min {min(r[1] for r in rows):.4f} maxDE {max(r[2] for r in rows):.2f}")


if __name__ == "__main__":
    main()
