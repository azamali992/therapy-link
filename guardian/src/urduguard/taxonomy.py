"""The label set, which labels gate and which are only reported, and the version string every response carries.

Protective labels are the ones the release gate (R1 to R4) is computed on. Descriptive labels are reported
in the coverage card but never gate a release. There is no religious-hate label: religious content is
filtered out of every training and evaluation file by script (see data/filters.py).
"""

from __future__ import annotations

TAXONOMY_VERSION = "urduguard-2.0"

LABELS: tuple[str, ...] = (
    "violence_threats",  # threats, incitement, graphic violence, calls for physical harm
    "harassment",        # targeted abuse, bullying, intimidation of a person
    "hate_group",        # hate or dehumanisation of a group by ethnicity, caste, gender, sexuality, nationality, disability
    "self_harm",         # suicide and self-harm content (descriptive only)
    "sexual",            # sexual content (descriptive only)
    "needs_caution",     # political, misinformation, conspiracy, or borderline content; a flag, not a block
    "benign",
)

PROTECTIVE: tuple[str, ...] = ("violence_threats", "harassment", "hate_group")
DESCRIPTIVE: tuple[str, ...] = ("self_harm", "sexual")

FORMS: tuple[str, ...] = ("en", "roman_ur", "ur", "mixed")

# OpenAI omni-moderation category names a Guardian label maps onto, for the /v1/moderations shape.
OPENAI_CATEGORIES: dict[str, tuple[str, ...]] = {
    "violence_threats": ("violence", "harassment/threatening", "hate/threatening"),
    "harassment": ("harassment",),
    "hate_group": ("hate",),
    "self_harm": ("self-harm", "self-harm/intent", "self-harm/instructions"),
    "sexual": ("sexual",),
}
OPENAI_NOT_COVERED: tuple[str, ...] = ("illicit", "illicit/violent", "sexual/minors", "violence/graphic")


def index(label: str) -> int:
    return LABELS.index(label)


def validate(labels: list[str]) -> None:
    unknown = set(labels) - set(LABELS)
    if unknown:
        raise ValueError(f"unknown labels {sorted(unknown)}")
    if "benign" in labels and len(labels) > 1:
        raise ValueError("benign is never combined with another label")
    if not labels:
        raise ValueError("a row needs at least one label")
