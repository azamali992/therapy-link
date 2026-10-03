# AI clinical review log

> **Licensed clinician sign-off: PENDING.** Everything recorded here is `ai-clinical-review`: the AI team acting in the clinical-lead role at the owner's request so work can go on. It is not a licensed clinician's approval. A Pakistan-licensed clinical psychologist must review and sign before any of this reaches a real patient, and before any model trained on it is recorded with a clinician's name in `ml/registry.json` (QA gate MG-1).

## 2026-10-03: red-line training rows

Scope: the 36 rows in `ml/therapylink_ml/data/authored/redline_{signs,style,violence}_01.jsonl`, all `pending_clinician` before this review, plus 23 new rows in `redline_prep_01.jsonl`.

Standard applied: `docs/clinical/red-lines.md` (R1–R10), safe-messaging guidance (WHO/IASP media and helpline guidance, Samaritans), direct risk inquiry in the Columbia (C-SSRS) style, means restriction, no method or dose detail, no diagnosis or medication advice, and gender-neutral Roman Urdu where the person gives no cue.

### Result

| | Rows |
|---|---|
| Approved unchanged | 8 (all medication and list-style rows except two) |
| Rewritten | 28 |
| New: preparation for death (R1), en / Roman Urdu / mixed | 20 (7 / 7 / 6) |
| New: hard negatives (will before surgery, wasiyat before Hajj, giving things away before emigrating) | 3 |

Every row carries its own record: `review: {by: "ai-clinical-review", date, decision, reason, licensed_clinician_signoff: "PENDING"}` and `review_status: "ai_clinical_review"`.

### What the rewrites fixed

- **Unverified service claims (27 rows).** "Umang's psychologists can talk with you right now", "abhi baat ho sakti hai", "through tonight". Eve now gives a service's name and number only, as `helplines.md` requires.
- **R5, missing direct safety question (10 rows):** every sexual-violence and child row lacked one or more; the third-party "asking for a friend" row never asked the person themself.
- **R3 (1 row):** `rl-ind-ur-02` said people do this "jab woh duniya chhorne ka faisla kar lete hain", which frames suicide as a decision.
- **Facts:** the ADHD row said only psychiatrists assess adult ADHD in Pakistan (clinical psychologists do too); the forced-marriage row cited the Ministry of Human Rights line 1099, which is weekday daytime and still an open allowlist decision, so it now relies on Madadgaar, whose published remit covers forced marriage.
- **Promises the app cannot keep:** "I'm not going anywhere", "I'm staying right here" replaced by "we can keep talking here".
- **Overclaims in everyday rows:** "foran kaam karti hai" for paced breathing; "aksar udaasi ka ishara" (implied diagnosis).
- Added clinically important first questions: whether the medicine has already been taken, whether there is a date in mind when the person names one, and for sextortion of a child, safety including thoughts of self-harm.

### How the loader treats these rows

`ml/therapylink_ml/data/loaders/authored.py` now knows three statuses: `approved` (licensed clinician), `ai_clinical_review`, `pending_clinician`. AI-reviewed rows are held back exactly like pending ones **unless** the build and the training run both set `TL_ACCEPT_AI_CLINICAL_REVIEW=1`. They are always tagged `review:ai_clinical_review` in the corpus, and `eve_sft.read_conversations` drops that tag unless the same variable is set, so a corpus built with the opt-in cannot leak into a run without it. Nothing was relabelled `approved`.

Use the opt-in for internal-testing models (v17 candidates) only.

### Tests added (`ml/tests/test_authored.py`)

- Red-line rows are never `approved`; AI-reviewed rows must carry the review record with `licensed_clinician_signoff: "PENDING"`.
- Held back by default; included only with the opt-in; pending rows stay out either way.
- Every crisis row's final reply asks directly about safety (R5) and no assistant turn endorses or frames the act as a decision (R1, R3).
- No reply claims who answers a helpline or when.
- At least 20 preparation rows across all three languages, plus hard negatives in each.

`ml/tests/test_data.py` was updated for the new tag. `pytest ml/tests`: 271 passed, 1 skipped.

### Open for the licensed clinician

- Read all 59 rows, starting with the 20 `rl-prep-*` rows and the rewritten child rows.
- The Roman Urdu has not had a native-speaker clinical review (UX.md D8).
- `prompts.py` V2 still says "Umang 0311-7786264 (free, 24/7)". I don't own that file. The ML team should drop "(free, 24/7)" before v17 trains, since the prompt is part of the model.
