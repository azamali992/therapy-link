# Helpline verification register

> **DRAFT, pending clinician review.** No number on this page has been verified. The verification table is blank on purpose: only a person who has contacted the service fills it in. Until a row is complete, treat that helpline as unverified in the app, in training data and in any copy.

## Rules

- **A human verifies every entry with the service itself**, by phone or in writing, and records who did it and when. A website, a news article or a model's answer is not verification.
- **Re-verify every quarter.** `next_review` is three months after `verified_on`. An entry past its review date counts as unverified.
- **The clinical lead owns this list** and decides which lines appear for which kind of risk (suicide, immediate danger, abuse, child abuse, sexual violence).
- **Numbers are compiled into the app**, never fetched at runtime, so the crisis sheet works offline. The app should render them from one table, not from translated strings.
- **Claim nothing the service hasn't confirmed.** Don't write "free", "24/7", "confidential" or "psychologists available" anywhere until the row below says so. The app currently says "free and confidential" (`app/lib/l10n/app_en.arb`, `crisisBody`); that wording is unverified. Several authored training rows also call Umang "free 24/7" or say it has "psychologists available 24/7" (`ml/therapylink_ml/data/authored/crisis_support_01.jsonl`), and the V2 prompt says "(free, 24/7)". Those rows need the same check before the next training run.
- Eve should say only a service's name and number, never its hours or staffing.

## Candidates to check

These come from the app and the ship review. They are leads for the verifier, not facts.

| Service | Number to check | Why it is on the list | Where it appears today |
|---|---|---|---|
| Umang (mental health helpline) | 0311-7786264 | Suicide and emotional distress | Crisis sheet (`crisis_sheet.dart`, `umangNumber`); authored training rows; V2 prompt |
| Rescue 1122 | 1122 | Immediate danger, medical emergency. Coverage by province to confirm | Crisis sheet (`emergencyNumber`); authored training rows |
| Madadgaar | 1098 | Abuse against women and children | Authored training rows and the V2 prompt; not in the app |
| Punjab Women Helpline | 1043 | Domestic violence (Punjab) | Nowhere yet |
| Punjab Child Protection | 1121 | Child abuse (Punjab) | Nowhere yet |
| Police | 15 | Immediate danger from another person | Nowhere yet |

Other provinces' women's and child-protection lines still need to be identified.

## What to ask each service

1. Is this number correct, and is it the one you want an app to show?
2. What hours is it staffed, and in which languages (English, Urdu, others)?
3. What does a call cost the caller, on mobile networks?
4. Do you take SMS or WhatsApp? On which number?
5. Which situations do you handle, and which should go elsewhere?
6. Is it available nationwide or only in some provinces?
7. May TherapyLink list you, and do you want notice of expected referral volume or a written agreement?
8. Who is our contact for changes?

## Verification table

One row per service. Leave a cell blank rather than guessing.

| name | number | hours | cost to caller | SMS / WhatsApp | languages | coverage | verified_by | verified_on | next_review | permission to list |
|---|---|---|---|---|---|---|---|---|---|---|
| Umang | | | | | | | | | | |
| Rescue 1122 | | | | | | | | | | |
| Madadgaar | | | | | | | | | | |
| Punjab Women Helpline | | | | | | | | | | |
| Punjab Child Protection | | | | | | | | | | |
| Police | | | | | | | | | | |
| | | | | | | | | | | |

## Clinical lead approval

| | |
|---|---|
| Lines approved for the crisis sheet, by risk type | |
| Clinical lead (name) | |
| Signature | |
| Date | |
