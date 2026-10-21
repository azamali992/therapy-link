"""Guardrail backends the harness can run. Each returns, per text, a Prediction in the Guardian taxonomy.

`flagged` is the binary verdict the gate uses: the system called the input unsafe. For systems whose
taxonomy has no harassment label, "unsafe" with any category still counts as flagged, so no system is
penalised for naming harms differently. `labels` carries the mapped per-label view for the extra tables.

Open models run with their official prompt template, greedy decoding, fp16. The OpenAI model name is pinned.
"""

from __future__ import annotations

import json
import os
import re
from dataclasses import dataclass, field

from .. import taxonomy

LLAMA_GUARD_3_MODEL = "meta-llama/Llama-Guard-3-8B"
QWEN3GUARD_MODEL = "Qwen/Qwen3Guard-Gen-0.6B"
OPENAI_MODEL = "omni-moderation-2024-09-26"

# Llama Guard 3 hazard codes (MLCommons) -> Guardian label, or "other" (unsafe but out of taxonomy)
LLAMA_GUARD_3 = {
    "S1": "violence_threats", "S2": "other", "S3": "sexual", "S4": "sexual", "S5": "other", "S6": "other",
    "S7": "other", "S8": "other", "S9": "violence_threats", "S10": "hate_group", "S11": "self_harm",
    "S12": "sexual", "S13": "other", "S14": "other",
}
# Qwen3Guard-Gen category names -> Guardian label
QWEN3GUARD = {
    "violent": "violence_threats", "sexual content or sexual acts": "sexual", "suicide & self-harm": "self_harm",
    "politically sensitive topics": "needs_caution", "non-violent illegal acts": "other", "pii": "other",
    "unethical acts": "other", "copyright violation": "other", "jailbreak": "other", "none": "benign",
}
OPENAI_TO_GUARDIAN = {n: g for g, names in taxonomy.OPENAI_CATEGORIES.items() for n in names}


@dataclass
class Prediction:
    flagged: bool
    labels: set[str] = field(default_factory=set)
    scores: dict[str, float] = field(default_factory=dict)
    raw: str = ""


class Backend:
    name = "backend"

    def predict(self, texts: list[str]) -> list[Prediction]:
        raise NotImplementedError


class UrduguardBackend(Backend):
    """This project's own model directory, in strict or loose mode."""

    def __init__(self, model_dir: str, mode: str = "strict"):
        from ..api import check_batch
        from ..model import Model

        self.model, self.mode, self._check = Model(model_dir), mode, check_batch
        self.name = f"urduguard:{self.model.name}:{mode}"

    def predict(self, texts: list[str]) -> list[Prediction]:
        return [Prediction(r.flagged, set(r.labels_fired), r.scores, "") for r in self._check(texts, mode=self.mode, model=self.model)]


class FixtureBackend(Backend):
    """Predictions read from a JSON file {text_id: flagged}; the CI gate uses it so no model has to download."""

    def __init__(self, path: str):
        self.table = json.loads(open(path, encoding="utf-8").read())
        self.name = "fixture"
        self.ids: list[str] = []

    def predict(self, texts: list[str]) -> list[Prediction]:
        return [Prediction(bool(self.table.get(i, False)), set(), {}, "") for i in self.ids]


class HFGenerativeBackend(Backend):
    """Llama Guard 3 or Qwen3Guard-Gen through transformers: official chat template, greedy, fp16."""

    def __init__(self, model_id: str, max_new_tokens: int = 24, strict: bool = True, device: str | None = None):
        import torch
        from transformers import AutoModelForCausalLM, AutoTokenizer

        self.model_id, self.strict = model_id, strict
        self.name = f"{model_id}:{'strict' if strict else 'loose'}"
        self.device = device or ("cuda" if torch.cuda.is_available() else "cpu")
        self.tok = AutoTokenizer.from_pretrained(model_id)
        self.tok.padding_side = "left"
        if self.tok.pad_token is None:
            self.tok.pad_token = self.tok.eos_token
        self.model = AutoModelForCausalLM.from_pretrained(model_id, dtype=torch.float16 if self.device == "cuda" else torch.float32).to(self.device).eval()
        self.max_new_tokens = max_new_tokens

    def predict(self, texts: list[str], batch_size: int = 8) -> list[Prediction]:
        import torch

        out = []
        for i in range(0, len(texts), batch_size):
            chats = [[{"role": "user", "content": t}] for t in texts[i:i + batch_size]]
            prompts = [self.tok.apply_chat_template(c, tokenize=False, add_generation_prompt=True) for c in chats]
            enc = self.tok(prompts, return_tensors="pt", padding=True).to(self.device)
            with torch.no_grad():
                gen = self.model.generate(**enc, max_new_tokens=self.max_new_tokens, do_sample=False, pad_token_id=self.tok.pad_token_id)
            for row in gen[:, enc["input_ids"].shape[1]:]:
                out.append(self.parse(self.tok.decode(row, skip_special_tokens=True)))
        return out

    def parse(self, text: str) -> Prediction:
        t = text.strip()
        low = t.lower()
        if "llama-guard" in self.model_id.lower():
            if low.startswith("safe"):
                return Prediction(False, {"benign"}, raw=t)
            codes = re.findall(r"S\d+", t)
            labels = {LLAMA_GUARD_3.get(c, "other") for c in codes}
            return Prediction(True, labels, raw=t)
        # Qwen3Guard-Gen: "Safety: Unsafe\nCategories: Violent, PII"
        m = re.search(r"safety:\s*(safe|unsafe|controversial)", low)
        level = m.group(1) if m else ("unsafe" if "unsafe" in low else "safe")
        cm = re.search(r"categories:\s*(.+)", low)
        cats = [c.strip() for c in cm.group(1).split(",")] if cm else []
        labels = {QWEN3GUARD.get(c, "other") for c in cats} - {"benign"}
        flagged = level == "unsafe" or (level == "controversial" and self.strict)
        return Prediction(flagged, labels if flagged else {"benign"}, raw=t)


class OpenAIBackend(Backend):
    """OpenAI moderation, model name pinned. Needs OPENAI_API_KEY. Sends the text to OpenAI."""

    def __init__(self, model: str = OPENAI_MODEL):
        import httpx

        self.model, self.name = model, f"openai:{model}"
        self.key = os.environ["OPENAI_API_KEY"]
        self.client = httpx.Client(timeout=60)

    def predict(self, texts: list[str]) -> list[Prediction]:
        out = []
        for i in range(0, len(texts), 32):
            r = self.client.post("https://api.openai.com/v1/moderations", headers={"Authorization": f"Bearer {self.key}"},
                                 json={"model": self.model, "input": texts[i:i + 32]})
            r.raise_for_status()
            for res in r.json()["results"]:
                labels = {OPENAI_TO_GUARDIAN[n] for n, on in res["categories"].items() if on and n in OPENAI_TO_GUARDIAN}
                out.append(Prediction(bool(res["flagged"]), labels or {"benign"}, {n: s for n, s in res["category_scores"].items() if s is not None}, ""))
        return out


def make(spec: str) -> Backend:
    """'urduguard:<dir>[:mode]', 'fixture:<file>', 'hf:<model_id>[:loose]', 'openai[:<model>]'."""
    kind, _, rest = spec.partition(":")
    if kind == "urduguard":
        d, _, mode = rest.rpartition(":") if rest.endswith(("strict", "loose")) else (rest, "", "strict")
        return UrduguardBackend(d, mode or "strict")
    if kind == "fixture":
        return FixtureBackend(rest)
    if kind == "hf":
        model_id, _, mode = rest.rpartition(":") if rest.endswith(("strict", "loose")) else (rest, "", "strict")
        return HFGenerativeBackend(model_id, strict=(mode != "loose"))
    if kind == "openai":
        return OpenAIBackend(rest or OPENAI_MODEL)
    raise ValueError(f"unknown backend {spec!r}")
