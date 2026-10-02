# TherapyLink: go-to-market and paid ads review (Pakistan first)

Role: growth marketing and paid-ads lead. Date: 2026-09-24. Branch `rebuild/v2`.

Everything below is grounded in the repo as it stands. Ad-platform and regulatory statements come from my knowledge of published policy and need checking against the live policy pages before money is spent. Those are marked "verify". CPI and budget numbers are estimates, not quotes.

## Summary

The product has a real, defensible wedge in Pakistan: a free companion that understands Roman Urdu and code-switching, with a crisis path that points to Pakistani numbers. Wysa, Headspace and the global chatbots don't do that, and the local players (Sehat Kahani, Marham, Taskeen, Umang) are people-and-helpline services rather than an always-on companion. The copy is already unusually good. It is plain, it doesn't overclaim, and the Roman Urdu reads like people actually type (`app/lib/l10n/app_ur.arb:12-13`, `:280-284`).

It is not ready to market yet. Several of the claims the brand is built on aren't true in the shipped build yet. The phone runs stock Gemma, not the fine-tuned Eve (`app/lib/core/ml/gemma_eve_engine.dart:21-35`). The trained safety model isn't published, so the app falls back to a keyword check and tells the user so (`app/lib/core/ml/onnx_guardian.dart:15`, `app_en.arb:55,66`). And the "what you say stays here" line (`app_en.arb:353`) skips the fact that every chat message sends a server-side emotion label (`app/lib/features/eve/eve_controller.dart:158`). A 2 GB download sits between the install and the first reply (`app_en.arb:35`, `gemma_eve_engine.dart:28`), and a forced sign-in comes first (`app/lib/app/router.dart:45-47`). With both in the way, paid installs would mostly never reach a conversation. There is no privacy policy, no terms, no "not for emergencies / not a therapist" statement, no age gate and no account deletion. Google Play needs all of those before a health app with accounts can be listed, and every ad network needs a policy URL.

Build zero analytics until there is a privacy-safe event scheme. That's the right default for this product (`app/pubspec.yaml` has no analytics SDK). It also means marketing is blind today, so a small, health-free event set is a launch prerequisite.

## Verdict

**Not ready for paid acquisition or a public store launch.** A closed beta through one or two partner universities or NGOs, recruited organically with no ads, is reasonable once the blockers below are closed. Paid ads should wait until (1) the fine-tuned Eve and the trained Guardian are the default on the phone, (2) the legal pages and store declarations exist, and (3) activation from install to first Eve reply is measured and above about 40%.

## Findings

| # | Finding | Severity | Owner | Evidence | Recommendation | Effort |
|---|---|---|---|---|---|---|
| 1 | Core claim "a counselling model we fine-tuned runs on the phone" is false in the build: on-device mode downloads stock Gemma 4 from litert-community | blocker | ml | `app/lib/core/ml/gemma_eve_engine.dart:21-35`; `app/PRODUCT.md:13`; README status "On-device Eve ... verified on a real phone" unchecked (`README.md`, Status) | Ship the fine-tuned LiteRT-LM export as the default URL before any claim about Eve's training appears in store copy or ads. Until then, no marketing asset may say "trained for Pakistan" or cite eval numbers | L |
| 2 | Trained crisis classifier not published; production falls back to keyword check and shows "Not published yet." to users | blocker | ml | `app/lib/core/ml/onnx_guardian.dart:15` (`TL_GUARDIAN_URL` defaults to empty); `app_en.arb:55,66`; README Guardian v0 catches 0% of Roman Urdu crisis probes | Publish Guardian v1 and bake the URL into release builds. Remove the "Not published yet" string from any user-visible surface before launch. Screenshots must never show the safety-model download card | M |
| 3 | Privacy line "What you say stays here" leaves out that every chat turn uploads an inferred valence + emotion label | blocker | code | `app/lib/features/eve/eve_controller.dart:158` queues `valence`, `emotion`, `source:'chat'`; `app/lib/core/api/models.dart:66` serialises it; copy at `app_en.arb:13,32,353` | Either stop uploading chat-derived mood unless the user turns it on, or say so in the welcome copy ("Your words stay on this phone. A mood score from each chat syncs to your account."). Store copy, Play Data safety form and ads must match whichever is true. A privacy promise we break is the one reputational event this brand cannot survive | S |
| 4 | No privacy policy, terms, "not a therapist / not for emergencies" statement, or age gate anywhere in the app | blocker | human + code | grep of `app/lib` for privacy/terms/disclaimer/age returns only `settings_screen.dart:77` and `insight_card.dart:41`; `welcome_screen.dart:20-73` goes straight to sign-in | Lawyer-reviewed privacy policy and terms hosted on a public URL. Add a one-screen onboarding statement: "Eve is an AI companion, not a doctor or therapist. In an emergency call 1122." Add an 18+ confirmation (or a separate, reviewed minors flow). Link both from You → Settings | M |
| 5 | No account deletion. Google Play requires in-app deletion plus a web deletion link for apps with accounts | blocker | code | `api/therapylink_api/routers/*.py`: no delete route for the user; only journal and care-link deletes (`journal.py:45`, `care.py:66`) | Add `DELETE /me` that wipes assessments, mood, journal, summaries and care links. Add an in-app "Delete account" row and a web form at the landing-page domain | M |
| 6 | No in-app way to report a harmful AI reply. Play's AI-generated content policy expects one | high | code | `app/lib/features/eve/eve_screen.dart`: no report or feedback control (grep for report/feedback/thumb finds none) | Long-press on an Eve message → "Report this reply" sends the reply text only, with explicit consent, to a moderation inbox. It doubles as the best source of real-world failure cases for ml/ | S |
| 7 | 2 GB model download plus forced sign-in stand between install and first reply. Prepaid-data Android users in the target segment will drop off | blocker for paid ads | code + ml | `app_en.arb:35` "about {gb} GB"; `gemma_eve_engine.dart:28` `gigabytes: 2.0`; `router.dart:45-47` redirects unsigned users to `/sign-in` before `/eve` | Let a new user talk to Eve (cloud path, clearly labelled) in the first minute while the model downloads on Wi-Fi in the background. Defer sign-in until they want check-ins or journal saved. Measure activation = first Eve reply within 24 h of install | L |
| 8 | Deterministic crisis sheet has Umang and 1122 only. No abuse or sexual-violence resource, though the "women facing family pressure" segment is a natural target and the model misses these cases | blocker if that segment is marketed to | code + human | `app/lib/features/shared/crisis_sheet.dart:7-8,46-57`; Madadgaar 1098 exists only in the model prompt (`ml/therapylink_ml/prompts.py:35`); eval `sft-v14` probe `s22` (en, rape disclosure) fails `resource`, `s15` (Roman Urdu self-harm) fails `resource` | Add Madadgaar 1098 and a verified women's-violence line to the sheet. Do not run women-focused campaigns until the sheet covers abuse and a human has verified each number (see What needs a human) | S |
| 9 | "It's free and confidential" / "free, 24/7" are claims about a third party that nobody has verified. 0311 is a mobile number, so ordinary call charges may apply | high | human | `app_en.arb:68` `crisisBody`; `ml/therapylink_ml/prompts.py:35` "Umang 0311-7786264 (free, 24/7)"; eval `sft-v14` `s01` reply repeats "free and open 24/7" | Get written confirmation from Umang of hours and cost. Ideally sign an MoU so they know referral volume is coming. Otherwise change to "confidential" and drop "free" | S |
| 10 | Brand hygiene: the Firebase project id `therapylink69` is what users see on the Google sign-in consent screen and in the auth domain | high | code + human | `app/README.md:16,18` | Create a clean production Firebase project (for example `therapylink-prod`) with a verified OAuth consent screen, app name, logo, privacy and terms URLs. The "69" suffix on a mental-health app's sign-in screen will be screenshotted | M |
| 11 | Wordmark art has a typo, "Linking to Calmnes" | medium | human | `app/README.md:99` | Fix the source file before any lockup goes on the store listing, landing page or ad creative | S |
| 12 | Name risk: "TherapyLink" implies licensed therapy, which the product doesn't provide to most users. That invites health-claim scrutiny from ad reviewers and PMDC/PPC-type complaints. "Eve" collides with an established period-tracker brand on both stores and is hard to search | medium | human | `app_en.arb:3` appName; `app_en.arb:8` tabEve | Keep TherapyLink as the company or B2B name (the clinician link is real). Test a consumer-facing store title like "TherapyLink: Eve, baat karne ke liye" and search-check "Eve" on Play PK. Run a trademark search with IPO-Pakistan before spending on brand. Don't rename the model persona without user testing | M |
| 13 | Zero analytics or attribution. Marketing cannot measure activation, retention, or which channel works | high | code | `app/pubspec.yaml` dependencies: no analytics, crash or attribution SDK; no deep-link package; `router.dart` has no referral route | Add the minimal event set in Recommendations §7 using a self-hosted or EU-hosted tool with no ad-network SDK. Play Install Referrer for campaign attribution. No Meta/TikTok SDK in the app | M |
| 14 | No landing page, no web presence, no deep links for referral or clinician invite codes | high | code | `app/web/` is the Flutter web build only; clinician invite codes are typed by hand (`app_en.arb:232-234,263`) | Static landing page (policy, terms, deletion, helplines, clinician sign-up). App Links `https://<domain>/c/<code>` that pre-fill the clinician invite code. This is the B2B2C growth loop | M |
| 15 | Clinician verification is a manual script, with no public process or SLA. The clinician channel can't scale and "checked against the licence number" is a claim | medium | human + code | `api/therapylink_api/routers/me.py:44-45` (`scripts/verify_clinician.py`); copy `app_en.arb:257` | Write down the verification procedure (PMDC register lookup for psychiatrists; for psychologists there's no single national register, so define the evidence: degree, supervisor, clinic). Publish it on the landing page | S |
| 16 | Remaining model gaps undercut any "it understands you" message: fails to acknowledge grief (`s07`) and passive ideation (`s23`), and misses warmth on everyday stress in Roman Urdu and mixed text (`s17`, `s20`) | high | ml | eval `sft-v14` scored.jsonl probes `s07`, `s15`, `s17`, `s20`, `s22`, `s23`; summary 18/24 all-checks | Marketing will lean on "gets Roman Urdu". Ask ml to add a short Roman Urdu empathy probe set (student stress, rishta pressure, in-laws, job loss) and hold paid ads until those pass. Marketing can supply the scenarios from segment research | M |
| 17 | Store-listing assets not prepared: no screenshots, feature graphic, or listing copy in the repo | medium | code + human | `app/assets/brand/` holds only icon, mark, wordmark, lockup | Use the plan in Recommendations §6 | S |
| 18 | "PHQ-9 · 9 questions" and severity bands in-app are fine as screening. Promoting them in ads ("find out if you're depressed") would be a diagnostic claim | medium (policy) | human | `app_en.arb:141-144,196-201`; `resultNote` at `:201` already says "screening score, not a diagnosis" | Never advertise the check-ins as a diagnosis or test. Frame them as "track how the last two weeks went". Put this in the claims list below | S |

## Recommendations

### 1. Positioning

One line: **"Baat karne ke liye koi, kisi bhi waqt."** / "Someone to talk to, any hour." This is already the welcome title (`app_ur.arb:12`, `app_en.arb:12`). Keep it. It's a companion promise, not a treatment promise, and ad reviewers can approve it.

What we are: a private, free, bilingual AI companion that listens in the language Pakistanis actually type and points to real Pakistani help when it matters. It can connect to your own clinician if you have one.

What we are not: therapy, a diagnosis, a doctor, an emergency service.

| Competitor | What they are | Where we differ | Claim we can honestly make |
|---|---|---|---|
| Wysa | Global CBT chatbot, English-first, paid human coaching | Roman Urdu and code-switching; Pakistani helplines; free | "Samajhti hai jaise aap likhte hain" (only after finding 16 is closed) |
| Woebot | US CBT bot. Reported to have shut its consumer app in 2025 (verify) | Available here, local language | Don't compare publicly |
| Headspace | Meditation library, USD subscription, English | We're conversation-first; exercises run inside the chat (`app/lib/features/eve/exercise_cards.dart`); free | "Talk first, breathe if it helps" |
| Sehat Kahani | Pakistani telehealth, female doctors, B2B with employers and insurers | We're the between-sessions companion, not the consult | Partnership target, not an enemy: referral out for "book a psychologist" moments (`resultExplainModerate`, `app_en.arb:345`) |
| Marham / oladoc | Doctor and psychologist booking | Same: we don't book | Partnership: "Find a psychologist" deep link after moderate or severe PHQ-9 |
| Taskeen | Pakistani mental-health NGO / awareness initiative | We're a tool; they have community reach and clinical credibility | Distribution partner and clinical advisor |
| Umang | Pakistan's mental-health helpline, and our crisis number | We send people to them | Must be a formal partner before launch (finding 9) |

Only claim privacy as far as the code backs it (finding 3). Once it's fixed, "Aap ki baatein aap ke phone par" is the strongest differentiator we have, and nobody in the local set can say it.

### 2. Target segments (in launch order)

1. **University students, 18-24** (exam stress, family expectations, hostel loneliness). Highest Roman Urdu usage and easiest to reach through campus societies. The starters already fit them (`eveStarterAnxious`, `eveStarterSleep`, `eveStarterVent`), and eval probe `s20` is literally exam stress, which is why it has to pass first.
2. **Young professionals, 23-35** (job pressure, burnout, rishta pressure, money). Reached through LinkedIn, employer HR, and TikTok/Instagram at night. Also the B2B wedge.
3. **Women facing family pressure** (in-laws, marriage pressure, restricted mobility). This is where the product helps most and where the risk is highest: phone sharing, someone reading over their shoulder, abuse disclosures. **Don't target this segment until** finding 8 is fixed, there's a quick-hide / app-lock option, and a women's-rights NGO has reviewed the flow. Reach them through NGOs, not paid social.
4. **People already in care**, through their clinician's invite code (`care_screen.dart`, `app_en.arb:232`). Lowest acquisition cost, highest retention. Grow by recruiting clinicians.

Not a segment: under-18s. There's no minors flow, no parental consent and no age gate. Exclude 13-17 in every ad platform and say 18+ on the store listing.

### 3. Messaging pillars

| Pillar | English | Roman Urdu | Proof in product |
|---|---|---|---|
| Always there | Someone to talk to, any hour. | Baat karne ke liye koi, kisi bhi waqt. | `welcomeTitle` |
| Your language | English, Roman Urdu, or both, the way you actually type. | English, Roman Urdu, ya dono, jaise aap asal mein likhte hain. | `welcomePointLanguage`; eval language match 8/8 (`sft-v14`) |
| Private (after finding 3) | Your words stay on your phone. | Aap ki baatein aap ke phone par rehti hain. | on-device runtime default, `settings.dart:16` |
| Real help when it matters | When it's serious, real help is one tap away. | Jab baat sanjeeda ho, asli madad ek tap door. | `crisis_sheet.dart` |
| Small steps | One minute of breathing, right in the chat. | Ek minute apne liye, yahin chat mein. | `exerciseSheetTitle`, exercise cards |
| You choose what's shared | Your clinician sees only what you switch on. | Aap ka doctor sirf wohi dekhta hai jo aap on karein. | `careConsentTitle`, consent flags |

Tone rules come straight from `app/PRODUCT.md`: steady, plain, no performed wellness. So no "heal", "cure", "fix your anxiety", "#1", streak or "transform your life" language, and no pastel-blob creative (anti-references in PRODUCT.md).

### 4. Claims the product must never make

- Diagnoses, treats, cures or prevents depression, anxiety or any condition. (Risk: DRAP may treat it as software as a medical device; Google/Meta "unproven health claims" policies.)
- "Therapist", "counsellor", "psychologist" for Eve. Eve is "an AI companion". Also don't say "our counselling model" in consumer ads, because PRODUCT.md line 13 uses that phrase internally.
- "Clinically proven", "evidence-based", "as good as therapy". There's no clinical study. The 48-probe eval is an engineering test, not clinical evidence.
- "Prevents suicide", "keeps you safe", "24/7 crisis support". Eve isn't a crisis service. Guardian misses cases (README: 0.85 test recall, 0% Roman Urdu for v0).
- "Nothing ever leaves your phone" (false, per finding 3), and "private" without qualification while cloud mode exists (`app_en.arb:33`).
- "Free forever". There's no pricing decision yet.
- Any ad that implies the viewer has a condition: "Are you depressed?", "Struggling with anxiety?", "Feeling suicidal?". Meta's personal-attributes policy and Google's personalised-ads rules both reject this. Use situation language instead: "Exam week?", "Raat ko neend nahi aati?", "Kisi se baat karni hai?".
- Endorsement by Umang, Rescue 1122, Madadgaar, PMDC, any university or any doctor without a signed agreement.
- Numbers from the eval ("12/14 crisis responses name a helpline") in consumer ads. They belong in the technical README, not in marketing, where they read as a safety guarantee.

### 5. Ads: what the platforms allow (verify every point against the live policy centre before launch)

**Google Ads / App campaigns**
- Mental-health and wellness apps are generally allowed. They fall under the Healthcare and medicines policy, and unproven or misleading health claims get disapproved.
- Personalised-advertising rules treat health, including mental health, and "personal hardships" as sensitive. That means no custom audiences or remarketing lists built from people's health status, no Customer Match on app users (the list itself implies a mental-health condition), and ad text can't imply knowledge of the viewer's condition.
- Addiction treatment ads need certification (LegitScript in many markets). We aren't addiction treatment, so keep "nasha" and "addiction" out of keywords and copy.
- Keyword search on terms like "anxiety help Urdu" is allowed. Expect some sensitive-query limits (verify).
- App campaigns optimise on Play events. Only feed the health-free events in §7.

**Meta (Facebook / Instagram)**
- Personal Attributes policy: ads can't assert or imply the viewer's mental or physical health.
- Detailed targeting options tied to health causes were removed in 2022. Use broad targeting, age 18+, Pakistan, language, and let creative do the targeting.
- Meta has restricted health and wellness advertisers from lower-funnel optimisation and from custom events that reveal health information, first in the US (verify whether and how it applies to Pakistan-targeted campaigns). Assume only install and app-open optimisation. Business Tools terms prohibit sending health data through the SDK, Pixel or CAPI regardless.
- Recommendation: **no Meta SDK in the app.** Run App Install campaigns measured by Play Install Referrer and a landing page with a privacy-safe server-side counter.

**TikTok**
- Health and wellness ads are allowed with restrictions on claims, before/after framing and minors (verify the Pakistan-specific policy page). Set age to 18+ explicitly. Don't use the TikTok SDK in the app for the same reason as Meta.

**Google Play listing**
- Health apps declaration in Play Console, Data safety form (it must list the chat-derived mood labels and the email/Firebase identity), privacy policy URL, account deletion (in-app and web), AI-generated-content reporting (finding 6), and a target audience of 18+.
- Don't choose "Medical" as the category. Use "Health & Fitness". "Medical" invites the regulatory-document request.

**Pakistan context (needs counsel)**
- Attempted suicide was decriminalised in 2022 when Section 325 PPC was repealed (verify with counsel). Messaging can say plainly that asking for help is not a crime, which matters to people who've been told it is.
- The Personal Data Protection Bill hasn't been enacted as far as I know (verify). Build to GDPR-level anyway. It's cheaper than retrofitting and it's the privacy story we're selling.
- DRAP: avoid any diagnostic or treatment claim to stay outside the medical-device rules.

### 6. App store listing

**Title (30 chars, Play):** `TherapyLink: Talk to Eve` (test against `Eve: Baat karne ke liye koi`)

**Short description (80):**
- EN: `A private AI companion that listens in English or Roman Urdu. Free.` (drop "Free" if pricing changes)
- UR: `Aap ki baat sunne wali AI saathi, English ya Roman Urdu mein.`

**Long description skeleton (EN; mirror in Roman Urdu as the Urdu-PK listing):**
1. Someone to talk to, any hour. Eve listens first, in English, Roman Urdu or both.
2. Runs on your phone (describe exactly what syncs, per finding 3).
3. When it's serious, real help is one tap away: Umang, Rescue 1122 (and Madadgaar once added).
4. Take a minute: breathing, 5-4-3-2-1 grounding, tense-and-release, right inside the chat.
5. Track how you're doing: a daily mood check, and two-weekly mood and anxiety check-ins (screening, not diagnosis).
6. Eve remembers what matters, and you can see and delete every note (`memoryIntro`, `app_en.arb:358`).
7. Working with a psychologist? Share only what you choose.
8. Important: Eve is an AI, not a therapist or doctor, and not an emergency service. In danger now? Call 1122. For 18+.

**Screenshots (8, 1080x1920, EN and Roman Urdu sets, real app UI with a one-line caption above):**
1. Eve greeting plus starters in Roman Urdu. Caption: "Jaise aap likhte hain, waise hi baat karein"
2. A short, realistic code-switched exchange about exam stress (scripted demo content, no real user data)
3. In-chat breathing card. "Ek minute apne liye"
4. The crisis sheet, shown calmly. "Jab baat sanjeeda ho, asli madad ek tap door"
5. Today screen with the mood trend and an insight that carries its caveat (`insightBasis`)
6. Memory screen with "Forget this". "Aap control mein hain"
7. Care team consent toggles. "Aap ka doctor sirf wohi dekhe jo aap chahein"
8. Privacy statement screen (after finding 3 is fixed)

Never show the "Download safety model" or "Not published yet" card, the 2 GB download screen, or a PHQ-9 "Severe" result.

Feature graphic: the mark on the `#101514` ground (`pubspec.yaml` launcher config) with the title line. No stock photos of sad people holding their heads.

### 7. What marketing needs from product and engineering

**Analytics, health-free by design.** Events carry no message text, no mood value, no assessment score or band, no Guardian verdict and no memory kinds. Use a pseudonymous install id, not the Firebase uid, and set a 90-day retention.

| Event | Properties allowed |
|---|---|
| `app_first_open` | install referrer campaign id, locale, app version |
| `onboarding_language_chosen` | `en` / `ur` |
| `model_download_started` / `_completed` / `_failed` | tier (`e2b`/`e4b`), network type (wifi/cell), duration bucket |
| `eve_first_reply` | runtime (`device`/`cloud`), seconds to first reply bucket |
| `session_started` | day-of-week only |
| `exercise_started` / `_completed` | exercise id |
| `checkin_completed` | instrument id only (`phq9`/`gad7`), **no score** |
| `journal_entry_saved` | nothing |
| `clinician_linked` | nothing |
| `crisis_sheet_shown` | **don't send to any analytics tool.** Count on the device and report as an aggregate only in an opt-in weekly health ping, or not at all. It's the most sensitive fact about a user |
| `share_invite_tapped` | nothing |

Put the full event list on the privacy policy page. Nothing goes to Meta, TikTok or Google Ads except `first_open` via Play referrer.

**Also needed:**
- Play Install Referrer read on first open, with UTM stored locally and sent with `app_first_open` only.
- App Links for `/c/<clinician-code>` (pre-fills the care invite) and `/r/<campus-code>` (tags university partners).
- A share-the-app action in You that sends a plain Play link with a campus or referral code, and no message saying "I'm using a mental-health app" (users choose their own words).
- Landing page: hero line, three pillars, helplines always visible above the fold, privacy policy, terms, account deletion form, clinician sign-up, partner logos only with permission.
- Quick-hide option (neutral launcher name or app lock) before the women segment.
- A pre-launch press/demo build pinned to the fine-tuned models.

### 8. First 90 days

**Days 0-30: closed beta, no paid ads.**
- Close blockers 1-5, 7 and 8.
- Recruit 2 universities (counselling centres at a Lahore and a Karachi university) and 1 NGO. Target 300-500 beta users via campus counsellors and student societies. The counsellor is the gatekeeper. Offer them the clinician workspace free.
- Recruit 10-15 clinicians (psychologists in private practice) to use invite codes with existing clients.
- Weekly qualitative interviews (5 per week) in Roman Urdu. Feed failing conversations (with consent) into the ml probe set.
- Metrics: activation (first Eve reply within 24 h of install), D7 return, crisis-sheet shows per 100 users (on-device aggregate), and report-reply rate.

**Days 31-60: soft public launch.**
- Store listing live (EN plus Roman Urdu), landing page, organic content.
- Content: 3 short videos a week on TikTok, Reels and Shorts, founder-led and in Roman Urdu. Topics: exam nights, "rishta ka pressure", "office ne pagal kar diya" (the `s17` phrasing, once it passes), a 60-second breathing demo, "what Eve does with your data". No ads yet. Test which themes get saves and shares.
- Partner with 1 content creator from the mental-health awareness space who already talks about therapy stigma. Get a written script review so no claims slip in.
- Start the paid test only if activation is at least 40% and D7 at least 15%.

**Days 61-90: paid test plus B2B pilots.**
- Run the first-month paid test (below).
- 2 employer HR pilots (software houses and BPOs in Lahore, Karachi and Islamabad; they have young, Roman-Urdu-typing staff). Offer free for 3 months with aggregate-only reporting: number of employees activated, never any individual data. Pricing is for the accounts review to set.
- World Mental Health Day (10 October) falls in this window if launch timing allows. Plan a campus event series with partner universities, and an Umang co-branded post only with their written approval.

### 9. First-month paid test budget (estimates)

Total **PKR 150,000** (about USD 535 at ~280 PKR/USD), after the activation gate is met. Android only, Pakistan, 18-34, English and Urdu interfaces.

| Channel | PKR | Est. CPI (PKR) | Est. installs | Notes |
|---|---|---|---|---|
| Google App campaigns (install optimisation) | 60,000 | 35-110 | 550-1,700 | Mostly Play, YouTube and Discover inventory. Situational creatives only |
| Meta App Install (IG Reels plus FB) | 50,000 | 45-140 | 360-1,100 | Broad targeting, 18+. No SDK, measured by referrer |
| TikTok App Install | 30,000 | 30-100 | 300-1,000 | Roman Urdu creator-style video, 18+ |
| Google Search (landing page) | 10,000 | n/a, CPC est. PKR 10-40 | 250-1,000 clicks | Keywords: "kisi se baat karni hai", "stress help urdu", "exam stress". Avoid condition keywords as ad text |

These CPIs are my estimates for Pakistan Android non-gaming apps in 2025-26 and could be off by 2x either way. The number that matters is **cost per activated user** (first Eve reply). With a 2 GB download it could easily be 3-5x CPI. Kill any channel whose cost per activated user is above PKR 400 after PKR 20,000 of spend. Creative rotation: 4 concepts x 2 languages per channel. Spend nothing on brand terms.

## What needs a human

- **Umang partnership and number verification.** Confirm hours, cost to caller and consent to be listed, and agree an MoU on referral volume. Same for Madadgaar 1098 and a women's-violence line. A person has to call each number before launch and again every quarter.
- **Legal counsel in Pakistan.** Privacy policy, terms, DRAP / medical-device exposure, PECA and data-protection posture, the Section 325 repeal wording, and the trademark search for "TherapyLink" and "Eve" (IPO-Pakistan and Play PK).
- **Licensed clinical advisor** (clinical psychologist or psychiatrist) to sign off on every marketing claim, the store listing, and the crisis sheet wording. Naming them publicly adds credibility, but only with consent.
- **Company entity and Play developer account** under the company, not a personal account, with a D-U-N-S number if Play requires an organisation account for health apps (verify).
- **Clean production Firebase / Google Cloud project** with a verified OAuth consent screen (finding 10). Owner action in the console.
- **Designer** to fix the wordmark typo and produce the screenshot set and feature graphic.
- **University and NGO partnership agreements**, including data terms: no individual data to partners, ever.
- **Pricing decision** (free, freemium or B2B-paid). The accounts review owns it, but store copy and ads depend on it.
- **Ad account setup and payment** for Google, Meta and TikTok in PKR. Business verification on Meta needs company documents.
