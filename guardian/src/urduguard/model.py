"""Load a model directory and score text. Nothing here logs, stores or prints input text.

A model directory holds:
    model.onnx          inputs input_ids/attention_mask (int64), one logits output [batch, n_labels]
    tokenizer.json      a `tokenizers` file
    config.json         {"labels": [...], "max_len": 128, "thresholds": {"strict": {form: {label: t}}, "loose": {...}},
                         "label_map": {source label: guardian label} (optional, for a placeholder model),
                         "model_name": str, "placeholder": bool}
    coverage_card.json  the coverage card the model ships with (see docs/research/07-product-api.md)

The ONNX file's sha256 is the `model_hash` every response carries.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np

from . import taxonomy

FILES = ("model.onnx", "tokenizer.json", "config.json", "coverage_card.json")


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


class Model:
    def __init__(self, directory: str | Path, threads: int = 2):
        import onnxruntime as ort
        from tokenizers import Tokenizer

        self.dir = Path(directory)
        missing = [f for f in FILES if not (self.dir / f).exists()]
        if missing:
            raise FileNotFoundError(f"{self.dir}: missing {missing}")
        self.config = json.loads((self.dir / "config.json").read_text(encoding="utf-8"))
        self.card = json.loads((self.dir / "coverage_card.json").read_text(encoding="utf-8"))
        self.labels: list[str] = self.config["labels"]
        self.label_map: dict[str, str] = self.config.get("label_map") or {}
        self.max_len: int = int(self.config.get("max_len", 128))
        self.model_hash = sha256_of(self.dir / "model.onnx")
        if self.card.get("model_hash") not in (None, "", self.model_hash) and not self.card.get("placeholder"):
            raise ValueError("coverage_card.json model_hash does not match model.onnx")
        opts = ort.SessionOptions()
        opts.intra_op_num_threads = threads
        self.session = ort.InferenceSession(str(self.dir / "model.onnx"), opts, providers=["CPUExecutionProvider"])
        self.tokenizer = Tokenizer.from_file(str(self.dir / "tokenizer.json"))
        self.tokenizer.enable_truncation(self.max_len)
        pad_id = self.config.get("pad_id", 1)
        self.tokenizer.enable_padding(pad_id=pad_id, pad_token=self.config.get("pad_token", "<pad>"))
        self.output_name = self.session.get_outputs()[0].name

    @property
    def name(self) -> str:
        return self.config.get("model_name", self.dir.name)

    @property
    def placeholder(self) -> bool:
        return bool(self.config.get("placeholder", False))

    def scores(self, texts: list[str]) -> list[dict[str, float]]:
        """Per-label probabilities in the Guardian taxonomy for each text (sigmoid over the model's logits,
        then label_map applied with max over sources that map to one Guardian label)."""
        if not texts:
            return []
        enc = self.tokenizer.encode_batch(texts)
        ids = np.array([e.ids for e in enc], dtype=np.int64)
        mask = np.array([e.attention_mask for e in enc], dtype=np.int64)
        logits = self.session.run([self.output_name], {"input_ids": ids, "attention_mask": mask})[0]
        probs = 1.0 / (1.0 + np.exp(-logits.astype(np.float64)))
        out = []
        for row in probs:
            g = {label: 0.0 for label in taxonomy.LABELS if label != "benign"}
            for src, p in zip(self.labels, row):
                dst = self.label_map.get(src, src) if self.label_map else src
                if dst in g:
                    g[dst] = max(g[dst], float(p))
            out.append(g)
        return out

    def thresholds(self, form: str, mode: str) -> dict[str, float]:
        table = self.config.get("thresholds", {}).get(mode, {})
        per_form = table.get(form) or table.get("default") or {}
        return {label: float(per_form.get(label, 0.5)) for label in taxonomy.LABELS if label != "benign"}
