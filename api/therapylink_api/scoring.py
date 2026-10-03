"""Standard scoring for PHQ-9, GAD-7 and BDI-II. Bands follow the published cut-offs."""

from __future__ import annotations

from dataclasses import dataclass

from therapylink_api.models import Instrument


@dataclass(frozen=True)
class Scored:
    score: int
    band: str
    flags: list[str]


_SPEC = {
    Instrument.phq9: {
        "items": 9,
        "max_item": 3,
        "bands": [(4, "minimal"), (9, "mild"), (14, "moderate"), (19, "moderately_severe"), (27, "severe")],
        "risk_item": 8,
    },
    Instrument.gad7: {
        "items": 7,
        "max_item": 3,
        "bands": [(4, "minimal"), (9, "mild"), (14, "moderate"), (21, "severe")],
        "risk_item": None,
    },
    Instrument.bdi2: {
        "items": 21,
        "max_item": 3,
        "bands": [(13, "minimal"), (19, "mild"), (28, "moderate"), (63, "severe")],
        "risk_item": 8,
    },
}

# How many points of increase constitute a clinically meaningful worsening, per instrument.
# PHQ-9 and BDI-II cross band boundaries every 5 points; GAD-7 every 4.
_WORSENED_THRESHOLD: dict[Instrument, int] = {
    Instrument.phq9: 5,
    Instrument.gad7: 4,
    Instrument.bdi2: 5,
}


def score(instrument: Instrument, answers: list[int]) -> Scored:
    spec = _SPEC[instrument]
    if len(answers) != spec["items"]:
        raise ValueError(f"{instrument.value} expects {spec['items']} answers, got {len(answers)}")
    if any(not isinstance(a, int) or a < 0 or a > spec["max_item"] for a in answers):
        raise ValueError(f"{instrument.value} answers must be integers 0..{spec['max_item']}")
    total = sum(answers)
    band = next(name for upper, name in spec["bands"] if total <= upper)
    flags: list[str] = []
    risk_item = spec["risk_item"]
    if risk_item is not None and answers[risk_item] > 0:
        flags.append("suicidal_ideation_item")
    return Scored(total, band, flags)


def delta(current: int, previous: int | None) -> int | None:
    return None if previous is None else current - previous


def attention(instrument: Instrument, band: str, delta_val: int | None, flags: list[str]) -> list[str]:
    """Clinician-facing attention signals for the most recent assessment result.

    Returns a list of zero or more tags:
      'risk_item'  — a suicidal ideation item was endorsed
      'severe'     — the result falls in the severe (or moderately_severe) band
      'worsened'   — the score increased by at least the instrument's clinical threshold
    """
    result: list[str] = []
    if "suicidal_ideation_item" in flags:
        result.append("risk_item")
    if band in ("severe", "moderately_severe"):
        result.append("severe")
    threshold = _WORSENED_THRESHOLD.get(instrument, 5)
    if delta_val is not None and delta_val >= threshold:
        result.append("worsened")
    return result
