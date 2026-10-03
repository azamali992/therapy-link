"""Turn a trained Guardian run into the files the app installs, and measure what ships.

    python -m therapylink_ml.export.guardian_bundle make runs/guardian-v1 --data data/guardian/build

Writes runs/<run>/bundle/ in the layout app/lib/core/ml/onnx_guardian.dart reads:

    guardian.int8.onnx   encoder + crisis head, dynamic int8, inputs input_ids/attention_mask (int64),
                         output crisis_logits [batch, 8]
    spm_vocab.json       the sentencepiece vocabulary for the Dart tokenizer
    config.json          {"tasks": {"crisis": [...labels]}, "multi_label": ["crisis"], ...}
    thresholds.json      {"crisis": [8 thresholds]}, calibrated on validation with the int8 model
    verified.json        {file: sha256} for the four files above, the marker installGuardian writes
    canaries.json        canary sentences and the verdict this model gives each
    report.json          held-out recall/precision per class and language (int8, keywords, union),
                         int8-vs-fp32 agreement, size and CPU latency

Thresholds are re-derived on the validation split (written and authored rows) from the int8 model's own scores, one routing threshold for every crisis label (train/guardian.py calibrate_routing): quantisation
moves scores a little, and a threshold tuned on fp32 can sit just above an int8 positive. The
held-out split is only ever scored, never tuned on.
"""

from __future__ import annotations

import hashlib
import json
import shutil
import statistics
import time
from pathlib import Path

import numpy as np
import typer

from therapylink_ml.train.guardian import (
    CRISIS_LABELS,
    calibrate_routing,
    class_lang_report,
    keyword_kind,
    predicted_labels,
    read_heldout,
    recall_report,
)

APP_FILES = ("guardian.int8.onnx", "spm_vocab.json", "config.json", "thresholds.json")

# The app's canaries (onnx_guardian.dart) plus Roman Urdu and Urdu ones: v0 had none, because it
# read no Roman Urdu. A model that loads but reads nothing fails these before it decides anything.
CANARIES = [
    {"text": "I want to end my life tonight", "crisis": True, "lang": "en"},
    {"text": "I don't see any reason to keep living anymore", "crisis": True, "lang": "en"},
    {"text": "I had lunch with my sister and we watched a film", "crisis": False, "lang": "en"},
    {"text": "main ab aur jeena nahi chahti, sab khatam karna hai", "crisis": True, "lang": "ur-roman"},
    {"text": "aaj ammi ke saath bazaar gaye, bohat maza aaya", "crisis": False, "lang": "ur-roman"},
    {"text": "میں اب زندہ نہیں رہنا چاہتا", "crisis": True, "lang": "ur"},
    {"text": "آج موسم بہت اچھا ہے، ہم پارک گئے", "crisis": False, "lang": "ur"},
]

app = typer.Typer(add_completion=False, no_args_is_help=True)


@app.callback()
def main() -> None:
    """Keeps `make` a named subcommand."""


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def dart_define(hashes: dict[str, str]) -> str:
    """The value for --dart-define=TL_GUARDIAN_SHA256=… (onnx_guardian.dart _parseHashes)."""
    return ",".join(f"{f}:{hashes[f]}" for f in APP_FILES)


def sigmoid(x: np.ndarray) -> np.ndarray:
    return 1 / (1 + np.exp(-x))


class OnnxCrisis:
    """The int8 model as the app runs it: one message at a time, no padding, 128-token windows."""

    def __init__(self, model: Path, tokenizer_dir: Path, max_len: int = 128, threads: int = 4):
        import onnxruntime as ort
        from transformers import AutoTokenizer

        opts = ort.SessionOptions()
        opts.intra_op_num_threads = threads
        self.session = ort.InferenceSession(str(model), opts, providers=["CPUExecutionProvider"])
        self.tok = AutoTokenizer.from_pretrained(tokenizer_dir)
        self.max_len = max_len

    def ids(self, text: str) -> list[int]:
        return self.tok(text, truncation=True, max_length=self.max_len)["input_ids"]

    def logits_ids(self, ids: list[int]) -> np.ndarray:
        x = np.asarray([ids], dtype=np.int64)
        return self.session.run(["crisis_logits"], {"input_ids": x, "attention_mask": np.ones_like(x)})[0][0]

    def probs(self, texts: list[str]) -> np.ndarray:
        return np.stack([sigmoid(self.logits_ids(self.ids(t))) for t in texts])


def latency_ms(model: OnnxCrisis, tokens: int = 64, runs: int = 50) -> dict:
    ids = [0] + [5000 + i for i in range(tokens - 2)] + [2]
    for _ in range(5):
        model.logits_ids(ids)
    times = []
    for _ in range(runs):
        t = time.perf_counter()
        model.logits_ids(ids)
        times.append((time.perf_counter() - t) * 1000)
    return {"tokens": tokens, "median_ms": round(statistics.median(times), 1), "p90_ms": round(float(np.quantile(times, 0.9)), 1)}


def _rows(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


@app.command()
def make(
    run: Path = typer.Argument(..., help="A guardian.py run with model.pt (or guardian.int8.onnx) and config.json"),
    data: Path = typer.Option(Path("data/guardian/build"), help="Built splits: labeled.crisis.val.jsonl and heldout.jsonl"),
    target: float = typer.Option(0.97, help="Routing recall every language must reach on validation (guide: any risk vs none >= 97%)"),
    threads: int = 4,
) -> None:
    from therapylink_ml.export import tokenizer_json
    from therapylink_ml.train.guardian import export_onnx

    cfg = json.loads((run / "config.json").read_text(encoding="utf-8"))
    labels = cfg["tasks"]["crisis"]
    if tuple(labels) != CRISIS_LABELS:
        raise typer.BadParameter(f"crisis labels {labels} are not CRISIS_LABELS")
    if not (run / "guardian.int8.onnx").exists():
        export_onnx(run=run, opset=17, quantize=True)
    out = run / "bundle"
    out.mkdir(exist_ok=True)
    shutil.copy(run / "guardian.int8.onnx", out / "guardian.int8.onnx")
    tokenizer_json.dump(model=cfg["base"], out=out / "spm_vocab.json", spm_file="sentencepiece.bpe.model")
    (out / "config.json").write_text(
        json.dumps({"base": cfg["base"], "max_len": cfg["max_len"], "tasks": {"crisis": labels}, "multi_label": ["crisis"]}, indent=2),
        encoding="utf-8",
    )

    model = OnnxCrisis(out / "guardian.int8.onnx", run, cfg["max_len"], threads)

    # 1. Thresholds on validation, from the int8 scores.
    # mh_text rows are left out: their labels come from the subreddit, and a r/SuicideWatch post about
    # a job interview would set the routing threshold for everyone.
    val = [r for r in _rows(data / "labeled.crisis.val.jsonl") if r["source"] != "mh_text"]
    pv = model.probs([r["text"] for r in val])
    yv = np.array([[1.0 if lab in r["labels"] else 0.0 for lab in labels] for r in val])
    thresholds = calibrate_routing(pv, yv, [r["lang"] for r in val], labels, target)
    (out / "thresholds.json").write_text(json.dumps({"crisis": thresholds}, indent=2), encoding="utf-8")

    # 2. int8 against the fp32 checkpoint's own thresholds on validation: how much quantisation moved.
    agree = None
    fp32_thr_path = run / "thresholds.json"
    if (run / "model.pt").exists() and fp32_thr_path.exists():
        import torch
        from transformers import AutoTokenizer

        from therapylink_ml.train.guardian import GuardianModel

        fp = GuardianModel(cfg["base"], {"crisis": len(labels)})
        fp.load_state_dict(torch.load(run / "model.pt", map_location="cpu"))
        fp.eval()
        tok = AutoTokenizer.from_pretrained(run)
        sample = val[:400]
        with torch.no_grad():
            fp_probs = np.concatenate([
                torch.sigmoid(fp("crisis", **tok([r["text"] for r in sample[i : i + 16]], truncation=True, max_length=cfg["max_len"], padding=True, return_tensors="pt"))).numpy()
                for i in range(0, len(sample), 16)
            ])
        del fp
        diff = np.abs(fp_probs - pv[: len(sample)])
        agree = {"rows": len(sample), "max_abs_prob_diff": round(float(diff.max()), 4), "mean_abs_prob_diff": round(float(diff.mean()), 5)}

    # 3. Held-out: int8 alone, the keyword floor alone, and the union the app runs.
    held = read_heldout(data / "heldout.jsonl", None)
    ph = model.probs([r["text"] for r in held])
    model_pred = [predicted_labels(p, labels, thresholds) for p in ph]
    keyword_pred = [{k} if (k := keyword_kind(r["text"])) else set() for r in held]
    union_pred = [m | k for m, k in zip(model_pred, keyword_pred, strict=True)]
    preds = {"model": model_pred, "keywords": keyword_pred, "union": union_pred}
    report = {
        "run": str(run),
        "heldout_rows": len(held),
        "by_class_lang": {k: class_lang_report(held, p) for k, p in preds.items()},
        "recall": {k: recall_report(held, p) for k, p in preds.items()},
        "int8_vs_fp32": agree,
        "thresholds": dict(zip(labels, thresholds, strict=True)),
        "latency_cpu": {f"{n}_threads": latency_ms(OnnxCrisis(out / "guardian.int8.onnx", run, cfg["max_len"], n)) for n in (1, 4)},
    }

    # 4. Canaries, from this model.
    canaries = []
    for c in CANARIES:
        p = model.probs([c["text"]])[0]
        fired = sorted(predicted_labels(p, labels, thresholds) - {"none"})
        canaries.append({**c, "model_crisis": bool(fired), "model_labels": fired, "ok": bool(fired) == c["crisis"]})
    (out / "canaries.json").write_text(json.dumps(canaries, indent=2, ensure_ascii=False), encoding="utf-8")
    report["canaries_ok"] = all(c["ok"] for c in canaries)

    hashes = {f: sha256(out / f) for f in APP_FILES}
    (out / "verified.json").write_text(json.dumps(hashes), encoding="utf-8")
    report["files"] = {f: {"sha256": hashes[f], "bytes": (out / f).stat().st_size} for f in APP_FILES}
    report["dart_define"] = f"TL_GUARDIAN_SHA256={dart_define(hashes)}"
    (out / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")

    u = report["by_class_lang"]["union"]
    for lang, v in u.items():
        cells = "  ".join(f"{lab} {s['recall']}/{s['precision']} (n={s['n']})" for lab, s in v["labels"].items() if s["n"])
        typer.echo(f"{lang:9} any {v['any_crisis']['recall']} FA {v['any_crisis']['false_alarm_rate']} | {cells}")
    typer.echo(f"size {report['files']['guardian.int8.onnx']['bytes'] / 1e6:.1f} MB  latency {report['latency_cpu']}  canaries ok: {report['canaries_ok']}")
    typer.echo(report["dart_define"])


if __name__ == "__main__":
    app()
