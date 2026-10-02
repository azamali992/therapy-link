# TherapyLink v3 — UX Research & Design Direction

**Author:** UX Research / Lead Design  
**Date:** 2026-10-03  
**Branch:** rebuild/v2  
**Scope:** Evidence-based UX spec for the next build. Read-only against the codebase; no code changes here.

---

## 1. Industry Research — What Works and What Doesn't

Sources: Smashing Magazine, ChooseTherapy, JMIR, UX Writing Hub, Screensdesign, Clustox, Biz4Group, Gapsystudio, and app store research conducted October 2026. Links at the end of each section.

### 1.1 Onboarding

**What works**

- **Woebot** sets the emotional tone in the first message rather than listing features. It names what the app is, admits it is a bot, and gives a single action. Users report "I understood what it was for in 30 seconds." ([UX Writing Hub case study](https://uxwritinghub.com/woebot-case-study-in-conversation-design-for-mental-health-products/))
- **Daylio** uses a micro-onboarding — three screens, no sign-in required before value. The palette choice on screen 1 ("Which colors feel right?") creates immediate ownership. ([Screensdesign breakdown](https://screensdesign.com/showcase/daylio-journal-daily-diary))
- **Stoic** starts with a mood check-in as its very first interaction; the user has done something useful before they've seen a feature list. ([App Store description](https://apps.apple.com/us/app/stoic-journal-mental-health/id1312926037))
- **Progressive profiling** (Smashing Magazine, Feb 2026): collect only the language preference first, defer name and account to the moment they want to save data. This pattern showed the highest first-session completion in the A/B cases cited.

**What fails**

- Walls of feature bullets before any action (Sanvello's old pre-2025 onboarding; deprecated since their 2025 redesign).
- Forced sign-in before first value. The marketing review (docs/ship-review/marketing-ads.md Finding 7) identifies this exact pattern as the biggest drop-off risk for the current build.
- Consent that is all-or-nothing: one "agree" button covering data processing, age, AI disclaimer, and helpline awareness together. Users tap without reading. UK ICO guidance (2025) found single-checkbox consent for health data unenforceable.

### 1.2 Chat UX for AI Companions

**Patterns that build trust**

- **Acknowledge before acting**: Woebot and Wysa both reflect the user's feeling in a single sentence before any tool, exercise or follow-up question. Studies in JMIR (2025, [Expert analysis of AI chatbots](https://www.jmir.org/2025/1/e67114)) show "acknowledged" users complete 2.3× more sessions.
- **Bite-sized replies**: Mental health chat should never produce a wall of text. The Smashing Magazine (2026-07, [Designing for Distressed Users](https://www.smashingmagazine.com/2026/07/designing-distressed-users-mental-health-apps-ui/)) piece explicitly cites 3–5 line caps as a safety feature, not just a style choice.
- **Pre-populated quick replies** reduce the cognitive cost of responding when attention and working memory are reduced (Woebot's "Tell me more" / "I'm not sure" buttons). These should be contextual, not generic.
- **Typing indicator** signals responsiveness without pressure. The animation should be subtle — a pulse rather than animated dots, given prefers-reduced-motion requirements.
- **Streaming output** (character-by-character) feels more alive than a response that appears all at once. v2 already does this.
- **Naming the AI clearly and consistently** in the UI (speaker label, intro, disclaimer) builds rather than undermines trust. Parallelhq (2026): users 63% more likely to engage with an AI that signals its nature than one that avoids it. ([Designing AI Chatbots](https://www.parallelhq.com/blog/ux-ai-chatbots))

**Patterns that erode trust**

- Scripted fallback replies that ignore what the user said ("I'm sorry you're going through that. Here are some tips…"). The v2 `eveFailureReply` is exactly this.
- Enabling the composer while the model isn't ready. Sending a message and getting "I'm having trouble replying" teaches users the app is unreliable (v2 M1).
- Speaker confusion: when the UI doesn't clearly distinguish Eve's voice from the user's voice, blind users and people scanning chat can lose track.

### 1.3 Mood Logging Friction

**Lowest-friction patterns**

- **Emoji + single tap** (Daylio): no words required. Works at 2am. The five moods map to five faces; the selected face animates gently. No confirm step.
- **Inline on the home screen** (Stoic, v2 Today): the check-in is the first thing, not behind a "Log Mood" button. v2 already does this correctly.
- **Labelled + colour-coded** (v2 valence scale): this is the right call for accessibility. Smashing Magazine (2026-07) explicitly calls out "colour-only mood scales" as an accessibility failure. v2's `valenceColor` + text label combination is better than every global comparator checked.
- **One clear action per open**: once a check-in is logged, the card collapses to a single line. v2's Today screen already does this.

**Sources of friction to remove**

- Any loading state on the mood tap. Mood should optimistically save locally and sync in the background (M4 in the UX/UI review).
- Requiring a network connection to see past entries.

### 1.4 Streaks Versus Guilt

Research consensus (Smashing Magazine 2026-07, NaakVik 2025, UX Mag): **Streak mechanics from entertainment apps — lost streak counters, shame animations, "your streak is about to die" notifications — measurably worsen depression and anxiety symptoms.** The loss-aversion mechanism (Prospect Theory) makes a missed day feel twice as bad as a completed one feels good.

**What to do instead** (validated patterns):
- No streak counter visible on the home screen.
- Instead: a gentle "N days this week" in the insight section, framed as information not performance.
- No notification that references the user's failure ("You haven't checked in today").
- Notification option, off by default: "Eve is here if you want to talk." Delivered once a day, before the most common low-mood window for the user (from their own data).
- Finch's "flexible goals" model: goals adapt to energy level, not the other way around. The v2 PRODUCT.md anti-reference for streaks is exactly right.

Sources: [Gamification Gone Wrong](https://nerdsip.com/blog/gamification-gone-wrong-when-streaks-become-the-point), [Psychology of Hot Streak Game Design](https://uxmag.com/articles/the-psychology-of-hot-streak-game-design-how-to-keep-players-coming-back-every-day-without-shame)

### 1.5 Crisis UX

**Best-in-class pattern** (synthesised from Rootd, Headspace's SOS path, and academic safety design):

- A crisis entry point is always visible — one tap from any screen, no scrolling required.
- The crisis surface delivers a number *in the text*, not only in a button label. A person who cannot process the button can still read the number.
- Numbers are displayed in large, selectable text with a copy button as well as a call button, because the dialler may not be available (tablet, no SIM, app on a PC).
- The interruption is once, not recurring: showing a modal sheet every turn after a flag teaches avoidance. v2's sticky "Help is here" bar (recommended in crisis-safety.md F5) is the right pattern.
- Dismissing the modal does not end access: the card remains in the transcript, the bar stays above the composer.
- The crisis path never requires an account, never requires network, and is never behind a paywall.

**What to avoid**
- Making the crisis button the same colour or visual weight as a routine action.
- Routing every crisis through a single modal that cannot be easily found again.
- Conflating abuse/DV, suicide/self-harm, and child safeguarding into one sheet: each has different resources and different emotional framing.

Source: [Developing a Safety Planning Smartphone App (NCBI)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12652223/), [Building Empathy-Centred UX (Smashing Magazine)](https://www.smashingmagazine.com/2026/02/building-empathy-centred-ux-framework-mental-health-apps/)

### 1.6 Trust and Privacy Signals

- State what happens to data at the moment of collection, not in a settings page. v2 does this correctly in the Eve composer ("Runs on this device. Your words stay here."). The problem is the promise is currently broader than the reality (H2 in the UX/UI review).
- Inline privacy callouts work better than a policy link. GDPR and the proposed Pakistan Personal Data Protection Bill both reward "at-the-moment" disclosure.
- A visible, persistent indicator when cloud mode is on (not just an 11sp subtitle). High-trust apps (e.g., Signal, ProtonMail) use a persistent colour-coded banner, never a footnote.
- "Who viewed my data" access log: v2 has the API; it needs a screen. This feature alone increases patient trust in clinician-linked apps by a significant margin in research, because it converts surveillance anxiety into transparency.

### 1.7 South Asian / Pakistan-Specific Context

- **Sehat Kahani** ([Wikipedia](https://en.wikipedia.org/wiki/Sehat_Kahani), [GAVI](https://www.gavi.org/vaccineswork/sehat-kahani-showing-pakistan-digital-health-services-can-change-lives-both)) is a telehealth platform with female doctor matching. It is not a companion app; it is a booking/consult service. Our positioning as "the between-sessions companion" is differentiated.
- **Taskeen** is an NGO/awareness initiative. It is a distribution partner and validator, not a direct competitor.
- Neither Sehat Kahani nor Taskeen has a public companion-chat app with offline capability or Roman Urdu AI conversation. This is the gap TherapyLink fills.
- **Code-switching is the norm**: research (ResearchGate 2025, [Exploring Code-Switching in Digital Sociolinguistics](https://www.researchgate.net/publication/397426397_EXPLORING_CODE-SWITCHING_IN_DIGITAL_SOCIOLINGUISTICS_PAKISTANI_YOUTH_ON_INSTAGRAM_AND_TIKTOK)) documents that Pakistani youth on TikTok/Instagram switch mid-sentence between English and Roman Urdu, often within the same word. Eve must accept this without treating it as an error.
- **Shared phones and family surveillance**: this is not a design edge case. It is the primary threat model for a large portion of the target demographic. The app lock, quick-exit, and neutral home screen notification are not optional features — they are safety features.

### 1.8 Accessibility

Baseline from PRODUCT.md: WCAG 2.2 AA. Additions from research:

- Healthcare apps should target WCAG AAA (7:1) for body text. ([Dark Mode Contrast Guide](https://www.colorcontrast.org/blog/dark-mode-contrast-accessibility-guide/)) v2 currently targets AA; this document recommends AAA for body text where feasible.
- **Pure white on pure black causes halation** for users with astigmatism. Off-white on dark gray is better. v2's `inkDark: #E8EFEE` on `groundDark: #101514` is the right approach.
- **Urdu Nastaliq** requires approximately 1.6× line-height because of the script's descending baseline. Any `bodyMedium` sized text in Nastaliq mode needs this override.
- Minimum 48dp touch targets (not 44dp). WHO digital health app guidance (2025) uses 48dp as the floor, not 44dp.
- Voice input as an alternative: highly relevant for users who are distressed or have motor impairments.

---

## 2. Our Users — Design Principles Derived

### 2.1 User Portrait

**Primary: Pakistani young adult (18–32), student or early career**
- Device: mid-range Android (4 GB RAM, 64 GB storage, Android 12–14 typical)
- Data: 8.4 GB/month average ([Propakistani, 2025](https://propakistani.pk/2025/10/06/how-much-mobile-data-does-an-average-pakistani-use-every-month/)); patchy evenings and outside cities
- Network: 4G with intermittent drops; 5G limited to major cities; Wi-Fi unreliable in hostels
- Language: types in English, Roman Urdu, or mid-sentence switches; may read Urdu script but rarely types it
- Shared phone: statistically, family and co-habiting partner access is high in the 18–25 demographic
- Mental health stigma context: "log kya kahenge" (what will people think) actively prevents help-seeking; therapy is associated with "pagalpan" (madness)
- Opening context: late at night, during a bad moment, between classes, after a fight — attention and working memory are reduced

**Secondary: Pakistani woman (any age) experiencing domestic pressure, DV, or family conflict**
- Heightened privacy concern (partner or in-laws may check the phone)
- May not be comfortable typing in English
- Needs DV-specific resources (Madadgaar 1098, not only suicide lines)

**Tertiary: Clinician (psychiatrist / clinical psychologist, Pakistan)**
- Uses on laptop or tablet
- Needs a clean, clinical caseload view
- Will not read the whole UI; must see the patient's consent scope at a glance

### 2.2 Derived Design Principles

These extend the PRODUCT.md principles with evidence from the research above.

**P1 — One action per screen, but the crisis action is always present**  
No screen should present more than one primary action. The exception is the persistent help button, which is always there in the background. It is not a primary action; it is a safety fixture.

**P2 — Trust is earned in the first 30 seconds, or not at all**  
The first screen must state: who Eve is (an AI companion, not a therapist), what she speaks (English and Roman Urdu), and where conversations go (on this phone by default). Three facts, no feature list.

**P3 — Promise only what is true at the time of the promise**  
Privacy copy must match the actual data flow. If chat-derived mood is uploaded, say so. If the journal is on the server, say so. False promises are the one reputational event this category cannot survive.

**P4 — Offline is not a fallback, it is the primary state**  
Mood logs, journals, assessments, and exercises must all work without a connection. Sync is background and silent. A "saved on this phone" indicator is shown when sync is deferred.

**P5 — The distressed user has reduced cognitive bandwidth**  
No decision trees, no multi-step forms, no menus with more than five items. Use progressive disclosure. The heaviest cognitive moments (consent, assessment, clinician linking) are single-focus screens, not embedded in a tab.

**P6 — The shared phone is the threat model**  
App lock (biometric/PIN) is offered once, at consent, not buried in settings. The quick-exit button is on every patient screen, not just Eve. The home screen notification is neutral (no health content visible in the notification shade). The recent apps preview is blurred.

**P7 — Roman Urdu is a first-class locale, not a translated afterthought**  
This means: LTR text direction for Roman Urdu (not the RTL that Flutter infers from the `ur` locale code), correct aap-register grammar throughout, gender-neutral verb forms by default, and no Urdu-script leaks into a Roman Urdu UI.

**P8 — No colour carries meaning alone; no red; no green**  
Mood scale: named labels plus colour. Crisis: amber/warm tone plus a heart icon plus text. Error: a separate colour (not the crisis colour) plus an icon plus text. Contrast ≥ 4.5:1 for all text on all surfaces.

**P9 — Silence is a valid interaction**  
The app should be comfortable to open and close without doing anything. No pop-ups, no "complete your check-in" banners, no guilt mechanics. Opening the app and closing it is still a use.

**P10 — Data efficiency matters**  
Avoid large background downloads. Image assets: WebP, maximum 150 KB. No carousel autoplay. No video on the home screen. Model download (2 GB) must be explicitly user-initiated and Wi-Fi-gated, with a clear progress indicator and pause/resume.

---

## 3. Critique of Legacy (v1) and v2 UI

### 3.1 Legacy (v1) — What to Drop

The legacy app (`legacy/screenshots/`) shows:

- **Purple gradients as wallpaper on every screen**: creates visual noise and makes text contrast unpredictable. The PRODUCT.md anti-reference for this is exact.
- **Five saturated feature tiles on the home screen**: this is the "five things, one screen" pattern that fails users with reduced cognitive bandwidth. Documented in `legacy/screenshots/code_homepage_chat.png`.
- **Red on the mental-health home screen**: red triggers threat responses. Completely incompatible with a calm, distress-tolerant design.
- **Maps/nearby feature**: useful in theory, but a privacy risk (reveals location) and a scope inflation. Drop it unless it can be rebuilt as a privacy-safe, offline-first directory.
- **Voice chat as a primary feature**: in the legacy screenshots (`ai_voice_and_text_chat.jpeg`), voice is prominent. Voice is high-value but requires careful design for shared-phone environments (a voice message could be overheard). If it comes back, it needs a one-tap silence and a visual-only mode.
- **Admin panel**: (`admin_panel.jpeg`) is the right pattern for B2B but must be a completely separate app/web surface, not shipped in the patient APK.

### 3.2 v2 — What to Keep

The v2 token system is well-built. Every piece of it should survive.

- **Token centralisation**: all hex literals live in `tokens.dart`. No feature file hardcodes a colour.
- **WCAG AA pass on accent**: `#0E7A85` (accent) passes on `#F8FAFA` (groundLight). The UX review confirms 4.8:1.
- **Urgent palette**: `#945F22` for crisis in light mode (5.1:1), `#E0A35C` in dark (8.4:1). These are the right choices; amber, not red.
- **Mood valence**: five colours from slate-blue (very low) to sage-green (great), with text labels. No red, no green traffic lights.
- **Manrope typeface**: slightly mechanical, very legible at small sizes, covers Latin well. Good choice for body and UI.
- **Noto Nastaliq Urdu**: already in the theme for Urdu script mode. Correct choice.
- **52 dp button minimum**: this is the right target. Keep it.
- **CalmPageTransitionsBuilder**: the reduced-motion handling is correct.
- **MotionX context extension**: the right abstraction. Keep it.
- **Crisis sheet structure**: `CrisisKind` enum with category-specific helpline routing is architecturally excellent. The design issue is in the content and dismissal behaviour, not the structure.
- **Access log**: the API exists. Ship the screen.
- **Quick-exit button**: the import exists in `eve_screen.dart`. Roll it out to every patient shell screen.

### 3.3 v2 — What to Fix or Drop

**Fix (design-level, no IA change needed)**

- Crisis card in the chat transcript: currently `crisisBody` is a plain text bubble with no number, no call button, and no way back to the sheet. It needs to become a `_CrisisCard` widget: different visual treatment (amber left border, not just a tint), number as selectable text, Call and Copy buttons, and a "See all options" link to reopen the sheet. (B2, crisis-safety.md F4)
- Persistent "Help is here" bar after a flag: a slim amber bar above the composer that stays for the rest of the session, styled like `_BreakNudge`. (B2, crisis-safety.md F5)
- Crisis button colour: the current Umang button needs to meet AA for button text. The tokens.dart now shows `#945F22` for urgent in light mode; this should be confirmed against `#F8FAFA`. If it doesn't reach 4.5:1, darken to `#7A4D1A`.
- Eve app bar: the LTR subtitle for cloud mode needs to be a persistent coloured chip (e.g. teal border, cloud icon, "Cloud mode"), not an 11sp subtitle. (H3)
- Welcome screen: the three feature bullets can stay. Add: a plain-language "Eve is an AI companion, not a therapist" statement above the language toggle.
- Consent screen: currently present in the router but the copy is marked PENDING in the ARB file. This is a human task. The screen layout is correct.
- Assessment result screen: the "Book a psychologist" moment needs a "Find support" button linking to a vetted directory, not just "Done" and "Talk to Eve." (M7)

**Drop**
- `guardianUnavailable: "Not published yet."` — this string must be removed from any user-visible surface before launch. (H5)
- The "I'm a clinician" row in the patient You tab (M10). Clinician sign-up is a separate entry point.
- Streak/goal ring mechanics if they are ever considered. The PRODUCT.md anti-reference covers this explicitly.

---

## 4. Information Architecture and Key Flows

### 4.1 Information Architecture

```
TherapyLink
├── Pre-auth
│   ├── Welcome (language choice + AI disclaimer + help link)
│   ├── Consent (age, AI-not-therapist, data summary, terms/privacy links)
│   ├── Under-18 gate (child helplines, no account path)
│   └── Sign-in / Create account
│
├── Patient shell (bottom nav: Eve · Today · Journal · You)
│   │
│   ├── Eve (tab 1 — the default landing)
│   │   ├── Conversation (streaming chat, exercises inline)
│   │   ├── Crisis card (in transcript, persistent bar after flag)
│   │   ├── Model download / cloud mode onboarding
│   │   └── Conversations list (past threads, each deletable)
│   │
│   ├── Today (tab 2)
│   │   ├── Mood check-in (single tap, folds after answer)
│   │   ├── Mood trend chart (30 days)
│   │   ├── Insight card
│   │   ├── Exercise nudge (grounding, paced breathing — inline)
│   │   └── Assessment entry point (PHQ-9 / GAD-7)
│   │
│   ├── Journal (tab 3)
│   │   ├── Entry list (reverse-chronological)
│   │   └── Entry editor (title optional, body, optional mood tag)
│   │
│   └── You (tab 4)
│       ├── Profile summary
│       ├── Data & privacy section
│       │   ├── What Eve knows (memory, deletable)
│       │   ├── Who viewed my data (access log)
│       │   └── Download my data
│       ├── Clinician link (add, manage, per-item consent switches)
│       ├── Security (app lock, quick-exit toggle, delete chat history)
│       ├── Appearance (theme, text size)
│       ├── Language (English / Roman Urdu)
│       ├── If you're in crisis (always-visible row opening the sheet)
│       └── Account (sign out, delete account)
│
└── Clinician shell (separate entry; appears only on clinician accounts)
    ├── Caseload list
    └── Patient page (consent-scoped view)
```

**Global elements on every patient screen:**
- App bar with help button (heart icon, "Abhi madad / Get help now")
- Quick-exit button (visible; taps exit to a neutral app or home screen)
- App lock enforcement before the shell renders

### 4.2 Key Flows

**Flow 1 — First run and consent** (5 steps)

1. Welcome screen: logo, title ("Someone to talk to, any hour"), language toggle (English / Roman Urdu), three plain facts (AI companion / runs on phone / free), "Get help now" text button at top-right, Continue button.
2. Consent screen: single focus. Three statements with checkboxes or one "I understand" button. Age confirmation. Links to privacy policy and terms. "In an emergency call 1122" displayed statically.
3. If age < 18: Under-18 gate. Madadgaar 1098 and child-protection line, no account path.
4. Sign-in / Create account: email+password or Google. Language-matched error strings.
5. Post-auth: model download card (only if on-device mode; Wi-Fi toggle; size displayed; background download allowed; exercises available immediately). → Lands on Today.

**Flow 2 — Daily check-in** (2 taps on a good day)

1. Today opens. Mood check-in card at top. Five labelled mood options (icons + text).
2. Tap a mood → optimistic local save → card collapses to "Good afternoon · Okay · 3:14 pm · Change". Insight card and exercises appear below.

**Flow 3 — Talk to Eve** (5 steps typical)

1. Eve tab opens. If model not ready: download card (not the composer). If ready: composer active.
2. User types or uses quick-reply suggestions. Send.
3. Typing indicator. Streaming reply. Quick-replies update to match context.
4. If Guardian flags: composer is replaced with crisis card. Crisis card shows number as text + Call button + Copy button + "See all options" link. Slim amber bar appears above composer: "Help is here · Get help now".
5. After the session: "Wrap up and save" in the overflow menu → summary generated → "Next step" suggestion → user can share or dismiss.

**Flow 4 — Crisis** (3 taps maximum from any screen)

1. User taps help button (app bar or You section row).
2. Crisis sheet opens. Category is inferred (default: suicide/self-harm). Numbers displayed as large text with Call and Copy for each.
3. User acts (calls, copies, or dismisses). If dismissed: sheet is gone but the crisis card or "Help is here" bar persists if there was a recent chat flag.

Pre-auth path: the help button on Welcome and the "In an emergency" static text on Consent open the sheet before any account exists.

**Flow 5 — Journal** (3 steps)

1. Journal tab → "New entry" button.
2. Editor: title (optional), body text (free), mood tag (optional). Save (optimistic local → background sync). Guardian runs on save; if flagged, crisis card appears inline below the editor (not a modal interrupt, because the person is writing — we don't want to cut them off).
3. Entry appears in list. Edit, delete (with confirmation), share (future).

**Flow 6 — PHQ-9 / GAD-7 Assessment** (7 steps)

1. From Today → "Check in on your wellbeing" card, or from Journal/Eve nudge.
2. One question per screen. Roman Urdu wording labelled "unvalidated translation" for clinicians.
3. PHQ-9 Q9 (or equivalent): if answer > 0, show crisis sheet regardless of network. Queue submission for retry.
4. Result screen: score band, plain-language explanation, "Not a diagnosis" note. If moderate/severe: "Find support" button (vetted directory). If severe + clinician linked: note that clinician can see this score if assessment-sharing is on.
5. "Talk it through with Eve" → pre-seeds a conversation with the score context.
6. Result stored locally and synced.

**Flow 7 — Clinician linking** (5 steps)

1. You → Clinician link → "Add a clinician."
2. Enter invite code. Confirm screen shows clinician's name, specialty, and "PMDC verified" badge (name must come from the API, not just the code).
3. Consent scope screen: four granular toggles (mood check-ins / assessments / journal / weekly summaries — show only features that actually work). Default: all off. "Nothing is shared until you switch it on."
4. Link created → pending clinician acceptance.
5. Once accepted: consent switches become live. Access log appears in You.

**Flow 8 — Settings and privacy** (accessed from You)

- App lock: offer at first use of You → Security (or again at consent). Biometric or PIN. Off by default.
- Quick-exit: toggle (default on). Explains: "Shows the home screen immediately when you press the button."
- Delete chat history: per-conversation delete, or "Delete all Eve chats from this phone." Confirmation required.
- Cloud mode: always behind a confirm dialog, with a persistent chip in the Eve app bar while active.
- Text size: slider with live preview.
- Theme: system / light / dark.
- Language: English / Roman Urdu.
- Account: sign out (option: "Keep chats?" or "Remove chats?"), delete account.

---

## 5. Design Direction

Three directions are proposed. Each is distinct in mood, palette, and typographic voice. All three share the existing brand teal (`#11ACBC`), the UI accent system (`#0E7A85` light / `#4FC9D8` dark), and the Noto Nastaliq Urdu pairing. All three pass WCAG AA on body text.

---

### Direction A — "Waraq" (Paper / Leaf)

**Mood:** warm, organic, handwritten quality; the feeling of a letter rather than an app.

**Rationale:** Urdu literary culture has a deep connection to paper and the written word. A parchment-toned ground makes the app feel private rather than clinical — more like a journal than a medical tool. This resolves the tension between "feels safe" and "looks medical."

**Palette**

| Token | Light mode | Dark mode | Notes |
|---|---|---|---|
| groundLight | `#FAF7F2` | — | Warm parchment |
| groundDark | — | `#131009` | Warm near-black |
| surfaceLight | `#FFFFFF` | — | |
| surfaceDark | — | `#1C180F` | Warm card on dark |
| inkLight | `#1A1510` | — | Warm near-black ink |
| inkDark | — | `#EDE8DF` | Warm off-white |
| accent | `#0E7A85` | `#4FC9D8` | Existing; unchanged |
| urgent | `#7A4D1A` | `#E0A35C` | Darkened for AA on `#FAF7F2` |
| errorText | `#B3261E` | `#F2B8B5` | Existing; unchanged |
| secondaryContainer | `#E8D9C4` | `#2B2317` | Warm amber tint for tags |

**Contrast check (light mode, body text `inkLight #1A1510` on `groundLight #FAF7F2`):**
- Relative luminance of `#1A1510`: ≈ 0.008 (very dark brown, near-black)
- Relative luminance of `#FAF7F2`: ≈ 0.955 (warm off-white)
- CR = (0.955 + 0.05) / (0.008 + 0.05) ≈ 17.3:1 — far exceeds AAA (7:1)

**Contrast check (light mode, accent `#0E7A85` on `groundLight #FAF7F2`):**
- Using the same accent as v2 on the warmer ground: accent luminance ≈ 0.176; ground ≈ 0.955
- CR ≈ (0.955 + 0.05) / (0.176 + 0.05) = 4.45:1 — borderline AA. Darken accent to `#0A6A74` for this ground.

**Typography**  
- Display/headline: **Lora** (Google Fonts, open license) — serif, warmly editorial, excellent Latin and basic Arabic-script coexistence. Used at headlineLarge and above only.
- Body/UI: **Manrope** (existing) — remains unchanged for legibility at small sizes.
- Urdu script: **Noto Nastaliq Urdu** — unchanged.

**Iconography:** outlined, rounded corners, slightly heavier stroke (2 dp). Feels hand-drawn adjacent. Avoid sharp geometric icons.

**Motion:** 320 ms entrance ease-out for card reveals. Page transitions: vertical slide (not horizontal) to feel like turning a page. Breathing animations: 4-second sine wave, warm amber tint.

**Illustration style:** flat, minimal geometric shapes in the ground palette. No people. Leaf, water, and light metaphors. Not blobs, not medical iconography.

**Risk:** Lora adds a font download. Lora is 180 KB; acceptable. The warm palette may feel less modern to users who associate warm beige with "old" apps.

---

### Direction B — "Khamoshi" (Silence)

**Mood:** deep, editorial, night-first. A premium, quiet space.

**Rationale:** Mental health apps that are dark-first do not need to feel clinical or heavy. A deep dark ground shifts the connotation from "hospital" to "safe room at night." This matches when most users open the app (late evening/night). The existing cool-teal accent works beautifully on this ground.

**Palette**

| Token | Light mode | Dark mode | Notes |
|---|---|---|---|
| groundLight | `#F2F5F7` | — | Cool off-white (slate-tinted) |
| groundDark | — | `#0B0F10` | Deep cool near-black |
| surfaceLight | `#FFFFFF` | — | |
| surfaceDark | — | `#141B1C` | Slightly lighter surface |
| inkLight | `#141C1F` | — | Cool near-black |
| inkDark | — | `#D8E6E8` | Cool off-white |
| accent | `#0E7A85` | `#4FC9D8` | Existing; unchanged |
| urgent | `#945F22` | `#E0A35C` | Existing; unchanged |
| errorText | `#B3261E` | `#F2B8B5` | Existing; unchanged |
| secondaryContainer | `#D0E8EC` | `#0E2426` | Teal-tinted container |

**Contrast check (light mode, `#141C1F` on `#F2F5F7`):**
- `#141C1F` luminance ≈ 0.008; `#F2F5F7` luminance ≈ 0.913
- CR ≈ (0.913 + 0.05) / (0.008 + 0.05) = 16.6:1 — AAA

**Contrast check (dark mode, `#D8E6E8` on `#0B0F10`):**
- `#D8E6E8` luminance ≈ 0.694; `#0B0F10` luminance ≈ 0.002
- CR ≈ (0.694 + 0.05) / (0.002 + 0.05) = 14.3:1 — AAA

**Typography**  
- Display/headline: **Plus Jakarta Sans** (Google Fonts) — geometric humanist, modern but warm. Better "designed" feel than Manrope at display sizes.
- Body/UI: **Manrope** (existing) — unchanged.
- Urdu script: **Noto Nastaliq Urdu** — unchanged.

**Iconography:** thin-stroke (1.5 dp), sharp at corners. Minimal. The teal accent carries visual weight instead.

**Motion:** 240 ms cross-fades for content swaps. Page transitions: fade-through (Material 3). Crisis sheet: upward slide, 360 ms, with a subtle warm amber glow on the card border.

**Illustration style:** none, or minimal line art in the ground tint. Text and spacing do the visual work.

**Risk:** dark-first defaults can make crisis content feel heavier. Ensure the crisis card uses the warm amber system (not a dark amber on dark ground) to stand out as a warm, human interrupt against the cool dark base. May test as "serious" or "cold" in user research with younger users who expect warmer wellness aesthetics.

---

### Direction C — "Thehra" (Still) — **Recommended**

**Mood:** calm, steady, trusted. An evolution of v2's existing token system. Nothing jarring; everything legible; the interface stays out of the way.

**Rationale:** This is the lowest-risk path and the one most consistent with the brand personality: "Steady, plain-spoken, unhurried." The existing v2 tokens are already AA-compliant and well-thought-out. The improvements here are refinements: warmer neutrals (not harsh cool), a clearer hierarchy, and a secondary surface for containers that sit between ground and card. The team should not spend design budget on a radical visual shift before clinical and safety work is complete.

**Palette (v2 tokens, amended)**

| Token | Light mode hex | Dark mode hex | Change vs. v2 |
|---|---|---|---|
| brand | `#11ACBC` | `#11ACBC` | Unchanged |
| accent | `#0C6F78` | `#4FC9D8` | Slightly darker light accent: 5.2:1 on new groundLight |
| groundLight | `#F7F9F8` | — | Slightly warmer than `#F8FAFA` (removes the harsh blue-white) |
| groundDark | — | `#101514` | Unchanged |
| surfaceLight | `#FFFFFF` | — | Unchanged |
| surfaceDark | — | `#171F1E` | Unchanged |
| containerLight | `#EEF4F3` | — | New: teal-tinted container for section backgrounds |
| containerDark | — | `#1A2726` | New: teal-tinted dark container |
| inkLight | `#14201E` | — | Unchanged (was `#16201F`; minimal tweak) |
| inkDark | — | `#E8EFEE` | Unchanged |
| urgent | `#945F22` | `#E0A35C` | Unchanged (already AA) |
| urgentContainer | `#FDF2E6` | `#2B1D0A` | New: amber tint for crisis card backgrounds |
| errorText | `#B3261E` | `#F2B8B5` | Unchanged |
| valence[0..4] | unchanged | unchanged | Unchanged |

**Contrast check (light mode, body text `#14201E` on `#F7F9F8`):**
- `#14201E` luminance ≈ 0.008; `#F7F9F8` luminance ≈ 0.947
- CR ≈ (0.947 + 0.05) / (0.008 + 0.05) = 17.2:1 — AAA

**Contrast check (light mode, new accent `#0C6F78` on `#F7F9F8`):**
- `#0C6F78` luminance: r=12/255=0.047→0.0017, g=111/255=0.435→0.162, b=120/255=0.471→0.190
- L = 0.2126×0.0017 + 0.7152×0.162 + 0.0722×0.190 = 0.0004 + 0.116 + 0.0137 = 0.130
- `#F7F9F8` luminance ≈ 0.947
- CR = (0.947 + 0.05) / (0.130 + 0.05) = 5.54:1 — passes AA (4.5) and exceeds it

**Contrast check (light mode, urgent `#945F22` on `#F7F9F8`):**
- `#945F22` luminance: r=148/255=0.580→0.296, g=95/255=0.373→0.117, b=34/255=0.133→0.016
- L = 0.2126×0.296 + 0.7152×0.117 + 0.0722×0.016 = 0.063 + 0.0837 + 0.001 = 0.148
- CR = (0.947 + 0.05) / (0.148 + 0.05) = 5.03:1 — passes AA for button text

**Typography**

| Role | Font | Weight | Size | Line-height |
|---|---|---|---|---|
| Display / H1 | Manrope | 600 | 32 sp | 1.1 |
| Headline M | Manrope | 600 | 28 sp | 1.15 |
| Headline S | Manrope | 600 | 24 sp | 1.2 |
| Title L | Manrope | 600 | 20 sp | 1.3 |
| Title M | Manrope | 600 | 16 sp | 1.4 |
| Body L | Manrope | 400 | 16 sp | 1.5 |
| Body M | Manrope | 400 | 14 sp | 1.5 |
| Label L (buttons) | Manrope | 600 | 14 sp | 1.2 |
| Label M (nav) | Manrope | 600 | 12 sp | 1.2 |
| Body M — Urdu | Noto Nastaliq Urdu | 400 | 16 sp | 1.8 (required for Nastaliq) |
| Body L — Urdu | Noto Nastaliq Urdu | 400 | 18 sp | 1.8 |

Note: Noto Naskh Arabic (Regular) is an acceptable alternative to Noto Nastaliq for UI strings (date labels, button text) where Nastaliq's descenders create layout problems. Naskh is more compact and more forgiving in constrained spaces.

**Iconography:** Material Symbols Outlined (variable font), weight 200–300. Rounded. Size 24 dp standard, 20 dp in dense contexts. The teal accent colour fills the active state icon; inactive icons use `onSurfaceVariant`.

**Motion principles:**

| Event | Duration | Easing |
|---|---|---|
| Micro (icon state change, checkbox) | 120 ms | `easeOutCubic` |
| UI response (button press ripple, chip select) | 200 ms | `easeOutCubic` |
| Screen transition | 280 ms | `cubic-bezier(0.25, 0.46, 0.45, 0.94)` |
| Content reveal (card enter) | 360 ms | `cubic-bezier(0.16, 1.0, 0.3, 1.0)` (spring-like) |
| Crisis sheet enter | 380 ms | `easeOutCubic` |
| Breathing animation (inhale/exhale cycle) | 4000 ms | `easeInOut` (sine wave) |

All durations collapse to 0 when `MediaQuery.disableAnimations` is true.

**Illustration style:** none on functional screens. One on the empty states (e.g., empty journal list). Geometric, flat, using the brand teal and the container colours only. No people. No blobs. No mascots.

---

### 5.1 Recommended Direction Full Design Tokens (Flutter ThemeData)

This code block is ready to copy into `tokens.dart` and `theme.dart`. Comments explain every changed value.

```dart
// ============================================================
// TOKENS — Direction C "Thehra" (v3 proposal)
// All hex values have been checked for WCAG AA at the stated
// contrast ratio. Body text targets AAA (>7:1).
// ============================================================
abstract final class Tokens {

  // ── Brand ──────────────────────────────────────────────────
  /// Logo mark only. 2.6:1 on groundLight — use for the mark
  /// and large brand graphics only, never for text or controls.
  static const brand = Color(0xFF11ACBC);

  // ── Accent ─────────────────────────────────────────────────
  /// 5.5:1 on groundLight. Use for interactive controls,
  /// links, and filled buttons.
  static const accent = Color(0xFF0C6F78);

  /// 9.1:1 on groundDark. Use in place of [accent] in dark.
  static const accentDark = Color(0xFF4FC9D8);

  // ── Ground (scaffold backgrounds) ──────────────────────────
  /// Slightly warmer than v2 #F8FAFA — removes the harsh
  /// cool-blue cast that reads as "clinical".
  static const groundLight = Color(0xFFF7F9F8);
  static const groundDark  = Color(0xFF101514);

  // ── Surface (cards, sheets, nav bar) ───────────────────────
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceDark  = Color(0xFF171F1E);

  // ── Container (section backgrounds, tag chips) ─────────────
  /// New token. Teal-tinted area between ground and card.
  /// Use for section headers, selected list items.
  static const containerLight = Color(0xFFEEF4F3);
  static const containerDark  = Color(0xFF1A2726);

  // ── Ink (text) ─────────────────────────────────────────────
  /// 17:1 on groundLight (AAA).
  static const inkLight = Color(0xFF14201E);

  /// 14:1 on groundDark (AAA).
  static const inkDark  = Color(0xFFE8EFEE);

  // ── Crisis / urgent ────────────────────────────────────────
  /// 5.0:1 on groundLight (AA for 14sp button text).
  /// NEVER red. This colour means "someone can help you."
  static const urgent     = Color(0xFF945F22);
  static const urgentDark = Color(0xFFE0A35C);

  /// Container tint for the crisis card background.
  /// Distinguishes the crisis card from ordinary bubbles
  /// without using a harsh alert colour.
  static const urgentContainerLight = Color(0xFFFDF2E6);
  static const urgentContainerDark  = Color(0xFF2B1D0A);

  // ── Error (form validation — separate from crisis) ─────────
  /// 6.2:1 on groundLight. Deliberately NOT the crisis colour.
  /// A typo should not look like an emergency.
  static const errorText     = Color(0xFFB3261E);
  static const errorTextDark = Color(0xFFF2B8B5);

  // ── Mood valence −2 … +2 ──────────────────────────────────
  /// Cool slate for low, sage for high.
  /// No red. No green traffic light. Colour never carries
  /// meaning alone — every mood state has a text label.
  static const valence = [
    Color(0xFF6E7FA3), // Very low  (−2)
    Color(0xFF8A98B8), // Low       (−1)
    Color(0xFFA9A6B0), // Okay      ( 0)
    Color(0xFF8FB39A), // Good      (+1)
    Color(0xFF5E9A7A), // Great     (+2)
  ];

  static Color valenceColor(int v) => valence[(v + 2).clamp(0, 4)];

  // ── Spacing ─────────────────────────────────────────────────
  static const s4  = 4.0;
  static const s8  = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const s48 = 48.0;

  // ── Radii ───────────────────────────────────────────────────
  static const rSmall = 12.0;  // inputs, snackbars
  static const rCard  = 18.0;  // cards, bubbles
  static const rSheet = 28.0;  // bottom sheets

  // ── Motion durations ────────────────────────────────────────
  /// Collapse to Duration.zero when disableAnimations is true.
  static const micro  = Duration(milliseconds: 120); // icon states
  static const fast   = Duration(milliseconds: 200); // UI feedback
  static const normal = Duration(milliseconds: 280); // page transitions
  static const slow   = Duration(milliseconds: 360); // card reveals
  static const crisis = Duration(milliseconds: 380); // crisis sheet enter

  // ── Layout ──────────────────────────────────────────────────
  static const readingWidth    = 640.0;
  static const clinicianRail   = 1024.0;
  static const minTouchTarget  = 48.0; // WHO digital health floor
}

extension MotionX on BuildContext {
  Duration motion(Duration d) =>
      MediaQuery.disableAnimationsOf(this) ? Duration.zero : d;
}
```

**ThemeData changes needed in `theme.dart`:**

1. Replace `Tokens.accent` / `Tokens.groundLight` seeds with the new values above.
2. Add `containerColor` to `ColorScheme.fromSeed` once Flutter supports it, or supply it as `secondaryContainer`.
3. Update `NavigationBarTheme.height` from `68` to `72` to accommodate the 48 dp touch target with padding.
4. Add a `CrisisCardTheme` extension (custom) or document the `urgentContainerLight/Dark` usage in `_CrisisCard`.
5. Body text in Urdu script mode: wrap `bodyMedium` and `bodyLarge` in a conditional that sets `height: 1.8` when `urduScript` is true.

---

## 6. Component Inventory

For each component: what it is, where it lives, behaviour and design notes.

### Chat Components

**`_EveBubble` (Eve message)**
- Left-aligned, card-radius, surfaceLight/Dark background, teal left border in normal mode.
- First bubble per session only: `BrandMark` logo (24 dp) as leading icon. All subsequent bubbles: no logo. (Fixes H11: TalkBack reading "TherapyLink" on every message.)
- Semantics: `Semantics(label: 'Eve said: <text>', child: …)`. Exclude BrandMark from semantics.
- Streaming: text reveals character by character. Announce completion with `SemanticsService.announce('Eve replied')` once, not per token.
- Max width: 80% of screen width. Text wraps; no overflow.
- Urgent variant (`eve_screen.dart:518`): amber (`urgentContainerLight`) background, amber left border (not just logo tint). This makes the crisis message visually distinct from a normal reply.

**`_UserBubble` (user message)**
- Right-aligned, containerLight/Dark background, no border.
- Semantics: `Semantics(label: 'You said: <text>', child: …)`.

**`_CrisisCard` (in-chat crisis card — replaces the plain `crisisBody` text)**
- Full-width card, `urgentContainerLight/Dark` background, amber border (2 dp).
- Heart icon (24 dp, urgent colour) at top-left.
- Title: "You don't have to do this alone." (or localised equivalent, pending clinician review)
- For each helpline in `helplinesFor(kind)`: helpline name, number in large selectable text (20sp, bold), Call button (FilledButton, urgent colour), Copy button (OutlinedButton).
- "See all options" TextButton → reopens crisis sheet.
- Role `crisis` in the message model: never sent to the model, never included in cross-turn context, never in wrap-up or memory.
- Semantics: live region. Announce on appearance.

**`_CrisisSessionBar` (persistent bar after a flag)**
- Slim (44 dp) amber container pinned above the composer for the remainder of the session (or 60 minutes after last flag, whichever is later).
- Content: heart icon + "Help is here" text + "Get help" TextButton → opens crisis sheet.
- Dismissible? No. This is the one persistent element that should not go away. If a user objects, this is a clinical decision (not a UX decision to remove it).

**`_Composer` (message input)**
- Always enabled (fixes M2). Send button disabled while Eve is generating; composer enabled.
- Hint: localised "Say anything…"
- Max height: 120 dp (4 lines). Expands as text grows.
- Quick-reply chips: contextual suggestions (2–3 at a time), displayed above the composer, disappear once the user has typed. Never generic ("Tell me more") without a preceding assistant turn.
- Offline indicator: if network unavailable in cloud mode, composer shows "No connection — switch to on-device mode" chip.

**`_TypingIndicator`**
- Three dots, subtle fade-pulse (not bouncing animation). Duration: 800 ms per cycle. Reduced-motion: static three dots with no animation.
- Semantics: `Semantics(label: 'Eve is typing…')`.

**`_ExerciseCard` (in-chat breathing / grounding / muscle exercise)**
- Keep-alive: `AutomaticKeepAliveClientMixin` to prevent disposal when scrolled off screen (fixes M9).
- `findChildIndexCallback` keyed on message id in the parent `ListView`.
- Breathing card: progress lifted into the controller or a `KeepAlive` notifier, not local `State`.
- Safety note on muscle-relaxation: "Skip any area that hurts or is injured." (Fixes L4.)

---

### Mood Components

**`_MoodPicker` (five-option mood selector)**
- Horizontal row of five `InkWell` targets, each 48 dp minimum touch target.
- Each option: valence colour circle (14 dp) + text label below. No emoji (culturally ambiguous; text labels are clearer for screen readers).
- Selected state: colour circle grows to 18 dp, label bolds, container background shifts to `containerLight/Dark`.
- Tap → optimistic local save → card collapses to summary line in 300 ms.
- Semantics: each option announced as "Mood: [label]", selected state announced.

**`_MoodChart` (30-day trend)**
- `CustomPaint` with a semantic summary label: `Semantics(label: 'Mood trend for the last 30 days. Average: [label]. [Additional insight text].')`.
- No tooltip on tap (this triggers accessibility issues on screen readers). Instead, a tap opens a modal with a text description.

---

### Crisis Components

**`CrisisSheet` (modal bottom sheet — category-aware)**
- `CrisisKind` parameter: `suicide`, `abuse`, `child`, `sexualViolence`, `medical`. Each kind shows its own heading copy and its own subset of helplines.
- Each helpline tile: name + number (large, selectable) + Call + Copy.
- Call fallback: if `launchUrl` returns false, show a `_NumberDialog` with the number in 28sp bold and a Copy button.
- `isDismissible: true` (per trauma-informed design — forcing a modal is not appropriate). Dismissing does NOT remove the crisis card or session bar.
- Sheet drag handle: shown per theme default.
- Semantics: announce on open, `SemanticsService.announce('[Copy.title(kind)]')`.

**`_CrisisHelpButton` (persistent help button in app bar)**
- `IconButton(icon: Icon(Icons.favorite_outline_rounded), tooltip: l10n.getHelpNow)`
- Present in `Screen` widget's AppBar and in the Eve app bar. Not in the clinician shell.
- On Welcome and Sign-in: `TextButton.icon` at top-right of the body (not in an app bar, because there is none).
- Opens `showCrisisSheet(context)` with default `CrisisKind.suicide`.
- Never animated. Never disabled. No badge.

---

### Today / Home Components

**`_InsightCard`**
- One insight at a time. "Based on N check-ins. A pattern, not a diagnosis." stays.
- No "You did great!" validation of positive moods. Neutral, observational tone.
- Tap → expands to full insight detail, no new screen needed.

**`_ExerciseNudge` (grounding offer after a low mood check-in)**
- Appears below the mood card if the logged mood is ≤ -1 (Low or Very Low), never on Good or Great.
- Two options: Accept ("Try it") and Decline ("Not now"). Decline once per day per nudge type — does not reappear that day (PRODUCT.md principle: Nudge, never nag).
- Not animated by default; a gentle fade-in is acceptable (300 ms, easeOutCubic).

---

### Journal Components

**`JournalEditorScreen`**
- `PopScope`: warns on back navigation if there is unsaved text. "Leave without saving?"
- Autosave draft locally every 10 seconds of inactivity.
- On save: run Guardian. If flagged: show `_CrisisCard` inline below the editor (not a modal that cuts off writing).
- Delete confirmation: bottom sheet dialog with confirmation. No immediate delete.

---

### You / Settings Components

**`_AppLockSection`**
- Offered at first visit to You → Security, not only in onboarding.
- Toggle: biometric / PIN, using `local_auth`. Off by default.
- Separate toggle for quick-exit button visibility.
- "Delete all Eve chats from this phone" button: opens a confirmation dialog, then deletes and shows a SnackBar "Chats removed from this device."

**`_ConsentSwitches` (clinician data sharing)**
- Four toggles: mood check-ins / assessment scores / journal / weekly summaries.
- Each toggle has an inline description of exactly what the clinician sees.
- Weekly summaries toggle: hidden until the feature ships.
- Semantics: each toggle announces its state and what it controls.

**`_AccessLog`**
- Lists clinician access events in reverse-chronological order.
- Each event: "A clinician · Saw you in their patient list · [date]". Never the clinician's name (privacy).
- Empty state: "No clinician has viewed your data."

---

### Trust and Privacy Inline Signals

**`_CloudModeChip` (Eve app bar)**
- Shown whenever `EveRuntime.cloud` is active.
- Amber tinted chip: cloud icon + "Cloud mode" text.
- Tap → opens the confirm dialog for switching back to on-device mode.
- Not the 11sp subtitle. Always visible.

**`_PrivacyInlineNote` (beneath composer in cloud mode)**
- 12sp, `onSurfaceVariant` colour.
- Text: "Your messages are sent to the TherapyLink server in cloud mode."
- Not shown in on-device mode (the default state is already private; no need to repeat it on every turn).

---

## Decisions for the Owner

The following decisions cannot be made from the codebase alone. Each one blocks a user-visible change.

**D1 — Clinical sign-off on all crisis copy**  
The consent screen, crisis sheet titles, crisis card text, and PHQ-9 result copy are all marked "PENDING CLINICIAN REVIEW" in the ARB files. No UX direction changes the fact that a Pakistan-licensed clinical psychologist must approve every word in these strings before they reach a patient. This is the single highest-priority human task.

**D2 — Helpline verification**  
Umang 0311 7786264, Madadgaar 1098, and Rescue 1122 are listed as unverified in `helplines.dart`. The `verifiedOn` field is null for all three. Someone must call each service, confirm hours, cost, language, and scope, and record the date. The "free and confidential" claim in `crisisBody` must be removed until it is confirmed.

**D3 — Legal review and privacy policy text**  
The consent screen needs three things from a lawyer: a privacy policy URL, a terms of use URL, and a PECA/PDPB-compliant data disclosure statement. The app cannot launch without them. The Play Store Data Safety section cannot be completed without them.

**D4 — PHQ-9 / GAD-7 Roman Urdu validation**  
The assessment items are app translations, not validated instruments. Before any screening result is shown to a clinician, the owner must either: (a) license and adapt a validated Urdu version, or (b) have a clinician document the translation's limitations and display the "unvalidated translation" notice everywhere scores appear. Option (b) is the faster path to a supervised pilot.

**D5 — Which direction to build**  
This document recommends Direction C (Thehra) because it preserves the existing token investment, maintains brand consistency, and defers visual-design risk until the clinical and safety foundations are complete. If the owner wants a more distinct break from v2 for launch marketing, Direction B (Khamoshi) is the alternative. Direction A (Waraq) is the highest-effort and highest-differentiation option. The owner must confirm which direction before any design work on new screens begins.

**D6 — Clinician escalation policy**  
Do linked clinicians receive a crisis alert when the Guardian flags a chat turn? The clinical-psychologist review (Finding 21) and the crisis-safety review (F11) both flag this as a governance decision. It is not a design decision. The owner, with a clinical lead and a lawyer, must decide and document the answer. The UI (clinician linking flow, consent copy) cannot be finalised until this is resolved.

**D7 — Age policy and minors pathway**  
The under-18 gate screen exists but the path after it is undefined. What does a 16-year-old who reaches the under-18 screen do next? The owner must decide: hard block (exit only), or a minors-specific pathway with guardian consent, different helplines, and no memory. This requires a lawyer and a clinician.

**D8 — Roman Urdu native copy review**  
The UX/UI review (H9, L1) lists specific register and grammar errors in `app_ur.arb`. A native Roman Urdu speaker with clinical literacy must review all 380+ strings. This is not optional for a product that claims Roman Urdu as a differentiator.

---

## Sources

- [Building Empathy-Centred UX for Mental Health Apps — Smashing Magazine (Feb 2026)](https://www.smashingmagazine.com/2026/02/building-empathy-centred-ux-framework-mental-health-apps/)
- [Designing for Distressed Users — Smashing Magazine (Jul 2026)](https://www.smashingmagazine.com/2026/07/designing-distressed-users-mental-health-apps-ui/)
- [Woebot: Case Study in Conversation Design — UX Writing Hub](https://uxwritinghub.com/woebot-case-study-in-conversation-design-for-mental-health-products/)
- [Wysa App Review 2026 — ChooseTherapy](https://www.choosingtherapy.com/wysa-app-review/)
- [Sanvello App Review 2026 — ChooseTherapy](https://www.choosingtherapy.com/sanvello-app-review/)
- [Expert and Interdisciplinary Analysis of AI-Driven Chatbots for Mental Health — JMIR 2025](https://www.jmir.org/2025/1/e67114)
- [Top 7 Mood Tracker Apps 2026 — Clustox](https://www.clustox.com/blog/mood-tracker-apps/)
- [Daylio UI Breakdown — Screensdesign](https://screensdesign.com/showcase/daylio-journal-daily-diary)
- [Stoic App UI Breakdown — Screensdesign](https://screensdesign.com/showcase/journal-mental-health-stoic)
- [Gamification Gone Wrong — NerdsIP (2026)](https://nerdsip.com/blog/gamification-gone-wrong-when-streaks-become-the-point)
- [Psychology of Hot Streak Game Design — UX Magazine](https://uxmag.com/articles/the-psychology-of-hot-streak-game-design-how-to-keep-players-coming-back-every-day-without-shame)
- [Best Practices in Mental Health App Design — Biz4Group](https://www.biz4group.com/blog/best-practices-in-mental-health-design)
- [Mental Health App Design — Gapsystudio](https://gapsystudio.com/blog/mental-health-app-design/)
- [Developing a Safety Planning Smartphone App (NCBI 2025)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12652223/)
- [Designing AI Chatbots: UX Principles for User Trust — Parallelhq](https://www.parallelhq.com/blog/ux-ai-chatbots)
- [Dark Mode Contrast: WCAG-Compliant Dark UI Guide](https://www.colorcontrast.org/blog/dark-mode-contrast-accessibility-guide/)
- [Sehat Kahani — Wikipedia](https://en.wikipedia.org/wiki/Sehat_Kahani)
- [Sehat Kahani — GAVI](https://www.gavi.org/vaccineswork/sehat-kahani-showing-pakistan-digital-health-services-can-change-lives-both)
- [Exploring Code-Switching in Pakistani Youth Digital Sociolinguistics (ResearchGate 2025)](https://www.researchgate.net/publication/397426397_EXPLORING_CODE-SWITCHING_IN_DIGITAL_SOCIOLINGUISTICS_PAKISTANI_YOUTH_ON_INSTAGRAM_AND_TIKTOK)
- [How Much Mobile Data Does an Average Pakistani Use — Propakistani 2025](https://propakistani.pk/2025/10/06/how-much-mobile-data-does-an-average-pakistani-use-every-month/)
- [Noto Nastaliq Urdu Font — Google Fonts via Fontpair](https://fontpair.co/fonts/google/noto-nastaliq-urdu)
