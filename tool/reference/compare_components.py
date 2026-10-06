"""Scores this package's components against SwiftUI, per component, on
both glass paths. Usage (after tool/reference/capture_components.sh and the
interactive captures listed in README.md):

  tool/fidelity/.venv/bin/python tool/reference/compare_components.py build/reference

Each component is cropped from the SwiftUI capture (swiftui/) and the
Flutter twin's (native/, shader/) at the same screen rectangle, and scored
with the fidelity harness's measures: SSIM and mean CIEDE2000. "pass" uses
the harness's bars (SSIM >= 0.97, mean dE <= 2.0). Writes
component_scores.json and component_pairs.png next to the captures.
"""
import json, pathlib, sys
import numpy as np
from PIL import Image
from skimage.color import deltaE_ciede2000, rgb2lab
from skimage.metrics import structural_similarity

S = 3
SSIM_MIN, DE_MAX = 0.97, 2.0

# name: (capture, left, top, right, bottom) in points.
CROPS = {
    "toggle on": ("controls", 160, 78, 242, 122),
    "toggle off": ("controls", 160, 178, 242, 222),
    "slider": ("controls", 44, 278, 358, 322),
    "segmented (light)": ("controls", 44, 378, 358, 422),
    "segmented (dark)": ("controls", 44, 478, 358, 522),
    "toggle off (dark)": ("controls", 160, 618, 242, 662),
    "slider (dark)": ("controls", 44, 718, 358, 762),
    "toolbar": ("toolbar", 0, 780, 402, 866),
    "accessory + tab bar": ("accessory", 0, 720, 402, 874),
    "sheet": ("sheet", 0, 400, 402, 874),
    "search field": ("search", 22, 792, 380, 852),
    "menu": ("menu", 120, 50, 402, 220),
    "swipe actions": ("swipe_trailing", 0, 110, 402, 176),
}


def load(d, name):
    return np.asarray(Image.open(d / f"{name}.png").convert("RGB"), dtype=np.float64) / 255


def crop(a, box):
    l, t, r, b = (int(v * S) for v in box)
    return a[t:b, l:r]


def score(a, b):
    ssim = structural_similarity(a, b, channel_axis=2, data_range=1.0)
    de = float(deltaE_ciede2000(rgb2lab(a), rgb2lab(b)).mean())
    return {"ssim": round(float(ssim), 4), "delta_e": round(de, 2),
            "pass": bool(ssim >= SSIM_MIN and de <= DE_MAX)}


def main():
    root = pathlib.Path(sys.argv[1])
    out, rows = {}, []
    for name, (cap, *box) in CROPS.items():
        ref_path = root / "swiftui" / f"{cap}.png"
        if not ref_path.exists():
            continue
        ref = crop(load(root / "swiftui", cap), box)
        entry, row = {}, [ref]
        for mode in ("native", "shader"):
            p = root / mode / f"{cap}.png"
            if not p.exists():
                continue
            got = crop(load(root / mode, cap), box)
            entry[mode] = score(ref, got)
            row.append(got)
        out[name] = entry
        rows.append(row)
    (root / "component_scores.json").write_text(json.dumps(out, indent=1) + "\n")
    # Side by side: SwiftUI | native | shader, one component per row.
    w = max(r[0].shape[1] for r in rows)
    h = sum(r[0].shape[0] + 6 for r in rows)
    sheet = np.ones((h, 3 * w + 12, 3))
    y = 0
    for r in rows:
        for i, img in enumerate(r):
            sheet[y:y + img.shape[0], i * (w + 6):i * (w + 6) + img.shape[1]] = img
        y += r[0].shape[0] + 6
    Image.fromarray((sheet * 255).astype(np.uint8)).save(root / "component_pairs.png")
    fmt = "{:<22} {:>8} {:>6} {:>5}   {:>8} {:>6} {:>5}"
    print(fmt.format("component", "native", "dE", "", "shader", "dE", ""))
    for name, e in out.items():
        n, s = e.get("native", {}), e.get("shader", {})
        print(fmt.format(name, n.get("ssim", "-"), n.get("delta_e", "-"),
                         "pass" if n.get("pass") else "fail",
                         s.get("ssim", "-"), s.get("delta_e", "-"),
                         "pass" if s.get("pass") else "fail"))
    for mode in ("native", "shader"):
        got = [e[mode] for e in out.values() if mode in e]
        if got:
            print(f"{mode}: {sum(g['pass'] for g in got)}/{len(got)} pass, "
                  f"median SSIM {np.median([g['ssim'] for g in got]):.4f}, "
                  f"median dE {np.median([g['delta_e'] for g in got]):.2f}")


if __name__ == "__main__":
    main()
