# Finance and accounts review: TherapyLink

Reviewer role: finance and accounts lead. Date: 2026-09-24. Branch: `rebuild/v2`.

Every figure below is an estimate. Each one carries its assumption as [E: ...]. Prices for cloud, Play fees and Pakistani taxes come from general knowledge. I could not check them live, so they are marked "not verified". The exchange rate used throughout is PKR 280 = USD 1 [E: rough 2025–26 rate; re-check before any contract].

## Summary

TherapyLink's cost structure is unusually good for an AI product. Chat inference runs on the patient's phone (`app/lib/core/settings/settings.dart:16` defaults to `EveRuntime.onDevice`), Guardian runs on the phone too, and the API stores no chat text (`api/README.md`). A free user therefore costs close to nothing at the margin. Sign-in is email/password and Google only (`app/lib/core/auth/auth_repository.dart:18-24`), with no SMS, so Firebase Auth costs nothing well past 10k MAU. The costs that matter are fixed: a clinical safety advisor, legal, accounting, and a small managed API/database. They come to about PKR 176k/month (~USD 630).

Server-first inference changes the picture at small scale. One always-on GPU costs about USD 300/month whether 100 or 1,000 people use it. That works out to ~USD 3.45 per MAU at 100 MAU against ~USD 0.45 on-device-first. The gap closes by 10k MAU (USD 0.085 vs 0.009).

Consumer subscriptions will not carry this in year one. At PKR 299/month, a 1.5% conversion rate and Play fees plus tax, consumer revenue covers fixed costs only at roughly 40k MAU. B2B licences carry it: one mid-size university contract (~PKR 100k/month) covers about 57% of the monthly fixed cost. The 12-month base case turns monthly-positive in month 10 and needs about PKR 1.8M (~USD 6.5k) of funding before then. I recommend holding PKR 2.5M to leave a contingency.

Money is not the biggest problem, though. The model that produces the good eval numbers, Eve v14, was trained on CC BY-NC and unverified-licence data. A company cannot legally charge for it or use it commercially as trained. In addition, the app currently downloads **stock** Gemma, not Eve. So the numbers that justify the product are not what a patient would get.

## Verdict

**Not ready to take money or to ship to patients under a company.** The unit economics are workable, and on-device-first is the right call financially. Three things block commercial launch before any budget matters:

1. Eve's training data licence.
2. No account deletion and no privacy policy, which Play requires and which patient health data demands.
3. No registered entity to hold Play payouts, sign B2B contracts, or carry liability.

None of them is expensive to fix. Retraining without NC data uses the free Kaggle quota. The rest is legal and admin work worth roughly PKR 300–500k one-off.

## Findings

| # | Finding | Severity | Owner | Evidence | Recommendation | Effort |
|---|---|---|---|---|---|---|
| F1 | Eve v14 was trained on non-commercial data, so it cannot back a paid or company product | blocker | ml | `ml/data/processed/DATA_CARD.md:9-11,17-23` lists counselchat (scraped, terms unverified), empathetic_dialogues and esconv (CC BY-NC 4.0) as "Commercial use: no". The SFT notebook passes `--weights esconv=0.5,...,counselchat=1.5,...` (`ml/notebooks/eve_sft_kaggle.ipynb`) and never passes `--exclude-nc`. `ml/therapylink_ml/train/eve_sft.py:164` defaults `exclude_nc=False`. `ml/KAGGLE.md:24` states the training is defensible only for "a non-commercial portfolio project". | Retrain with `--exclude-nc` and re-run the 48-probe eval. Budget one Kaggle run (~5 h of the free 30 GPU-h/week) [E: from `--max-hours 5` in the notebook]. Treat MentalChat16K (GPT-3.5-generated rows, `DATA_CARD.md:75`) as a legal-review item: the dataset is MIT, but the upstream generator's terms still apply. Write a model card that lists every source. | M |
| F2 | The app ships stock Gemma and a keyword-only Guardian, not the trained models the finances assume | blocker | code | `app/lib/core/ml/gemma_eve_engine.dart:21-35` points at the `litert-community/gemma-4-E2B-it` stock conversion ("The fine-tuned Eve replaces these once the LiteRT-LM export ... is published"). `app/lib/core/ml/onnx_guardian.dart:15` `TL_GUARDIAN_URL` defaults to `''`, so Guardian stays heuristic. Stock E2B names a resource on crisis in 1/14 probes (base-e2b, `README.md` results table). | Publish the commercially-clean Eve `.litertlm` and Guardian ONNX, then wire both URLs. Host them on Cloudflare R2 or public Hugging Face: storage is under USD 1/month and egress is free [E: R2 zero-egress pricing, not verified]. This is a hosting line item, not a GPU cost. | M |
| F3 | Cloud inference endpoint has no rate limit, quota or metering, so GPU spend is unbounded | high | code | `api/therapylink_api/routers/inference.py:11-37` forwards any authenticated request. `api/therapylink_api/schemas.py:145-153`: `ChatMessage.content` has no length cap and `messages` has no max count; only `max_tokens<=1024`. No rate-limit code anywhere in `api/` (grep for rate/throttle/slowapi returned nothing). Anyone who creates an email account can drive the GPU. | Before `TL_INFERENCE_BASE_URL` is ever set in production, cap message count and characters, add a per-uid daily turn quota, log tokens per uid per day, and put cloud mode behind an entitlement (paid tier or B2B tenant). | S |
| F4 | No account deletion and no privacy policy or terms in the app | blocker | code + human | `api/therapylink_api/routers/me.py:27-73`: the only DELETE is `/me/clinician`, with no route to delete a patient account and its assessments, journal, mood and summaries. `app/lib/l10n/app_en.arb` contains no privacy-policy or terms strings (grep count 0). | Add `DELETE /me` with cascade, an in-app delete button and a web deletion URL, which Google Play requires for apps with accounts. A lawyer drafts the privacy policy and terms [E: PKR 100–250k one-off, not verified]. | M |
| F5 | No billing, entitlement or usage analytics exist, so there is nothing to price against yet | high | code | Grep of `app/lib`, `api/therapylink_api` and `app/pubspec.yaml` for billing/subscription/payment/jazzcash/in_app_purchase returned nothing. No product analytics package in `app/pubspec.yaml:16-43`. | Add Google Play Billing (`in_app_purchase`), with server-side verification through the Play Developer API into a `subscriptions` table and an `entitlement` field on `/me`. Add privacy-preserving counts only (MAU, sessions, conversion) with no message content, matching the product promise in `app/PRODUCT.md`. | M |
| F6 | No legal entity, tax registration or payout bank account | blocker (for charging) | human | Nothing in the repo. `api/therapylink_api/settings.py:10` defaults to the student Firebase project `therapylink69`, which shows it is still running as a personal project. | Register a private limited company with SECP, obtain an NTN from FBR, register for provincial sales tax on services (PRA/SRB/ICT, depending on where the company sits), open a business bank account that can receive Google Play payouts, and create a separate production Firebase/GCP project owned by the company. | M |
| F7 | The suggested free API host does not suit patient data | high | code + human | `api/README.md` "Deploy" suggests Hugging Face Spaces or the Neon free tier. Spaces sleep, sit on a public-by-default platform and come with no data-processing agreement. | Budget Cloud Run with 1 min-instance (~USD 15/mo) plus managed Postgres with backups (~USD 25/mo) [E: Cloud Run and Neon/Supabase list prices, not verified]. Sign the provider DPAs. Pick a region with a lawyer: GCP has no Pakistan region, and Pakistan's data protection bill (status not verified) may restrict moving health data abroad. | S |
| F8 | The ~2 GB model download is a cost to the patient and hurts acquisition | medium | code | `gemma_eve_engine.dart:29`: `gigabytes: 2.0` for E2B. | Default the download to Wi-Fi only and show the size in PKR terms before it starts [E: mobile data at ~PKR 100–250/GB, not verified, so ~PKR 200–500 per install]. Keep the no-download path usable (crisis path, check-ins, journal). Count download completion as a funnel metric. | S |
| F9 | Paid clinical oversight is not budgeted, but a patient product needs it | high | human | The crisis path and PHQ-9/GAD-7 result copy (`app_en.arb:344-345`) give clinical guidance. The eval judge is rule-based (`ml/therapylink_ml/eval/safety_rules.py`). No licensed person signs off anywhere in the repo. | Retain a licensed clinical psychologist as safety advisor [E: PKR 100k/month part-time retainer]. Get professional indemnity or tech E&O insurance if a Pakistani insurer will write it (availability not verified). Put both in fixed costs, as the budget below does. | M |
| F10 | Helpline numbers are used without a partner agreement | medium | human | The crisis sheet lists Umang 0311-7786264, Rescue 1122 and Madadgaar 1098 (task brief; crisis sheet in `app/lib/features/eve/`). | Before directing patient volume to Umang, sign an MoU or at least get written permission. Budget an in-kind or donation line [E: PKR 0–25k/month]. This also becomes a marketing asset. | S |
| F11 | Training depends on one person's free Kaggle quota | low | human | `ml/KAGGLE.md:3,9`: 30 GPU-h/week, gated on phone verification of a personal account. Kaggle's terms for commercial training use were not verified. | Move the company's training runs to a company-owned account. Budget a fallback of ~USD 50–100/month of rented GPU for months with heavy retraining [E: ~100–200 T4/L4 hours at ~USD 0.4–0.5/h, not verified]. | S |

## Unit economics

### Usage assumptions (per monthly active user)

- 8 chat sessions a month, 10 turns each: 80 Eve replies [E: typical engagement for a companion app; replace with real telemetry once F5 lands].
- Each turn sends up to ~4,096 tokens of prompt and reply (`app/lib/features/eve/eve_controller.dart:66-70`). Median reply is 64.5 words (`ml/runs/eval/sft-v14/summary.json`, `median_reply_words`), so ~100 output tokens.
- Memory and summary passes add up to 300 + 250 output tokens every few turns (`eve_controller.dart:347,357`), and wrap-up adds 200 + 60 (`eve_controller.dart:210,213`).
- API traffic (mood batch, assessments, journal, `/me`): ~200 requests per MAU per month [E].

### Cost per active user per month

On-device-first means inference runs on the phone. Server-first means every Eve turn goes through `/inference/chat` to a llama.cpp GPU server.

| MAU | On-device-first (USD / PKR) | Server-first, always-on GPU (USD / PKR) | Server-first, scale-to-zero GPU (USD) |
|---:|---:|---:|---:|
| 100 | 0.45 / 126 | 3.45 / 966 | ~1.05 |
| 1,000 | 0.05 / 14 | 0.35 / 98 | ~0.35 |
| 10,000 | 0.009 / 2.7 | 0.085 / 24 | ~0.085 |

What these numbers assume:

- **Infra only.** People costs are covered in the next section.
- **On-device infra:** USD 45/month at 100 MAU (Cloud Run min-instance ~15, managed Postgres ~25, logs/backups ~5); USD 50 at 1k; USD 95 at 10k (larger DB tier, second API instance) [E: list prices, not verified].
- **Firebase Auth:** USD 0 [E: email and Google sign-in are free below 50k MAU; no SMS in this app].
- **Model hosting:** ~USD 0 [E: R2 or public Hugging Face].
- **Always-on GPU:** one L4/T4-class GPU at ~USD 300/month covers 100 and 1k MAU. 10k MAU needs ~2.5 GPUs (USD 750) [E: 800k turns/month is ~0.3 turns/s on average and ~1 turn/s at a late-night peak; llama.cpp serving E2B Q4 with parallel slots handles roughly one turn per second per GPU including ~3k-token prefill. The v14 eval measured 37.8 tok/s single-stream on the RTX 2050 dev box (`sft-v14/summary.json` latency); a data-centre GPU with batching is several times that. Not load-tested].
- **Scale-to-zero** (for example Cloud Run GPU) is cheaper at 100 MAU, but loading a 2 GB model from cold takes tens of seconds. That is poor for someone in distress, although the crisis path itself stays on-device and deterministic.

Conclusion: stay on-device-first. Offer server inference only as a paid or B2B option for phones that cannot run E2B, and only after F3 is fixed.

## Fixed monthly costs (on-device-first, once live with patients)

| Line | PKR k / month | Assumption |
|---|---:|---|
| API + DB + backups + logs | 13 | USD 45, see above |
| Domain, email, Apple developer (USD 99/yr), misc SaaS | 5 | [E] Google Play registration is a one-off USD 25 |
| Accountant / tax filer (monthly sales-tax and withholding returns, annual return) | 20 | [E: small-firm retainer in Lahore/Karachi] |
| Clinical safety advisor, licensed psychologist, part-time | 100 | [E] |
| Legal retainer (policy updates, B2B contract review) | 21 | [E: ~PKR 250k/yr] |
| Insurance (PI / cyber), if obtainable | 14 | [E: availability not verified] |
| Contingency | 3 | |
| **Total** | **176** (~USD 630) | Excludes founder salary and marketing |

With server-first, add PKR 84k/month for one always-on GPU.

The owner's salary is zero in this budget. At a market salary for a Pakistani mid-level Flutter/ML engineer [E: PKR 250–400k/month], break-even moves out by more than a year. That choice belongs to the owner, so it is stated here rather than hidden.

One-off costs in months 1–2: company registration and legal drafting (privacy policy, terms, clinician agreement, B2B template) PKR ~300k; independent security test and clinical safety review of the probe set PKR ~200k [E].

## Business models and pricing recommendation

| Model | Price (recommended) | Rationale |
|---|---|---|
| **Free tier (B2C)** | PKR 0 | On-device Eve, crisis path, PHQ-9/GAD-7, mood, journal, clinician sharing. Crisis features and basic chat must never be paywalled: that would be unethical, and the marginal cost is ~0 anyway. |
| **TherapyLink Plus (B2C)** | PKR 299/month or PKR 2,499/year through Google Play Billing | Longer memory, guided programmes, PDF export for a clinician, and optional cloud mode for low-end phones. PKR 299 sits below common streaming subscriptions in Pakistan [E: not verified]. Play supports carrier billing in Pakistan (Jazz, Zong, Telenor) [E: not verified], which matters because card penetration is low. |
| **University licence (B2B)** | PKR 300–500 per enrolled student per year, minimum PKR 600k/yr | Campus counsellors get the clinician workspace and the university gets aggregate, anonymised uptake reports. This is where year-one revenue comes from. |
| **Employer licence (B2B)** | PKR 150–250 per employee per month, minimum 100 seats | Pakistani employers rarely buy EAPs, so this is a slower sale than universities [E]. |
| **Clinician SaaS seat** | PKR 3,000/month per verified clinician | Caseload dashboard (`api/therapylink_api/routers/clinician.py`), consent-gated. Pay by JazzCash/Easypaisa merchant or a local card gateway on the web, not in-app. |
| **NGO / government** | Grant or cost-recovery | Pitch it as a free public-good tier: Roman Urdu, on-device, no chat data leaves the phone. Good fit for WHO/UNICEF-funded mental-health programmes and provincial health departments [E]. |

Net per Plus subscriber: PKR 299 × 0.85 (Play's 15% subscription fee) ≈ 254, less embedded sales tax on services (~16%) ≈ **PKR 214/month** [E: Play fee tier and whether Google remits the tax in Pakistan are not verified].

Payment rails:

- **In-app digital subscriptions:** Google Play Billing only. Play policy requires it for digital goods.
- **B2B and clinician seats:** bank transfer against a sales-tax invoice, or JazzCash/Easypaisa merchant or a local card gateway on a web billing page [E: ~1.5–3% MDR, not verified]. Stripe does not onboard Pakistani entities directly [E: not verified as of 2026].

## Break-even

- **Consumer only:** 176k / 214 ≈ 823 paying subscribers. At 1.5% conversion that needs ~55k MAU; at 2%, ~41k MAU [E: 1–2% freemium conversion in a price-sensitive market].
- **B2B:** one university at ~PKR 100k/month plus ~25 clinician seats (PKR 75k) covers fixed costs.
- **Base case below:** monthly break-even in month 10, with cumulative funding need peaking at about PKR 1.9M in month 9.

## 12-month P&L sketch (PKR thousands, base case)

Assumptions:

- MAU ramps from 50 to 4,000 through a campus pilot and organic growth [E].
- Plus launches in month 4 at 1.5% conversion, PKR 214 net per subscriber.
- First paid university from month 7 at 100k/month, second from month 10.
- Clinician seats grow from 5 (month 6) to 20 (month 12) at PKR 3k.
- Marketing: 30k in month 3, then 60k/month (campus events plus Meta/Google app-install ads) [E: Pakistan Android CPI ~USD 0.1–0.4; Meta restricts health targeting].
- B2B sales tax is collected and remitted, so it is excluded from revenue.

| Month | MAU | Plus subs | Consumer rev | B2B rev | Clinician seats rev | Total revenue | Fixed | One-off | Marketing | Total cost | Net | Cumulative |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 50 | 0 | 0.0 | 0 | 0 | 0.0 | 90 | 300 | 0 | 390 | -390.0 | -390.0 |
| 2 | 100 | 0 | 0.0 | 0 | 0 | 0.0 | 120 | 200 | 0 | 320 | -320.0 | -710.0 |
| 3 | 200 | 0 | 0.0 | 0 | 0 | 0.0 | 176 | 0 | 30 | 206 | -206.0 | -916.0 |
| 4 | 500 | 8 | 1.7 | 0 | 0 | 1.7 | 176 | 0 | 60 | 236 | -234.3 | -1,150.3 |
| 5 | 800 | 12 | 2.6 | 0 | 0 | 2.6 | 176 | 0 | 60 | 236 | -233.4 | -1,383.7 |
| 6 | 1,200 | 18 | 3.9 | 0 | 15 | 18.9 | 176 | 0 | 60 | 236 | -217.1 | -1,600.9 |
| 7 | 1,600 | 24 | 5.1 | 100 | 24 | 129.1 | 176 | 0 | 60 | 236 | -106.9 | -1,707.7 |
| 8 | 2,000 | 30 | 6.4 | 100 | 30 | 136.4 | 176 | 0 | 60 | 236 | -99.6 | -1,807.3 |
| 9 | 2,500 | 38 | 8.1 | 100 | 36 | 144.1 | 176 | 0 | 60 | 236 | -91.9 | -1,899.2 |
| 10 | 3,000 | 45 | 9.6 | 200 | 45 | 254.6 | 176 | 0 | 60 | 236 | 18.6 | -1,880.5 |
| 11 | 3,500 | 53 | 11.3 | 200 | 54 | 265.3 | 176 | 0 | 60 | 236 | 29.3 | -1,851.2 |
| 12 | 4,000 | 60 | 12.8 | 200 | 60 | 272.8 | 176 | 0 | 60 | 236 | 36.8 | -1,814.4 |
| **Year** | | | **61.6** | **900** | **264** | **1,225.5** | | **500** | | **3,039.9** | **-1,814.4** | |

Months 1–2 fixed costs are lower because the clinical retainer starts part-way. With server-first, add 84k/month from month 3 (~PKR 840k over the year), which pushes break-even past month 12.

Reading of the table: consumer revenue is under 5% of year-one revenue. The business is a B2B product with a free consumer front door. Sales effort should go into two university pilots, starting now.

## Accounting and compliance

- **Company:** SECP private limited company (online registration via LEAP) [E: government fee under PKR 10k; consultant PKR 20–50k]. Annual return, audited accounts once over thresholds, and a registered office.
- **Tax:** FBR NTN and annual income tax return. Provincial sales tax on services applies to IT/software services, and the rate depends on the province [E: ~15–16% standard, some IT services at reduced rates; not verified]. If Play payouts count as export remittance, check registration with PSEB/PSEB-equivalent for the reduced export-of-IT-services regime [E: not verified]. Corporate B2B customers will withhold income tax at source on service payments [E: rate not verified]. Track the withholding certificates so they can be claimed.
- **B2B invoicing:** sequentially numbered sales-tax invoices showing the company NTN/STRN, customer NTN, service description, tax amount and period. Keep a subscription register (customer, seats, start/end dates, amount) and recognise annual licences monthly as deferred revenue. Use one invoice template and one bank account from day one.
- **Play revenue:** book gross sales with the Play fee as a cost of sales, reconciled monthly against Play's earnings report. Keep the tax-inclusive price separate from net.
- **Clinician payouts:** do not run any in year one. The product sells seats *to* clinicians and does not route patient payments *to* them. Becoming a payment intermediary brings escrow, withholding on every payout, and liability for the clinical service. If a marketplace is added later, use a licensed payment aggregator's split-payment product and a written clinician agreement.
- **Data protection:** privacy policy, a data-processing record, DPAs with Google/Firebase, the DB host and the model host, and a documented deletion path (F4). Treat PHQ-9/GAD-7 scores and journal text as sensitive health data.
- **Model licences:** Gemma's terms of use (prohibited-use policy; licence terms not re-verified here) and a model card listing every training source (F1).

## Recommendations

1. Retrain Eve v15 or v16 with `--exclude-nc` on Kaggle and re-run the 48-probe eval. Ship only a commercially clean adapter (F1). Costs PKR 0 on free quota.
2. Publish Eve and Guardian artefacts and wire the URLs in the build, so patients get the evaluated models (F2).
3. Harden `/inference/chat` (caps, quota, metering) before cloud mode is ever enabled, and gate it by entitlement (F3).
4. Build `DELETE /me`, the privacy policy screen, Play Billing with server verification, and content-free usage counts (F4, F5).
5. Deploy on Cloud Run plus managed Postgres under a company-owned GCP/Firebase project, not Spaces (F6, F7).
6. Launch free-first. Add Plus at PKR 299/2,499 once there are ~1,000 MAU of retention data. Lead revenue with university licences.
7. Raise or set aside PKR 2.5M for year one, zero founder salary assumed. Re-forecast monthly against real MAU and conversion.

## What needs a human

- A lawyer: confirm Eve cannot be used commercially as trained. Review MentalChat16K upstream terms, Gemma terms and Kaggle terms for commercial training. Draft the privacy policy, terms, clinician agreement and B2B licence. Advise on the health-data residency position under Pakistani law.
- A chartered accountant or tax adviser: SECP registration, NTN, which provincial sales-tax regime applies, whether Play payouts qualify as IT export, withholding rates on B2B receipts, and the book-keeping setup.
- A licensed clinical psychologist: paid safety advisor who signs off the crisis path, the probe set and the assessment copy. Also check whether insurance can be bought.
- Umang (and ideally Rescue 1122 and Madadgaar): written permission or an MoU before directing patient volume to them.
- University counselling heads: pilot and price conversations. Only the owner or a sales lead can have these.
- Google Play: merchant account for the new company, carrier-billing availability, and the current fee tier, verified in the console.
- The owner: decide founder salary and total runway, and whether cloud inference is offered at all in year one.
