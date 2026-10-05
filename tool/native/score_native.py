"""Scores native-mode captures against SwiftUI references.

Usage: score_native.py <run-dir> <ref-dir> [label] [prefix]

Pairs <run-dir>/<id>.<label>.png with <ref-dir>/<id>.swiftui.png and scores
each scene's glass region with compare.score (imported read-only). Writes
<run-dir>/native-report.json and prints a per-family summary. Parity is
SSIM >= 0.999 and mean dE <= 0.2.
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool/fidelity"))
import compare  # noqa: E402

SSIM_PARITY = 0.999
DE_PARITY = 0.2


def family(sid):
    variant, _, rest = sid.partition("-")
    if variant in ("merge", "morph"):
        return variant
    return f"{variant} {rest.rsplit('-', 1)[-1]}"


def main():
    run = pathlib.Path(sys.argv[1])
    ref = pathlib.Path(sys.argv[2])
    label = sys.argv[3] if len(sys.argv) > 3 else "native"
    prefix = sys.argv[4] if len(sys.argv) > 4 else ""
    spec = compare.load_spec()
    rows, missing = [], []
    for scene in spec["scenes"]:
        sid = scene["id"]
        if not sid.startswith(prefix):
            continue
        a, b = run / f"{sid}.{label}.png", ref / f"{sid}.swiftui.png"
        if not (a.exists() and b.exists()):
            missing.append(sid)
            continue
        ia, ib = compare.load(a), compare.load(b)
        h, w = ia.shape[:2]
        scale = w / 402
        x0, y0, x1, y1 = compare.region_for(scene, scale, w, h)
        s = compare.score(ia[y0:y1, x0:x1], ib[y0:y1, x0:x1])
        whole = float(abs(ia - ib).max() * 255)
        s.update(id=sid, family=family(sid), full_frame_max=whole,
                 parity=s["ssim"] >= SSIM_PARITY and s["delta_e"] <= DE_PARITY)
        rows.append(s)
        print(f"{sid:40s} ssim {s['ssim']:.5f}  dE {s['delta_e']:.4f}  "
              f"dEmax {s['de_max']:.2f}  frame max {whole:.0f}"
              f"{'' if s['parity'] else '  <-- not at parity'}")
    fams = {}
    for r in rows:
        fams.setdefault(r["family"], []).append(r)
    print()
    print(f"{'family':16s} n  parity  min SSIM  max dE  max dEmax")
    for f, rs in sorted(fams.items()):
        print(f"{f:16s} {len(rs):2d} {sum(r['parity'] for r in rs):3d}     "
              f"{min(r['ssim'] for r in rs):.5f}  {max(r['delta_e'] for r in rs):.4f}"
              f"  {max(r['de_max'] for r in rs):.2f}")
    if rows:
        print(f"\nall: {sum(r['parity'] for r in rows)}/{len(rows)} at parity, "
              f"min SSIM {min(r['ssim'] for r in rows):.5f}, "
              f"max dE {max(r['delta_e'] for r in rows):.4f}, missing {len(missing)}")
    (run / f"{label}-report.json").write_text(
        json.dumps({"rows": rows, "missing": missing}, indent=1))
    return 0 if rows and all(r["parity"] for r in rows) and not missing else 1


if __name__ == "__main__":
    sys.exit(main())
