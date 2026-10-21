"""Guardian v2 on Kaggle (2x T4): train the primary and the fallback on the full mix, export, run the harness.

Push as a PRIVATE script kernel with one private dataset holding:
    guardian/           this directory (src, data/build/*.jsonl, train, tests, pyproject.toml), as `code/guardian`
Settings: GPU T4 x2, Internet on. Outputs land in /kaggle/working/runs/<name>/ and are copied back with
`kaggle kernels output`. Nothing here reads the evaluation split; the harness run at the end uses the val
split only. The Aegis test split stays untouched until the model is frozen and tagged.
"""

import glob
import os
import shutil
import subprocess
import sys
import time

START = time.time()
subprocess.run([sys.executable, "-m", "pip", "install", "-q", "peft", "onnx", "onnxruntime", "tokenizers"], check=True)

CODE = os.path.dirname(glob.glob("/kaggle/input/**/code/guardian/pyproject.toml", recursive=True)[0])
WORK = "/kaggle/working/guardian"
shutil.copytree(CODE, WORK, dirs_exist_ok=True)
os.chdir(WORK)
subprocess.run([sys.executable, "-m", "pip", "install", "-q", "-e", "."], check=True)
env = {**os.environ, "PYTHONUNBUFFERED": "1", "TOKENIZERS_PARALLELISM": "false"}
subprocess.run(["nvidia-smi"])

# Every train file is checked against the evaluation-set hashes before anything trains.
for f in glob.glob("data/build/*.jsonl"):
    subprocess.run([sys.executable, "-I", "data/exclusion.py", f], check=True)

RUNS = {
    # name: argv for train/train_encoder.py. --rows 0 means every row; --steps 0 means full epochs.
    "xlmr-lora-r8": ["--base", "FacebookAI/xlm-roberta-base", "--rows", "0", "--steps", "0", "--epochs", "3", "--batch", "32", "--lr", "2e-4", "--lora-r", "8"],
    "mdeberta-lora-r8": ["--base", "microsoft/mdeberta-v3-base", "--rows", "0", "--steps", "0", "--epochs", "3", "--batch", "32", "--lr", "2e-4", "--lora-r", "8"],
}
MAX_HOURS = 10
for name, argv in RUNS.items():
    if (time.time() - START) / 3600 > MAX_HOURS - 2:
        print(f"skipping {name}: not enough session time left")
        continue
    out = f"/kaggle/working/runs/{name}"
    t0 = time.time()
    rc = subprocess.run([sys.executable, "train/train_encoder.py", *argv, "--out", out], env=env).returncode
    print(f"{name}: rc={rc} {(time.time() - t0) / 60:.0f} min")
    if rc != 0:
        continue
    subprocess.run([sys.executable, "-m", "urduguard.export", f"{out}/model", f"{out}/export", "--name", name], env=env, check=True)
    subprocess.run([sys.executable, "-m", "urduguard.eval.harness", "--backend", f"urduguard:{out}/export:strict", "--data", "data/build/val.jsonl",
                    "--forms", "en", "ur", "roman_ur", "--out", f"{out}/eval-val"], env=env, check=True)
    shutil.rmtree(f"{out}/model", ignore_errors=True)  # keep the export, drop the fp32 checkpoint (size)

print(f"done in {(time.time() - START) / 3600:.1f} h")
