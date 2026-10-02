# Supervised pilot protocol

> **DRAFT, pending clinician and legal review.** This is an engineering draft that pulls together what the ship review asked for (`docs/ship-review/SHIP_PLAN.md`, "Where the line is" and Phase 1; `clinical-psychologist.md`, "What needs a human"). It has not been reviewed by a clinician, a lawyer or an ethics board, and no pilot may start from it as written. Every item marked **(decide)** is a question for them, not a proposal to adopt.

## 1. Purpose

Find out, under clinical supervision and with a small number of consenting adults, whether Eve and the crisis path behave safely with real people before any wider release. The pilot is not a trial of effectiveness and makes no treatment claim.

## 2. Preconditions: nothing starts until all are true

| # | Precondition | Owner | Done (date, initials) |
|---|---|---|---|
| P1 | Every blocker B1–B20 in `SHIP_PLAN.md` is closed | code, ml, human | |
| P2 | The model participants use is the exact artifact that passed the hard gates, pinned by hash. On device that means a fine-tuned `.litertlm` evaluated on a phone; on a server, real hosting, not a laptop | ml | |
| P3 | Guardian v1 is bundled and required before chat opens, with the keyword floor underneath | code, ml | |
| P4 | A Pakistan-licensed clinical psychologist has rated the served build with the protocol in `clinical-psychologist.md` §2, with zero red-line violations | human | |
| P5 | The red lines are signed (`docs/clinical/red-lines.md`) | clinical lead | |
| P6 | The helplines shown in the app are verified (`docs/clinical/helplines.md`) | human | |
| P7 | The company exists, and a lawyer has approved the privacy policy, terms and the consent form below | human | |
| P8 | An ethics or IRB review is done, if results will be published or used as evidence **(decide)** | human | |
| P9 | The partner institution has agreed to this protocol in writing | human | |
| P10 | Chat can be switched off remotely for every participant without an app update, and that switch has been tested end to end on the pilot build: chat closes, the crisis sheet and helplines keep working. `SHIP_PLAN.md` does not plan this yet (none of B1–B20 covers it); `backend-devops.md` §3 sketches one as a Remote Config flag. Without it the stop rule in section 8 cannot be carried out, because an on-device model keeps answering until each participant updates | code | |

## 3. Participants

### Inclusion

- Adults, 18 or over, confirmed at enrolment by the partner, not only self-declared in the app.
- Recruited through a partner institution: a university counselling centre or an NGO. No public listing, no ads, no paid acquisition.
- Able to reach the named on-call clinician (section 5) and consenting to that contact.
- Owns an Android phone that can run the pilot build.
- 20–50 participants in total.

### Exclusion **(decide)**

The clinical lead sets these. Questions to settle:

- Anyone currently at high suicide risk at screening, and how the partner screens for it.
- Anyone in an acute crisis, psychosis or mania, or under active inpatient care.
- Anyone for whom a shared phone makes the app unsafe (for example, someone living with an abusive partner) while the app has no lock or quick exit.
- Whether current therapy clients of the partner may join, and whether their therapist must agree.

## 4. Consent

Written consent, taken by the partner before the app is installed. The form is written by the lawyer and clinical lead; it must at least say, in English and Roman Urdu, in plain words:

- Eve is an AI. It is not a therapist, not therapy, and not an emergency service.
- **Nobody watches the chat in real time.** A risk said to Eve does not alert the on-call clinician or any linked clinician. In an emergency, call the numbers in the crisis sheet.
- What is stored where: on the phone, and on the server (see `docs/legal/data-inventory.md`).
- What the pilot team will see, and that any transcript review needs a separate, explicit opt-in.
- How to leave the study at any time without giving a reason, and what happens to their data when they do.
- Who to contact with a concern or complaint, other than the development team.

Record the consent form version and date for each participant. Re-consent if the form changes.

## 5. On-call clinician

| | |
|---|---|
| Name | |
| Registration body and number | |
| Hours of cover | |
| How participants reach them | |
| Backup clinician | |

The on-call clinician can pause the pilot on their own authority.

## 6. Incident log

An incident is any of: a red-line violation seen in a reply; a crisis the app failed to route; a participant harmed or at risk after using the app; a privacy or data breach; a wrong or unreachable helpline number; a participant complaint about safety.

Log every incident within 24 hours. Keep the log outside the app's databases, with access limited to the pilot team. Record what happened, not the whole conversation; quote chat text only with the participant's consent.

| Field | Entry |
|---|---|
| Incident ID | |
| Date and time found | |
| Reported by (participant, clinician, partner, developer) | |
| Participant ID (pseudonymous) | |
| Category (red line R1–R10 / missed crisis / harm / privacy / helpline / other) | |
| What happened | |
| App build and model ID | |
| Immediate action taken, and by whom | |
| Participant contacted? When, by whom | |
| Pilot paused? (yes / no) | |
| Root cause | |
| Fix, and where it is tracked | |
| Reviewed at weekly review (date) | |
| Closed by, and date | |

## 7. Weekly safety review

Once a week while the pilot runs, the clinical lead, the on-call clinician and the engineering owner meet. Minutes are kept.

1. New incidents: each one reviewed and assigned.
2. Open incidents: status.
3. Crisis-routing counts from content-free telemetry (sheet shown, call tapped), where available.
4. Transcripts from participants who opted in to review, sampled as the clinical lead decides **(decide)**.
5. Withdrawals and the reasons given.
6. Decision: continue, change, or pause. Recorded with names.

## 8. Stop rule

- **Any red-line violation seen in the field pauses the pilot.** No new messages go to Eve until the clinical lead has reviewed it and signed off a fix or a decision to resume.
- A participant seriously harmed, where the app may have contributed, pauses the pilot and triggers an external review **(decide who)**.
- A data breach pauses the pilot, and the lawyer decides on notification.
- The on-call clinician or the partner can pause the pilot at any time.

Pausing means: turn off chat through the remote switch required by P10 (not built yet, so no pilot can start), leave the crisis sheet and helplines working, and tell participants in plain words.

## 9. Leaving the study

- A participant can leave at any time, in the app or by telling the partner.
- On leaving, their server data is deleted and they are shown how to delete the app's data on their phone. Anything already in the de-identified incident log stays, with that noted in the consent form **(decide)**.

## 10. End of pilot

The pilot runs for 8–12 weeks. A public release needs that pilot period with no unresolved serious incident, plus the conditions in `SHIP_PLAN.md` ("Ready for open public use"). The final report goes to the clinical lead, the partner and, if one reviewed the pilot, the ethics board.

## Sign-off

| Role | Name | Signature | Date |
|---|---|---|---|
| Clinical lead | | | |
| Lawyer | | | |
| Partner institution | | | |
| Ethics / IRB (if required) | | | |