# Exporting Eve to the phone

Two artifacts come out of every training run. Both start from the same merged checkpoint.

| Artifact | Runtime | Used for |
|---|---|---|
| `.litertlm` | LiteRT-LM via `flutter_gemma` | The app, on-device (Android / iOS / web) |
| `.gguf` (Q4_K_M) | llama.cpp | Eval harness and the tunnelled cloud path on the 2050 box |

Only an adapter that passed the gate (`gate.json` next to it says `"passed": true`) and the local eval gets exported.

## 1. Merge into the float base

```powershell
.venv\Scripts\python -m therapylink_ml.export.merge runs\eve-sft\adapter --out runs\eve-merged --dtype float32
```

Unsloth trains against a pre-quantised repo and records it as the adapter's base (`unsloth/gemma-4-e2b-it-unsloth-bnb-4bit` for v14 and v15). Merging into that would bake 4-bit rounding into the "float" checkpoint that litetune converts and verifies against. `merge` maps the known Unsloth 4-bit repos to their float repo (`unsloth/gemma-4-E2B-it`) on its own, and fails on any other quantised base with a message to pass `--base <float repo>`. `training_prompt.json` is copied into the merged checkpoint, so it still says which system prompt it needs.

## 2. Check the merge (GGUF + eval)

A QLoRA adapter merged into a float base behaves slightly differently from the adapter on its 4-bit base, so re-run the eval on the merged model before converting anything for the phone:

```bash
python llama.cpp/convert_hf_to_gguf.py runs/eve-merged --outfile runs/eve-f16.gguf --outtype f16
llama.cpp/build/bin/llama-quantize runs/eve-f16.gguf runs/eve-q4_k_m.gguf Q4_K_M
```

Then the 48 probes on `runs/eve-q4_k_m.gguf` with the prompt from `training_prompt.json`. The hard gates must still hold; if they don't, the merge is the problem, not the adapter.

## 3. LiteRT-LM (app): convert, then verify

Use a separate venv, since litetune pins its own litert-torch.

```powershell
python -m venv .venv-export
.venv-export\Scripts\pip install -r requirements-export.txt
.venv-export\Scripts\litetune convert --model runs\eve-merged --output-dir runs\eve-litertlm --recipe weight_only_wi8_afp32
.venv-export\Scripts\litetune verify --model runs\eve-litertlm\weight_only_wi8_afp32\*.litertlm --reference runs\eve-merged --data data\processed\conversations.val.jsonl --json > runs\eve-litertlm\manifest.json
```

Conversion runs on CPU on purpose (reproducible); E2B fits in 16 GB RAM, E4B wants more, so run it on Kaggle if it swaps. `verify` reports the accuracy delta between the float merge and the quantised bundle; record it next to the on-device latency.

The stock int4 bundle is about 2.0 GB and a wi8 bundle will be larger (not measured yet). If it's too big, try an int4 recipe and re-run the full safety eval on it, because quantisation moves exactly these edge behaviours.

## 4. Publish

Upload the `.litertlm` to a Hugging Face repo and point `eveModelSpecs` in `app/lib/core/ml/gemma_eve_engine.dart` at it. Serve it with the prompt its `training_prompt.json` names; a model served a prompt it wasn't trained on drifts (v14: 18/24 safety with its own prompt, 12/24 with V2). Stock `litert-community` Gemma scored 7/24 and stays out of patient builds.
