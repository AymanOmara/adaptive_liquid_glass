"""Measurement captures must reject launch/error screens."""
import numpy as np
import pytest
from PIL import Image

from capture_fine import validate_frame


def test_capture_backdrop_validation(tmp_path):
    expected = tmp_path / "background.png"
    actual = tmp_path / "capture.png"
    row = np.tile(np.arange(1206, dtype=np.uint16) % 128 + 64, (2622, 1))
    pixels = np.repeat(row[..., None], 3, axis=2).astype(np.uint8)
    Image.fromarray(pixels).save(expected)
    Image.fromarray(pixels).save(actual)
    validate_frame(actual, expected)
    for color in ("black", "magenta"):
        Image.new("RGB", (1206, 2622), color).save(actual)
        with pytest.raises(RuntimeError, match="backdrop mismatch"):
            validate_frame(actual, expected)


def test_capture_rejects_wrong_resolution(tmp_path):
    image = tmp_path / "image.png"
    Image.new("RGB", (100, 100), "gray").save(image)
    with pytest.raises(RuntimeError, match="capture size"):
        validate_frame(image, image)
