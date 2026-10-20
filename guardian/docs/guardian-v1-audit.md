# Guardian v1 audit

Written 2026-10-21 from the files in this repo. Numbers come from `ml/releases/guardian-v1b/report.json`, `ml/data/guardian/DATA_CARD.md` and `ml/therapylink_ml/train/guardian.py`; nothing here was re-measured.

## What v1 is

- One `FacebookAI/xlm-roberta-base` encoder (278M params) with a linear head per task. Only the `crisis` head ships. It is multi-label over a fixed tuple of 8 labels: `none, suicidal, self_harm, abuse, child, sexual_violence, harm_to_others, medical` (`CRISIS_LABELS` in `ml/therapylink_ml/train/guardian.py`).
- Input: one user message, max 128 tokens, no conversation context at inference (the label guide allows up to three earlier turns; the shipped model never sees them).
- Loss: BCE. Thresholds: one per label, calibrated on the validation split to hit 0.95 recall. The shipped `thresholds.json` is `none: 0.5` and `0.02` for every risk label, which means "fire on almost anything". That is why precision on the held-out set is 0.34 to 0.62 per class.
- Export: dynamic int8 ONNX, opset 17, 278 MB (`guardian.int8.onnx`), plus a SentencePiece vocab JSON for a Dart tokenizer. CPU latency on an i5-12450H: 52 ms at 64 tokens single thread, 63 ms at 128 tokens two threads.
- A keyword floor (regexes for suicide, sexual violence, abuse, minors, in English, Roman Urdu and Urdu script) runs under the model and is mirrored line for line in Dart. On the held-out set the keywords alone detect 29.6% of crises; the model 97.2%; the union 97.5%.
- There was a v1a (Multilingual-MiniLM-L12, worse AUC, dropped) and the project memory records a v1c with a pruned vocabulary (31k tokens, 110 MB). **v1c's release directory is not in this repo** and the registry (`ml/registry.json`) has no guardian entry at all. Only `ml/releases/guardian-v1b/` exists, so v1b is the only release that can be audited.

## What it was trained on

Training split: 20,005 rows. From the data card:

| Source | Rows (train) | What it is | Labels from | Licence |
|---|---:|---|---|---|
| written batches | 4,498 | Messages written by Claude subagents, one brief per batch, one language per batch | The generating model, then a relabel pass against the guide (115 rows changed) | Project-owned |
| respellings of those | 2,401 | Roman Urdu spelling swaps (nahi/nai/nhi, hai/hy/h), Urdu keyboard variants, emoji noise | Inherited | Project-owned |
| machine translations | 6,953 | English written rows and short mh_text posts through `Helsinki-NLP/opus-mt-en-ur`, then a crude rule romaniser (`urdu/transliterate.py`) | Inherited from the English row | Inherited |
| mh_text | 4,279 | Real Reddit posts, suicidal vs not | Subreddit of origin | CC BY 4.0 |
| urdu_mh | 1,790 | Urdu-script tweets used as `none` only | Dataset's own label; ~97% of the dataset is itself opus-mt translation of English | CC BY 4.0 |
| authored rows | 84 | Hand-written conversations from the app's authoring set | Category of the conversation | Project-owned |

Rows per language form (train / val / held-out):

| Form | train | val | held-out |
|---|---:|---:|---:|
| en | 5,845 | 525 | 314 |
| ur-roman | 6,015 | 269 | 318 |
| mixed | 1,738 | 171 | 297 |
| ur (script) | 6,407 | 146 | 313 |

Where the Urdu came from, by form:

- **Urdu script.** Mostly machine translation (opus-mt-en-ur) of English rows, plus urdu_mh tweets (themselves mostly opus-mt output), plus some written batches. Translationese dominates. The data card admits the translations are "stiff" and that opus-mt drifts into Bible verses (a regex drops those).
- **Roman Urdu.** Three sources: subagent-written batches, respelled copies of those, and the romaniser applied to the machine-translated Urdu. The romaniser drops short vowels ("mire shohr ne") and the data card says it "reads unlike real typing". No real Pakistani Roman Urdu text from the wild is in the training set.
- **Mixed.** Subagent-written only.

## Where the labels came from

Every label is AI-assigned except: the 84 authored rows (category assigned by whoever wrote the conversation), the 48 eval probes, and mh_text's subreddit labels (which are not labels of the message; they are the forum it was posted in). The data card is explicit: "Every label is AI-assigned ... The guide wants two labels per item and kappa >= 0.75 on suicidal and self_harm. Nobody has done that." No licensed clinician has labelled or adjudicated any row. The held-out set was written by different subagents under a different brief, then relabelled row by row against the guide by the AI team.

## What the 97% on 1,242 held-out messages measures

- The held-out split is 1,242 rows: 1,194 from four subagent-written batches (h01 to h04) plus the 48 safety and therapeutic eval probes. 713 rows carry a risk label, 529 are `none`.
- The 97.2% is **any-crisis detect recall**: the model fired at least one risk label on 693 of the 713 risk rows. It is not per-class accuracy, and it is not exact-label recall (that is 93.3%).
- Per form: en 98.3%, mixed 98.3%, ur-roman 97.2%, ur 95.0%. False-alarm rate on the `none` rows: en 14.8%, mixed 9.7%, ur-roman 18.8%, ur 15.9%. With the keyword union the false-alarm rate rises to 17.8% to 25.4%.
- Limits, in order of how much they matter:
  1. **Same generator both sides.** Train and held-out messages were written by the same family of models under briefs written by the same team. A different brief is not a different distribution. The 0.35 Jaccard leak check removes near-copies, not style.
  2. **Labels are AI-assigned on both sides.** 97% means the model agrees with the labelling model 97% of the time. It says nothing about agreement with a clinician.
  3. **Thresholds at 0.02** buy recall with a 15 to 25% false-alarm rate on a `none` set that is 42 to 53 hard negatives per form. On real chat the false-alarm rate is unknown; the project memory records "my boss is stressing me out" firing `sexual_violence` at 0.91.
  4. **Small classes.** `child` 51, `harm_to_others` 43, `medical` 41 rows across all four forms; per form these are 10 to 15 items, so "100% recall" has a Wilson lower bound near 0.72.
  5. **Urdu-script and Roman Urdu held-out rows are also synthetic**, so the per-form numbers do not measure how the model does on text Pakistanis actually type.
  6. **No CIs are reported anywhere** in report.json.
  7. **fp32 vs int8 agreement is null**: the fp32 checkpoint was deleted on Kaggle after export, so nobody knows what quantisation cost.

## Sources the paper evaluates on: did v1 ever touch them?

Grep over the whole repo (py, md, json, jsonl, ipynb, dart, toml, txt, yml; venvs and build dirs excluded) for `aegis`, `indicguard`, `indicsafe`, `xl-sum`/`xlsum`, `ruhsold`, `cyberbull`, `purutt`, `hasoc`, case-insensitive:

| Source | Hits in repo | v1 touched it |
|---|---:|---|
| Aegis 2.0 (any split) | 0 | No |
| IndicGuard | 0 | No |
| IndicSafe | 0 | No |
| XL-Sum (BBC Urdu) | 0 | No |
| RUHSOLD | 0 | No |
| Urdu Cyberbullying corpus | 0 | No |
| PURUTT | 0 | No |
| HASOC (any language) | 0 | No |

The only public text in v1 is mh_text (Reddit, English), urdu_mh (Zenodo 19232922, Urdu tweets), GoEmotions (emotion head, not shipped) and the opus-mt-en-ur translator. None overlap the paper's evaluation sets. v1 is clean with respect to hard rule 1.

## What cannot be reused for a general guardrail

- **The taxonomy.** v1's labels are about who needs which helpline (suicide, abuse, child, medical). A general guardrail needs violence/threats, harassment, hate, sexual content, self-harm, and benign. Only `self_harm`+`suicidal` (as one descriptive label) and `harm_to_others` (as a seed for violence) map across. `abuse`, `child`, `sexual_violence` and `medical` are victim-disclosure labels, not content-harm labels; a guardrail must not block a person disclosing abuse.
- **The training data.** Every row is a first-person disclosure to a support chatbot. There is no harassment, no hate, no threats aimed at a third party, no sexual content that is not a disclosure of assault, and no benign chat that is not distress. Reusing it would teach a guardrail to flag victims.
- **The held-out set and its 97%.** Same generator, AI labels, wrong taxonomy. It cannot be cited for v2 at all.
- **The keyword floor.** Written for suicide and abuse disclosure. The Roman Urdu patterns in it (e.g. `khud ?kushi`, `jaan de`, `maar(ta|ti|te)`) are a useful seed list for the Roman Urdu spelling-variant table, nothing more.
- **The thresholds and calibration method** (0.02 everywhere, one recall target). A guardrail needs a false-alarm rate it can state per form.
- **The 128-token single-message input** is fine to keep for a moderation endpoint; most moderation inputs are one message.

What can be reused:

- The XLM-R export path (`guardian_bundle.py`: torch to ONNX opset 17, dynamic int8, hash manifest, canaries) as a reference for v2's export script, rewritten without app references.
- The respelling tables in `guardian_v1.py` (`respell_roman`, `respell_urdu`) as the start of the variant sampler in `guardian/data/translit.py`.
- The idea of a `provenance` column (v1's `source`, `author`, `generated`, `ai_labelled`, `commercial_ok`) but widened to carry licence, original label, and how the Urdu was produced.
- The Kaggle push and run helpers (`kaggle_push.py`) as the way to launch v2's notebook.
- `urdu/transliterate.py` as a baseline romaniser to beat, not to ship.

## Decisions for v2

1. v2 starts from no v1 data. Not one v1 row enters v2's training or evaluation sets. v1's held-out set is not an evaluation set for v2.
2. v2's taxonomy is built from Aegis 2.0, mapped to Llama Guard 3, Qwen3Guard and OpenAI omni-moderation, with protective harms first class and self-harm and sexual content descriptive. v1's labels are not in it.
3. The v1 int8 ONNX model is wired behind the v2 API as a clearly labelled placeholder so the server starts today. Its labels are mapped to `self_harm` (suicidal, self_harm) and `violence` (harm_to_others) and nothing else; every other v1 label is dropped, since they are disclosures, not harms. The placeholder is removed the day a v2 model exists.
4. Every row in v2 carries `provenance.labels_from` (`human`, `model`, `inherited`) and `provenance.urdu_from` (`human`, `machine`, `transliterated`, `native`). The data manifest reports counts by those fields so nobody can repeat the v1 mistake of citing synthetic recall as if it were real.
5. v2 reports 95% confidence intervals on every rate, per form, and never reports a rate without its denominator.
6. v2 keeps 128 tokens and single-message input for the moderation endpoint.
7. The keyword floor is not part of v2. A guardrail that fires on `maar` would block half of Pakistani chat.
