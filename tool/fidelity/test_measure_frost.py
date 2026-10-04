"""Frost transfer function and tone decoders (Task 17c)."""
import pathlib
import sys

import numpy as np
from scipy.ndimage import gaussian_filter1d

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool/scenes"))

import gen_backgrounds as gb  # noqa: E402
import measure_frost as mf  # noqa: E402

H, W = 40, 480


def _codes(period, h=H, w=W):
    return [np.asarray(gb.code("x", period, k, w, h), np.float64) / 255.0 for k in range(4)]


def test_frost_codes_are_x_only_short_periods_and_flats_are_uniform():
    assert {p for _, p, _ in gb.FROST_CODES.values()} == {32, 48, 80}
    assert {a for a, _, _ in gb.FROST_CODES.values()} == {"x"}
    assert len(gb.FROST_CODES) == 12
    assert 0 in gb.FLAT_LEVELS and 255 in gb.FLAT_LEVELS and len(gb.FLATS) == 16
    img = np.asarray(gb.flat(26, 8, 4))
    assert img.shape == (4, 8, 3) and np.all(img == 26)


def test_modulation_recovers_gain_times_gaussian_mtf():
    # Glass: blur (sigma 9 px along x), then out = 0.3 * in + 0.6 per channel.
    sigma, gain, off = 9.0, 0.3, 0.6
    px = np.mgrid[0:H, 0:W][1] + 0.5
    for period in (32, 48, 80, 128):
        imgs = [gain * gaussian_filter1d(i, sigma, axis=1, mode="wrap") + off
                for i in _codes(period)]
        amp, mean = mf.modulation(imgs, period, px)
        inner = amp[:, 60:-60, 1]
        expect = gain * gb.CODE_AMP * np.exp(-0.5 * (2 * np.pi * sigma / period) ** 2)
        assert abs(np.median(inner) - expect) < 2e-3, (period, np.median(inner), expect)
        assert abs(np.median(mean[:, 60:-60, 1]) - (gain * 0.5 + off)) < 2e-3


def test_modulation_follows_the_sampled_coordinate():
    # A pure shift of 7 px: with the true sampled coordinate the coherent
    # amplitude is the full CODE_AMP; with the pixel's own position it is not.
    shift = 7
    imgs = [np.roll(i, -shift, axis=1) for i in _codes(32)]
    px = np.mgrid[0:H, 0:W][1] + 0.5
    amp, _ = mf.modulation(imgs, 32, px + shift)
    assert abs(np.median(amp[..., 1]) - gb.CODE_AMP) < 3e-3
    wrong, _ = mf.modulation(imgs, 32, px)
    assert np.median(wrong[..., 1]) < 0.5 * gb.CODE_AMP


def test_gaussian_mtf_and_tap_kernel_transfer():
    assert mf.gaussian_mtf(32, 0.0) == 1.0
    assert np.isclose(mf.gaussian_mtf(64, 8.0), np.exp(-0.5 * (2 * np.pi * 8 / 64) ** 2))
    # A kernel of taps (x offsets, weights) transfers sum w cos(2 pi x / P).
    taps = [(-4.0, 0.25), (0.0, 0.5), (4.0, 0.25)]
    assert np.isclose(mf.taps_mtf(taps, 16), 0.5 + 0.5 * np.cos(2 * np.pi * 4 / 16))


def test_tone_curve_from_flats():
    # out = 0.2 + 0.7 * in on every channel, in the interior.
    levels = [0, 64, 128, 255]
    imgs = {v: np.full((10, 10, 3), 0.2 + 0.7 * v / 255) for v in levels}
    interior = np.ones((10, 10), bool)
    curve = mf.tone_curve(imgs, interior)
    assert [c[0] for c in curve] == [v / 255 for v in levels]
    assert np.allclose([c[1][1] for c in curve], [0.2 + 0.7 * v / 255 for v in levels])
