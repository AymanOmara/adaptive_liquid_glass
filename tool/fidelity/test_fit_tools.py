"""Smoke tests for the grid/parity/probe fitting tools.

Synthetic everywhere: a two-scene spec, tiny numpy backdrops and a fake
score pool — no real 75-scene run, no simulator, no build/ captures.
"""
import json
import pathlib
import sys
from types import SimpleNamespace

import numpy as np
import pytest
from PIL import Image

import fit
import grid
import parity
import probe

HERE = pathlib.Path(__file__).resolve().parent
CONSTANTS = HERE / "standard_constants.json"

SHAPES = [{"x": 5, "y": 5, "w": 20, "h": 15, "shape": "rect",
           "radius": 0, "variant": "regular"}]


def _spec(*ids):
    return {"device": {"width": 90, "height": 70, "scale": 3},
            "scenes": [{"id": i, "background": "bg", "brightness": "light",
                        "shapes": SHAPES} for i in ids]}


SPEC = _spec("clear-a", "clear-b")
PARITY_SPEC = _spec("p1", "p2")


def _png(path, seed, size=(90, 70)):
    rng = np.random.default_rng(seed)
    Image.fromarray((rng.random((*size, 3)) * 255).astype(np.uint8)).save(path)


# --- grid.py: the best grid point is the largest min SSIM ---------------------

class FakePool:
    """Scores keyed by the scanned value: v=0.1 has the larger min, v=0.2 the
    larger mean (0.999/0.96 -> mean 0.9795 vs 0.98/0.975 -> 0.9775)."""

    SCORES = {0.1: (0.98, 0.975), 0.2: (0.999, 0.96)}

    def __init__(self, scene_ids, procs):
        pass

    def scores(self, constants):
        s1, s2 = self.SCORES[constants["clearDark"]["dim"]]
        return [("clear-a", s1, 0.5), ("clear-b", s2, 0.5)]

    def close(self):
        pass


def test_grid_picks_largest_min_and_counts_passes(tmp_path, monkeypatch, capsys):
    monkeypatch.setattr(fit, "SPEC", SPEC)
    monkeypatch.setattr(fit, "Pool", FakePool)
    monkeypatch.setattr(sys, "argv",
                        ["grid.py", str(CONSTANTS), "clearDark", "clear", "dim=0.1,0.2"])
    grid.main()
    out = capsys.readouterr().out
    assert "dim=0.1 min 0.9750 (clear-b) mean 0.9775 pass 2" in out
    assert "dim=0.2 min 0.9600 (clear-b) mean 0.9795 pass 1" in out
    # 0.2 wins on mean but loses on min: the tool must take 0.1.
    assert out.rstrip().endswith("best (0.975, (0.1,))")


# --- parity.py: model-vs-flutter, flutter-vs-swiftui, skips without flutter ---

def _parity_dirs(tmp_path):
    (tmp_path / "example/assets/backgrounds").mkdir(parents=True)
    yy, xx = np.mgrid[0:70, 0:90] / 90.0
    Image.fromarray(
        (np.stack([xx, yy, 1 - xx], -1) * 255).astype(np.uint8)).save(
        tmp_path / "example/assets/backgrounds/bg.png")
    run = tmp_path / "run"
    run.mkdir()
    for sid, seed in (("p1", 1), ("p2", 2)):
        _png(run / f"{sid}.flutter.png", seed, size=(70, 90))
        _png(run / f"{sid}.swiftui.png", seed, size=(70, 90))  # identical: perfect device score
    (run / "p2.flutter.png").unlink()  # p2 has no Flutter capture
    return run


def test_one_scores_model_vs_flutter_and_flutter_vs_swiftui(tmp_path, monkeypatch):
    run = _parity_dirs(tmp_path)
    spec_path = tmp_path / "spec.json"
    spec_path.write_text(json.dumps(PARITY_SPEC))
    monkeypatch.setattr(parity, "ROOT", tmp_path)
    parity._A.update(spec=json.loads(spec_path.read_text()), run=run,
                     ref=tmp_path / "unused", constants=json.loads(CONSTANTS.read_text()))
    sid, p_ssim, p_de, f_ssim, f_de, m_ssim, m_de = parity.one("p1")
    assert sid == "p1"
    assert 0.0 <= p_ssim <= 1.0 and p_de >= 0.0  # model vs Flutter
    assert f_ssim == pytest.approx(1.0)  # Flutter vs SwiftUI: identical PNGs
    assert f_de == pytest.approx(0.0, abs=1e-6)
    assert 0.0 <= m_ssim <= 1.0 and m_de >= 0.0  # model vs SwiftUI


class _SerialPool:
    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def map(self, fn, ids):
        return [fn(i) for i in ids]


def test_missing_flutter_capture_is_skipped(tmp_path, monkeypatch, capsys):
    run = _parity_dirs(tmp_path)
    spec_path = tmp_path / "spec.json"
    spec_path.write_text(json.dumps(PARITY_SPEC))
    monkeypatch.setattr(parity, "ROOT", tmp_path)  # backgrounds live under tmp
    monkeypatch.setattr(parity, "mp", SimpleNamespace(  # keep the test in-process
        get_context=lambda name: SimpleNamespace(Pool=lambda n: _SerialPool())))
    monkeypatch.setattr(sys, "argv",
                        ["parity.py", str(run), "--scenes", str(spec_path),
                         "--ref-dir", str(tmp_path / "unused"), "--procs", "1"])
    parity.main()
    out = capsys.readouterr().out
    assert "p1" in out
    assert "p2" not in out
    assert "device: pass 1/1" in out


# --- fit.get/put: the g13 small-shape tone keys -------------------------------

def test_fit_get_put_supports_g13_small_tone_keys():
    c = fit.resolve_constants(json.loads(CONSTANTS.read_text()))
    # clear still ships the keys off (absent from the file -> defaults);
    # regular ships the g13 curve, so its defaults are checked after an
    # explicit reset rather than against the identity.
    assert fit.get(c, "clear", "stone4") == pytest.approx(0.5)  # identity
    assert fit.get(c, "clear", "smallSizeLo") == 0.0
    assert fit.get(c, "clear", "smallSizeHi") == 0.0
    fit.put(c, "regular", "stone4", 0.61)
    fit.put(c, "regular", "smallSizeHi", 34.0)
    assert fit.get(c, "regular", "stone4") == pytest.approx(0.61)
    assert c["regular"]["smallToneKnots"][4] == pytest.approx(0.61)
    assert fit.get(c, "regular", "smallSizeHi") == pytest.approx(34.0)
    for k in ("stone0", "stone8", "smallSizeLo", "smallSizeHi"):
        assert k in fit.KEYS
    assert fit.BOUNDS["stone0"] == (0, 1)
    assert fit.BOUNDS["smallSizeLo"] == (0, 60)


# --- probe.py: one key scan, and unknown keys error clearly -------------------

def _fake_score_one(sid, constants):
    return (1.0 - abs(constants["clearDark"]["dim"] - 0.3) * 0.1, 0.5)


def test_scan_prints_base_then_one_row_per_value(tmp_path, monkeypatch, capsys):
    monkeypatch.setattr(fit, "_load", lambda ids: None)
    monkeypatch.setattr(fit, "score_one", _fake_score_one)
    monkeypatch.setattr(sys, "argv",
                        ["probe.py", str(CONSTANTS), "clearDark", "clear-a,clear-b",
                         "dim=0.2,0.3,0.4"])
    probe.main()
    lines = capsys.readouterr().out.splitlines()
    assert lines[0].startswith("base ") and lines[0].count("/") == 2
    assert [line.split()[0] for line in lines[1:]] == ["dim=0.2", "dim=0.3", "dim=0.4"]
    # The stub peaks at dim=0.3: the middle row must score highest on both scenes.
    assert lines[2].split(maxsplit=1)[1] > lines[1].split(maxsplit=1)[1]
    assert lines[2].split(maxsplit=1)[1] > lines[3].split(maxsplit=1)[1]


def test_unknown_key_exits_naming_the_key(tmp_path, monkeypatch):
    monkeypatch.setattr(fit, "_load", lambda ids: None)
    monkeypatch.setattr(fit, "score_one", _fake_score_one)
    monkeypatch.setattr(sys, "argv",
                        ["probe.py", str(CONSTANTS), "clearDark", "clear-a", "bogus=0.1"])
    with pytest.raises(SystemExit, match="bogus"):
        probe.main()
