"""The Python surface: load(), check(), check_batch(), and the GuardResult every route is built from.

Privacy is a property of this module, not a setting: no function here writes, logs or caches the text
it is given or the result it returns.
"""

from __future__ import annotations

import os
import time
from dataclasses import asdict, dataclass, field
from pathlib import Path

from . import taxonomy
from .forms import detect
from .model import Model

MODES = ("strict", "loose")
_default: Model | None = None


@dataclass(frozen=True)
class GuardResult:
    flagged: bool                       # any protective label over its threshold (strict: needs_caution too)
    labels: dict[str, bool]
    scores: dict[str, float]
    protective_flag: bool
    descriptive: dict[str, bool]
    needs_caution: bool
    form: str
    form_confidence: float
    thresholds: dict[str, float]
    coverage: dict
    model_hash: str
    model_name: str
    placeholder: bool
    taxonomy_version: str = taxonomy.TAXONOMY_VERSION
    mode: str = "strict"
    latency_ms: float = 0.0
    labels_fired: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return asdict(self)

    def to_openai(self) -> dict:
        """One OpenAI moderation `results[]` entry. Categories this model does not cover are false/0.0, or
        null where OpenAI itself types them nullable (illicit, illicit/violent)."""
        cats: dict[str, bool | None] = {}
        scores: dict[str, float | None] = {}
        base = {"harassment": "harassment", "hate": "hate_group"}
        for g, names in taxonomy.OPENAI_CATEGORIES.items():
            for n in names:
                if n.endswith("/threatening"):  # harassment/threatening = harassment AND violence_threats
                    b = base[n.split("/")[0]]
                    cats[n] = bool(self.labels[b] and self.labels["violence_threats"])
                    scores[n] = min(self.scores[b], self.scores["violence_threats"])
                else:
                    cats[n] = bool(self.labels[g])
                    scores[n] = self.scores[g]
        for n in taxonomy.OPENAI_NOT_COVERED:
            nullable = n.startswith("illicit")
            cats[n] = None if nullable else False
            scores[n] = None if nullable else 0.0
        return {
            "flagged": self.protective_flag or any(self.descriptive.values()),
            "categories": cats,
            "category_scores": scores,
            "category_applied_input_types": {n: (["text"] if cats[n] is not None else []) for n in cats},
            "form": self.form,
            "coverage": self.coverage,
            "model_hash": self.model_hash,
            "thresholds_mode": self.mode,
            "taxonomy_version": self.taxonomy_version,
        }


def load(directory: str | Path | None = None) -> Model:
    """Load a model directory (default: $URDUGUARD_MODEL_DIR) and make it the module default."""
    global _default
    directory = directory or os.environ.get("URDUGUARD_MODEL_DIR")
    if not directory:
        raise RuntimeError("no model directory: pass one or set URDUGUARD_MODEL_DIR")
    _default = Model(directory)
    return _default


def _model(model: Model | None) -> Model:
    if model is not None:
        return model
    if _default is None:
        return load()
    return _default


def _coverage(model: Model, form: str) -> dict:
    per_form = (model.card.get("forms") or {}).get(form) or {}
    return {
        "form_tested": form in (model.card.get("forms_tested") or []),
        "catch_rate": (per_form.get("catch_rate") or {}).get("value"),
        "false_alarm_rate": (per_form.get("false_alarm_rate") or {}).get("value"),
        "placeholder": bool(model.card.get("placeholder", False)),
    }


def check_batch(texts: list[str], mode: str = "strict", model: Model | None = None, form: str | None = None) -> list[GuardResult]:
    if mode not in MODES:
        raise ValueError(f"mode must be one of {MODES}")
    m = _model(model)
    t0 = time.perf_counter()
    all_scores = m.scores(texts)
    latency = (time.perf_counter() - t0) * 1000 / max(len(texts), 1)
    out = []
    for text, scores in zip(texts, all_scores):
        guess = detect(text)
        f = form or guess.form
        thr = m.thresholds(f, mode)
        labels = {label: scores[label] >= thr[label] for label in scores}
        protective = any(labels[l] for l in taxonomy.PROTECTIVE)
        caution = labels["needs_caution"]
        out.append(GuardResult(
            flagged=protective or (caution and mode == "strict"),
            labels=labels, scores=scores, protective_flag=protective,
            descriptive={l: labels[l] for l in taxonomy.DESCRIPTIVE}, needs_caution=caution,
            form=f, form_confidence=max(guess.script_ratio, guess.roman_ratio) if f != "en" else 1.0 - max(guess.script_ratio, guess.roman_ratio),
            thresholds=thr, coverage=_coverage(m, f), model_hash=m.model_hash, model_name=m.name, placeholder=m.placeholder,
            mode=mode, latency_ms=round(latency, 2), labels_fired=[l for l, on in labels.items() if on],
        ))
    return out


def check(text: str, mode: str = "strict", model: Model | None = None, form: str | None = None) -> GuardResult:
    return check_batch([text], mode=mode, model=model, form=form)[0]
