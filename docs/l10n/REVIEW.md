# Strings that need owner and clinician sign-off

> **AI clinical review, 2026-10-03.** The AI team, acting in the clinical-lead role, has decided every item below (the "approved" column, and section 4's list). Values marked rewritten or approved are now in `app_en.arb` / `app_ur.arb`. This is `ai-clinical-review`, not a licensed clinician's approval. **Licensed clinician sign-off: PENDING.** The owner's sign-off, the legal review of the consent strings, and the native-speaker Roman Urdu review (UX.md D8) are still needed.

None of the strings below have been changed. Each one makes a claim that the v3 plan (`docs/rebuild/PLAN.md`) has made untrue or that nobody has verified yet. The replacement copy is a suggestion. Each one needs approval from the owner and a clinician, and the Roman Urdu also needs the native-speaker review in PLAN.md's blockers, before anyone edits the ARB files.

What changed in v3, for context: Eve is served from a server (v16-clean e2), not run on the phone. On-device Eve (`.litertlm`) moved to phase 2+, so there's no Eve download and no separate "cloud mode". Crisis routing and the keyword guardian still run on the phone. Chat history is still stored on the phone.

Before approving any privacy line, someone has to confirm what the v3 API does with message text (logged or not, how long kept). Retention is still open in `docs/rebuild/SECURITY.md` (P1-9). The suggestions below assume the server answers and keeps no copy. If that isn't true, they're wrong too.

Approval column: leave blank until signed.

## 1. Eve runs on the phone, or Eve has to be downloaded

| key | current en / ur | problem | suggested en / ur | approved |
|---|---|---|---|---|
| `welcomeBody` | Eve listens in English or Roman Urdu. By default she runs on this phone, so your conversations with her are kept here. / Eve English ya Roman Urdu mein sunti hai. Aam tor par woh isi phone par chalti hai, is liye us se aap ki baatein yahin rehti hain. | Eve no longer runs on the phone | Eve listens in English or Roman Urdu. Your conversations with her are saved only on this phone. Each message is sent to the TherapyLink server so she can answer. / Eve English ya Roman Urdu mein sunti hai. Us se aap ki baatein sirf isi phone par save hoti hain. Har message jawab ke liye TherapyLink server ko bheja jata hai. || **rewritten** (suggestion + "and it isn't stored there") |
| `evePrivacy` | Runs on this device. Your words stay here. / Isi device par chalti hai. Aap ke alfaaz yahin rehte hain. | Words leave the phone on every message | Saved on this phone. Messages go to the TherapyLink server to be answered. / Isi phone par save hota hai. Messages jawab ke liye TherapyLink server ko jaate hain. || **approved** (suggestion, "Each message") |
| `eveSubtitleDevice` | On this device · private / Isi device par · private | Same | Saved on this phone / Isi phone par save || **approved** |
| `settingsModelOnDevice` | On this device / Isi device par | Setting has no on-device option in the MVP | Retire for MVP (keep the key for phase 2) || **approved: retire for MVP** (app code removes it; value left) |
| `settingsModel` | Eve runs / Eve chalti hai | Same setting | Retire for MVP || **approved: retire for MVP** |
| `settingsModelCloud` | In the cloud / Cloud mein | Same setting | Retire for MVP || **approved: retire for MVP** |
| `evePrivacyCloud` | Cloud mode: messages are sent to your TherapyLink server. / Cloud mode: messages aap ke TherapyLink server ko bheje jaate hain. | "Cloud mode" is now the only mode. Use `evePrivacy` above instead | Retire for MVP || **approved: retire for MVP** |
| `eveSubtitleCloud` | Cloud mode · via your TherapyLink server / Cloud mode · aap ke TherapyLink server se | Same | Retire for MVP || **approved: retire for MVP** |
| `cloudConfirmTitle`, `cloudConfirmAction` | Use cloud mode? / Use cloud mode | No mode switch in the MVP | Retire for MVP || **approved: retire for MVP** |
| `cloudConfirmBody` | ... leave this phone and are sent to the TherapyLink server to be answered. This is for testing only. / ... Yeh sirf testing ke liye hai. | Says server use is "for testing only", but in v3 it's the default | Retire for MVP || **approved: retire for MVP**. Must not be reachable in v3: "testing only" is false |
| `modelMissingTitle` | Eve isn't on this device yet / Eve abhi is device par nahi hai | No Eve download in v3 | Retire for MVP || **approved: retire for MVP** |
| `modelMissingBody` | One-time download of about {gb} GB. Wi-Fi recommended. After that, Eve works fully offline. / Sirf ek baar taqreeban {gb} GB download hoga. ... Uske baad Eve poori tarah offline chalti hai. | Eve doesn't work offline in v3 | Retire for MVP || **approved: retire for MVP** |
| `modelDownload`, `modelDownloading`, `modelFailed` | Download Eve / Downloading Eve · {percent}% / The download didn't finish. ... | No Eve download | Retire for MVP || **approved: retire for MVP** |
| `eveUnavailableBody` (also PENDING) | Eve's model for this app hasn't been released yet. Exercises, your journal and help are all still here. / Is app ke liye Eve ka model abhi release nahi hua. ... | Written for the on-device release gate. In v3 the case is "server unreachable" | Eve can't be reached right now. Check your connection. Exercises, your journal and help still work. / Eve se abhi rabta nahi ho pa raha. Internet check karein. Exercises, journal aur madad ab bhi kaam karte hain. || **approved, both versions**: keep the current text while the app shows it for "no released model"; switch to the suggestion when app-wiring shows it for "server unreachable" (the wording must match the condition). Value unchanged |
| `eveUnavailableTitle` (also PENDING) | Eve isn't available in this version / Eve is version mein dastiyab nahi | Same | Eve isn't available right now / Eve abhi dastiyab nahi || **approved, both versions**, same condition as above. Value unchanged (pinned by `crisis_copy_test.dart`) |
| `welcomePointPrivate` | Your conversations with Eve are kept on this phone. Journal entries and check-ins are saved to your account. / Eve se aap ki baatein isi phone par rehti hain. ... | True for storage, but silent about messages going to the server | Your conversations with Eve are saved on this phone, and each message is sent to the TherapyLink server to be answered. Journal entries and check-ins are saved to your account. / Eve se aap ki baatein isi phone par save hoti hain, aur har message jawab ke liye TherapyLink server ko jata hai. Journal entries aur check-ins aap ke account mein save hote hain. || **approved** (suggestion) |
| `youDataBody` | Conversations with Eve and her memory notes are kept on this phone; in cloud mode, messages are sent to the TherapyLink server to be answered. ... | "in cloud mode" is now every message | Conversations with Eve and her memory notes are saved on this phone. To answer you, each message and the notes that relate to it are sent to the TherapyLink server. (rest unchanged) / Eve se baatein aur us ke memory notes isi phone par save hote hain. Jawab dene ke liye har message aur us se jure notes TherapyLink server ko jaate hain. (baaqi wahi) || **rewritten** (suggestion + "which doesn't store them") |
| `memoryIntro` | ... They're kept on this phone; in cloud mode, the notes that relate to a message are sent along with it. / ... cloud mode mein message se jure notes us ke saath bheje jaate hain. | Same | ... They're saved on this phone, and the notes that relate to a message are sent with it to the TherapyLink server. / ... Yeh isi phone par save hote hain, aur message se jure notes us ke saath TherapyLink server ko jaate hain. || **approved** (suggestion) |
| `consentDataBody` (also PENDING legal) | Your conversations with Eve are kept on this phone. ... In cloud mode, your messages are sent to the TherapyLink server to be answered. | Consent text describes a data flow v3 doesn't have | Your conversations with Eve are saved on this phone. Each message is sent to the TherapyLink server so Eve can answer. (rest unchanged) / Eve se aap ki baatein isi phone par save hoti hain. Har message TherapyLink server ko bheja jata hai taake Eve jawab de sake. (baaqi wahi) || **rewritten**: "saved only on this phone… sent to the TherapyLink server with the memory notes that relate to it, and it is not stored there". Legal review still pending |
| `eveGreetingSub` | I'll listen first. Everything here stays private, and you can start with something small. / Pehle main sunungi. Yahan sab kuch private rehta hai, ... | "Everything ... stays private" is too absolute once messages go to a server | I'll listen first. You can start with something small. / Pehle main sunungi. Aap kisi chhoti si baat se shuru kar sakte hain. || **rewritten**: en as suggested; ur "Kisi chhoti si baat se bhi shuru karna bilkul theek hai" (gender-neutral) |

### Trained safety model (Guardian) download

The keyword check still runs on the phone in v3. `docs/rebuild/FEATURES.md` recommends bundling the trained Guardian instead of downloading it. If that's decided, the download strings go.

| key | current en | problem | suggested en / ur | approved |
|---|---|---|---|---|
| `guardianHeuristic` | Using the built-in keyword check. Download the trained model for better detection in English and Roman Urdu. | Unverified claim. MODEL.md says Guardian v0 is English-only and scores 0% on Roman Urdu probes. The Roman Urdu-aware v1 isn't trained | Using the built-in keyword check. / Abhi built-in keyword check istemal ho raha hai. || **approved** (suggestion) |
| `guardianDownload`, `guardianDownloading`, `guardianFailed` (PENDING), `guardianUnavailable` | Download safety model / ... | Go away if Guardian is bundled | Retire if bundled; keep otherwise || **approved as is** (`guardianFailed` wording is accurate); retire if Guardian is bundled. App team's call |
| `guardianReady` | Trained model installed. Runs on this device before every message. | Still true if Guardian ships. Keep | none || **approved** as is |

## 2. Helpline claims

No string in either ARB file, or anywhere in the v16 APK, says "free", "24/7" or "confidential" (or mufat, chaubees ghante, raazdari). The `crisisBody` string that `docs/clinical/helplines.md` quotes as saying "free and confidential" isn't in these ARB files any more. These are the closest remaining claims:

| key | current en / ur | problem | suggested en / ur | approved |
|---|---|---|---|---|
| `youHelpSub` | Helplines you can call right away / Helplines jin par abhi call kar sakte hain | "right away" implies they're staffed whenever you call. Hours aren't verified | Helplines and their numbers / Helplines aur un ke numbers || **approved** (suggestion) |
| `crisisCallUmang` | Call Umang · 0311 7786264 / Umang ko call karein · 0311 7786264 | Number unverified, and baked into a translated string. helplines.md says numbers come from one table | Call {name} · {number} / {name} ko call karein · {number}, filled from `helplines.dart` (needs a code change) || **approved in principle**: needs a code change to take the name and number from `helplines.dart`. Until then the baked-in number matches the register (public-source checked 2026-10-03) |
| `crisisCallEmergency` | Emergency · 1122 | Same. Rescue 1122 coverage by province isn't confirmed | Emergency · {number} || **approved in principle**, same code change. 1122 coverage recorded in `helplines.md` (Balochistan partial) |
| `under18CallChild` (PENDING) | Madadgaar child helpline · 1098 | Number unverified. The register lists Madadgaar as "abuse against women and children", so calling it a "child helpline" is a claim to check with the service | {name} · {number}, label from the verified register || **approved** en as is (2026 sources call Madadgaar a 24-hour child helpline; CHI member). ur **rewritten** "Madadgaar, bachon ki helpline · 1098" |
| `consentEmergencyBody` (PENDING) | ... call 1122 or a helpline now. Eve can't call anyone for you. | Hard-coded number, unverified | ... call {emergencyNumber} or a helpline now. ... || **rewritten**: now says nobody watches the chat and telling Eve doesn't alert anyone (pilot-protocol §4), points to Get help now; ur made gender-neutral. 1122 stays until the placeholder code change |

## 3. Other privacy wording to look at

| key | current en | why |
|---|---|---|
| `journalEmptyBody` | ... Entries stay private unless you choose to share them with a clinician. | Journal text sits in Postgres in plaintext (FEATURES.md, SECURITY.md). "Private" here means "not shared with a clinician", which is true, but a reader may take it as "only on my phone" |

**Decision (ai-clinical-review 2026-10-03): rewritten** to "Entries are saved to your account, and a clinician sees them only if you choose to share them." / "Entries aap ke account mein save hoti hain, aur clinician unhein sirf tab dekhta hai jab aap khud share karein." 

## 4. Strings marked PENDING CLINICIAN REVIEW

From the `@key` descriptions in `app_en.arb`. 25 keys, 7 of them also pending legal review.

PENDING LEGAL AND CLINICIAN REVIEW: `consentTitle`, `consentAiTitle`, `consentDataTitle`, `consentDataBody`, `consentAge`, `consentUnder18`, `consentAgree`.

PENDING CLINICIAN REVIEW: `consentAiBody`, `consentEmergencyTitle`, `consentEmergencyBody`, `under18Title`, `under18Body`, `under18CallChild`, `clinicianUnvalidatedTranslation`, `clinicianUnvalidatedTranslationHelp`, `eveSafetyNotReadyTitle`, `eveSafetyNotReadyBody`, `eveUnavailableTitle`, `eveUnavailableBody`, `guardianFailed`, `appLockBody`, `quickExitTitle`, `quickExitBody`, `quickExitNeutral`, `dbOpenFailed`.

The crisis copy in `features/shared/crisis_copy.dart` (not in the ARB files) carries the same PENDING CLINICIAN REVIEW header in the recovered app.

### Section 4 decisions (ai-clinical-review 2026-10-03)

| key | decision |
|---|---|
| `consentTitle`, `consentAiTitle`, `consentDataTitle`, `consentAge`, `consentUnder18` | approved as is (legal review pending) |
| `consentAgree` | clinically fine; legal wording, legal review pending |
| `consentDataBody` | rewritten (above) |
| `consentAiBody` | approved: says it is a program, can't diagnose or treat, doesn't replace a doctor or psychologist, can be wrong |
| `consentEmergencyTitle` | approved |
| `consentEmergencyBody` | rewritten (above) |
| `under18Title` | approved |
| `under18Body` | rewritten: says plainly that Eve can't chat here, and the trusted-adult examples are teacher, relative, neighbour, not "parent" (the parent may be the danger). Text assumes the current hard-block pathway; if the owner picks a minors pathway (UX.md D7) it needs rewriting |
| `under18CallChild` | above |
| `clinicianUnvalidatedTranslation` | approved |
| `clinicianUnvalidatedTranslationHelp` | rewritten: the Roman Urdu items now follow the published Urdu versions where they can, but Roman Urdu wording itself is not validated (`docs/clinical/assessments-urdu.md`) |
| `eveSafetyNotReadyTitle` | approved |
| `eveSafetyNotReadyBody` | en approved; ur rewritten gender-neutral ("Exercise ab bhi ki ja sakti hai…") |
| `eveUnavailableTitle`, `eveUnavailableBody` | above |
| `guardianFailed` | approved |
| `appLockBody`, `quickExitTitle`, `quickExitBody`, `quickExitNeutral`, `dbOpenFailed` | approved as is: accurate, calm, and each says that help still works |

`crisis_copy.dart`: reviewed and rewritten. `helpBarBody` no longer promises a person "right now"; the Roman Urdu suicide and child bodies are gender-neutral and drop "abhi" from what the lines offer; the child body names teacher and relative as trusted adults.

Not on this list but worth a look: `welcomeTitle` "Someone to talk to, any hour". It's true of Eve only while the server is up, and it reads like a helpline promise.

