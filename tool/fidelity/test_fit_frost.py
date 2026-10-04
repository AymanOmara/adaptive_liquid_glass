"""Frost wide-tail fitter transfer functions (Task 17c)."""
import math
import pathlib
import sys

import numpy as np
import pytest

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import fit_frost as ff  # noqa: E402
from glass_model import frost_taps, impeller_kernel  # noqa: E402


@pytest.mark.parametrize("sigma", [2.0, 5.5, 10.0])
@pytest.mark.parametrize("period", [32, 48, 80, 128])
def test_taps_mtf_matches_spatial_taps(sigma, period):
    """The analytic cos-sum equals the MTF of the spatial tap layout."""
    taps = frost_taps(sigma)
    mtf = float(sum(w * math.cos(2 * math.pi * dx / period) for dx, dy, w in taps))
    assert ff.taps_mtf(period, sigma) == pytest.approx(mtf, abs=1e-9)


@pytest.mark.parametrize("period", [32, 80, 128])
def test_imp_mtf_matches_kernel(period):
    """The analytic cos-sum equals the MTF of the exact kernel the renderer
    runs (the truncated renormalised Gaussian is flatter than the continuous
    one at small radii, so the kernel itself is the contract)."""
    sigma = 3.0
    k = impeller_kernel(sigma)
    x = np.arange(-(k.size // 2), k.size // 2 + 1)
    mtf = float(np.sum(k * np.cos(2 * np.pi * x / period)))
    v = ff.imp_mtf(period, sigma)
    assert v == pytest.approx(mtf, rel=1e-6)
    assert 0.0 < v <= 1.0
