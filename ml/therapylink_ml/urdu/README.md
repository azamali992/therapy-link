# Roman Urdu synthesis

There is no Roman Urdu counselling corpus. This builds one from the English corpus, and measures how natural the result is.

```text
stage1  translate.py      EN → Urdu script            opus-mt-en-ur, sentence-level
stage2  transliterate.py  Urdu script → rough Roman   rule-based seed, deliberately plain
stage3  restyle.py        seed → natural Roman Urdu   open LLM + few-shot real exemplars
stage4  verify.py         back-translate + similarity drop anything whose meaning drifted
stage5  rate.py           blinded human rating        mean naturalness + Krippendorff's α
        verify.py build-corpus                        writes conversations.bilingual.train.jsonl
```

Every stage is resumable: rerun and it continues from where the output file ends.

## Run

```powershell
$py = ".venv\Scripts\python"
& $py -m therapylink_ml.urdu.translate --limit 2000
& $py -m therapylink_ml.urdu.transliterate
# start an OpenAI-compatible server with an open model (llama-server on the 2050, or vLLM on Kaggle), then:
& $py -m therapylink_ml.urdu.restyle --base-url http://localhost:8080/v1 --model qwen3.5-9b
& $py -m therapylink_ml.urdu.verify --base-url http://localhost:8080/v1 --model qwen3.5-9b
& $py -m therapylink_ml.urdu.rate make-sheet --n 300
# ... raters fill their sheets ...
& $py -m therapylink_ml.urdu.rate alpha rating\rater_a.csv rating\rater_b.csv rating\rater_c.csv
& $py -m therapylink_ml.urdu.verify build-corpus
```

## Exemplars (`data/urdu/exemplars.txt`)

Stage 3 needs at least a dozen lines of *authentic* Roman Urdu — real posts, one per line — as style reference. Pull them from the Roman Urdu sentiment corpora, strip anything identifying, and keep them varied in mood. Do not write them yourself; the point is register the model can't invent.

## Honesty notes

- The stage-2 transliterator is crude on purpose. Its output is a control condition in the rating sheet (20 % of items), so the α run also tells you how much stage 3 actually bought.
- The restyle model must be open-weights. Hosted APIs make the corpus unreproducible and raise terms-of-service questions about training on their outputs.
- The 200-item held-out Roman Urdu eval set must be written by native speakers, not generated. Nothing in this directory produces it.
- Report α as it comes out. A real 0.6 says more than a suspicious 0.9.
