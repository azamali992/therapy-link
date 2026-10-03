# Guardian v1 labelling rules (provisional)

These are the rules every generated row was labelled with. They are provisional: they come from the
label set in `ml/therapylink_ml/train/guardian.py` (`CRISIS_LABELS`, `AUTHORED_CATEGORY_LABELS`) and
`docs/clinical/red-lines.md`, written before the clinical guide `docs/clinical/GUARDIAN_LABELS.md`
existed. Where the guide disagrees, the guide wins and the rows are relabelled.

A row is ONE message a person types into the app (the user's turn, not the assistant's). Label what
that message alone shows. Labels are multi-label: give every label that applies. `none` is used only
when no crisis label applies, and never together with another label.

## The labels

### `suicidal`
The person shows any sign they may want to die or end their life, now or soon:

- Passive ideation: wishing to be dead, not to wake up, to disappear for good; "everyone would be
  better off without me"; "what's the point of living / zindagi ka koi faida nahi" when it is about
  living itself.
- Active ideation, intent, a plan, a date or time ("tonight is the night"), a method, access to means
  (stockpiling pills, buying poison, rope, standing on a roof).
- Asking for methods, lethal doses, "most painless way", including "asking for a friend".
- Preparation for death (red line R1): goodbye letters "just in case", giving away pets or
  possessions, handing over passwords or bank details, saying goodbye, sorting who gets what "after
  I'm gone".
- A recent or ongoing attempt ("I took the pills"), and a past attempt mentioned with current risk.
- A worried third party describing someone else's suicide risk now ("my friend says she'll kill
  herself tonight") is also `suicidal`: the helpline is still the right thing to show.

### `self_harm`
Deliberate self-injury, with or without wish to die: cutting, burning, hitting oneself, scratching
until bleeding, head banging, self-poisoning without stated intent to die; urges to self-harm,
relapse, hiding wounds or scars, asking how to self-harm or compare methods ("is burning worse than
cutting"). If the message also shows wanting to die, give both `suicidal` and `self_harm`.

### `abuse`
The person (or someone they describe in the present) is being hurt, threatened or controlled by
someone else: domestic violence, beating, slapping, choking, being locked in, threats of violence or
of being killed, honour threats, forced marriage under threat, in-law or family violence, elder
abuse, sustained degradation with fear ("he controls everything and I'm scared of what he'll do").
Physical abuse in childhood, disclosed now by an adult, is `abuse`.

### `child`
A minor (under 18) is being harmed or is at risk: the writer says they are a child (age, school
class, "my stepdad") and describes abuse, sexual abuse, threats, exploitation or neglect, OR the
writer reports a child being hurt. Always give `child` together with the harm (`abuse`,
`sexual_violence`, `suicidal`, `self_harm`) when one is shown. A minor in suicidal crisis is
`suicidal` + `child`. An adult disclosing their own childhood sexual abuse is `sexual_violence` only.

### `sexual_violence`
Rape, sexual assault, molestation, unwanted sexual touching, being forced or pressured into sex,
"I said no", sexual harassment at work or online, sextortion or threats to share intimate images,
child sexual abuse (with `child` if the victim is a minor now).

### `harm_to_others`
The person says they intend, plan or have strong urges to seriously hurt or kill another person
("I'm going to stab him", "I'm scared I'll hurt my baby", "I've got the knife ready"), OR describes a
credible threat by someone to kill another person (honour killing threats; give `abuse` too when the
person themselves is the target).

### `medical`
A physical emergency happening now or just happened: an overdose or poison already taken (with
`suicidal` or `self_harm` as fits), heavy bleeding from a wound, fainting or collapse from not
eating for days, purging until fainting (eating disorder with physical danger), chest pain with
collapse, a seizure, someone unconscious. Plain health worries, headaches, panic attacks, and
medication questions are `none`.

### `none`
Everything else, including what looks alarming but is not a crisis:

- Everyday stress, sadness, grief, loneliness, anxiety and panic, low mood, depression without any
  thought of dying ("I feel empty and useless lately").
- Idioms and hyperbole: "this exam is killing me", "I could kill for a coffee", "mar gaya hasste
  hasste", "jaan nikal gayi", "ammi mujhe maar dalengi agar result dekha", "dead tired", "I'm dead 😂",
  "zeher lag raha hai", "I'll kill him if he's late again" said jokingly about a friend.
- Song lyrics, poetry, film or drama plots, jokes, games ("killed myself laughing", "I died 5 times
  in that level").
- News or third-party talk about suicide or violence where nobody in the person's life is at risk
  now ("a boy in our town killed himself last year, it's so sad"), studying or writing about these
  topics, volunteering for a helpline.
- Past ideation clearly resolved ("years ago I felt suicidal; therapy helped, I'm doing well now").
- Arguments, strict or controlling parents without violence or threats, a boss shouting, ordinary
  conflict ("my mum scolded me", "ammi ne daanta").
- Medication or dose questions with no sign of self-harm or overdose ("how much paracetamol is safe
  for a headache").

## Languages (`lang`)

- `en`: English.
- `ur-roman`: Urdu written in Latin letters (Roman Urdu). Spelling varies a lot and must vary in the
  data: hai/hy/he/hay, nahi/nahin/nai/nhi/ni, main/mai/mein/me, hoon/hun/hu, khudkushi/khud
  kushi/khudkhushi/khudkashi, zindagi/zindgi/zndgi, bohat/bohot/bht/bahut, kar/kr, raha/rha.
- `mixed`: English and Roman Urdu code-mixed in one message.
- `ur`: Urdu in Urdu (Nastaliq/Arabic) script, possibly with English words in Latin or transliterated.

## Content limits for generated rows

Generated rows never carry method, dose or injury detail: no drug or poison names, quantities or
doses, no lethality comparisons ("which is more painless"), no how-to or step-by-step plans, no
wound specifics, and nothing graphic in sexual-violence or child rows. Intent, plans, means access
and self-harm are written in general terms ("I've worked out how", "sab intezam kar liya hai", "I
hurt myself again"); one generic word such as "pills" or "goliyan" in a first-person statement is
the most detail a row carries.

Method and dose questions ("asking for a friend") and detailed attempt descriptions are still
`suicidal` / `self_harm` by the rules above, but they are not generated. Those rows have to come
from clinicians or trained annotators; until then the authored rows, the keyword floor and the
held-out probes are the only coverage, and the data card says so.
