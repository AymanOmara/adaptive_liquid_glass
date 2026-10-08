"""Compare clear-glass model candidates without changing shipped constants.

This is an experiment, not a device certification. Reports keep raw model
scores separate from predictions using the saved device/model residual.
Run `probe_clear.py --help` for the required reference capture directory.
"""
import argparse
import copy
import json
import math
import os
import pathlib

# Each experiment already owns a process worker. Avoid multiplying those
# workers by a full BLAS thread pool; preserve explicit user settings.
for _name in ("OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "VECLIB_MAXIMUM_THREADS"):
    os.environ.setdefault(_name, "1")

import fit
from compare import DELTA_E_MAX, SSIM_MIN
from glass_model import resolve_constants


def passes(ssim, delta_e):
    return ssim >= SSIM_MIN and delta_e <= DELTA_E_MAX


def evaluate(rows, baseline, captured, ssim_margin=0.001, de_margin=0.03):
    """Predict changes, preserving raw scores and the official thresholds."""
    result = []
    for sid, ssim, delta_e in rows:
        bs, bd = baseline[sid]
        device = captured[sid]
        ps = ssim + device["ssim"] - bs
        pd = max(0.0, delta_e + device["delta_e"] - bd)
        result.append({
            "id": sid, "model_ssim": ssim, "model_delta_e": delta_e,
            "model_pass": passes(ssim, delta_e),
            "predicted_device_ssim": ps, "predicted_device_delta_e": pd,
            "predicted_device_pass": passes(ps, pd),
            "captured_device_pass": device["pass"],
            "safe_gain": not device["pass"] and passes(ps - ssim_margin, pd + de_margin),
            "lost_pass": device["pass"] and not passes(ps, pd),
        })
    gains = sum(r["safe_gain"] for r in result)
    losses = sum(r["lost_pass"] for r in result)
    return {
        "model_passed": sum(r["model_pass"] for r in result),
        "predicted_device_passed": sum(r["predicted_device_pass"] for r in result),
        "safe_gains": gains, "lost_passes": losses,
        "predicted_min_ssim": min(r["predicted_device_ssim"] for r in result),
        "worth_device_validation": gains > 0 and losses == 0 and
            all(r["predicted_device_ssim"] >= 0.95 for r in result),
        "scenes": result,
    }


def apply_candidate(base, patch):
    """Both applies to clear variants; a named set applies to that set only."""
    out = copy.deepcopy(base)
    for name, values in patch.items():
        if name == "both":
            out["clear"].update(values)
            out["clearDark"].update(values)
        elif name in ("clear", "clearDark"):
            out[name].update(values)
        elif name in ("_postIsotropic", "_postSecondOrder", "_frostDepthMix",
                      "_wideGH", "_wideExact", "_lensZone", "_lensDepthField", "_wideAspectPower", "_postGH", "_capsuleLensExponent", "_curvedLensCorrection"):
            if name in ("_postSecondOrder", "_wideExact", "_lensDepthField"):
                if not isinstance(values, bool):
                    raise ValueError(f"{name} requires a boolean")
            elif name in ("_wideGH", "_postGH"):
                choices = (0, 3, 5, 7) if name == "_wideGH" else (3, 5, 7)
                if type(values) is not int or values not in choices:
                    raise ValueError(f"{name} requires one of {choices}")
            elif not isinstance(values, (int, float)) or not math.isfinite(values):
                raise ValueError(f"{name} requires a finite number")
            elif name in ("_postIsotropic", "_frostDepthMix") and not 0 <= values <= 1:
                raise ValueError(f"{name} must be between 0 and 1")
            elif name == "_lensZone" and not 1 <= values <= 3:
                raise ValueError("_lensZone must be between 1 and 3")
            elif name == "_wideAspectPower" and not -1 <= values <= 1:
                raise ValueError("_wideAspectPower must be between -1 and 1")
            elif name == "_capsuleLensExponent" and not 1.5 <= values <= 3:
                raise ValueError("_capsuleLensExponent must be between 1.5 and 3")
            elif name == "_curvedLensCorrection" and not -1 <= values <= 1.5:
                raise ValueError("_curvedLensCorrection must be between -1 and 1.5")
            out[name] = values
        else:
            raise ValueError(f"Unsupported candidate key: {name}")
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--reference", type=pathlib.Path, required=True,
                    help="Saved shipped-build captures, including report.json and SwiftUI PNGs")
    ap.add_argument("--candidates", type=pathlib.Path, required=True,
                    help='JSON list of [name, patch] pairs; baseline is automatic')
    ap.add_argument("--out", type=pathlib.Path, required=True)
    ap.add_argument("--workers", type=int, choices=(1, 2), default=1)
    ap.add_argument("--text-only", action="store_true", help="Screen candidates; never a full acceptance run")
    args = ap.parse_args()
    report = json.loads((args.reference / "report.json").read_text())
    captured = {s["id"]: s for s in report["scenes"]}
    scenes = [s for s in fit.SPEC["scenes"] if s["id"].startswith("clear-")
              and (not args.text_only or "-text-" in s["id"])]
    ids = [s["id"] for s in scenes]
    if not ids:
        ap.error("No clear scenes selected")
    for sid in ids:
        if sid not in captured or not (args.reference / f"{sid}.swiftui.png").is_file():
            ap.error(f"Missing reference scene: {sid}")
    candidates = json.loads(args.candidates.read_text())
    names = [name for name, _ in candidates]
    if len(names) != len(set(names)) or "baseline" in names:
        ap.error("Candidate names must be unique; baseline is automatic")
    base = resolve_constants({})
    # Reject invalid experiments before starting any expensive workers.
    for _, patch in candidates:
        apply_candidate(base, patch)
    # The forked workers inherit this path; no simulator or capture is used.
    fit.REF = args.reference.resolve()
    pool = fit.Pool(ids, args.workers)
    output = {
        "kind": "model_experiment", "device_certified": False,
        "reference": str(fit.REF), "scored": len(ids),
        "full_clear_matrix": not args.text_only,
        "thresholds": {"ssim_min": SSIM_MIN, "delta_e_max": DELTA_E_MAX},
        "prediction_warning": "Saved residuals may change with rendering changes; fresh captures are required.",
        "candidates": {},
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    try:
        baseline_rows = pool.scores(base)
        baseline = {sid: (s, d) for sid, s, d in baseline_rows}
        for name, patch in [("baseline", {})] + candidates:
            rows = baseline_rows if name == "baseline" else pool.scores(apply_candidate(base, patch))
            item = evaluate(rows, baseline, captured)
            item["patch"] = patch
            item["shader_implementation_required"] = any(k.startswith("_") for k in patch)
            item["eligible_for_full_validation"] = item["worth_device_validation"] and not args.text_only
            output["candidates"][name] = item
            print(f"{name}: model {item['model_passed']}/{len(ids)}, predicted device "
                  f"{item['predicted_device_passed']}/{len(ids)}, safe gains {item['safe_gains']}, "
                  f"lost passes {item['lost_passes']}", flush=True)
            args.out.write_text(json.dumps(output, indent=2) + "\n")
    finally:
        pool.close()


if __name__ == "__main__":
    main()
