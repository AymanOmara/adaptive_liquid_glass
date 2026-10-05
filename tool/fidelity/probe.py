"""1-D sensitivity scans on the NumPy model.

    probe.py <constants.json> <set> <id1,id2,...> key=v1,v2,... [key=...]

Prints SSIM/dE per scene for the base constants and for each value of each
key (one key changed at a time, in <set>).
"""
import copy
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import fit  # noqa: E402


def main():
    base = fit.resolve_constants(json.loads(pathlib.Path(sys.argv[1]).read_text()))
    st, ids = sys.argv[2], sys.argv[3].split(",")
    fit._load(ids)

    def line(c):
        return " ".join(f"{s:.4f}/{d:.2f}" for s, d in
                        (fit.score_one(i, fit.model_constants(c)) for i in ids))
    print("base", line(base))
    for arg in sys.argv[4:]:
        k, vs = arg.split("=")
        for v in vs.split(","):
            c = copy.deepcopy(base)
            fit.put(c, st, k, float(v))
            print(f"{k}={v}", line(c), flush=True)


if __name__ == "__main__":
    main()
