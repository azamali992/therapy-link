# Guardian v1 data card

Training, validation and held-out data for Guardian v1's crisis head: one user message in, a multi-label verdict over `none, suicidal, self_harm, abuse, child, sexual_violence, harm_to_others, medical` out. Labels follow `docs/clinical/GUARDIAN_LABELS.md` (AI clinical review, 2026-10-03). **No licensed clinician has labelled or adjudicated any of it yet**, so the held-out numbers are provisional and gate MG-11 can't be signed on them.

## Rebuild

```powershell
$py = "D:\therapylink\ml\.venv\Scripts\python.exe"
& $py -m therapylink_ml.data.guardian_v1 fetch    # mh_text and urdu_mh (CC BY 4.0) into data/raw/guardian/
& $py -m therapylink_ml.data.guardian_mt run      # en -> Urdu script -> rough Roman Urdu (opus-mt-en-ur); ran on a Kaggle T4
& $py -m therapylink_ml.data.guardian_v1 build    # writes data/guardian/build/ (gitignored)
```

`build/` and `mt/` are gitignored and rebuild from what is committed: `written/`, `heldout/`, `relabel_guide_v1.jsonl`, the authored rows and the eval probes. The build is deterministic (seed 13).

## What is in it

| Split | Rows | Where from |
|---|---:|---|
| train | 20,005 | written batches 4,498, their respellings 2,401, machine translations 6,953, mh_text 4,279, urdu_mh 1,790, approved authored rows 84 |
| val | 1,111 | 15% of every written batch per label set (788), authored 23, mh_text 300 (posts longer than the translator takes, so none reach training translated) |
| test (held-out) | 1,242 | held-out batches h01-h04 (1,194) and the 48 safety and therapeutic eval probes |

Label counts per language (a row can carry several labels):

**train**

| lang | none | suicidal | self_harm | abuse | child | sexual_violence | harm_to_others | medical | rows |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| en | 3,415 | 1,906 | 135 | 235 | 109 | 176 | 21 | 5 | 5,845 |
| ur-roman | 2,787 | 1,961 | 313 | 553 | 253 | 356 | 131 | 85 | 6,015 |
| mixed | 768 | 401 | 159 | 196 | 104 | 163 | 83 | 92 | 1,738 |
| ur | 3,807 | 1,741 | 234 | 351 | 156 | 244 | 75 | 37 | 6,407 |

**val**

| lang | none | suicidal | self_harm | abuse | child | sexual_violence | harm_to_others | medical | rows |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| en | 261 | 192 | 22 | 33 | 12 | 20 | 2 | 0 | 525 |
| ur-roman | 133 | 45 | 18 | 39 | 16 | 24 | 14 | 7 | 269 |
| mixed | 83 | 38 | 16 | 18 | 8 | 13 | 6 | 6 | 171 |
| ur | 53 | 34 | 16 | 25 | 9 | 15 | 5 | 3 | 146 |

**held-out**

| lang | none | suicidal | self_harm | abuse | child | sexual_violence | harm_to_others | medical | rows |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| en | 135 | 77 | 48 | 33 | 13 | 28 | 11 | 10 | 314 |
| ur-roman | 138 | 73 | 47 | 33 | 11 | 25 | 10 | 11 | 318 |
| mixed | 124 | 71 | 46 | 31 | 12 | 25 | 11 | 10 | 297 |
| ur | 132 | 76 | 48 | 34 | 15 | 25 | 11 | 10 | 313 |

Every row says where it came from: `source` (written, augmented, mt, mh_text, urdu_mh, tl_authored, eval_probe), `author` (the batch or dataset), `generated` (written for this project), `ai_labelled` (labels assigned by a model, not a person) and `commercial_ok`.

## Sources

- **Written batches** (`written/t*.jsonl`, `heldout/h*.jsonl`). Messages written by Claude subagents for this project, one brief per batch, each in one language and style. Generated and AI-labelled. They were labelled under `LABEL_RULES.md` while the clinical guide was being written, then reconciled with it: `relabel_guide_v1.jsonl` changes 115 training rows (mostly `harm_to_others` dropped from threats aimed at the user, rule 12, and the writer's own past attempts or self-harm moved from `none` to a risk label, rule 6; a friend's or relative's resolved past stays `none`, since rule 5 is about current risk), the build drops a lone `child` from a minor's own suicidal or self-harm message (rule 13), and the held-out batches were relabelled row by row against the guide, with `acuity`, `hard_negative`, `distress` and `who` added.
- **Respellings** (`augmented`). One copy of each written training row with Roman Urdu words swapped for other common spellings (nahi/nai/nhi, hai/hy/h, khudkushi/khud kushi), Urdu-script keyboard variants (ہے/ھے, Arabic yeh and kaf), case, punctuation and emoji noise. Only training rows; never val or test.
- **Machine translation** (`mt`). English written rows and short mh_text posts through opus-mt-en-ur, then the repo's crude romaniser (`urdu/transliterate.py`), each keeping its English row's labels. Translations whose length is off or that quote scripture (opus-mt drifts into Bible verses) are dropped. Translationese, so training only.
- **mh_text** (CC BY 4.0, commercial use allowed). 1,500 suicidal and 2,500 other real Reddit posts (v1a used 3,000/5,000, which made English mostly long Reddit text), suicidal vs not, labelled by subreddit. A `none` post the keyword floor reads as suicidal is dropped, since subreddit labels put "I want to die" posts from r/depression under `none`.
- **urdu_mh** (CC BY 4.0). Urdu-script tweets, used as `none` only, minus any that mention dying. About 97% machine-translated (see the registry note).
- **tl_authored**. The approved authored rows, labelled by category as `guardian.py` always has.

Left out: EmpatheticDialogues and ESConv (CC BY-NC) and CounselChat (terms unverified). None of them has Guardian labels anyway. Every row in every split has `commercial_ok: true`, and the build refuses to write a split that doesn't.

## Held-out set

Written apart from training: separate subagents, a different brief (invented personas, replies mid-conversation, risk late in long messages, indirect wording in at least half the crisis rows), and no access to the training batches. Train and val rows whose word-overlap Jaccard with any held-out row is 0.35 or more are dropped (the guide's rule, §5), as is any translation whose English source is that close. The 24 safety probes are part of the held-out set. Thresholds are calibrated on val, not on the probes, so they can be.

Against the guide's §5 targets: every language has 117 to 125 `suicidal` + `self_harm` positives (target 60) and 31 to 34 `abuse` (target 30). `child` (11 to 15), `sexual_violence` (25 to 28), `harm_to_others` (10 to 11) and `medical` (10 to 11) are below the 30 the guide asks for, and hard negatives are 42 to 53 per language (target 60). Recall on those small classes has wide intervals: 10 of 10 has a Wilson 95% lower bound of 0.72.

## Known gaps

- **No method or dose questions, and no detailed attempt descriptions, were generated.** The content limits in `LABEL_RULES.md` keep them out, and several English and Roman Urdu suicide batches were stopped by a safety classifier and not retried. mh_text carries some real ones in English. Guide rule 3 and the S6/M1 kind of message need clinician-written rows.
- **English `medical` (5 rows) and `harm_to_others` (20 rows) are thin in training, and validation has 0 and 2.** The English batch for them was never written, so their thresholds are set by the pooled languages.
- **Every label is AI-assigned** except the authored rows, the probes and mh_text's subreddit labels. The guide wants two labels per item and kappa ≥ 0.75 on `suicidal` and `self_harm`. Nobody has done that.
- **Annotator calls the clinician has to rule on:** safe-use dosing questions ("how many fever tablets a day is safe") are `none` here, though rule 3 read literally makes every dose question `suicidal`; a friend's or relative's resolved past attempt or abuse is `none` in training (I read rule 5 as current risk; the annotator had applied rule 6); `who` on `none` rows was filled inconsistently.
- Roman Urdu from the romaniser drops short vowels ("mire shohr ne") and reads unlike real typing. Urdu-script translations are stiff.
