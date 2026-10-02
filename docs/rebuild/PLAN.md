# TherapyLink v3: build plan

Owner: Azam. Drafted 2026-10-03 from the discovery docs in this folder: FEATURES.md, MODEL.md, UX.md, SECURITY.md and BACKEND.md. The design direction is still in progress (see "Design" below).

## Decisions already made

| Decision | Choice | Why |
|---|---|---|
| App framework | Flutter (Dart) | The safety-critical v2 logic (crisis routing, output guard, helplines, PHQ-9 item 9, SQLCipher, app lock, quick exit) is tested Dart and carries over. The native parts already ran on the owner's phone. |
| App scope | A completely new app with a new design | Legacy shows the feature set and v2 supplies proven logic. Neither UI is kept. |
| Visual identity | Legacy palette (night #1D1E2C to plum #34063F, pink #F23598, violets, lime #89F336), dark-first, unique, not Claude-like, with Blender-made 3D for Eve and breathing | Owner direction. The design skills used are design-taste-frontend, high-end-visual-design, emil-design-eng, impeccable and design:design-critique. |
| Eve model | v16-clean epoch 2 (Gemma 4 E2B + LoRA), served from a server | It is the only commercially clean model that passed its gate, and the best clean model on the 5-sample eval. DPO v16 overfit (201 pairs). No fine-tuned phone build (.litertlm) exists yet. |
| Eve's served prompt | V2 "psychologist" prompt, memory notes on | The model was trained on V2. The app must send exactly that prompt (`test_prompt_parity`). |
| Backend | FastAPI + Postgres (Neon, Singapore/Mumbai) + Firebase Auth | v2 API is tested (107/108, consent fix in progress). Cheap at pilot scale (about $25-75/month). |
| Crisis routing | On the device, before the model, never dependent on the server | No model passes the helpline hard gate (best 49/70). Routing and output guard stay in front of Eve. |
| Repository | Start a fresh repo for v3 | `rebuild/v2` carries legacy history with leaked keys. Never push it anywhere as-is. |

## Do today (owner only)

1. **Firestore rules on project `therapylink69`.** Check Firebase console > Firestore > Rules. If they read `allow read, write: if true`, set deny-all now. Legacy users' chats and journals are stored there in plaintext.
2. **Revoke and confirm the legacy credentials.** SECURITY.md §5.2 has a checkbox list. The GCP service-account key (`legacy/assets/google_speech.json`) matters most: confirm it is deleted in IAM and review audit logs.
3. **Make `azamali992/fyp_therapylink` private or archive it.** All of those keys are in its history.

## MVP scope (first closed pilot, about 100 people)

Keep (rebuilt with the new design):
- Onboarding: welcome, 18+ gate, versioned consent, email/Google sign-in. Get help is reachable before sign-in.
- Eve chat: server inference with streaming, conversation list, delete, memory notes (view/delete), wrap-up with one next step, exercise cards in chat.
- Safety: on-device keyword guardian before every message, crisis card matched to danger type, pinned help bar, 60-minute crisis mode, output guard against unknown numbers, journal screening, PHQ-9 item 9 offline check.
- Today: 5-point mood check-in, 7-day trend, insights only with enough data, PHQ-9 and GAD-7, breathing and grounding exercises (3D breath object).
- Journal: private, encrypted, mood while writing, prompts.
- You: app lock, quick exit, theme, language (English / Roman Urdu), export, delete account, sign out with wipe.
- Clinician linking by invite code with per-section consent and access log (patient side), plus a minimal clinician view.

Later (phase 2+): Urdu-script UI, voice, on-device Eve (.litertlm), verified clinician directory, admin panel, guardian/family pathway, clinician crisis alerts.

Dropped from legacy: Places map and booking marketplace, Gemini summaries, Render-hosted services, art canvas, ambient sounds/YouTube meditations (may return later as curated content), hard-coded stats and badges.

## Build phases and team

Each workstream runs in its own git worktree in the new repo. Agents do not push; Claude reviews, runs the tests, and merges.

| Phase | Workstreams (parallel) | Exit criteria |
|---|---|---|
| 0. Foundation (about 1 week) | **Repo:** new repo, CI (format, analyze, tests, gitleaks). **App shell:** Flutter 3.47.4 project, design tokens from the approved direction, router, l10n, theme (light + dark), SQLCipher DB, app lock, quick exit. **API:** carry v2 API over, consent fix, Dockerfile, TL_ENV guard. **ML:** model registry (`ml/registry.json`), llama-server config behind the API with `--api-key`, no public tunnel. | App boots on a real phone; API 108/108; ml 256/256 with prompt parity. |
| 1. Core experience (about 2 weeks) | **Eve:** chat UI with 3D presence, streaming, memory, conversations. **Safety:** port guardian, crisis card/mode, output guard, helplines (data-driven, updatable from server with offline fallback). **Today + Journal + Exercises.** **You/Settings + clinician linking.** | All crisis tests ported and passing; offline check-ins and journal work; QA test plan executed. |
| 2. Hardening (about 1 week) | **Security:** SECURITY.md P0 code items (App Check, rate limits, key restriction, deletion page). **QA:** E2E on two low/mid Android phones, accessibility, reduced motion, Roman Urdu LTR. **Perf:** cold start, 3D fallbacks to video/poster on low-end devices. | P0 code items closed; no open P0/P1 bugs. |
| 3. Pilot | Deploy (Cloud Run + Neon), clinician-signed copy, verified helplines, pilot protocol. | Owner's human blockers closed (see below). |

Parallel ML track (Kaggle, about 4-5 GPU hours): v17-clean SFT with clinician-approved red-line rows, then DPO with 800-1,000 pairs (at least 30% safety, clinician rewrites, 1 epoch, early stop), then Guardian v1 with Roman Urdu. Evals use `--greedy` so worst-of-5 is reported.

## Owner decisions still open

1. **Design direction.** Pending the new mockups.
2. **Under-18 path.** Adults only for the pilot (recommended), or a guarded 16-18 path.
3. **Clinician crisis alerts.** Should a linked clinician be alerted when the guardian flags a crisis turn? This is a clinical-governance call.
4. **Clinician side in the pilot.** Patient-side linking plus a minimal clinician view (recommended), or defer it to phase 2.

## Human blockers before any real patient

- Company entity (SECP, FBR NTN) and company-owned Firebase/GCP/Play accounts.
- A lawyer writes the privacy policy and terms; a public account-deletion URL.
- A Pakistan-licensed clinician signs the red lines, crisis copy, consent text and the served model.
- Each helpline number verified in writing with the service (Umang, Madadgaar 1098, Rescue 1122), plus a women's/DV line.
- Roman Urdu copy reviewed by a native speaker with clinical background. PHQ-9/GAD-7 translation status documented.
