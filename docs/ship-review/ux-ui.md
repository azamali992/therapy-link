# TherapyLink ship review: UX/UI (trauma-informed, mobile)

Reviewer role: senior UX/UI designer. Method: read every patient and clinician screen in `app/lib/features/**`, the theme in `app/lib/app/theme/**`, both ARB files, the router and the parts of the controller and API that decide what a person sees. Nothing here was run on a device. Where a claim depends on runtime behaviour I say "not verified on device". Contrast ratios were computed from the hex tokens in `tokens.dart`.

## Summary

The visual system is calm and well built. Tokens are centralised, red is never used, the mood scale has labels, 52 dp buttons are the default, most animation goes through `context.motion()`, and the privacy copy is plain and short. The chat, the in-chat exercises, the memory screen and the consent switches are better than most apps in this category.

The problems sit in the places a distressed person depends on most:

1. **Help is not reachable on request.** `showCrisisSheet` is called from exactly two places: when Guardian flags a message (`eve_screen.dart:78-82`) and when PHQ-9 item 9 comes back flagged from the server (`assessment_screen.dart:44-46`, `:266`). No screen has a help button. Welcome and sign-in don't either, so a person who installs the app in crisis has to create an account before they can see a helpline. `app/PRODUCT.md:24,32` says the opposite should be true.
2. **Help can be lost after one swipe.** The crisis sheet can be dismissed by dragging it down. What stays in the chat is `crisisBody` ("Someone can talk with you right now…"), with no number and no button (`eve_controller.dart:164`), so there is no way back to the sheet.
3. **The app says "what you say stays here", and some of it doesn't.** A valence and emotion label is inferred from every chat message and uploaded (`eve_controller.dart:158-159`, `:376-388`). Journal entries live on the server. Cloud mode is a single tap from the model banner and needs no confirmation.
4. **Shared phones.** Local chats and memories are not scoped to the user and are not cleared on sign-out (`database.dart:66`, `auth_repository.dart:47-51`). There is no app lock and no way to delete chat history.
5. **Roman Urdu mode almost certainly renders right-to-left.** The app uses the `ur` locale code with Flutter's global delegates and never overrides direction. The Roman Urdu copy also has register and gender problems, plus one dangerous label collision.

## Verdict

**Not ready for real patients.** Five blockers, each fixable in the repo in a few days: crisis access from every screen, a crisis state that can't be lost, an offline-safe item 9 check, local data that survives sign-out, and a first-run consent and disclaimer screen. Legal text, helpline verification and clinical review of the Roman Urdu wording need people outside the codebase (see the last section).

## Findings

Severity: blocker = before any real patient; high = before public launch; medium = soon after; low = nice to have. Effort: S < 1 day, M 1-3 days, L > 3 days.

### Blockers

**B1. No way to reach help on request, from any screen, including before sign-in.** blocker · code · M
Evidence: `grep showCrisisSheet` finds only `eve_screen.dart:81`, `assessment_screen.dart:45` and `:266`. `patient_shell.dart:80-85` has four tabs and no help action. The Eve app bar (`eve_screen.dart:112-131`) holds only an overflow menu. `welcome_screen.dart` and `sign_in_screen.dart` have no help link. The router sends every signed-out user to `/welcome` or `/sign-in` (`router.dart:219-222`). `PRODUCT.md:24` lists "Chat UIs that hide the crisis path…" as an anti-reference.
Recommendation: add a persistent "Get help now" / "Abhi madad" action. Put it as an always-visible `IconButton` (Icons.support, tooltip and semantics label) in the Eve app bar and in the `Screen` widget's AppBar (`widgets.dart:204`), so every patient screen inherits it. Add a text button at the bottom of Welcome and Sign-in that opens the same sheet with no account needed. Also make it reachable from You as a row titled "If you're in crisis". Target: help is one tap from every screen and two taps at most from a locked-out state.

**B2. The crisis state can be dismissed for good.** blocker · code · S
Evidence: `crisis_sheet.dart:16` `isDismissible: true`, and the theme's drag handle is on (`theme.dart:163`). The message saved in the chat is `crisisBody` only (`eve_screen.dart:42`, `eve_controller.dart:164`): "You don't have to carry this alone. Someone can talk with you right now — it's free and confidential." It gives no number. `_EveBubble` with `urgent: true` only tints the logo and border (`eve_screen.dart:518,536`). It has no action.
Recommendation: render the crisis reply as a dedicated `_CrisisCard` in the chat. Show the helpline names and numbers as text, plus "Call Umang" and "Emergency 1122" buttons and "Show all options", which reopens the sheet. After a flagged turn, keep a slim "Help is here" bar above the composer for the rest of the session, styled like `_BreakNudge`. Keep the sheet dismissible, since forcing a modal is not trauma-informed, but make sure dismissing it never removes the way back.

**B3. A flagged PHQ-9 item 9 shows nothing when the network fails.** blocker · code · S
Evidence: `assessment_screen.dart:40-52`. The crisis sheet opens only if `result.flags` from the server contains `suicidal_ideation_item`. On any exception the person sees `errorGeneric` ("Something went wrong. Check your connection…") and gets no help. The answers sit in `_answers` locally.
Recommendation: check `_answers[8] > 0` for PHQ-9 on the device before submitting. If it's positive, show the flagged panel and crisis sheet whatever the network does. Queue the submission for retry, the same way mood is queued (`queueMood`). A self-harm answer must never produce a connectivity error as the only response.

**B4. Chats and memories are shared across accounts and survive sign-out.** blocker · code · M
Evidence: one database file for everyone, `driftDatabase(name: 'therapylink')` (`database.dart:66`). `watchMessages(conversationId)` has no user filter. The conversation id sits in SharedPreferences (`settings.dart:119`). `signOut()` only signs out of Firebase and Google (`auth_repository.dart:47-51`). The next person to sign in on the phone sees the previous person's Eve conversation and "What Eve remembers". `PRODUCT.md:9` describes "mid-range Android phone" users, and family-shared phones are common in the target market.
Recommendation: key the database file by Firebase uid (`therapylink_<uid>`). On sign-out, confirm with "Sign out and remove Eve chats from this phone?" and close and delete the local database and memory prefs. Say plainly that Eve chats are not backed up.

**B5. No first-run consent, disclaimer or age check.** blocker · code + human · M
Evidence: `welcome_screen.dart:141-194` has three selling points and a language toggle, then "Continue" goes to sign-in (`:188-192`). There is no statement that Eve is an AI and not a therapist, no "not for emergencies", no age confirmation (`PRODUCT.md:9` says adults), no privacy policy or terms link, and no consent to processing health data (check-ins, journal, chat-derived mood) on a server. `grep -i "privacy policy\|terms"` over `lib/` finds nothing.
Recommendation: add a single consent step after the language choice, with three short plain statements in the chosen language, each with a checkbox or one "I understand" button:
- "Eve is an AI companion, not a doctor or therapist."
- "If you're in danger, call 1122 or Umang, and you can do it from any screen."
- "Your Eve chats stay on this phone. Check-ins, journal and a mood score estimated from your chats are saved to your account."
Add an age confirmation, and link a privacy policy and terms (the texts themselves are a human task). Store the consent version and timestamp.

### High

**H1. Roman Urdu mode will render the whole UI right-to-left and use Urdu script for system strings.** high · code · S
Evidence: the locale is `Locale('ur')` (`welcome_screen.dart:185`, `settings_screen.dart:157`), and the delegates include `GlobalMaterialLocalizations` and `GlobalWidgetsLocalizations` (`app_localizations.dart:90-92`). Flutter treats `ur` as an RTL language. `grep Directionality|textDirection lib/` finds no override. With RTL, user bubbles (`AlignmentDirectional.centerEnd`, `eve_screen.dart:471`) move to the left, back arrows and paddings mirror, and Latin-script Roman Urdu text is right-aligned. `MaterialLocalizations.cancelButtonLabel` (`memory_screen.dart:32`, `caseload_screen.dart:32`) and `DateFormat(locale)` (`today_screen.dart:43`, journal, day markers) produce Urdu-script text inside a Latin-script UI. Not verified on device, but this is Flutter's documented behaviour.
Recommendation: wrap the app in `Directionality(textDirection: TextDirection.ltr)` whenever the language is Roman Urdu, in `app.dart`'s `builder`. Format dates with `en` (or a small Roman Urdu month table) and supply Roman Urdu for the few Material strings you use (Cancel, OK). The cleaner long-term fix is a distinct locale code (for example `ur-Latn`, or a custom delegate) so real Urdu script can be added later without conflict.

**H2. The "stays on this phone" promise is broader than what the app does.** high · code · S
Evidence: `welcomePointPrivate` "What you say stays here" (`app_en.arb:353`), `evePrivacy` "Nothing you say here is uploaded" (`:32`). But every chat message's inferred valence and emotion is queued and uploaded as a mood point with `source: 'chat'` (`eve_controller.dart:158-159,376-388`), and it feeds the clinician's mood trend. `youDataBody` (`:218`) mentions "mood trend" but not that it's inferred from chats.
Recommendation: either stop uploading chat-derived mood (keep it local, and upload only mood the person taps on Today), or say it: "Eve estimates a mood score from each message. Only that score, not your words, is saved to your account." Put this at consent (B5), in `youDataBody`, and on the Care screen's "Mood trend" switch.

**H3. Cloud mode is a one-tap privacy downgrade with no confirmation.** high · code · S
Evidence: `_ModelBanner` offers "Use cloud mode instead" as a TextButton on the download prompt and on failure (`eve_screen.dart:272,293`), and it calls `setEveRuntime(cloud)` immediately. The settings segment does the same (`settings_screen.dart:193-200`). The only disclosure is a small grey line (`:202`) and the app-bar subtitle (`eve_screen.dart:105`).
Recommendation: show a confirm dialog before switching: "In cloud mode your messages are sent to TherapyLink's server to get Eve's reply. [Keep on this phone] [Use cloud]". While cloud is on, show a visible chip in the Eve app bar, not just the 11 sp subtitle.

**H4. The crisis button fails contrast in light mode.** high · code · S
Evidence: the Umang button is `backgroundColor: urgent (#B9772E), foregroundColor: scheme.surface (#F8FAFA)` (`crisis_sheet.dart:47`, same at `assessment_screen.dart:265`). The contrast is 3.49:1, below AA 4.5:1 for 14 sp labelLarge text. `PRODUCT.md:36` requires ≥ 4.5:1. Error text in `scheme.tertiary` on the light ground is 3.49-3.66:1 (`sign_in_screen.dart:332`, `assessment_screen.dart:349`, `journal_editor_screen.dart:277`, `care_screen.dart:380`). Dark mode passes (8.4:1).
Recommendation: darken `Tokens.urgent` to about `#8F5A1F` (check it reaches ≥ 4.5:1 against both `#F8FAFA` and `#FFFFFF`), or use dark ink on the current amber. Use a separate `errorText` token for form errors rather than reusing the crisis colour, because an error message should not look like the crisis path.

**H5. The trained safety model is opt-in and buried in Settings. The fallback shows "Not published yet" to patients.** high · code · S
Evidence: `guardianProvider` uses keywords unless the ONNX model was downloaded from Settings → Safety check (`onnx_guardian.dart:210-215`, `settings_screen.dart:203-204`). `TL_GUARDIAN_URL` defaults to empty (`onnx_guardian.dart:15`), which disables the button with the label `guardianUnavailable` "Not published yet." (`app_en.arb:66`).
Recommendation: download Guardian automatically along with Eve (it is small next to the 2 GB model), with no separate button. Remove the Safety check section from patient Settings, or reduce it to a status line. Never show "Not published yet" in a shipped build.

**H6. The keyword fallback misses feminine Roman Urdu phrasing.** high · code (and ml) · S
Evidence: `guardian.dart:20-22` matches `marna chahta` but not `marna chahti`, and `mar jaun` but not `mar jana chahti`/`mar jaana`. A woman typing "main marna chahti hoon" is not flagged by the keyword path. That path is the only one when Guardian isn't downloaded (H5).
Recommendation: make the patterns gender-neutral (`marna chaht[ai]`, `mar ja(u|oo|n|na|ana)`, `khud ko (khatam|maar)`, `zinda nahi rehna`). Add unit tests with feminine and masculine forms. Hand the list to the psychologist reviewer.

**H7. No app lock, no chat deletion, and "New conversation" hides history.** high · code · M
Evidence: the Eve overflow menu (`eve_screen.dart:125-129`) has wrap-up, exercises and new conversation. `newConversation()` switches the id with no confirmation (`eve_controller.dart:130-138`), and the old thread becomes unreachable in the UI though it stays in the database ("Older ones stay in the database", `settings.dart:68`). The database layer has no delete for messages or conversations (`database.dart:97-103` only deletes memories).
Recommendation: add a Conversations list (past threads, each deletable) and "Delete all Eve chats" in You. Add an optional app lock using the device biometric or PIN (`local_auth`), off by default and offered once at consent. Consider an optional discreet notification and app label, given family-shared phones.

**H8. Journal entries are not screened for risk.** high · code · S
Evidence: `journal_editor_screen.dart:185-206` posts to the API with no Guardian call. Writing "I want to end it" in the journal gets no response.
Recommendation: run `guardianProvider.classify` on save. If it flags, save the entry and then show the crisis card or sheet. The journal is where people write what they won't say to a chatbot.

**H9. The same Roman Urdu phrase means "very low mood" and "minimal symptoms".** high · code (copy) · S
Evidence: `app_ur.arb:77` `moodVeryLow: "Bohat kam"` and `:196` `bandMinimal: "Bohat kam"`. One is the worst mood and the other is the best screening result. `bandLabel` and `moodLabel` both appear on Today.
Recommendation: moods: "Bohat bura / Bura / Theek / Acha / Bohat acha" (or "Bohat udaas…"). Bands: "Na hone ke barabar / Halka / Darmiyana / Kaafi zyada / Shadeed".

**H10. Hard-coded English and untranslated error paths on the screens people see first.** high · code · S
Evidence: `sign_in_screen.dart:252-258` (all auth errors), `:307` ("or"), `:318`, `:328` (validators). `eve_controller.dart:61`: `eveFailureReply` is an English literal saved into the chat, so a Roman Urdu user whose reply fails gets English. `settings_screen.dart:162,173` ('A' glyphs have no semantics). `brand_mark.dart:18` label 'TherapyLink'.
Recommendation: move all of these to ARB. For `eveFailureReply`, store a marker role (like `exerciseRole`) and render localised text in the UI, which also keeps the "never sent to the model" check robust.

**H11. Screen-reader experience of the chat.** high · code · M
Evidence: every first Eve bubble includes `BrandMark` with `Semantics(label: 'TherapyLink')` (`eve_screen.dart:518`, `brand_mark.dart:17`), so TalkBack reads "TherapyLink" and then the text. Bubbles are not labelled by speaker (user vs Eve). New or streamed replies are not a live region, so a blind user doesn't hear that Eve answered. `MoodChart` is a `CustomPaint` with no semantic summary (`mood_chart.dart:38`). The breathing card in chat (`exercise_cards.dart:246-256`) has no live region, while the full-screen player does (`breathing_player.dart:108-110`).
Recommendation: wrap bubbles in `Semantics(label: 'Eve said' / 'You said', …)` and exclude the mark (`ExcludeSemantics`). Announce a completed reply with `SemanticsService.announce`, not every token. Give the chart a label like "Mood, last 30 days: mostly Okay, lower in evenings". Reuse the player's live region in the chat card.

### Medium

**M1. First run shows a 2 GB download before Eve can talk, and messages sent before it fail with a misleading reply.** medium · code · M
Evidence: `modelMissingBody` "about {gb} GB" with `gigabytes: 2.0` (`gemma_eve_engine.dart:28`). The composer stays enabled while the model is missing (`eve_screen.dart:157`). `reply()` calls `_load()` (`gemma_eve_engine.dart:142`), and a failure becomes `eveFailureReply` "I'm having trouble replying right now…" (`eve_controller.dart:321-324`), which implies a glitch rather than "not downloaded". Not verified on device. Welcome promises "Someone to talk to, any hour" (`app_en.arb:12`).
Recommendation: while the model is missing, replace the composer with the download card plus two alternatives: exercises (which work offline now) and the help sheet. Show download size, a Wi-Fi-only toggle, resume on failure, and let the person keep using Today and Journal while it downloads.

**M2. The composer is disabled while Eve generates.** medium · code · S
Evidence: `_Composer(enabled: !state.generating)` → `TextField(enabled: enabled)` (`eve_screen.dart:157,656`). A disabled field drops focus, so the keyboard closes after every send and the person can't start typing their next thought.
Recommendation: keep the TextField enabled and disable only the send button while generating.

**M3. Destructive actions with no confirmation or undo.** medium · code · S
Evidence: journal delete (`journal_editor_screen.dart:208-220,240`), memory "Forget this" (`memory_screen.dart:347-351`), "Remove clinician" (`care_screen.dart:366`), sign out (`you_screen.dart:117`), new conversation (`eve_screen.dart:117-118`). Journal drafts are lost on back navigation (there is no `PopScope`), and on a save error the text stays only while the screen is open.
Recommendation: confirm dialogs for journal delete and clinician removal. SnackBar with Undo for memory deletes. Autosave journal drafts locally and warn on back with unsaved text.

**M4. Journal and check-ins don't work offline.** medium · code · M
Evidence: journal list, create and update go straight to the API (`journal_editor_screen.dart:191-198`, `api_client.dart:63-70`). Assessments submit only online (`assessment_screen.dart:40`). The target user opens the app "late at night… on a mid-range Android phone" (`PRODUCT.md:9`).
Recommendation: write locally first (drift), sync in the background, and show a quiet "Saved on this phone, will sync" state.

**M5. The Care screen shows the clinician's raw uid, not who they are.** medium · code · S
Evidence: `SectionTitle(link.clinicianUid)` (`care_screen.dart:355`). `CareLinkOut` exposes only `clinician_uid` (`api/therapylink_api/schemas.py:117`). The patient can't confirm they linked the right person before switching on journal sharing.
Recommendation: return the clinician's display name, specialty and "Verified PMDC" state in the link. After entering a code, show "You're linking with Dr X, PMDC verified. Nothing is shared until you switch it on." as a confirm step.

**M6. The "Weekly summaries" consent switch controls nothing.** medium · code · S
Evidence: `ApiClient.shareSummary` exists (`api_client.dart:73-76`), but nothing in `lib/` calls it (`grep shareSummary`). The patient can turn on a share for data that is never produced, and the clinician's section always shows "Not shared".
Recommendation: hide the switch until the feature exists. When it does, make sharing a summary an explicit per-summary action ("Share this wrap-up with Dr X?") after wrap-up, not a blanket toggle, because chat content is the most sensitive data here.

**M7. Assessment results tell people to see a professional but give them nowhere to go.** medium · code + human · M
Evidence: `resultExplainModeratelySevere` and `resultExplainSevere` ("please book time with a psychologist or doctor this week", `app_en.arb:346-347`). The result view offers only "Done" and "Talk it through with Eve" (`assessment_screen.dart:275-278`).
Recommendation: add "Find support" linking to a vetted list (government and NGO clinics by city, Umang, the Care screen if a clinician is linked). The list itself needs human curation. On a flagged result, the flagged panel's button is labelled "Call Umang · 0311…" but opens the sheet instead of dialling (`assessment_screen.dart:266-269`). Make the label match the action ("See ways to get help now") or dial directly.

**M8. The layout breaks at large text sizes.** medium · code · M
Evidence: the text scale multiplies the OS scale by an in-app 0.85-1.6 slider with no clamp (`app.dart:31`, `settings_screen.dart:166-167`), so an OS at 2.0× becomes 3.2×. Fixed widths: `SizedBox(width: 150)`, `SizedBox(width: 60)` in the clinician assessment row (`patient_screen.dart:63-64`). The Eve app-bar title is a `Row` with an unconstrained `Column` (`eve_screen.dart:95-110`); the long cloud subtitle will overflow. Three exercise tiles side by side with `maxLines: 2` titles (`today_screen.dart:89-98,178`). Not verified on device. `PRODUCT.md:36` requires surviving 1.6×.
Recommendation: clamp the combined scale (for example `.clamp(0.85, 2.0)`), use `Expanded` or `Flexible` in the app-bar title, stack the Today exercise tiles vertically when `textScaler.scale(14) > 20`, and replace fixed widths with `Wrap` or `Table`. Add golden tests at 1.0, 1.6 and 2.0 for Eve, Today, Result and the crisis sheet.

**M9. In-chat exercises can lose their state.** medium · code · S
Evidence: breathing and muscle timers live in `State` objects inside a lazily built, reversed `ListView.separated` (`eve_screen.dart:364-372`, `exercise_cards.dart:182-227,435-477`), and `findChildIndexCallback` is not set. Scrolling the card off-screen, or a new message shifting indices, can dispose it mid-exercise. Not verified on device.
Recommendation: pass `findChildIndexCallback` keyed on message id, and lift exercise progress into the controller or keep it alive (`AutomaticKeepAliveClientMixin`).

**M10. The "I'm a clinician" row sits in every patient's You tab.** medium · code · S
Evidence: `you_screen.dart:111`. Continuing converts the account role at once (`me.py:52-53`), and the router then locks the person into `/clinic` (`router.dart:227`).
Recommendation: move clinician sign-up to a separate entry point (web or a sign-in link). If it stays, put it under an "About / For professionals" section with a confirmation.

**M11. The clinician view doesn't say the Roman Urdu wording is unvalidated, or which language was used.** medium · code · S
Evidence: `assessment_items.dart:3-4` says the non-validated Roman Urdu note should appear wherever scores are shown to a clinician. `patient_screen.dart:55-73` and the caseload rows don't show it, and the assessment language isn't sent (`assessment_screen.dart:41`). The flag icon has no semantics label (`patient_screen.dart:69`).
Recommendation: send `lang` with each submission, and show "Roman Urdu (app translation, not validated)" next to those scores. Label the flag icon "Item 9 endorsed".

### Low

**L1. Roman Urdu register and grammar.** low · code (copy) · S
Evidence and suggested replacements (`app_ur.arb`):
- `:67` crisisTitle "Yeh sanjeeda lagta hai, aur acha kiya aap ne kaha" → "Yeh bohat bhaari baat hai, aur achha kiya ke aap ne bataya".
- `:205` "Naya entry" → "Nayi entry".
- `:301` "Kaso aur chhoro" (tu-form, clashes with the aap register used everywhere else) → "Kasein aur dheela chhorein".
- `:294` "2 khushbuein jo aap soongh sakte hain" (implies pleasant smells) → "2 cheezein jin ki boo ya khushbu aap mehsoos kar sakte hain".
- `:223` "Look" → "Theme".
- `:17` "Khush aamdeed" for "Welcome back" → "Dobara khush aamdeed".
- `:90` insightTimeOfDay has a singular/plural mismatch ("Aap ki subah … rahi hain").
- Masculine default when addressing the user ("sakte hain", "karenge", "kar rahe hain") runs throughout. It's acceptable, but a native clinical reviewer should decide.

**L2. Reduce motion is not fully honoured.** low · code · S
Evidence: `InkSparkle.splashFactory` and the page transitions (`theme.dart:165-172`) ignore `disableAnimations`. Breathing haptics fire on every phase regardless of setting (`exercise_cards.dart:212`).
Recommendation: when motion is reduced, use `NoSplash` or `InkRipple` and `FadeUpwardsPageTransitionsBuilder` with zero duration. Add a haptics toggle.

**L3. Crisis dialling has no fallback.** low · code · S
Evidence: `launchUrl` result ignored (`crisis_sheet.dart:48,54`). On a tablet or web with no dialler, nothing happens.
Recommendation: if `canLaunchUrl` is false, show the number large with a copy button. Add Madadgaar 1098 (named in the product brief) if a human confirms it's the right service for this audience, and add "Text someone you trust" (open contacts or SMS).

**L4. Muscle release has no safety note.** low · code (copy) · S
Evidence: `muscleIntro` (`app_en.arb:303`).
Recommendation: add "Skip any area that hurts or is injured."

## Recommendations: top 10 UX changes by impact

1. **Help button on every screen, including Welcome and Sign-in** (B1). This is the single most important change.
2. **Crisis card in the chat, with numbers, call buttons and a way back to the sheet, plus a session-long "Help is here" bar after a flag** (B2).
3. **Check PHQ-9 item 9 on the device, whatever the network does** (B3), **and screen journal entries with Guardian** (H8).
4. **Per-user local data, cleared on sign-out; chat history list with delete; optional app lock** (B4, H7).
5. **First-run consent: AI-not-therapist, emergencies, what data goes where, age, policy links** (B5), **with privacy copy made accurate: chat-derived mood, and a confirm before cloud mode** (H2, H3).
6. **Force LTR and Latin-script system strings in Roman Urdu mode; fix the "Bohat kam" collision; native clinical copy pass** (H1, H9, L1).
7. **Guardian downloads automatically with Eve; gender-neutral keyword fallback; no "Not published yet" in the UI** (H5, H6).
8. **Fix crisis-button and error contrast with a separate error token** (H4).
9. **Screen-reader pass on chat: speaker labels, announce replies, chart summary, no "TherapyLink" per bubble** (H11), **and localise every hard-coded string** (H10).
10. **First-run model flow: disable the composer with alternatives until Eve is installed; keep the keyboard up while Eve replies** (M1, M2).

## What needs a human

- **Clinical psychologist (Pakistan-licensed) review of the crisis copy in both languages**: `crisisTitle`, `crisisBody`, `resultFlagged`, `resultExplain*`, `groundingOffer`, `eveBreakNudge`, and the in-chat crisis card from B2. Also sign-off on whether the crisis sheet should be dismissible and what it should offer after a false positive.
- **Helpline verification**: confirm Umang's number (0311-7786264), hours, and whether the call is actually free, since `crisisBody` says "free and confidential". Confirm that Rescue 1122 is right for a self-harm emergency in every province. Confirm whether Madadgaar 1098 (a child and women's line) belongs in an adults-only app. Re-check every quarter.
- **Roman Urdu validation of PHQ-9 and GAD-7**: the wording is an app translation (`assessment_items.dart:3-4`). Either license and adapt a validated Urdu version, or have a clinician document the translation's limits. Score bands in Roman Urdu need the same review.
- **Native-speaker copy review** of all 380 Roman Urdu strings for register, gendered forms and cultural fit (L1 is a starting list, not a full review).
- **Legal**: privacy policy and terms covering health data, chat-derived mood, journal on the server, clinician access and cloud mode, in line with Pakistani law (PECA and the pending Personal Data Protection Bill), plus Play Store health-app declarations. The consent screen in B5 needs this text.
- **Referral directory** for M7 (clinics and NGOs by city), curated and kept current by a person.
- **Moderated usability test** with 6-8 target users (18-35, mixed English and Roman Urdu, including women on shared phones), with a clinician present. Tasks: find help from each tab, first-run to first Eve reply, take PHQ-9, link a clinician. Include TalkBack users and the 1.6× text scale.
- **Clinician verification process** for PMDC numbers (`scripts/verify_clinician.py` exists but depends on a person checking licences).
