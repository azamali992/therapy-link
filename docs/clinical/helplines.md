# Helpline verification register

> **Status: public-source check done 2026-10-03 (ai-clinical-review). Phone verification: NOT DONE. Licensed clinician sign-off: PENDING.**
> Every number below was checked against current public sources on 2026-10-03. Nobody has called any of these services. "verified-by-public-source" means a current web source from the operator, WHO, UN Women, Child Helpline International or 2026 reporting confirms the number and who the line is for. It does not mean the line answers, or answers in Urdu, or will take our referrals. A person still has to confirm each line with the service before the pilot (pilot precondition P6).

## Rules

- **Two levels of verification.** `public-source`: a current, citable web source confirms the number and remit (done below). `service-confirmed`: a named person has contacted the service and recorded the answers to the questions at the end of this page (not done). The app's `verifiedOn` in `app/lib/features/shared/helplines.dart` records the public-source check only, and the comment there says so.
- **Re-check every quarter.** Next public-source check is due **2026-12-31**. An entry past its date counts as unverified.
- **The clinical lead owns this list** and decides which lines appear for which kind of risk.
- **Numbers are compiled into the app**, never fetched at runtime, so the crisis sheet works offline. The app renders them from the one table in `helplines.dart`, never from translated strings.
- **Claim nothing the service hasn't confirmed to us.** Even where a public source says "24/7" or "free", the app and Eve don't repeat it until the service confirms it: hours change, and a call to a mobile number is never free for the caller. Eve says a service's name and number, and who it's for where a source states that. Never hours, cost or staffing.
- **Never link to a helpline's website from the app.** Two of the sites checked below are gone (one suspended, one taken over by a gambling site).

## Public-source check, 2026-10-03

| Line | Number | What it is, per source | Who it's for | Hours / cost (as published; not used in the app) | Coverage | Sources | Status |
|---|---|---|---|---|---|---|---|
| **Umang** | 0311-7786264 | Mental health and psychosocial support hotline, founded by Dr Kinza Naeem | Anyone in emotional distress or suicidal crisis | WHO lists "24/7". A 2020 government press release called it free of cost, but only the first 3 months of that project were described as free | National (mobile number) | [WHO EMRO, Pakistan mental health and psychosocial support services (© WHO 2026)](https://www.emro.who.int/mhps/mental_health_professionals.html), which also lists WhatsApp numbers by time slot. [PID press release, 10 Dec 2020](https://pid.gov.pk/site/press_detail/15391) | **Verified-by-public-source, with a warning.** On 2026-10-03, umang.com.pk redirected to the host's "Account Suspended" page, and its TLS certificate had expired on 2026-09-28. A March 2026 directory lists a *different* Umang number, 0317-4288665 ([islamabad.org.pk](https://islamabad.org.pk/helpline-numbers-pakistan-emergency-contacts/)), which no primary source confirms. **First line to confirm by phone.** If it can't be confirmed, the suicide sheet is left with Rescue 1122 only, and a replacement mental-health line must be found |
| **Rescue 1122** | 1122 | Provincial emergency ambulance, rescue and fire services | Medical emergencies, accidents, anyone in immediate danger | Not stated on the official pages | Punjab (all 36 districts), Khyber Pakhtunkhwa, Sindh (SERS, since 2022), Islamabad (CARES 1122), GB, AJK. **Balochistan: highways and parts of Quetta only** | [Punjab Emergency Service](https://rescue.gov.pk/), [Rescue 1122 KP](https://rescuekp.gov.pk/), [Wikipedia: Rescue 1122](https://en.wikipedia.org/wiki/Rescue_1122) (Sindh, Islamabad, Balochistan coverage) | Verified-by-public-source. The Balochistan gap is a known limit. Police 15 is the fallback there |
| **Madadgaar National Helpline** | 1098 | Run by Lawyers for Human Rights and Legal Aid (LHRLA). Counselling, crisis intervention, legal aid and referral | Women and children facing violence, abuse and exploitation, including forced marriage and trafficking | Described as "a 24-hour child helpline" in 2026 reporting | National | [Accountability Lab Pakistan, 2026](https://pakistan.accountabilitylab.org/protecting-pakistans-children-why-are-children-still-vulnerable-to-abuse-and-what-happens-when-they-report-it/) (cites events of August 2026), [Child Helpline International, 23 Jul 2026](https://childhelplineinternational.org/beyond-the-call-nine-years-of-advocacy-for-children-in-pakistan/), [UN Women Asia-Pacific emergency contacts](https://asiapacific.unwomen.org/en/countries/pakistan/evaw-pakistan/emergency-contacts) | Verified-by-public-source. **madadgaar.org now serves a gambling site**: never link to it |
| **Punjab Women's Helpline** | 1043 | Punjab Commission on the Status of Women (PCSW). All-women call agents, legal advisers, psychosocial counsellor. Refers to the Punjab Women Protection Authority and Dar-ul-Aman shelters | Women facing violence, harassment, discrimination, property and inheritance disputes | PCSW says "toll-free" and "available 24/7" | **Punjab only** | [PCSW, Helpline 1043](https://pcsw.punjab.gov.pk/helpline_) | Verified-by-public-source. Added to the app as "Punjab Women Helpline" for abuse and sexual violence |
| **Punjab Child Protection** | 1121 | Child Protection and Welfare Bureau, Punjab. Rescue and support for children facing violence, exploitation, abuse or neglect; "anyone can inform us about any child who is in trouble" | Children at risk, and adults reporting them | Page says "free support"; hours not stated | **Punjab only** | [CPWB Helpline](https://cpwb.punjab.gov.pk/helpline), [CPWB FAQ](https://cpwb.punjab.gov.pk/faqs) | Verified-by-public-source. Added to the app as "Punjab Child Protection" for child |
| **Police** | 15 | Police emergency | Immediate danger from another person | — | National | [UN Women Asia-Pacific emergency contacts](https://asiapacific.unwomen.org/en/countries/pakistan/evaw-pakistan/emergency-contacts) | Verified-by-public-source. On the model's allowlist in context (`safety_rules.POLICE_15`). Not on the crisis sheet, to keep the sheet short |
| **Ministry of Human Rights helpline** | 1099 | Legal advice, counselling and referral for human-rights violations | Anyone, including women and children | Published hours: weekdays 8:30 am to 9:00 pm. Toll-free. WhatsApp 0333-9085709 | National | [MoHR Human Rights Information Resource Portal: Helpline 1099](https://portal.mohr.gov.pk/media_library/helpline-1099/) (fetched; the hours come from MoHR's helpline description in search results and must be confirmed) | Verified-by-public-source as a **daytime advice line, not a crisis line**. The owner still has to decide whether it stays on the allowlist (`ALLOW_MOHR_1099`). I removed it from the red-line training rows |

### Candidates not added yet

| Line | Number | Why not yet |
|---|---|---|
| Sindh Women's Helpline (Women Development Department) | 1094 | Newest source found is from 2018–2020. Needs a current source or a call |
| KP Bolo Helpline (gender-based violence) | 0800-22227 | KP Social Welfare page found; operational in 6 districts per earlier reporting. Needs a current check of coverage |
| Pakistan Emergency Helpline (PEHL) | 911 | Launched in 2022 to route to all emergency services. **The model allowlist treats 911 as a foreign number (R6)**. Leave that until 911's current status in Pakistan is confirmed; 1122 and 15 are the better-known numbers anyway |
| Rozan Counselling Helpline | 0800-22444 | Women and young people. Published hours Monday–Saturday, 10 am–6 pm, so not a crisis line. Possible daytime referral |

## What the app shows (`helplines.dart`, 2026-10-03)

| Crisis kind | Lines, in order |
|---|---|
| suicide | Umang 0311 7786264, Rescue 1122 |
| abuse | Madadgaar 1098, Punjab Women Helpline 1043, Umang, Rescue 1122 |
| sexual violence | Madadgaar 1098, Punjab Women Helpline 1043, Umang, Rescue 1122 |
| child | Madadgaar 1098, Punjab Child Protection 1121, Rescue 1122 |
| self-harm | Umang, Rescue 1122 |
| harm to others | Rescue 1122, Police 15 (this sheet only) |
| medical | Rescue 1122 |

When Guardian flags several kinds at once, the most urgent routes first: medical, suicide, harm to others, child, sexual violence, abuse, self-harm (`crisisPriority` in `app/lib/core/ml/guardian.dart`). AI clinical review 2026-10-03 agrees with this order: an emergency in progress needs 1122 before anything else.

The model (Eve) may name only Umang, 1122, 1098, 15 in context, and 1099 while `ALLOW_MOHR_1099` is true (`ml/therapylink_ml/eval/safety_rules.py`). Provincial lines stay on the sheet, not in the model's mouth: the model doesn't know where the person is.

## Where the unverified claims were, and what happened to them

| Place | Claim | Done |
|---|---|---|
| `ml/therapylink_ml/data/authored/crisis_support_0{1,2,3}.jsonl`, `continuity_01.jsonl` | "free", "24/7", "psychologists available", "any hour", "muft", "24 ghante", "raazdari", "confidential" (45 sentences) | Rewritten to name and number (commit "Take unverified helpline claims out…"). A test now checks every authored row |
| `redline_*.jsonl` | "Umang's psychologists… right now", "abhi baat ho sakti hai" | Rewritten in the red-line review |
| `app/lib/l10n/*.arb` | None found ("free", "24/7", "confidential" absent). `youHelpSub` says "right away" | See `docs/l10n/REVIEW.md` |
| `app/lib/features/shared/crisis_copy.dart` | "You can talk to a person right now" (`helpBarBody`), "In numbers par aap abhi kisi se baat kar sakte hain" | Rewritten (see the crisis copy commit) |
| `ml/therapylink_ml/prompts.py`, V2 prompt | "Umang 0311-7786264 (free, 24/7)" | **Not mine to change.** The ML team must drop "(free, 24/7)" before v17 trains (the prompt is part of the model), and update `app/lib/core/ml/eve_engine.dart` to match |

## Still to do by phone

Owner or licensed clinician. Ask each service:

1. Is this number correct, and is it the one you want an app to show?
2. What hours is it staffed, and in which languages (English, Urdu, others)?
3. What does a call cost the caller on mobile networks?
4. Do you take SMS or WhatsApp? On which number?
5. Which situations do you handle, and which should go elsewhere?
6. Is it available nationwide or only in some provinces?
7. May TherapyLink list you, and do you want notice of expected referral volume or a written agreement?
8. Who is our contact for changes?

Umang first (website suspended, conflicting number in circulation), then Madadgaar (website hijacked), then the rest.

## Service-confirmed table

Leave a cell blank rather than guessing.

| name | number | hours | cost to caller | SMS / WhatsApp | languages | coverage | verified_by | verified_on | next_review | permission to list |
|---|---|---|---|---|---|---|---|---|---|---|
| Umang | | | | | | | | | | |
| Rescue 1122 | | | | | | | | | | |
| Madadgaar | | | | | | | | | | |
| Punjab Women Helpline | | | | | | | | | | |
| Punjab Child Protection | | | | | | | | | | |
| Police | | | | | | | | | | |

## Clinical lead approval

AI clinical review (2026-10-03) recommends the lines-by-kind table above. **Licensed clinician sign-off: PENDING.**

| | |
|---|---|
| Lines approved for the crisis sheet, by risk type | |
| Clinical lead (name) | |
| Signature | |
| Date | |
