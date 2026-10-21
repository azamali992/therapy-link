"""Map each source's labels into the Guardian taxonomy.

A row keeps every in-scope label it maps to. A row whose only labels are out of scope (criminal planning,
PII, drugs, profanity, fraud, malware, ...) is DROPPED, not relabelled benign: a guardrail that learned
"how do I launder money" is benign would be wrong, and these harms are simply not what this model is for.
Jailbreak rows are dropped (no jailbreak detector). Every drop is counted in the manifest.
"""

from __future__ import annotations

# Aegis 2.0 category -> Guardian label(s). Missing keys are out of scope.
AEGIS = {
    "Violence": ["violence_threats"],
    "Threat": ["violence_threats"],
    "Harassment": ["harassment"],
    "Hate/Identity Hate": ["hate_group"],  # religious hate rows are removed by filters.religious first
    "Suicide and Self Harm": ["self_harm"],
    "Sexual": ["sexual"],
    "Needs Caution": ["needs_caution"],
    "Political/Misinformation/Conspiracy": ["needs_caution"],
    # Out of scope, listed so the manifest can say so by name:
    "Criminal Planning/Confessions": [],
    "Guns and Illegal Weapons": [],
    "Controlled/Regulated Substances": [],
    "Profanity": [],
    "PII/Privacy": [],
    "Sexual (minor)": [],  # the whole row is removed by filters.minors
    "Unauthorized Advice": [],
    "Immoral/Unethical": [],
    "Illegal Activity": [],
    "Fraud/Deception": [],
    "Malware": [],
    "Copyright/Trademark/Plagiarism": [],
    "High Risk Gov Decision Making": [],
    "Manipulation": [],
    "Other": [],
}

# Which Aegis categories count as protective for the gate (used by the eval harness when it reads Aegis test).
AEGIS_PROTECTIVE = ("Violence", "Threat", "Harassment", "Hate/Identity Hate")


def map_aegis(prompt_label: str | None, violated: str) -> tuple[list[str], str]:
    """Guardian labels for one Aegis-style prompt row, and why ('ok', 'out_of_scope', 'unlabelled')."""
    cats = [c.strip() for c in (violated or "").split(",") if c.strip()]
    if prompt_label == "safe" and not cats:
        return ["benign"], "ok"
    if prompt_label is None:
        return [], "unlabelled"
    labels: list[str] = []
    for c in cats:
        for g in AEGIS.get(c, []):
            if g not in labels:
                labels.append(g)
    if prompt_label == "safe" and labels == ["needs_caution"]:
        return labels, "ok"
    if not labels:
        return [], "out_of_scope"
    return [l for l in labels if l != "benign"], "ok"
