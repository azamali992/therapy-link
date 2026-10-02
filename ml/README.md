# ml/

Data pipeline, training and evaluation for TherapyLink's two models.

| Model | What it is | Trains on |
| --- | --- | --- |
| **Guardian** | `XLM-RoBERTa-base` multi-task encoder with one head per task (crisis, emotion, valence, condition). The trained run, `guardian-v0`, has a **binary** crisis head (`none` / `suicidal`) trained on English text only, and it catches 0 % of the Roman Urdu and mixed crisis probes. Abuse, rape, child abuse and self-harm without suicidal intent have no label yet. | RTX 2050 / 4050 |
| **Eve** | Gemma 4 QLoRA counselling model. The runs so far (v13–v15) are **E2B**; `eve_sft.py` defaults to E4B, and a Qwen3.5-4B comparison is possible. | Kaggle T4 (E2B ~8 GB, E4B ~10 GB) |

### What ships today

Neither trained model reaches a patient in a default build:

- The app's on-device Eve downloads **stock** Gemma 4 E2B from `litert-community`, not a fine-tune. That base scored 7/24 on the safety probes and named a helpline on 1 of 14 crisis probes (`runs/eval/base-e2b`). The best fine-tune, v14 (18/24, 12/14), exists only as a LoRA GGUF served by llama-server, and every eval number so far comes from that GGUF path, not from the int8 `.litertlm` a phone would run. See [EXPORT.md](EXPORT.md).
- Guardian runs on the phone only when the app was built with `TL_GUARDIAN_URL` and the patient downloads it from Settings. Otherwise the app falls back to a keyword regex that caught about 12 % of the crisis probes (`runs/guardian-v0/probe_results.json`).

A multi-label, Roman Urdu-aware Guardian v1 (suicidal, self-harm, abuse, child, sexual violence, harm to others, medical) is planned, not trained. Details and the gates both models must pass are in `docs/ship-review/SHIP_PLAN.md`.

## Setup (local box)

```powershell
python -m venv .venv
.venv\Scripts\python -m pip install torch --index-url https://download.pytorch.org/whl/cu126
.venv\Scripts\python -m pip install -r requirements-local.txt -e .
```

## Build the corpus

```powershell
.venv\Scripts\tl-data list
.venv\Scripts\tl-data build            # everything
.venv\Scripts\tl-data build --only esconv --only annomi
```

Writes to `data/processed/`:

- `conversations.{train,val,test}.jsonl` — Eve training data, unified chat schema (`therapylink_ml/schema.py`)
- `labeled.{task}.{train,val,test}.jsonl` — Guardian training data
- `DATA_CARD.md` — per-source counts, licenses, and a non-commercial callout
- `samples.md` — three random examples per source; read this after every loader change

Raw downloads cache under `data/cache/` (gitignored).

First build (2026-09-14): 43,179 conversations and 178,120 labelled texts. EmpatheticDialogues is more than half the conversations but its listener turns are casual and sometimes flippant, so the SFT notebook down-weights it to ~15 % (`--weights empathetic_dialogues=0.15`). Read `samples.md` before changing weights.

## Layout

```text
therapylink_ml/
  schema.py            Conversation / Message / LabeledText + text cleaning
  data/registry.py     dataset registry with license metadata
  data/loaders/        one module per source; registers itself on import
  data/splits.py       exact dedupe + deterministic per-source split
  data/build.py        `tl-data` CLI
tests/
```

## Evaluating Eve

`tl-eval` runs the probes in `therapylink_ml/eval/probes/` against a model and scores the replies. Runs land in `runs/eval/<name>/`: `responses.jsonl` and `meta.json` from `generate`, then `scored.jsonl` and `summary.json` from `score`.

The ship-plan gate is 5 sampled replies plus one greedy reply per probe, with the prompt the app actually sends (`SERVED_SYSTEM_PROMPT` in `prompts.py`):

```powershell
.venv\Scripts\tl-eval generate --backend "openai:http://localhost:8080/v1|eve" --name eve-v16-served `
  --samples 5 --greedy --system served --model-id <gguf file> --adapter-id "eve-sft-v16 epoch 1"
.venv\Scripts\tl-eval score eve-v16-served
.venv\Scripts\tl-eval report base-e2b eve-v16-served --markdown runs\eval\compare.md
```

Safety is reported as worst-of-N over the samples and as the mean; the greedy reply is scored on its own. Rule checks come from `eval/safety_rules.py`, and an undecided check never counts as a pass.

### `tl-eval generate`

| Flag | What it does |
| --- | --- |
| `--backend` | `llamacpp:<gguf>`, `openai:<base_url>\|<model>` (a running llama-server) or `hf:<id>[\|<adapter>]` |
| `--name` | Run name; the output directory under `runs/eval/` |
| `--suite` | `all` (the headline probes, default) or one probe file's name without `.jsonl`, e.g. `safety` |
| `--include-drafts` | With `--suite all`, also run the `*_draft` probe files. They are reported apart and never enter the headline metrics |
| `--samples` | Draws per probe at `--temperature` (default 1). The gate uses 5 |
| `--greedy` | Also generate one temperature-0 reply per probe, scored separately |
| `--temperature` | Sampling temperature (default 0.7) |
| `--max-tokens` | Reply cap (default 400) |
| `--system` | `training` (`EVE_SYSTEM_PROMPT`, the prompt Eve trains on, default) or `served` (what the app sends) |
| `--notes-file` | Memory/summary notes to add after the system prompt, as the app does |
| `--notes-layout` | `fold` (notes after the system prompt) or `exchange` (a prior user turn and a short acknowledgement) |
| `--model-id` | What model this is (GGUF file name or HF id), recorded in `meta.json` |
| `--adapter-id` | Which adapter, e.g. `eve-sft-v14 epoch 2`, recorded in `meta.json` |
| `--dtype` | `hf` backend only: `bf16`, `fp32` or `auto`. Never fp16 for Gemma 4 |
| `--thinking` | Let the model emit reasoning tokens. Eve is trained without them |

`meta.json` also records the prompt and probe hashes and the git commit, so `report` refuses to put runs side by side when they answered different probes.

### `tl-eval rescore`

Re-applies the current `safety_rules.py` to stored replies after a rule change. Nothing is generated and no model server is called. Each run's `summary.json` is left alone; the new numbers go to `rescored.json` beside it, and a before/after table to `--out`.

| Flag | What it does |
| --- | --- |
| `NAMES` | Runs to re-score (default: every run with `responses.jsonl`) |
| `--out` | Markdown comparison (default `runs/eval/rescored-summary.md`) |

```powershell
.venv\Scripts\tl-eval rescore base-e2b sft-v14
```

### `tl-eval calibrate`

Measures agreement between the LLM judge and a clinician's labels. The judge's verdicts are advisory until this accepts it: Cohen's kappa at least `--min-kappa` and a false-pass rate at most `--max-false-pass`, pooled and for every criterion on its own. The labels are a CSV with this header:

```text
run,id,sample,criterion,human
```

`human` is `pass` or `fail`, and the judge's verdict is looked up in that run's `scored.jsonl` (score the run with `--judge-backend` first). Add a `greedy` column set to `true` to label the greedy reply, or give a `judge` column instead of `run,id,sample` to compare verdicts you already have.

| Flag | What it does |
| --- | --- |
| `LABELS` | The CSV above |
| `--min-kappa` | Lowest acceptable kappa (default 0.7) |
| `--max-false-pass` | Highest acceptable rate of judge passes on replies the human failed (default 0.05) |

```powershell
.venv\Scripts\tl-eval calibrate runs\eval\labels.csv
```

It writes `labels.calibration.json` next to the CSV.

## Guardian → phone

```powershell
$py = ".venv\Scripts\python"
& $py -m therapylink_ml.train.guardian train --task crisis --task condition --task emotion --epochs 3 --out runs\guardian
& $py -m therapylink_ml.train.guardian export-onnx --run runs\guardian          # guardian.onnx + guardian.int8.onnx (~265 MB)
& $py -m therapylink_ml.export.tokenizer_json --out runs\guardian\spm_vocab.json  # vocab for the Dart tokenizer
& $py -m therapylink_ml.export.tokenizer_reference --out runs\guardian\tokenizer_reference.json
```

Upload `guardian.int8.onnx`, `spm_vocab.json`, `config.json`, `thresholds.json` to a Hugging Face repo and set `TL_GUARDIAN_URL` when building the app. Copy `spm_vocab.json` and `tokenizer_reference.json` into `app/test/fixtures/` to run the tokenizer parity test.

Training on a 4 GB GPU needs the default `--freeze-embeddings`: the 250k-row embedding table is 70 % of XLM-R's parameters and its AdamW state alone would exceed VRAM.

## Tests

```powershell
.venv\Scripts\python -m pytest
```
