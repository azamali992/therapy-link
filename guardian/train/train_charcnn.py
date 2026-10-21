"""Character-level CNN trained from scratch (Zhang et al. 2015 style, small), multi-label over Guardian labels.

    python train/train_charcnn.py --rows 2000 --epochs 8 --out runs/charcnn-smoke

Its case is Roman Urdu spelling robustness, which has to be measured, not assumed. Writes a Guardian model
directory straight to <out>/model (model.onnx int8, a char-level tokenizer.json the package can load,
config.json, placeholder coverage_card.json) so the eval harness can run it like any other model.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from datetime import date
from pathlib import Path

import numpy as np
import torch
from torch import nn

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import DATA, TARGET_LABELS, dev_report, read, smoke_subset, targets  # noqa: E402

from urduguard import taxonomy  # noqa: E402
from urduguard.model import sha256_of  # noqa: E402

PAD, UNK = "<pad>", "<unk>"


class CharCNN(nn.Module):
    def __init__(self, vocab: int, n_labels: int, dim: int = 64, channels: int = 256, kernels=(3, 5, 7)):
        super().__init__()
        self.emb = nn.Embedding(vocab, dim, padding_idx=0)
        self.convs = nn.ModuleList([nn.Conv1d(dim, channels, k, padding=k // 2) for k in kernels])
        self.drop = nn.Dropout(0.3)
        self.head = nn.Linear(channels * len(kernels), n_labels)

    def forward(self, input_ids, attention_mask):
        x = self.emb(input_ids).transpose(1, 2)                     # [b, dim, s]
        mask = attention_mask.unsqueeze(1).to(x.dtype)             # [b, 1, s]
        feats = [torch.relu(c(x)) * mask for c in self.convs]
        pooled = torch.cat([f.max(dim=2).values for f in feats], dim=1)
        return self.head(self.drop(pooled))


def build_tokenizer(texts: list[str], max_len: int):
    """A `tokenizers` Tokenizer that splits text into characters, so the package's Model class loads it unchanged."""
    from tokenizers import Regex, Tokenizer, models, normalizers, pre_tokenizers

    chars = {}
    for t in texts:
        for ch in t.lower():
            chars[ch] = chars.get(ch, 0) + 1
    vocab = {PAD: 0, UNK: 1}
    for ch, _ in sorted(chars.items(), key=lambda kv: -kv[1]):
        if ch.strip() or ch == " ":
            vocab[ch] = len(vocab)
    tok = Tokenizer(models.WordLevel(vocab, unk_token=UNK))
    tok.normalizer = normalizers.Lowercase()
    tok.pre_tokenizer = pre_tokenizers.Split(Regex("."), behavior="isolated")
    tok.enable_truncation(max_len)
    tok.enable_padding(pad_id=0, pad_token=PAD)
    return tok, vocab


def encode(tok, texts: list[str]):
    enc = tok.encode_batch(texts)
    return (torch.tensor([e.ids for e in enc], dtype=torch.long), torch.tensor([e.attention_mask for e in enc], dtype=torch.long))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--rows", type=int, default=2000)
    ap.add_argument("--dev-rows", type=int, default=600)
    ap.add_argument("--epochs", type=int, default=8)
    ap.add_argument("--batch", type=int, default=32)
    ap.add_argument("--lr", type=float, default=1e-3)
    ap.add_argument("--max-len", type=int, default=512, help="characters")
    ap.add_argument("--out", required=True)
    ap.add_argument("--seed", type=int, default=13)
    a = ap.parse_args()
    torch.manual_seed(a.seed)
    device = "cuda" if torch.cuda.is_available() else "cpu"

    train_rows = smoke_subset(read(DATA / "train.jsonl"), a.rows, a.seed)
    dev_rows = smoke_subset(read(DATA / "val.jsonl"), a.dev_rows, a.seed)
    tok, vocab = build_tokenizer([r["text"] for r in train_rows], a.max_len)
    ids, mask = encode(tok, [r["text"] for r in train_rows])
    y = torch.tensor(targets(train_rows))
    model = CharCNN(len(vocab), len(TARGET_LABELS)).to(device)
    opt = torch.optim.AdamW(model.parameters(), lr=a.lr, weight_decay=1e-4)
    loss_fn = nn.BCEWithLogitsLoss()
    t0, losses = time.time(), []
    for epoch in range(a.epochs):
        model.train()
        perm = torch.randperm(len(ids))
        for i in range(0, len(perm), a.batch):
            b = perm[i:i + a.batch]
            logits = model(ids[b].to(device), mask[b].to(device))
            loss = loss_fn(logits, y[b].to(device))
            opt.zero_grad(set_to_none=True)
            loss.backward()
            opt.step()
            losses.append(loss.item())
        print(f"epoch {epoch + 1} loss {np.mean(losses[-len(perm) // a.batch:]):.4f} {time.time() - t0:.0f}s", flush=True)
    train_time = time.time() - t0

    model.eval()
    dids, dmask = encode(tok, [r["text"] for r in dev_rows])
    with torch.no_grad():
        probs = torch.sigmoid(model(dids.to(device), dmask.to(device))).cpu().numpy()
    report = dev_report(dev_rows, probs)

    out = Path(a.out) / "model"
    out.mkdir(parents=True, exist_ok=True)
    model.cpu()
    torch.onnx.export(model, (ids[:1], mask[:1]), str(out / "model.fp32.onnx"), input_names=["input_ids", "attention_mask"], output_names=["logits"],
                      dynamic_axes={"input_ids": {0: "b", 1: "s"}, "attention_mask": {0: "b", 1: "s"}, "logits": {0: "b"}}, opset_version=17, dynamo=False)
    from onnxruntime.quantization import QuantType, quantize_dynamic

    quantize_dynamic(str(out / "model.fp32.onnx"), str(out / "model.onnx"), weight_type=QuantType.QInt8)
    (out / "model.fp32.onnx").unlink()
    tok.save(str(out / "tokenizer.json"))
    thresholds = {m: {"default": {l: 0.5 for l in TARGET_LABELS}} for m in ("strict", "loose")}
    thresholds["loose"]["default"]["needs_caution"] = 1.1
    (out / "config.json").write_text(json.dumps({"model_name": Path(a.out).name, "placeholder": False, "base": "char-cnn-from-scratch", "max_len": a.max_len,
                                                 "pad_id": 0, "pad_token": PAD, "labels": TARGET_LABELS, "thresholds": thresholds}, indent=2), encoding="utf-8")
    (out / "coverage_card.json").write_text(json.dumps({
        "taxonomy_version": taxonomy.TAXONOMY_VERSION, "model_name": Path(a.out).name, "model_hash": sha256_of(out / "model.onnx"), "placeholder": True,
        "date": date.today().isoformat(), "forms_tested": [], "forms": {}, "thresholds": thresholds,
        "gate": {k: {"status": "not_measurable", "measured": None} for k in ("R1", "R2", "R3")} | {"R4": {"status": "not_applicable"}, "R5": {"status": "cleared", "measured": True}},
        "form_detector": {"accuracy": None, "confusion": None}, "signed_off_by": [], "eval_set": None,
        "not_tested": ["Smoke-trained on a 2,000-row subset. No evaluation-set run has been made."],
    }, indent=2), encoding="utf-8")
    (Path(a.out) / "dev.json").write_text(json.dumps(report, indent=1), encoding="utf-8")
    (Path(a.out) / "train.json").write_text(json.dumps({
        "base": "char-cnn", "rows": len(train_rows), "dev_rows": len(dev_rows), "epochs": a.epochs, "batch": a.batch, "lr": a.lr, "max_len_chars": a.max_len,
        "vocab": len(vocab), "params": sum(p.numel() for p in model.parameters()), "train_seconds": round(train_time), "final_loss": float(np.mean(losses[-50:])), "device": device,
    }, indent=1), encoding="utf-8")
    print(json.dumps(report["per_form"], indent=1))
    print(f"saved {out}, {train_time:.0f}s")


if __name__ == "__main__":
    main()
