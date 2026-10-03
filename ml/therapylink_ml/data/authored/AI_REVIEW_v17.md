# AI clinical review of the v17 multi-turn rows

> Licensed clinician sign-off: PENDING. This is ai-clinical-review (the AI team in the clinical-lead role), the same standard as docs/clinical/AI_REVIEW_LOG.md on the clinical-review branch. The rows train only with TL_ACCEPT_AI_CLINICAL_REVIEW=1.

## AI clinical review: v17 English multi-turn rows

> **Licensed clinician sign-off: PENDING.** This is `ai-clinical-review`, the AI team in the clinical-lead role. It is not a licensed clinician's approval.

- Input: `e_en_multiturn.jsonl` (70 rows: 45 eve, 25 crisis)
- Output: `v17_multiturn_en_01.jsonl` (70 rows kept)
- Date: 2026-10-03
- Standard: `red-lines.md` R1-R10, `helplines.md` (name and number only), the V2 prompt, and the bar set by `redline_prep_01.jsonl`. The standard is the same one used in the earlier AI review (`AI_REVIEW_LOG.md`).

| Decision | Rows |
|---|---|
| Approved unchanged | 49 |
| Rewritten | 21 (eve 12, crisis 9) |
| Rejected | 0 |

The batch was strong. None of the input rows praised preparation (R1), framed suicide as a decision (R3), blamed a survivor or advised confrontation (R4), named a medication, made therapist claims, or claimed "free / 24/7" for Umang. Every crisis reply from the risk turn on already stated worry, asked about safety and gave a verified number.

## Main fixes

- **No plan or means question after high-risk answers (6 crisis rows).** These were a named time, completed preparations, stated intent, "I've thought about how", "not soon" and "tomorrow I don't know". I added a direct plan or timing question (C-SSRS style) or a means-restriction line, or both.
- **Madadgaar outcome claims (2 rows).** The replies said Madadgaar would "work out where you can be safe" or "advise about your children". These are now name, number and published remit only.
- **Invented detail or assumptions (6 rows).** These were a visit length, a flight length, an undated duration, a health reassurance an AI can't give, and two gender assumptions.
- **Smaller fixes.** These were a memory note announced instead of used, an implied second question, a hint toward a career outside medicine on results day, a dismissive "help on paper", ambiguous self-harm wording, and two unnatural phrasings.

## Rewritten rows

- v17-mt-en-001: Turn 3 assumed the team lead's gender before any cue, and "power is going" read awkwardly.
- v17-mt-en-002: "I remember that..." announced the memory note (R8). It is now used naturally.
- v17-mt-en-004: "In-laws staying for a week" was invented. It is now "visiting from the village", as she said.
- v17-mt-en-013: The results-day reply suggested work outside medicine, which read as dismissing her goal. "Missing an exam score" was unnatural.
- v17-mt-en-021: The invented flight length ("two hours") was removed.
- v17-mt-en-022: "It says more about uncertainty than about your health" was an unfounded health reassurance. It is replaced with a reflection of the loop.
- v17-mt-en-025: The referral claimed "this has gone on for weeks", which she never said. It now rests on the postnatal context.
- v17-mt-en-028: "Opening semester" was changed to "first semester".
- v17-mt-en-031: An implied second question was turned into a statement, so the reply asks one question.
- v17-mt-en-034: "In the opening minute" was changed to "first".
- v17-mt-en-043: "Family help on paper" dismissed the brother's support. It was reworded.
- v17-mt-en-048 (crisis): The reply did not follow up "I wouldn't do anything soon". It now asks directly about later intent and a time in mind.
- v17-mt-en-049 (crisis): After completed preparations and a yes to suicidal thoughts, there was no plan or timing question. One was added, with no praise of the debt-clearing.
- v17-mt-en-050 (crisis): The person named "next week" and the reply asked about neither a plan nor means. A direct plan question and means restriction were added.
- v17-mt-en-057 (crisis): The reply re-asked about tonight, which the person had already answered. It now asks whether there is a plan for tomorrow.
- v17-mt-en-059 (crisis): Intent was stated with a set trigger, and means restriction was added.
- v17-mt-en-061 (crisis): After "I've thought about how", means restriction was added.
- v17-mt-en-062: Turn 1 assumed a daughter, and it is now gender-neutral.
- v17-mt-en-066 (crisis): "Isn't something you deserve to keep doing alone" read as if the self-harm would go on. It was reworded.
- v17-mt-en-068 (crisis): The Madadgaar claim "can work out where you can be safe" became its published remit only.
- v17-mt-en-070 (crisis): The Madadgaar claims about advising on the children (custody) became name, number and remit only.

## Rejected rows

None.

## Checks (all 70 kept rows pass)

- `score_reply` passes on the final turn.
- No assistant turn has a list, more than 2 "?", a medication name, a free/24/7 claim or a service-staffing claim.
- Every crisis final asks about safety, and no crisis turn uses ENDORSE or decision wording.
- `rubric` hard failures are empty for every eve turn and every crisis turn from the risk turn on, and the rewritten turns carry no soft flags.
- User-turn Jaccard against the eval probes is below 0.35.

## For the licensed clinician

- Read the six crisis rows above that gained plan or means questions (048, 049, 050, 057, 059, 061). Check that the wording is right for a first follow-up.
- Everyday rows with weeks of low mood (024, 040) and the postnatal row (025) stay on the eve route with a psychologist/doctor referral and no risk screen. Decide whether a gentle screen belongs there.

## AI clinical review: v17 multi-turn rows, Roman Urdu and mixed

> **Licensed clinician sign-off: PENDING.** This is `ai-clinical-review`: the AI team acting in the clinical-lead role, not a licensed clinician. A Pakistan-licensed clinical psychologist must review and sign before these rows reach a real patient.

Date: 2026-10-03
Input: `f_ur_multiturn.jsonl` (70 everyday rows, route `eve`: 40 ur-roman, 30 mixed)
Output: `reviewed/v17_multiturn_ur_01.jsonl`

Standard: the same one as `docs/clinical/AI_REVIEW_LOG.md` (2026-10-03), plus red lines R1-R10, `helplines.md` and the V2 system prompt.

## Result

| | Rows |
|---|---|
| Approved unchanged | 56 |
| Rewritten | 14 (17 assistant turns) |
| Rejected | 0 |

Every kept row has `review_status: "ai_clinical_review"` and a `review` record with `licensed_clinician_signoff: "PENDING"`. User turns, ids, categories, routes and notes are unchanged.

The batch was in good shape. Nothing broke R7-R10: no diagnoses or medicine names, no invented history, the AI-boundary rows say plainly that Eve is an AI and not a therapist, and none of them offers Eve as enough. Notes rows use the memory naturally and don't recite it.

## What the rewrites fixed

- **More than one question (3 rows):** ur-019, ur-023, mx-003.
- **Arguing with or pre-empting the person (4 rows):** replies that told the person their thought "isn't true", answered their own question before the person could, or claimed to know what a parent or boss thinks (ur-006, mx-002, mx-012, mx-029). They now test the thought gently and end on one question.
- **Lecturing (2 rows):** "zaroori hai" phrasing in ur-011 and mx-005.
- **Clinical gaps (2 rows):** ur-016 treated a first episode of racing heart and breathlessness as anxiety with no medical check, so a gentle suggestion to see a doctor is added. mx-005 (controlling fiance) now gently asks whether the person feels afraid.
- **Overclaims about exercises (2 rows):** ur-018 and mx-016 now say "madad kar sakti hai" instead of stating the effect.
- **Stilted Roman Urdu (3 rows):** gender-avoiding passives such as "qadam uthaya gaya", "nibhai gayin" and "jo yahan bayan hua" are replaced with natural phrasing that is still gender-neutral (ur-016, ur-021, ur-036).

## Per row

| id | decision | reason |
|---|---|---|
| v17-mt-ur-006 | rewritten | The last reply argued with the person ("poora sach nahi hai") and claimed to know what Ammi sees. It now tests the thought gently and keeps the hurt of the comparison valid. |
| v17-mt-ur-011 | rewritten | Removed the lecturing "jaanchna zaroori hai" and the leading "office ki siyasat" suggestion. |
| v17-mt-ur-016 | rewritten | Added a gentle doctor check for a first episode of racing heart. Replaced a stilted passive. |
| v17-mt-ur-018 | rewritten | Overclaim: grounding "le aati hai" became "wapas laane mein madad kar sakti hai". |
| v17-mt-ur-019 | rewritten | The first reply asked two questions; it now asks one. |
| v17-mt-ur-021 | rewritten | Stilted "jo yahan bayan hua" became natural, gender-neutral "jo aap ko hota hai". |
| v17-mt-ur-023 | rewritten | Stacked questions reduced to one. Offering an in-chat exercise "phone ki jagah" contradicted itself, so it now says "scrolling ki jagah". |
| v17-mt-ur-036 | rewritten | Two stilted passives rewritten in natural, gender-neutral Roman Urdu. |
| v17-mt-mx-002 | rewritten | Claimed the critical boss focuses on content, which Eve can't know and which played down the fear. The reply now validates the fear first. |
| v17-mt-mx-003 | rewritten | The second reply asked two questions; it now asks one. |
| v17-mt-mx-005 | rewritten | Removed the lecture. With a controlling fiance, the reply now gently checks for fear. |
| v17-mt-mx-012 | rewritten | Imposed the exercise ("check karte hain") and answered its own question. It now offers the idea and asks one open question. |
| v17-mt-mx-016 | rewritten | Overclaim: tense-and-release "madad karti hai" became "madad kar sakti hai". |
| v17-mt-mx-029 | rewritten | Put the question mid-turn, then pre-empted the answer. The guilt is now tested gently and the reply ends on one question. |

## Checks run on every kept row

All 70 rows pass: `score_reply("eve", lang, t).passed`; no `has_list`; at most two "?"; no `MEDICATION` match; no "free", "24/7", "24 ghante" or "muft"; none of the words suicide, khudkushi, emergency, helpline, hotline, 1122, Umang or Madadgaar; `rubric("eve", lang, t)[0] == []`; the gendered-verb regex after "aap" never matches; and every user turn has word-set Jaccard < 0.35 against every probe text in `eval/probes/*.jsonl`.

## Open for the licensed clinician

- **The Roman Urdu and mixed phrasing still needs a native-speaker clinical review (UX.md D8).** This review read it as a fluent reader would, but it is not a native-speaker clinician's sign-off.
- Several everyday rows (ur-019, ur-032, mx-013, mx-014) describe weeks of low mood, loss of interest and poor sleep, and point the person to a psychologist or doctor without asking about hopelessness. That is consistent with the V2 prompt, which asks about suicide only when there are signs. A clinician should confirm that this is the wanted behaviour.
