## Design Critique: TherapyLink v3, "Jugnu"

Stage: direction / exploration, before sign-off. Reviewed: `index.html` (seven 360×760 phone mockups and the design system) at 1280 px and 400 px, plus the CSS tokens. The Blender assets were not yet on disk, so every Eve spot showed the CSS fallback.

### Overall Impression
This is a strong, coherent identity, clearly unlike Claude and unlike the five rivals. "One colour, one job" is a real system, and the paper-and-navy crisis sheet is the best idea on the page. The biggest risk is that Eve currently reads as the generic glossy "AI voice orb" (Siri, Gemini, ChatGPT voice). That undercuts the whole "unique" brief until the Blender bloom replaces it.

### Usability
| Finding | Severity | Recommendation |
|---|---|---|
| "Get help" / "Madad" header pills, Copy buttons and some chips are 36 to 40 px tall | 🔴 Critical | Every help, call and copy control gets at least a 48 dp target (Android). Get help is the most important control in the app: make it 48 dp, with at least 8 dp of spacing from quick exit so a shaking hand can't hit the wrong one. |
| On Today, a missed day is an empty outline, which looks like a new moon. The new moon is also how "Bahut bura" reads in the scale. | 🔴 Critical | Show a missed day as a small dash or dotted ring at a different size, never as a moon. Missed days must never look like a bad mood (UX.md: no guilt mechanics). |
| The moon-phase mood scale is novel, but its meaning isn't self-evident (is full good, or just "more"?) | 🟡 Moderate | Keep the labels always visible (done) and add the scale's ends in words on first use. Test with 5 people before locking. The fallback is five filled dots of increasing size. |
| Welcome promises "Someone to talk to, any hour." but Eve is served and can be down | 🟡 Moderate | Make it "Someone to talk to, day or night" and keep the existing "Eve is resting" state. Help numbers stay the 24/7 promise, not Eve. |
| At 400 px, header controls and hero text clip on the right (seen opened from disk in quirks mode) | 🟡 Moderate | Re-check on the published page. If it persists, wrap the header controls under the brand and cap the hero text at 100%. |
| The crisis sheet closes back to chat with a pinned "Madad yahan hai" bar | 🟢 Minor (good) | Keep it. This fixes the v2 "dismissed with no way back" failure. |

### Visual Hierarchy
- **What draws the eye first**: Eve's bloom, then the pink action. That's correct for chat and welcome. On Today the 3D isn't present, so the check-in leads, which is also correct.
- **Reading flow**: top-left title, then content, then one pink action at the bottom. It's consistent across screens.
- **Emphasis**: right things emphasised. The lime "protection on" states read as calm confirmation, not alarm. Unbounded display is used only for screen titles, which keeps it in check.

### Consistency
| Element | Issue | Recommendation |
|---|---|---|
| Typography | Phone UI uses 13 px in about 15 places (meta lines, chips, tab labels) | Minimum 14 sp for anything a user needs to read, 15 to 16 sp for Roman Urdu body text. Keep 12 to 13 sp only for timestamps. Atkinson helps, but the audience includes low-literacy and low-vision users on cheap screens. |
| Colour | The role system holds on all seven screens (violet = Eve, pink = one action, lime = protected, navy/paper = help) | Encode the roles as named tokens in Flutter (`evePresence`, `primaryAction`, `protectedState`, `helpSurface`) so they can't drift. |
| Eve presence | Header Eve, hero Eve and breath object all reuse the same orb shading | The breathing object should look different from Eve (Eve is a companion; breath is a tool). Use the Blender `breath.glb` petals/rings, not another sphere. |
| Shape | Radii are consistent: pills for actions, ~20 px cards | No change. |

### Accessibility
- **Color contrast**: passes. Dark ink #F4EFF9 on #13131E ≈ 17:1. Secondary #A497B8 ≈ 7:1. Pink action text #16061C on #F23598 ≈ 6:1. The crisis sheet's navy on paper is 14.2:1. Light mode's #5A5878 on #F1EDF6 ≈ 6:1.
- **Touch targets**: fail in places (36 to 40 px, see Usability).
- **Text readability**: mostly good. Nastaliq at line height 2.1 renders well; raise small UI text as above. Reduced motion has a real preview toggle, which is good.

### What Works Well
- One colour per role makes the legacy palette feel deliberate instead of loud. That's a real upgrade on the legacy tile dashboard.
- Help is "the one bright page". It's unmistakable on a dark app without using red or alarm styling.
- Honest copy throughout: replies come from the server, chats stay on this phone, and "a pattern, not a diagnosis".
- Eve's states (idle / listening / thinking) drive the 3D clip and the halo together, so motion carries meaning.
- The breathing screen keeps every cue on one 16 s clock.

### Priority Recommendations
1. **Replace the orb with the real Blender bloom everywhere, including the fallbacks.** Uniqueness depends on Eve's form. The CSS fallback should be the rendered poster image, not a radial gradient. Until the render lands, show a still of the bloom, never a glossy sphere.
2. **Make Get help, Call and Copy 48 dp or larger, and space Get help apart from quick exit.** These are the controls that matter most to someone in crisis.
3. **Make a missed day look nothing like a mood, and raise UI text to at least 14 sp.** Missed days must not read as "Bahut bura", and small text fails the people most likely to need the app.
