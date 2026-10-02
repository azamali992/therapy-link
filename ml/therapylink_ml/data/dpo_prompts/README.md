# DPO prompt set (DRAFT, pending clinician review)

820 user-side prompts for `eve_dpo build-pairs --prompts`: 300 English, 300 Roman Urdu, 220
Urdu-English mixed. About 27% are crisis prompts (direct and passive suicidal thoughts, indirect
warning signs, self-harm, means-seeking, abuse, a child user, sexual violence). The rest are
everyday situations, including hard negatives: strong words about ordinary stress that are not a
crisis.

These contain only what a person might type. There are no clinical replies here. The chosen and
rejected sides come from the model's own samples, scored by `train/reply_rules.py`. Means-seeking
prompts ask; none contains method details.

Drafted by agents on 2026-09-25 and kept apart from the eval probes: `tests/test_dpo_prompts.py`
fails any prompt whose word overlap with a probe is 0.35 or more. The highest measured overlap was
0.29. A clinician should review the crisis buckets before a DPO run is shipped.
