"""Measure UIKit indicator geometry and fade from a ViewDump trace.

Usage: python3 tool/reference/measure_indicator_trace.py path/to/indicator-trace
Times are seconds from scene launch. Fade timing uses presentation opacity
and the last dragging/decelerating sample as its baseline.
"""

import argparse
import json
import math
from pathlib import Path
import re


def fields(text):
    return {key: float(value) for key, value in re.findall(
        r"(\w+)=(-?(?:\d+(?:\.\d*)?|\.\d+)|nan)", text)}


def measure(path):
    samples = []
    rejected = 0
    for line_number, line in enumerate(path.read_text().splitlines(), 1):
        if not line.strip():
            continue
        parts = line.split(" | ")
        try:
            time = float(parts[0].split()[0])
            scroll = fields(parts[0])
            if not math.isfinite(time) or not {"oy", "dragging", "decelerating"} <= scroll.keys():
                raise ValueError("Missing scroll sample")
            if not math.isfinite(scroll["oy"]):
                scroll["oy"] = None
            bars = []
            for part in parts[1:]:
                name = part.split()[0]
                values = fields(part)
                if (re.search(r"scroll.*indicator", name, re.IGNORECASE)
                        and {"x", "y", "w", "h", "op", "a", "hid"} <= values.keys()
                        and all(math.isfinite(value) for value in values.values())):
                    bars.append({"class": name, **values})
            samples.append({"line": line_number, "t": time, **scroll, "bars": bars})
        except (ValueError, IndexError):
            rejected += 1

    result = {"source": str(path), "sample_count": len(samples),
              "rejected_lines": rejected, "baseline": None,
              "geometry": None, "fade": None}
    if not samples:
        return {**result, "status": "empty_trace"}
    if any(right["t"] <= left["t"] for left, right in zip(samples, samples[1:])):
        return {**result, "status": "nonmonotonic_timestamps"}

    # Select the vertical indicator, excluding horizontal and zero-size bars.
    for sample in samples:
        vertical = [bar for bar in sample["bars"] if bar["h"] > bar["w"] > 0]
        sample["indicator"] = max(vertical, key=lambda bar: bar["h"], default=None)

    def diagnostic(sample):
        return {key: sample[key] for key in
                ("line", "t", "oy", "dragging", "decelerating", "indicator")}

    visible = [sample for sample in samples if sample["indicator"] is not None
               and sample["indicator"]["op"] > 0.001
               and not sample["indicator"]["hid"]]
    if not visible:
        return {**result, "status": "no_visible_vertical_indicator",
                "observed_classes": sorted({bar["class"] for sample in samples
                                            for bar in sample["bars"]})}
    active = [index for index, sample in enumerate(samples)
              if sample["dragging"] or sample["decelerating"]]
    geometry_samples = [sample for sample in visible
                        if sample["dragging"] or sample["decelerating"]] or visible
    result["geometry"] = {
        "units": "points", "sample_count": len(geometry_samples),
        "ranges": {key: [min(sample["indicator"][key] for sample in geometry_samples),
                         max(sample["indicator"][key] for sample in geometry_samples)]
                   for key in ("x", "y", "w", "h")},
        "first_visible": diagnostic(visible[0]),
        "last_visible": diagnostic(visible[-1]),
    }
    if not active:
        return {**result, "status": "no_drag_or_deceleration_baseline"}
    baseline_index = active[-1]
    baseline = samples[baseline_index]
    result["baseline"] = {"last_active": diagnostic(baseline),
                          "first_idle": diagnostic(samples[baseline_index + 1])
                          if baseline_index + 1 < len(samples) else None}
    after = [sample for sample in samples[baseline_index:]
             if sample["indicator"] is not None]
    if not after:
        return {**result, "status": "indicator_missing_after_baseline"}
    peak = max(sample["indicator"]["op"] for sample in after)
    if peak <= 0.001:
        return {**result, "status": "indicator_invisible_after_baseline"}
    peak_index = next(index for index, sample in enumerate(after)
                      if sample["indicator"]["op"] == peak)
    descending_index = next((index for index in range(peak_index + 1, len(after))
                             if after[index]["indicator"]["op"] < peak - 0.001), None)
    if descending_index is None:
        return {**result, "status": "fade_not_observed", "peak_opacity": peak}
    previous = after[descending_index - 1]
    onset = after[descending_index]
    end = next((sample for sample in after[descending_index:]
                if sample["indicator"]["op"] <= 0.001), None)
    last_positive = after[after.index(end) - 1] if end else None
    result["fade"] = {
        "peak_opacity": peak,
        "opacity_zero_threshold": 0.001,
        "hold_seconds_bounds": [round(previous["t"] - baseline["t"], 4),
                                round(onset["t"] - baseline["t"], 4)],
        "last_full_opacity": diagnostic(previous),
        "first_fading": diagnostic(onset),
        "last_positive_opacity": diagnostic(last_positive) if last_positive else None,
        "first_zero_opacity": diagnostic(end) if end else None,
        "duration_seconds_bounds": [round(last_positive["t"] - onset["t"], 4),
                                    round(end["t"] - previous["t"], 4)] if end else None,
        "samples": [diagnostic(sample) for sample in after[descending_index - 1:]
                    if end is None or sample["t"] <= end["t"]],
    }
    return {**result, "status": "complete" if end else "fade_end_not_observed"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace", type=Path)
    args = parser.parse_args()
    try:
        report = measure(args.trace)
    except OSError as error:
        parser.error(str(error))
    print(json.dumps(report, indent=2, allow_nan=False))
