"""Regular experiments must preserve unrelated renderer constants."""
import pytest

from glass_model import resolve_constants
from probe_regular import apply_regular


def test_regular_patch_isolated_from_clear_dark_and_source():
    base = resolve_constants({})
    out = apply_regular(base, {"regular": {"ambientMix": .2}})
    assert out["regular"]["ambientMix"] == .2
    assert base["regular"]["ambientMix"] == 0.18  # item 8 round 3 shipped value
    assert all(out[k] == base[k] for k in ("clear", "clearDark", "regularDark"))


@pytest.mark.parametrize("patch", [{"clear": {"ambientMix": .2}},
                                   {"regular": {"ambientMxi": .2}}])
def test_regular_patch_rejects_wrong_variant_and_misspelled_parameter(patch):
    with pytest.raises(ValueError):
        apply_regular(resolve_constants({}), patch)
