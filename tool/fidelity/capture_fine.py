"""Capture independent native fine-detail probes on an explicitly named simulator.

Uses separate measurement assets; never updates official fidelity captures.
"""
import argparse
import json
import pathlib
import shutil
import subprocess
import time

from PIL import Image
import numpy as np


def run(*args, required=True):
    p = subprocess.run(["xcrun", "simctl", *args], capture_output=True,
                       text=True, timeout=45)
    if required and p.returncode:
        raise RuntimeError(p.stderr.strip())
    return p


def validate_frame(path, background):
    """Reject home/startup/error frames using unobstructed backdrop pixels."""
    with Image.open(path) as image, Image.open(background) as expected:
        if image.size != (1206, 2622) or expected.size != image.size:
            raise RuntimeError("Unexpected capture size")
        box = (60, 2400, 1140, 2450)
        actual = np.asarray(image.convert("RGB").crop(box), dtype=float)
        target = np.asarray(expected.convert("RGB").crop(box), dtype=float)
        if np.mean(np.abs(actual - target)) > 8:
            raise RuntimeError("Native backdrop mismatch: startup screen or missing assets")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--udid", required=True)
    ap.add_argument("--assets", type=pathlib.Path, required=True)
    ap.add_argument("--out", type=pathlib.Path, required=True)
    ap.add_argument("--bundle", default="com.aymanomara.adaptiveLiquidGlassExample",
                    choices=("com.aymanomara.adaptiveLiquidGlassExample",
                             "com.codex.fidelityFineProbe"))
    args = ap.parse_args()
    devices = json.loads(run("list", "devices", "--json").stdout)["devices"]
    found = [(runtime, d) for runtime, ds in devices.items() for d in ds
             if d["udid"] == args.udid]
    if len(found) != 1:
        raise ValueError("Simulator not found")
    runtime, device = found[0]
    if not (runtime.endswith("iOS-26-4") and device["state"] == "Booted"
            and device["name"] == "iPhone 17 Pro (Codex Fidelity)"):
        raise ValueError("Only the dedicated iOS 26.4 Codex simulator is allowed")
    spec = json.loads((args.assets / "fine.json").read_text())
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "manifest.json").write_text(json.dumps({
        "kind": "independent_native_measurement", "device_certified": False,
        "udid": args.udid, "runtime": runtime, "bundle": args.bundle,
        "spec": spec}, indent=2))
    bundle = args.bundle
    for index, scene in enumerate(spec["scenes"]):
        path = args.out / f"{scene['id']}.swiftui.png"
        if path.exists():
            continue
        if shutil.disk_usage(args.out).free < 20_000_000_000:
            raise RuntimeError("Capture stopped: less than 20 GB free")
        run("terminate", args.udid, bundle, required=False)
        run("launch", args.udid, bundle, "-scene", scene["id"],
            "-renderer", "swiftui", "-sceneFile", "assets/fine.json")
        time.sleep(2.5)
        run("io", args.udid, "screenshot", str(path))
        try:
            validate_frame(path, args.assets / "backgrounds" / f"{scene['background']}.png")
        except RuntimeError:
            path.unlink()
            raise
        print(f"Captured {index + 1}/{len(spec['scenes'])}: {scene['id']}", flush=True)


if __name__ == "__main__":
    main()
