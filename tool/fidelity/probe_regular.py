"""Guard regular-colour candidates against all saved scenes they affect.

Reports model scores and residual-based device predictions separately.
No simulator operations or production constants edits are performed.
"""
import argparse
import copy
import json
import pathlib

from probe_clear import evaluate  # also caps numerical worker thread pools
import fit
from glass_model import resolve_constants
from compare import SSIM_MIN, DELTA_E_MAX


def apply_regular(base, patch):
    out = copy.deepcopy(base)
    for name, values in patch.items():
        if name in ("_isolateSmallColour", "_ambientBeforeTint"):
            if not isinstance(values, bool):
                raise ValueError(f"{name} requires a boolean")
            out[name] = values
            continue
        if name not in ("regular", "regularDark") or not isinstance(values, dict):
            raise ValueError("Only regular/regularDark variant patches are accepted")
        unknown = set(values) - set(base[name])
        if unknown:
            raise ValueError(f"Unknown {name} fields: {sorted(unknown)}")
        out[name].update(values)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--reference", required=True, type=pathlib.Path)
    ap.add_argument("--candidates", required=True, type=pathlib.Path)
    ap.add_argument("--out", required=True, type=pathlib.Path)
    ap.add_argument("--workers", type=int, choices=(1, 2), default=1)
    ap.add_argument("--brightness", choices=("light", "dark", "both"), default="light")
    args = ap.parse_args()
    captured = {r["id"]: r for r in json.loads((args.reference / "report.json").read_text())["scenes"]}
    scenes = [s for s in fit.SPEC["scenes"]
              if s["id"].startswith(("regular-", "tinted-", "merge-"))
              and (args.brightness == "both" or s["brightness"] == args.brightness)]
    ids = [s["id"] for s in scenes]
    candidates = json.loads(args.candidates.read_text())
    names = [name for name, _ in candidates]
    if "baseline" in names or len(names) != len(set(names)):
        ap.error("Candidate names must be unique; baseline is automatic")
    base = resolve_constants({})
    for _, patch in candidates:
        apply_regular(base, patch)
        for name in patch:
            if name.startswith("_"):
                continue
            brightness = "dark" if name == "regularDark" else "light"
            if args.brightness not in (brightness, "both"):
                ap.error(f"{name} changes require its affected scenes to be scored")
    for sid in ids:
        if sid not in captured or not (args.reference / f"{sid}.swiftui.png").is_file():
            ap.error(f"Missing reference {sid}")
    fit.REF = args.reference.resolve()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    pool = fit.Pool(ids, args.workers)
    report = {"kind": "regular_model_experiment", "device_certified": False,
              "reference": str(fit.REF), "scored": len(ids), "brightness": args.brightness,
              "thresholds": {"ssim_min": SSIM_MIN, "delta_e_max": DELTA_E_MAX},
              "candidates": {},
              "warning": "Predictions need fresh device validation; saved residuals can change."}
    try:
        baseline_rows = pool.scores(base)
        baseline = {sid: (s, d) for sid, s, d in baseline_rows}
        for name, patch in [("baseline", {})] + candidates:
            rows = baseline_rows if name == "baseline" else pool.scores(apply_regular(base, patch))
            result = evaluate(rows, baseline, captured)
            result["patch"] = patch
            result["predicted_overall_passed"] = sum(r["pass"] for sid, r in captured.items()
                                                    if sid not in ids) + result["predicted_device_passed"]
            report["candidates"][name] = result
            args.out.write_text(json.dumps(report, indent=2) + "\n")
            print(f"{name}: predicted {result['predicted_device_passed']}/{len(ids)}, "
                  f"overall {result['predicted_overall_passed']}/{len(captured)}, "
                  f"safe gains {result['safe_gains']}, lost passes {result['lost_passes']}", flush=True)
    finally:
        pool.close()


if __name__ == "__main__":
    main()
