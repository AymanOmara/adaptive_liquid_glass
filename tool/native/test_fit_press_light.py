import numpy as np
import pytest

from fit_press_light import fit_correction


def test_recovers_known_light_and_validates_on_unseen_pixels():
    y, x = np.indices((64, 240))
    d2 = (x - 180) ** 2 + (y - 30) ** 2
    expected = 4.2 + 12.6 * np.exp(-d2 / (2 * 37 ** 2))
    residual = np.repeat(expected[..., None], 3, axis=2)
    training = x % 2 == 0
    parameters, correction = fit_correction(residual, training, d2)
    assert parameters["lift_px"] == pytest.approx(4.2, abs=1e-5)
    assert parameters["peak_px"] == pytest.approx(12.6, abs=1e-5)
    assert parameters["sigma_pt"] == pytest.approx(37, abs=1e-5)
    assert np.abs(correction[~training] - expected[~training]).max() < 1e-5


def test_can_reduce_an_overbright_baseline():
    y, x = np.indices((64, 240))
    d2 = (x - 160) ** 2 + y ** 2
    expected = -2 - 7 * np.exp(-d2 / (2 * 41 ** 2))
    parameters, correction = fit_correction(
        np.repeat(expected[..., None], 3, axis=2), np.ones(x.shape, bool), d2)
    assert parameters["lift_px"] < 0
    assert parameters["peak_px"] < 0
    np.testing.assert_allclose(correction, expected, atol=1e-5)


def test_rejects_empty_interior():
    with pytest.raises(ValueError, match="interior pixels"):
        fit_correction(np.zeros((2, 2, 3)), np.zeros((2, 2), bool), np.zeros((2, 2)))
