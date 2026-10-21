"""Fine-tune a pretrained encoder as a multi-label classifier over the Guardian labels (LoRA by default).

    python train/train_encoder.py --rows 2000 --steps 300 --out runs/xlmr-smoke
    python train/train_encoder.py --base microsoft/mdeberta-v3-base --full --rows 50000 --epochs 2 --out runs/mdeberta

Writes <out>/model (merged HF model + tokenizer, ready for `python -m urduguard.export`), <out>/dev.json
(per-form catch and false-alarm rate at 0.5 on the val split) and <out>/train.json (settings, time, loss).
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

import numpy as np
import torch
from torch.utils.data import DataLoader

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import DATA, TARGET_LABELS, dev_report, read, smoke_subset, targets  # noqa: E402


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="FacebookAI/xlm-roberta-base")
    ap.add_argument("--rows", type=int, default=2000)
    ap.add_argument("--dev-rows", type=int, default=600)
    ap.add_argument("--steps", type=int, default=300, help="stop after this many optimiser steps (0 = full epochs)")
    ap.add_argument("--epochs", type=int, default=1)
    ap.add_argument("--batch", type=int, default=16)
    ap.add_argument("--lr", type=float, default=2e-4)
    ap.add_argument("--max-len", type=int, default=128)
    ap.add_argument("--lora-r", type=int, default=8)
    ap.add_argument("--full", action="store_true", help="full fine-tune with the embeddings frozen instead of LoRA")
    ap.add_argument("--out", required=True)
    ap.add_argument("--seed", type=int, default=13)
    a = ap.parse_args()

    from transformers import AutoModelForSequenceClassification, AutoTokenizer

    torch.manual_seed(a.seed)
    device = "cuda" if torch.cuda.is_available() else "cpu"
    train_rows = smoke_subset(read(DATA / "train.jsonl"), a.rows, a.seed)
    dev_rows = smoke_subset(read(DATA / "val.jsonl"), a.dev_rows, a.seed)
    tok = AutoTokenizer.from_pretrained(a.base)
    model = AutoModelForSequenceClassification.from_pretrained(
        a.base, num_labels=len(TARGET_LABELS), problem_type="multi_label_classification",
        id2label=dict(enumerate(TARGET_LABELS)), label2id={l: i for i, l in enumerate(TARGET_LABELS)})
    if a.full:
        for p in model.base_model.embeddings.parameters():
            p.requires_grad = False
    else:
        from peft import LoraConfig, get_peft_model

        model = get_peft_model(model, LoraConfig(r=a.lora_r, lora_alpha=2 * a.lora_r, lora_dropout=0.05, task_type="SEQ_CLS",
                                                 target_modules=["query", "key", "value", "dense"]))
    model.to(device)
    trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)

    y = torch.tensor(targets(train_rows))
    texts = [r["text"] for r in train_rows]
    loader = DataLoader(list(range(len(texts))), batch_size=a.batch, shuffle=True)
    opt = torch.optim.AdamW([p for p in model.parameters() if p.requires_grad], lr=a.lr, weight_decay=0.01)
    scaler = torch.amp.GradScaler(enabled=device == "cuda")
    model.train()
    step, losses, t0 = 0, [], time.time()
    for epoch in range(a.epochs):
        for idx in loader:
            enc = tok([texts[i] for i in idx], padding=True, truncation=True, max_length=a.max_len, return_tensors="pt").to(device)
            with torch.autocast(device_type=device, dtype=torch.float16, enabled=device == "cuda"):
                out = model(**enc, labels=y[idx].to(device))
            scaler.scale(out.loss).backward()
            scaler.unscale_(opt)
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            scaler.step(opt)
            scaler.update()
            opt.zero_grad(set_to_none=True)
            losses.append(out.loss.item())
            step += 1
            if step % 25 == 0:
                print(f"step {step} loss {np.mean(losses[-25:]):.4f} {time.time() - t0:.0f}s", flush=True)
            if a.steps and step >= a.steps:
                break
        if a.steps and step >= a.steps:
            break
    train_time = time.time() - t0

    model.eval()
    probs = []
    with torch.no_grad():
        for i in range(0, len(dev_rows), 64):
            enc = tok([r["text"] for r in dev_rows[i:i + 64]], padding=True, truncation=True, max_length=a.max_len, return_tensors="pt").to(device)
            probs.append(torch.sigmoid(model(**enc).logits.float()).cpu().numpy())
    report = dev_report(dev_rows, np.concatenate(probs))

    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    merged = model.merge_and_unload() if not a.full else model
    merged.save_pretrained(out / "model")
    tok.save_pretrained(out / "model")
    (out / "dev.json").write_text(json.dumps(report, indent=1), encoding="utf-8")
    (out / "train.json").write_text(json.dumps({
        "base": a.base, "lora": not a.full, "lora_r": a.lora_r, "rows": len(train_rows), "dev_rows": len(dev_rows), "steps": step,
        "batch": a.batch, "lr": a.lr, "max_len": a.max_len, "trainable_params": trainable, "train_seconds": round(train_time),
        "final_loss": float(np.mean(losses[-25:])), "device": device,
        "gpu_peak_mb": int(torch.cuda.max_memory_allocated() / 1e6) if device == "cuda" else None,
    }, indent=1), encoding="utf-8")
    print(json.dumps(report["per_form"], indent=1))
    print(f"saved {out}/model, {step} steps, {train_time:.0f}s, loss {np.mean(losses[-25:]):.4f}")


if __name__ == "__main__":
    main()
