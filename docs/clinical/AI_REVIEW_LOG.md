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

## 2026-10-03: the rest of the clinical review

All `ai-clinical-review`. **Licensed clinician sign-off: PENDING** on every item.

| Deliverable | Where | Summary |
|---|---|---|
| Guardian v1 labelling guide | `GUARDIAN_LABELS.md` | The eight labels the head already uses, acuity and hard-negative fields, 13 decision rules, 15–24 worked examples per class in English, Roman Urdu and Urdu script, recall/precision targets for MG-11 |
| Helplines | `helplines.md`, `app/lib/features/shared/helplines.dart` | Public-source check of Umang, 1122, 1098, 15, 1099; Punjab 1043 and 1121 added to the sheet. Umang's website is suspended and madadgaar.org serves a gambling site, so both are first for a phone check. 46 unverified claim sentences removed from the authored crisis rows |
| Red lines | `red-lines.md` | R1–R12 with pass conditions and checks; R11 and R12 new |
| Crisis, consent and privacy copy | `crisis_copy.dart`, ARB files, `docs/l10n/REVIEW.md` | Every REVIEW.md item decided; storage wording now matches v3; consent says nobody watches the chat; under-18 text rewritten |
| PHQ-9 / GAD-7 | `assessments-urdu.md`, `assessment_items.dart` | Roman Urdu follows the validated Urdu versions (Ahmad et al. 2017, 2018); unvalidated-translation notice kept |
| Model | `MODEL_REVIEW.md` | v16c-e2 accepted for internal testing only; 0/8 smoke crisis replies free of red-line violations under R1/R11; keyword floor misses the smoke crisis prompts; v17 must-fix list and release gate |

## 2026-10-03: "I'm not suicidal" and crisis mode that wouldn't end

`ai-clinical-review`. **Licensed clinician sign-off: PENDING.** Found on the owner's phone test: after a crisis message, every chat message brought the help sheet back, even after the person wrote that they were not suicidal.

Two causes, both in the app (`guardian.dart`, `eve_controller.dart`, `crisis_mode.dart`):

1. **A denial scored as a crisis.** The keyword floor matches "suicid", and Guardian v1b scored "i am not suicidal" 0.94 suicidal, "main suicidal nahi hun" 0.98. That is the answer a person gives to "are you thinking of ending your life?".
2. **Crisis mode fed itself.** In crisis mode the last few messages were re-read together with the flagged ones, so the flagged message flagged the next, which flagged the one after, for as long as the person kept talking within 20 minutes. Eve was never asked.

Decisions:

- **Denials are not scored.** `NegationAwareGuardian` removes a negation plus the danger it denies ("not suicidal", "would never kill myself", "I don't want to die", "suicidal nahi hun", the Urdu-script form) and reads the rest, so "I'm not suicidal but I want to die tonight" is still a crisis. Past tense ("wasn't suicidal until last week"), "can't stop thinking about suicide" and "I don't want to die but I don't want to live like this" are still crises. Tests pin both lists.
- **One carried turn, not a chain.** The turn straight after a crisis message still counts as part of it ("I already took them" has no crisis words). The turn after that is read on its own.
- **A denial ends crisis mode** when it answers a suicide or self-harm flag and nothing else in the message raised one. It does not end crisis mode raised for an overdose, abuse or a child: "I'm not suicidal" says nothing about those.
- **Crisis mode still lasts an hour otherwise**, with the lines after each Eve reply. Whether an hour and a card on every reply is right is for the clinical lead.

Not fixed, for the clinical lead and ML: Guardian v1b is noisy on ordinary messages at its recall-first thresholds. "my boss is stressing me out" scores 0.91 sexual_violence and "mujhe neend nahi aa rahi" fires medical. Guardian v1c has more false alarms on hard negatives, not fewer. The denial reading removes one cause; the rest is the recall-versus-noise decision (MG-11).
