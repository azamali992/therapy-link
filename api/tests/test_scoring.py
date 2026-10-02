import pytest

from therapylink_api.models import Instrument
from therapylink_api.scoring import score


def test_phq9_bands_and_risk_flag():
    assert score(Instrument.phq9, [0] * 9).band == "minimal"
    assert score(Instrument.phq9, [1] * 9).band == "mild"
    assert score(Instrument.phq9, [2] * 9).band == "moderately_severe"
    assert score(Instrument.phq9, [3] * 9).band == "severe"
    s = score(Instrument.phq9, [0] * 8 + [1])
    assert s.flags == ["suicidal_ideation_item"]


def test_gad7_bands():
    assert score(Instrument.gad7, [1, 1, 1, 1, 1, 0, 0]).band == "mild"
    assert score(Instrument.gad7, [3] * 7).band == "severe"


def test_bdi2_bands():
    assert score(Instrument.bdi2, [0] * 21).band == "minimal"
    assert score(Instrument.bdi2, [1] * 21).band == "moderate"


def test_rejects_wrong_length_and_range():
    with pytest.raises(ValueError):
        score(Instrument.phq9, [0] * 8)
    with pytest.raises(ValueError):
        score(Instrument.gad7, [4] * 7)
