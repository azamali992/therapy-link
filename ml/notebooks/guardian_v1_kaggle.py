"""Guardian v1 on a Kaggle T4: train the crisis head on two encoders and report on the held-out set.

Pushed as a PRIVATE script kernel with the private dataset `therapylink-guardian-v1-data` (the
built splits from `python -m therapylink_ml.data.guardian_v1 build` plus a copy of therapylink_ml).
Outputs land in /kaggle/working/runs/<name>/: model.pt, config.json, thresholds.json, metrics.json,
heldout_report.json and the tokenizer files. ONNX export and the latency check run locally on CPU.

Both encoders read the same XLM-R sentencepiece vocabulary, so either one runs behind the app's
Dart tokenizer unchanged; the pick between them is size and on-phone latency against recall.
"""

import glob
import os
import shutil
import subprocess
import sys
import time

START = time.time()
subprocess.run([sys.executable, "-m", "pip", "install", "-q", "typer", "rich", "onnx", "onnxruntime", "onnxscript"], check=True)

SRC = os.path.dirname(glob.glob("/kaggle/input/**/build/labeled.crisis.train.jsonl", recursive=True)[0])
CODE = os.path.dirname(glob.glob("/kaggle/input/**/code/therapylink_ml/__init__.py", recursive=True)[0])
WORK = "/kaggle/working/code"
shutil.copytree(os.path.dirname(CODE), WORK, dirs_exist_ok=True)
os.chdir(WORK)
env = {**os.environ, "PYTHONPATH": WORK, "PYTHONUNBUFFERED": "1", "TOKENIZERS_PARALLELISM": "false"}
print("data:", SRC, os.listdir(SRC))
subprocess.run(["nvidia-smi"])

RUNS = {
    # name: (base, lr, epochs)
    "xlmr-base": ("FacebookAI/xlm-roberta-base", "3e-5", "5"),
    "minilm-l12": ("microsoft/Multilingual-MiniLM-L12-H384", "6e-5", "8"),
}
results = {}
for name, (base, lr, epochs) in RUNS.items():
    out = f"/kaggle/working/runs/{name}"
    t0 = time.time()
    rc = subprocess.run(
        [sys.executable, "-u", "-m", "therapylink_ml.train.guardian", "train", "--task", "crisis", "--base", base,
         "--data-dir", SRC, "--out", out, "--epochs", epochs, "--lr", lr, "--batch", "32", "--max-len", "128",
         "--no-with-authored", "--no-freeze-embeddings", "--lang-recall", "0.98", "--seed", "13"],
        env=env,
    ).returncode
    train_min = (time.time() - t0) / 60
    # Exit 1 means some group is below 95%; the report is written either way.
    hrc = subprocess.run(
        [sys.executable, "-u", "-m", "therapylink_ml.train.guardian", "heldout", f"{SRC}/heldout.jsonl", "--run", out, "--probes-in-heldout"],
        env=env,
    ).returncode
    subprocess.run([sys.executable, "-u", "-m", "therapylink_ml.train.guardian", "probe", "--run", out], env=env)
    # Export here rather than on the laptop, whose RAM is shared with other work. Only the int8 file
    # leaves Kaggle; the fp32 graph is dropped, and the XLM-R checkpoint too once exported.
    subprocess.run([sys.executable, "-u", "-m", "therapylink_ml.train.guardian", "export-onnx", "--run", out], env=env)
    for f in ["guardian.onnx", "guardian.onnx.data"] + (["model.pt"] if name == "xlmr-base" else []):
        if os.path.exists(f"{out}/{f}"):
            os.remove(f"{out}/{f}")
    results[name] = {"train_rc": rc, "heldout_rc": hrc, "train_minutes": round(train_min, 1)}
    print(name, results[name], flush=True)

print("all done", results, f"{(time.time() - START) / 3600:.2f} h")
with open("/kaggle/working/runs/summary.txt", "w") as f:
    f.write(repr(results))
shutil.rmtree(WORK, ignore_errors=True)
