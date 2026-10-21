# 03. Roman Urdu: sources, transliteration, spelling variation, code-mixing

Status: research note for `urduguard` data pipeline. Date: 2026-10-21.
Scope: how to make Roman Urdu training rows from Urdu-script rows, with provenance.

## 1. Parallel and lexicon resources

| Resource | What it holds | Urdu numbers | Licence | Link |
| --- | --- | --- | --- | --- |
| Dakshina v1.0 (Roark et al., LREC 2020) | Native-script Wikipedia text, romanisation lexicon with attestation counts, full-sentence romanisations, 12 languages | Lexicon: 25,000 native word types train, 2,500 dev, 2,500 test. Sentences: 10,000 strings sampled; Urdu has fewer because several hundred non-Urdu Perso-Arabic strings were removed. Round-trip CER 3.5 to 8.5% across languages. | CC BY-SA 4.0 | [repo](https://github.com/google-research-datasets/dakshina), [paper](https://aclanthology.org/2020.lrec-1.294/), [tar](https://storage.googleapis.com/gresearch/dakshina/dakshina_dataset_v1.0.tar) |
| Roman-Urdu-Parl (Alam and Hussain, ACM TALLIP 2021) | Roman Urdu / Urdu script sentence pairs | 6.37M pairs (6,365,808 rows per the HF mirror) | Not found on the paper page. Check the authors' download page before use. | [paper](https://dl.acm.org/doi/10.1145/3464424), [HF mirror](https://huggingface.co/datasets/Mavkif/Roman-Urdu-Parl-split) |
| Aksharantar (AI4Bharat, EMNLP Findings 2023) | Word-level transliteration pairs, 21 languages incl. Urdu | 26M pairs total; per-language Urdu count not checked | See repo | [paper](https://aclanthology.org/2023.findings-emnlp.4/) |
| RU-EN-Emotion (Ilyas et al., ACM TALLIP 2023) | Code-mixed Roman Urdu / English sentences from YouTube, Twitter, a retailer site | 20,000 code-mixed sentences out of 400,000 scraped | Not found | [paper](https://dl.acm.org/doi/10.1145/3552515) |
| Ameer et al. 2022 (WASSA 2023 shared task data) | Code-mixed Roman Urdu / English SMS, 12 emotion labels | 11,914 messages | Not found | [WASSA system paper](https://aclanthology.org/2023.wassa-1.58.pdf) |
| Hope speech Roman Urdu (arXiv 2506.21583) | Code-mixed Roman Urdu posts | 4,953 posts, 108,249 words | Not found | [arXiv](https://arxiv.org/pdf/2506.21583) |

Notes.
- Dakshina is Wikipedia text. Register is formal. Its romanisations are annotator-made, not chat text.
- Roman-Urdu-Parl is the only large sentence-level pair set. Its Roman side was partly machine-made; treat it as noisy.
- Dakshina lexicon counts per romanisation are the only attested frequency source found. The tar was not downloaded for this note. Per-word counts below are therefore not quoted.

## 2. Open transliterators

| Tool | Direction | Urdu | Method | Licence | Status | Link |
| --- | --- | --- | --- | --- | --- | --- |
| AI4Bharat IndicXlit | Roman to native and native to Roman | Yes (`urd`), one of 21 languages | Transformer, ~11M params, trained on Aksharantar | See repo | Active | [repo](https://github.com/AI4Bharat/IndicXlit) |
| libindic indic-trans | Any pair among 16 languages incl. `urd` and `eng` | Yes | Rule-based or ML (structured perceptron), needs Cython and SciPy | AGPL-3.0 | Last commit Oct 2022 | [repo](https://github.com/libindic/indic-trans) |
| urduhack | None. Normalisation, tokenisation, POS, NER. | n/a | n/a | MIT | Last commit Apr 2023, Python 3.6 to 3.7 | [repo](https://github.com/urduhack/urduhack) |
| Transformer on Roman-Urdu-Parl (arXiv 2503.21530) | Both | Yes | Seq2seq transformer | Not found | Paper only | [arXiv](https://arxiv.org/html/2503.21530v1) |
| `data/translit.py` (this project, `rule-v0`) | Urdu script to Roman | Yes | Char and digraph rules, 70-word lexicon, variant sampler | Project licence | Prototype | this repo |

Why not use IndicXlit or indic-trans for the core:
- IndicXlit output spelling is learned from Aksharantar, which mixes Indian Urdu romanisation habits. Not checked against Pakistani chat spelling.
- indic-trans is AGPL-3.0. That licence would attach to anything that links it.
- Both are extra dependencies with native code. The rule file is 170 lines of stdlib.
- Rules are inspectable. A native speaker can point at the rule that produced a bad token.

## 3. LLM transliteration

| Item | Fact |
| --- | --- |
| Quality | Good on frequent words. Spelling drifts between calls. Not reproducible without logging every output. |
| Cost | Pay per token, per row, per rerun. A rule file costs nothing to rerun. |
| Provenance | Output cannot be traced to a rule. A correction fixes one row, not a class of rows. |
| Licence | Terms of use differ per vendor. Some restrict using outputs to train competing models. |
| Role here | Not used for the core. Allowed later for a small held-out comparison set, tagged `"translit": "llm-<model>"`. |

## 4. Spelling variation

Attested statements from the literature:
- Dakshina: "most [words] received a romanization from more than one annotator, though the annotated romanizations may agree"; counts per pair are stored. [README](https://github.com/google-research-datasets/dakshina#lexicons-lexicons)
- Review by Khan et al. (MDPI Computers 2022): for یہ the top five Roman variants are "yeah, yeh, yeah, ye, yah"; خوشی appears as kushi, kushai, khooshi, khoshi, khshi; "bakwaas" as bakwas, bakwass, bkwass (citing Mehmood et al.). [paper](https://www.mdpi.com/2073-431X/11/1/3)
- Sharf and Mansoor rules (cited in the same review): 100 phonetic rules; kesi, kesy, kesyy, kesiy, kesii all map to kese.
- Sharf and Rahman 2017, "Lexical normalization of Roman Urdu text", IJCSNS 17(12):213-221. Corpus of about 280,000 Roman Urdu sentences from Twitter, Reddit, news and poetry sites. [citing review](https://www.researchgate.net/publication/366240479_Lexical_Normalization_of_Roman_Urdu)
- Mehmood et al., TERUN (transliteration-based encoding for Roman Hindi/Urdu normalisation), unsupervised. [S2](https://www.semanticscholar.org/paper/adcf51472c40a4e13e6cc7a23431463419b97f4a)
- Numeric frequencies per variant: not found in any paper read for this note. Dakshina per-pair counts exist but were not extracted.

Variant table used by `respell()`. Source column: A = attested in a cited paper above; O = own observation of Pakistani chat text, not measured.

| Canonical | Variants | Source |
| --- | --- | --- |
| mujhe | mujhay, mjhe, muje, mujy | O |
| nahi | nhi, nahin, nai, ni, nae | O |
| kya | kia, kiya | O |
| hai | hy, h, he, hain | O |
| kar | kr | O |
| main | mein, mai, mn, me | O |
| aur | or, r, aor | O |
| tum | tm | O |
| acha | accha, achha | O |
| bohat | bohot, bahut, bht, buhat | O |
| kyun | kyu, q, kiun, kion | O |
| phir | fir, phr | O |
| mera | mra, maira | O |
| hoon | hun, hu, hon | O |
| zindagi | zindgi, zndgi | O |
| maar | mar | O |
| jaan | jan | O |
| dost | dst, dosst | O |
| yaar | yar, yr | O |
| log | loag, lg | O |
| bhai | bhae, bhaii, bhi | O. "bhi" collides with بھی (also). Kept because it is seen in chat, flagged for review. |
| sab | sb | O |
| kuch | kch, kuchh | O |
| ab | abb | O |
| ghar | ghr | O |
| paise | pesay, paisay, pese | O |
| larki | larkii, ladki, lrki | O |
| shadi | shaadi, shadii | O |
| yeh | ye, yah, yeah | A (MDPI review) |
| khushi | kushi, khooshi, khoshi, khshi | A (MDPI review) |
| bakwaas | bakwas, bakwass, bkwas | A (MDPI review, Mehmood et al.) |
| kaise | kese, kesi, kesy, kaisay | A (Sharf and Mansoor rules via MDPI review) |
| woh | wo, vo | O |

Patterns behind the O rows: vowel dropping (nhi, bht, sb), y for i or ee (hy, mujy), h for hai, q for kyun, single for double consonant (acha), r/d swap on retroflex ڑ (larki/ladki). These match the vowel-drop and ending-letter rules Sharf and Mansoor describe. Frequencies are unknown. Native-speaker review should rank each set before training.

## 5. Code-mixing with English

| Study | Sample | Code-mixing figure | Link |
| --- | --- | --- | --- |
| Ilyas et al. 2023 | 400,000 comments from YouTube (350,000), Twitter (40,000), Whatmobile.pk (10,000) | Code-mixed sentences kept after semi-automatic filtering: YouTube 7,936 (2.3%), Twitter 10,000 (25%), retailer 2,037 (20%). Filter was a screen, not a count, so these are lower bounds. | [paper](https://dl.acm.org/doi/10.1145/3552515) |
| Ilyas et al. 2023 on Ameer et al. 2022 | 11,914 SMS messages | "more than 37% of the messages ... are monolingual" | same |
| Token-level English share inside a Roman Urdu sentence | n/a | Not found. No paper read for this note reports English token rate per sentence. | |

Decision for the pipeline: `codemix_rate` default 0.15 of dictionary words. The number is a guess. It is stored in provenance so it can be swept later.

## 6. Pipeline

```
Urdu-script row
  -> transliterate()  rule-v0: tashkeel strip, lexicon, char rules, aspirates, ں, ہ, ی/ے, و, ا
  -> respell(seed, rate=0.3)   swap words for attested or observed variants
  -> codemix(seed+1, rate=0.15) swap dictionary content words for English
  -> provenance tag
```

Provenance per item:

```json
{"urdu_from": "transliterated", "translit": "rule-v0", "variant_seed": 7,
 "respell_rate": 0.3, "codemix_rate": 0.15, "source_text": "<urdu script>"}
```

`respell_rate` is included on top of the required fields so a sample is reproducible from the tag alone.

## 7. Examples from `translit.py` (rule-v0)

Sentences written for this note. Not from any dataset.

| # | Input | Output | Verdict |
| --- | --- | --- | --- |
| 1 | مجھے نہیں پتہ کیا کروں | mujhe nahi pata kya karoon | OK (all lexicon hits) |
| 2 | تم بہت اچھے ہو یار | tum bohat ache ho yaar | OK |
| 3 | کل اسے سبق سکھاؤں گا | kal usay sabq sakhaaon ga | OK-ish. "sabq" wants "sabaq": the short-vowel guess only fires after the first consonant. |
| 4 | میں آج گھر نہیں جاؤں گا۔ | main aaj ghar nahi jaun ga. | OK. ۔ mapped to "." |
| 5 | یہ لوگ ہمیشہ جھوٹ بولتے ہیں | yeh log hamesha jhot bolte hain | OK. "jhot" is readable, "jhoot" is more common. Medial و is always "o". |
| 6 | تمہارا فون کہاں ہے؟ | tumhara fon kahan hai? | OK. "fon" for a loanword; chat writes "phone". Loanword list needed. |
| 7 | مجھے اب زندگی سے کوئی امید نہیں | mujhe ab zindagi se koi amid nahi | BAD. "amid" should be "umeed": short vowel u and long ee are both unmarked in script. zindagi only right because it is in the lexicon. |
| 8 | وہ لڑکی کل شادی کر رہی ہے | woh larki kal shaadi kar rahi hai | OK |
| 9 | معلوم نہیں وقت کیسے گزر گیا | mlom nahi waqt kaise gazr gia | BAD. ع dropped leaves "mlom" (maloom). "gazr" wants "guzar" (short vowels). "gia" wants "gaya": medial ی is always "i". |
| 10 | وہ گئی تھی، میں آئے گا | woh gi thi, main aaie ga | BAD. Hamza ئ maps to "i", so گئی becomes "gi" (gayi) and آئے becomes "aaie" (aaye). Verb forms with ئ need a rule or lexicon entries. Also grammar is wrong on purpose; translit does not care. |

Extra probes: کھانا -> khaana (aspirate OK). وقت -> waqt (initial و plus guessed short vowel). پیار -> piaar (medial ی before ا should be "y"). Izafat (e.g. حکومتِ پاکستان) is stripped with tashkeel and the "-e-" is lost; not handled in rule-v0.

Known gaps, in order of damage: short vowels (every unlexiconed word), hamza on verbs, medial ی before ا, ع, izafat, nasal ں before consonant (کرتے ہیں fine, but سنبھال -> sanbhaal), English loanwords.

## Decision

1. Core transliteration is `rule-v0` in `data/translit.py`. Stdlib, inspectable, deterministic. No AGPL or model dependency.
2. The function-word lexicon grows first. It is the cheapest fix for the short-vowel problem. Next additions: the 200 most frequent Urdu tokens in the source rows, romanised by hand.
3. Spelling variation comes from the VARIANTS table. Rows marked O get native-speaker review before the next release. Dakshina `ur` lexicon counts will be extracted to replace guesses with attested counts (CC BY-SA 4.0, attribution needed).
4. Code-mixing is word-level replacement from a 29-entry dictionary at rate 0.15. No sentence-level switching. The rate is unsupported by literature and will be swept.
5. Every synthetic row carries the provenance tag above. A correction form for native speakers maps `source_text` plus `variant_seed` back to the exact rule run.
6. IndicXlit is kept as an optional comparison path, not a dependency. LLM transliteration is not used for the core.
7. Roman-Urdu-Parl is not pulled in until its licence is confirmed.
