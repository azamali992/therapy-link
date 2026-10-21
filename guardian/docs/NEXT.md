# What to run next

Written 2026-10-21 at the end of the scaffold session. Everything below is what the scaffold proved it can run, scaled up. Nothing here has produced a number worth quoting.

## What exists and was run

| Piece | State | Evidence |
|---|---|---|
| Data pipeline | ran end to end on Aegis 2.0 (train, validation) and IndicGuard (Urdu train, valid) | `data/MANIFEST.md`: train 50,340 rows (en 16,191 / ur 17,360 / roman_ur 16,788), val 2,610; 5,368 religious rows removed, 394 minors, 300 first-person self-harm; 396 evaluation-set duplicates dropped |
| Evaluation-set exclusion | 9,389 text hashes and 2,964 ids over Aegis test and IndicGuard English/Urdu test; checked in CI | `data/hashes/eval_exclusion.json`, `data/exclusion.py` |
| Eval harness | ran on a real guard model | `runs/eval/qwen3guard-gen-0.6b-aegis-train/report.md` |
| Package, CLI, server | start and answer with the placeholder model | `tests/` (32 tests), `models/v1-crisis-placeholder/` |
| CI gate | fixture backend, baseline written | `.github/workflows/guardian-gate.yml`, `tests/fixtures/` |
| Smoke training 1 | char CNN from scratch, 1,891 rows, 8 epochs, 10 s | `runs/charcnn-smoke/`, `runs/eval/charcnn-smoke-val/report.md` |
| Smoke training 2 | XLM-R base, LoRA r=8, 2,000 rows, 300 steps | `runs/xlmr-lora-smoke/`, `runs/eval/xlmr-lora-smoke-val/report.md` |

## The comparison table, first rows

All rows are smoke-scale and read `data/build/val.jsonl` (the validation split, never the test split). The Roman Urdu column is rule-transliterated text with spelling variants, not text a person typed, so it measures robustness to the transliterator as much as to Roman Urdu. Catch rate is on protective items (violence_threats, harassment, hate_group), false-alarm rate on benign items, 95% intervals in the report files.

| System | Train rows | en catch | roman_ur catch | ur catch | en false alarm | roman_ur FA | ur FA | R1 roman_ur | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| Qwen3Guard-Gen-0.6B, strict, as released | 0 (zero-shot) | 93.4% | 34.4% | 81.6% | 23.6% | 32.5% | 42.2% | not cleared (gap +59, CI [+47, +70]) | 300 paired Aegis train items, 891 rows, 514 s on the RTX 2050. Its "unsafe" on any category counts as flagged. |
| char CNN from scratch (smoke) | 1,891 | 27.9% | 21.3% | 21.7% | 11.8% | 9.0% | 9.4% | not cleared (gap +6.7, CI [+0.3, +13.1]) | 282k params, 0.3 MB int8. A floor, not a candidate. |
| XLM-R base LoRA r=8 (smoke) | 1,891 | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | cleared (gap 0), but R2 not cleared | 119 steps (one epoch), 30 s, peak 2.4 GB; the export is 279 MB int8 and scores 2,132 val rows in 562 s on CPU. Sits at the all-negative solution. Shows why R1 and R3 alone can never clear a model: R2 is the floor. |

What the Qwen row already shows, and the paper should check on the real test set: a released multilingual guard that holds up on Urdu script (82%) collapses on Roman Urdu (34%), and its false-alarm rate is higher in both Urdu forms than in English. That is exactly the pattern the parity gate exists to catch. It is also exactly the kind of number that must not be quoted from train items or from transliterated text.

## Run this on Kaggle

Notebook: `notebooks/guardian_v2_kaggle.py`. Push it as a private script kernel with a private dataset holding `guardian/` (with `data/build/*.jsonl` built locally first). GPU T4 x2, Internet on. It installs the package, re-checks every train file against the exclusion hashes, trains the primary and the fallback, exports both to int8 ONNX and runs the harness on the val split.

Before the first launch:

1. Add the native Roman Urdu sources from `docs/research/02-training-data.md` to `data/sources.json` and `data/build.py`: RUT (`hafiz-hassaan-saeed/Roman-Urdu-Toxic-Corpus`, CC BY 4.0) and PURUTT after a 200-row audit of what "toxic" means there, and RUHSOLD from the GitHub TSVs minus its Religious Hate class. Without them every Roman Urdu training row is transliterated and the Roman Urdu numbers are about the transliterator.
2. Rebuild, re-run `data/exclusion.py` on the build, commit the new `MANIFEST.md`.
3. Decide the `Sexual (minor)` rows: the build currently drops them (minors filter). Keep that unless the paper needs them.

### Training mix (current build)

| Form | benign | violence_threats | harassment | hate_group | self_harm | sexual | needs_caution |
|---|---:|---:|---:|---:|---:|---:|---:|
| en | 8,708 | 1,849 | 1,584 | 1,606 | 206 | 946 | 3,049 |
| ur (Google-translated) | 9,179 | 2,055 | 1,658 | 2,126 | 239 | 1,018 | 2,996 |
| roman_ur (transliterated) | 8,948 | 2,055 | 1,602 | 2,017 | 233 | 1,018 | 2,885 |
| mixed | 1 | 0 | 0 | 0 | 0 | 0 | 0 |

The `mixed` form is empty. Make mixed rows by splicing English spans from the paired Aegis row into the Urdu or Roman Urdu row at the word level (`translit.codemix` does word-level substitution; sentence-level mixing is not written yet).

### Starting hyperparameters

| | primary: XLM-R base | fallback: mDeBERTa-v3-base |
|---|---|---|
| adapter | LoRA r=8, alpha 16, dropout 0.05 on query, key, value, dense | same |
| batch, seq len | 32, 128 | 32, 128 |
| lr, schedule | 2e-4, linear warmup 5%, decay to 0 (the smoke script has no schedule yet; add one) | 2e-4 |
| epochs | 3, keep the best val macro-F1 checkpoint | 3 |
| loss | BCE with logits; try positive weights for self_harm (206 rows) | same |
| fp16 | yes | try fp32 first if the loss goes NaN |
| time per epoch, 50k rows, one T4 | about 15 min (estimate: 50k rows / (32 rows x 1.6 steps/s)) | about 20 min |
| then | `python -m urduguard.export`, harness on val, calibrate per-form thresholds on val, write the coverage card, freeze, tag | same |

Thresholds: after training, pick per-form thresholds on the val split for strict (catch-rate target) and loose (false-alarm target), write them into `config.json` under `thresholds.strict.<form>` and `thresholds.loose.<form>`, and run the harness again. Only then does R1 to R3 mean anything.

Freeze order (hard rule 2): tag the model and its hash before any hand-rendered Urdu test items exist. The Aegis test split stays untouched until then.

## The three things most likely to go wrong

1. **The Roman Urdu numbers are about the transliterator.** `translit.py` rule-v0 drops short vowels on unlexiconed words ("mlom" for maloom, "gazr" for guzar) and the respelling table is mostly one person's observation, not attested frequencies. A model that scores well on this Roman Urdu has learned the transliterator's habits. Fix: add the native sources (step 1 above) and hold out a native Roman Urdu dev set before believing any Roman Urdu number. The perturbation test in `docs/research/04-architecture.md` section 5 has to run on native text.
2. **The religious filter is broad and leaks both ways.** It removed 5,368 source rows by keyword (words like "god", "holy", "ram", "cult" match far beyond religion) and it will still miss transliterated or misspelt religious words. Review `data/filters.py` RELIGION_WORDS with a native speaker, and run the filter on the eval set with the same list so the paper's eval and the training data are filtered identically.
3. **Train-set noise from Aegis prompt labels.** Aegis labels are per prompt but some rows are later turns of a dialogue ("The man is an idiot" carries Suicide and Self Harm). The out-of-scope drop and the first-person filter removed some, not all. A 200-row audit per label before the full run will show how much label noise the gate will inherit. Also: 243 Aegis train prompts duplicate test prompts under other ids; the build drops them, but any other source derived from Aegis (CultureGuard, Nemotron v3) carries the same duplicates and must go through `exclusion.py` too.

Two smaller ones: the form detector is a word list and will route short English messages with "yaar" to roman_ur; and the `loose` mode thresholds are placeholders at 0.5 and 1.1 until calibration runs.
