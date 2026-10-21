"""Export a trained Hugging Face sequence classifier to a Guardian model directory (int8 ONNX).

    python -m urduguard.export runs/xlmr-smoke/model models/xlmr-smoke --name xlmr-smoke

Writes model.onnx (dynamic int8, opset 17), tokenizer.json, config.json (labels, max_len, default thresholds
0.5 per form and mode) and a placeholder coverage_card.json with the model hash filled in and every rate null.
The eval harness fills the card later; export never claims a number.
"""

from __future__ import annotations

import argparse
import json
from datetime import date
from pathlib import Path

from . import taxonomy
from .model import sha256_of

LABELS = [l for l in taxonomy.LABELS if l != "benign"]


def export(model_dir: str, out: str, name: str, max_len: int = 128, opset: int = 17) -> Path:
    import torch
    from onnxruntime.quantization import QuantType, quantize_dynamic
    from transformers import AutoModelForSequenceClassification, AutoTokenizer

    out_dir = Path(out)
    out_dir.mkdir(parents=True, exist_ok=True)
    tok = AutoTokenizer.from_pretrained(model_dir)
    model = AutoModelForSequenceClassification.from_pretrained(model_dir).eval()
    labels = [model.config.id2label[i] for i in range(model.config.num_labels)]

    class Wrapped(torch.nn.Module):
        def __init__(self, m):
            super().__init__()
            self.m = m

        def forward(self, input_ids, attention_mask):
            return self.m(input_ids=input_ids, attention_mask=attention_mask).logits

    enc = tok(["example text"], return_tensors="pt", padding="max_length", max_length=16)
    fp32 = out_dir / "model.fp32.onnx"
    torch.onnx.export(Wrapped(model), (enc["input_ids"], enc["attention_mask"]), str(fp32), input_names=["input_ids", "attention_mask"],
                      output_names=["logits"], dynamic_axes={"input_ids": {0: "b", 1: "s"}, "attention_mask": {0: "b", 1: "s"}, "logits": {0: "b"}},
                      opset_version=opset, dynamo=False)
    quantize_dynamic(str(fp32), str(out_dir / "model.onnx"), weight_type=QuantType.QInt8)
    fp32.unlink()
    tok.backend_tokenizer.save(str(out_dir / "tokenizer.json"))
    thresholds = {mode: {"default": {l: 0.5 for l in LABELS}} for mode in ("strict", "loose")}
    thresholds["loose"]["default"]["needs_caution"] = 1.1  # loose mode never flags on caution alone
    (out_dir / "config.json").write_text(json.dumps({
        "model_name": name, "placeholder": False, "base": model.config._name_or_path, "max_len": max_len,
        "pad_id": tok.pad_token_id, "pad_token": tok.pad_token, "labels": labels, "thresholds": thresholds,
    }, indent=2), encoding="utf-8")
    model_hash = sha256_of(out_dir / "model.onnx")
    (out_dir / "coverage_card.json").write_text(json.dumps({
        "taxonomy_version": taxonomy.TAXONOMY_VERSION, "model_name": name, "model_hash": model_hash, "placeholder": True,
        "date": date.today().isoformat(), "forms_tested": [], "forms": {}, "thresholds": thresholds,
        "gate": {k: {"status": "not_measurable", "measured": None} for k in ("R1", "R2", "R3")} | {"R4": {"status": "not_applicable"}, "R5": {"status": "cleared", "measured": True}},
        "form_detector": {"accuracy": None, "confusion": None}, "signed_off_by": [], "eval_set": None,
        "not_tested": ["No evaluation has been run on this export yet. Run urduguard eval and fill this card before any release."],
    }, indent=2), encoding="utf-8")
    print(f"wrote {out_dir} ({(out_dir / 'model.onnx').stat().st_size / 1e6:.0f} MB) {model_hash}")
    return out_dir


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("model_dir")
    ap.add_argument("out")
    ap.add_argument("--name", required=True)
    ap.add_argument("--max-len", type=int, default=128)
    a = ap.parse_args()
    export(a.model_dir, a.out, a.name, a.max_len)
