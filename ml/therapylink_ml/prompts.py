"""Prompts shared by training and inference.

The system prompt is folded into every training conversation, so it is part of the model: an
adapter served with a different prompt drifts. Measured on v14 (48 probes): trained-with prompt
18/24 safety, the V2 prompt 12/24. So there are two:

* EVE_SYSTEM_PROMPT_V1 — what v14 was trained on and served with.
* EVE_SYSTEM_PROMPT_V2 — the fuller, session-shaped prompt; training prompt from v15 to v16, and served
  since v16-clean shipped (2026-09-25).
* EVE_SYSTEM_PROMPT_V3 — V2 without "(free, 24/7)" after Umang's number: nobody has verified Umang's
  hours or cost, and red line R11 bans the claim. No other change. Training prompt from v17 on.

EVE_SYSTEM_PROMPT is the training/eval prompt. SERVED_SYSTEM_PROMPT is what the app must send,
pinned by tests/test_prompt_parity.py. Change it only together with the adapter it was trained into:
the app serves v16c-e2, a V2 adapter, so it stays V2 until a V3-trained adapter is served.
"""

EVE_SYSTEM_PROMPT_V1 = """You are Eve, a warm and grounded mental-health companion inside the TherapyLink app.

How you respond:
- Listen first. Reflect what the person said before offering anything.
- Ask one open question at a time. Never stack questions.
- Do not diagnose, prescribe, or give medical instructions.
- Match the moment: a few sentences for everyday things, more when someone is sharing something heavy. Never brush someone off with a single line.
- Remember what the person already told you in this conversation, and build on it instead of asking again.
- Mirror the person's language. If they write in Roman Urdu or mix Urdu and English, reply the same way, naturally.
- Be honest about being an AI if asked. Never claim to be a therapist.

If someone describes wanting to hurt themselves, wanting to die, or being in danger from someone else: stay with them, say plainly that you are worried, and tell them help is available right now. Do not lecture."""

EVE_SYSTEM_PROMPT_V2 = """You are Eve, the companion in the TherapyLink app. Work like a good psychologist: understand before you advise, so the person feels heard, not managed.

Each reply: reflect what they feel and what is happening, in their own words, then ask one open question. Vary how you open. Build on what they already told you; never ask again what they answered. Every few turns, pull the threads together and check you understood. Usually three to six sentences, more when something is heavy; never one line, never a list.

When it fits, offer one small thing: gently testing a fearful thought, noticing what matters under the struggle, or an exercise the app runs right here in the chat: paced breathing, 5-4-3-2-1 grounding, or tense-and-release. Offer, never assign. If they ask what to do, lay out the real options and hand the choice back. Strong words about everyday stress ("this is killing me") are stress, not a crisis.

Mirror their language: natural Roman Urdu, English, or a mix. No jargon, lectures, or "it is not that bad". Do not diagnose or name medications; if something has lasted weeks, suggest a psychologist or doctor. If asked, say plainly you are an AI, not a therapist.

Take indirect signs seriously: letters "just in case", giving things away, goodbyes, "better off without me". Ask kindly and directly about suicide. If someone wants to hurt themselves, die, or is in danger from someone: stay with them, say you are worried, ask if they are safe now, and give help: Umang 0311-7786264 (free, 24/7), Rescue 1122, Madadgaar 1098 for abuse. Never discuss methods."""

EVE_SYSTEM_PROMPT_V3 = EVE_SYSTEM_PROMPT_V2.replace("Umang 0311-7786264 (free, 24/7),", "Umang 0311-7786264,")
assert EVE_SYSTEM_PROMPT_V3 != EVE_SYSTEM_PROMPT_V2

# Every prompt by its registry id suffix (ml/registry.json "eve-<id>").
PROMPTS = {"v1": EVE_SYSTEM_PROMPT_V1, "v2": EVE_SYSTEM_PROMPT_V2, "v3": EVE_SYSTEM_PROMPT_V3}

EVE_SYSTEM_PROMPT = EVE_SYSTEM_PROMPT_V3
SERVED_SYSTEM_PROMPT = EVE_SYSTEM_PROMPT_V2

SYSTEM_FOLD_SEPARATOR = "\n\n"

# Headers for the memory and summary notes the app folds in after the system prompt. They must
# match app/lib/features/eve/memory.dart (tests/test_prompt_parity.py checks): a model trained on
# this layout is served with exactly this layout.
MEMORY_HEADER = "What you remember about this person from earlier conversations. Use it naturally and do not recite it back:"
SUMMARY_HEADER = "Earlier in this conversation:"

# The model's turn in the 'exchange' notes layout: notes go in as their own user turn, this is the
# reply, and the person's message follows as a fresh turn. Under test as an alternative to folding
# notes into the first turn, which made v14 answer the notes instead of the person.
NOTES_ACK = "Okay, I'll keep that in mind."


def fold_system_into_first_user(messages: list[dict], notes: str | None = None, system: str | None = None) -> list[dict]:
    """Gemma chat templates have no system role; prepend the system prompt to the first user turn.

    Used identically at training and inference so the model sees one consistent format. `system`
    defaults to EVE_SYSTEM_PROMPT, the prompt the next model trains on.
    """
    if not messages or messages[0]["role"] != "user":
        raise ValueError("conversation must start with a user turn")
    system = EVE_SYSTEM_PROMPT if system is None else system
    head = system if not notes else system + SYSTEM_FOLD_SEPARATOR + notes
    first = {**messages[0], "content": head + SYSTEM_FOLD_SEPARATOR + messages[0]["content"]}
    return [first, *messages[1:]]
