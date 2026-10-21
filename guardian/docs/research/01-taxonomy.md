# 01. Taxonomy: Aegis 2.0, the five baselines, and the Guardian v2 label set

Scope: label sets only. Data volumes, rendering and training recipes live in later files.
Every number below is either quoted from the linked source or counted from the public parquet files (marked "counted").

## 1. Aegis 2.0 (NAACL 2025)

- Paper: Ghosh et al., "AEGIS2.0: A Diverse AI Safety Dataset and Risks Taxonomy for Alignment of LLM Guardrails", NAACL 2025. https://aclanthology.org/2025.naacl-long.306/ (arXiv: https://arxiv.org/abs/2501.09004)
- Dataset card: https://huggingface.co/datasets/nvidia/Aegis-AI-Content-Safety-Dataset-2.0 (now titled "Nemotron Content Safety Dataset V2"). 33,416 rows: train 30,007, validation 1,445, test 1,964. License CC-BY-4.0. "English (may contain small samples in other languages)".
- Columns: `prompt`, `response`, `prompt_label` (safe/unsafe), `response_label`, `violated_categories` (comma-separated), `prompt_label_source`, `response_label_source`.
- Taxonomy (paper, Table 2): 12 core categories plus `Other`, and 9 fine-grained categories. Labels are standardized to "Safe, Needs Caution or one of the risk categories". Multi-label: a row can carry several categories.

### 1.1 Category strings and counts (counted from the parquet files, one count per category mention)

| `violated_categories` string | Tier | Train | Val | Test |
| --- | --- | --- | --- | --- |
| Criminal Planning/Confessions | core | 7,734 | 400 | 509 |
| Needs Caution | special | 3,804 | 165 | 243 |
| Violence | core | 3,047 | 130 | 182 |
| Hate/Identity Hate | core | 2,954 | 157 | 183 |
| Harassment | core | 2,758 | 134 | 152 |
| Profanity | core | 2,072 | 118 | 115 |
| Sexual | core | 1,780 | 59 | 102 |
| Controlled/Regulated Substances | core | 1,671 | 94 | 118 |
| PII/Privacy | core | 1,633 | 66 | 102 |
| Guns and Illegal Weapons | core | 1,142 | 47 | 62 |
| Suicide and Self Harm | core | 891 | 43 | 52 |
| Unauthorized Advice | fine | 549 | 26 | 28 |
| Political/Misinformation/Conspiracy | fine | 468 | 21 | 23 |
| Fraud/Deception | fine | 427 | 25 | 14 |
| Other | core | 318 | 7 | 14 |
| Sexual (minor) | core | 281 | 15 | 12 |
| Immoral/Unethical | fine | 265 | 14 | 15 |
| Illegal Activity | fine | 216 | 13 | 12 |
| Threat | core | 205 | 10 | 16 |
| Malware | fine | 167 | 5 | 8 |
| Copyright/Trademark/Plagiarism | fine | 94 | 4 | 4 |
| High Risk Gov Decision Making | fine | 90 | 5 | 3 |
| Manipulation | fine | 7 | 0 | 2 |
| (empty = safe) | - | 9,747 | not counted | 719 |

Split labels (counted): train `prompt_label` unsafe 17,711 / safe 12,296; test unsafe 1,059 / safe 905. Test has 1,112 prompt-only rows (null response).
Paper names differ slightly from the dataset strings ("Guns/Illegal Weapons", "Controlled/Regulated substances"); the table above uses the dataset strings.

### 1.2 Needs Caution handling

- Definition (paper, section 3): annotators label "ambiguous instances as Needs Caution, in order to prevent the unnecessary classification of uncertain content as unsafe". A system can be "defensive" (block) or "permissive" depending on how the label is read. https://arxiv.org/abs/2501.09004
- Annotator rule (paper, Table 6): "If you are not sure whether it is toxic or not, label it as 'Needs Caution'."
- Paper experiments (Appendix A.4.2): "we map Needs Caution to Safe, thus building a permissive model variant. Results for the defensive model variant that maps Needs Caution to Unsafe have been left for future work."
- Released binary labels (counted): every row whose only category is `Needs Caution` has `prompt_label = safe` (train 2,148 of 2,148; test 156 of 156). Rows that carry `Needs Caution` next to a risk category can be unsafe (test: 69 of 243).

## 2. Baseline taxonomies mapped onto Aegis 2.0

### 2.1 Llama Guard 3 (8B and 1B)

- 8B card: https://huggingface.co/meta-llama/Llama-Guard-3-8B. 14 categories "based on the MLCommons taxonomy of 13 hazards, as well as an additional category for Code Interpreter Abuse". Languages: English, French, German, Hindi, Italian, Portuguese, Spanish, Thai.
- 1B card: https://huggingface.co/meta-llama/Llama-Guard-3-1B. 13 categories (S1 to S13, no S14). Same languages.
- MLCommons v0.5 taxonomy announcement: https://mlcommons.org/2024/04/mlc-aisafety-v0-5-poc/

| LG3 code | LG3 name | Closest Aegis 2.0 category |
| --- | --- | --- |
| S1 | Violent Crimes | Violence; Threat (hate-motivated violent crimes also touch Hate/Identity Hate) |
| S2 | Non-Violent Crimes | Criminal Planning/Confessions; Fraud/Deception; Controlled/Regulated Substances; Guns and Illegal Weapons; Malware; Illegal Activity. Card text puts "threats, intimidation" here too |
| S3 | Sex-Related Crimes | Sexual; Harassment ("sexual harassment") |
| S4 | Child Sexual Exploitation | Sexual (minor) |
| S5 | Defamation | Harassment (partial); no exact Aegis match |
| S6 | Specialized Advice | Unauthorized Advice |
| S7 | Privacy | PII/Privacy |
| S8 | Intellectual Property | Copyright/Trademark/Plagiarism |
| S9 | Indiscriminate Weapons | Guns and Illegal Weapons (partial) |
| S10 | Hate | Hate/Identity Hate (card lists "religious affiliation, caste" among protected traits) |
| S11 | Suicide & Self-Harm | Suicide and Self Harm |
| S12 | Sexual Content | Sexual |
| S13 | Elections | Political/Misinformation/Conspiracy |
| S14 | Code Interpreter Abuse (8B only) | Malware (partial) |
| none | - | Profanity, Harassment, Needs Caution, Other have no LG3 code |

### 2.2 Qwen3Guard-Gen (4B and 0.6B)

- Cards: https://huggingface.co/Qwen/Qwen3Guard-Gen-4B and https://huggingface.co/Qwen/Qwen3Guard-Gen-0.6B. Report: https://arxiv.org/abs/2510.14276. 119 languages. Output format `Safety: Safe|Unsafe|Controversial`, then `Categories: ...`, and for responses `Refusal: Yes|No`.
- Severity levels (card and report, section 2): Unsafe = "harmful across most scenarios"; Controversial = "harmfulness may be context-dependent or subject to disagreement across different applications"; Safe = "safe across most scenarios".
- How Controversial labels were built (report, section 3.3): two models trained with "Loose" and "Strict" reweighting annotate held-out halves; "conflicting predictions are marked as Controversial". The report also notes such instances "are limited in number" because of their ambiguity.

| Qwen3Guard category | Closest Aegis 2.0 category |
| --- | --- |
| Violent | Violence; Threat; Guns and Illegal Weapons (card: "manufacture, acquisition, or use of weapons"; also "depictions of violence") |
| Non-violent Illegal Acts | Criminal Planning/Confessions; Controlled/Regulated Substances; Malware; Illegal Activity |
| Sexual Content or Sexual Acts | Sexual; Sexual (minor) |
| Personally Identifiable Information | PII/Privacy |
| Suicide & Self-Harm | Suicide and Self Harm |
| Unethical Acts | Hate/Identity Hate; Harassment; Profanity; Threat; Immoral/Unethical; Fraud/Deception (card lists "hate speech, offensive language, harassment, insults, threat, defamation, extremism") |
| Politically Sensitive Topics | Political/Misinformation/Conspiracy |
| Copyright Violation | Copyright/Trademark/Plagiarism |
| Jailbreak (input only) | no Aegis category |
| Controversial (level, not category) | Needs Caution |

### 2.3 OpenAI omni-moderation-2024-09-26

- Snapshot page: https://platform.openai.com/docs/models/omni-moderation-latest (alias `omni-moderation-latest` resolves to `omni-moderation-2024-09-26`). Guide: https://platform.openai.com/docs/guides/moderation. 13 categories, multi-label, with `category_scores` in [0, 1] and a top-level `flagged`.
- The Aegis 2.0 paper's own map (Appendix A.9, Tables 10 and 11) only abbreviates the eight OpenAI Moderation Dataset labels (S, H, V, HR, SH, S3, H2, V2); it gives no formal cross-walk, so the table below is this project's.

| OpenAI category | Doc definition (short) | Closest Aegis 2.0 category |
| --- | --- | --- |
| harassment | "harassing language towards any target"; hate at non-protected groups counts here | Harassment; Profanity (targeted) |
| harassment/threatening | harassment "that also includes violence or serious harm" | Threat; Harassment |
| hate | hate "based on race, gender, ethnicity, religion, nationality, sexual orientation, disability status, or caste" | Hate/Identity Hate |
| hate/threatening | hate "that also includes violence or serious harm towards the targeted group" | Hate/Identity Hate; Threat; Violence |
| illicit | "advice or instruction on how to commit illicit acts" | Criminal Planning/Confessions; Fraud/Deception; Controlled/Regulated Substances; Malware |
| illicit/violent | illicit plus "references to violence or procuring a weapon" | Criminal Planning/Confessions; Guns and Illegal Weapons; Violence |
| self-harm | "promotes, encourages, or depicts acts of self-harm" | Suicide and Self Harm |
| self-harm/intent | speaker "intend[s] to engage in acts of self-harm" | Suicide and Self Harm |
| self-harm/instructions | "instructions or advice on how to commit such acts" | Suicide and Self Harm |
| sexual | "meant to arouse sexual excitement" or "promotes sexual services" | Sexual |
| sexual/minors | sexual content with "an individual who is under 18" | Sexual (minor) |
| violence | "depicts death, violence, or physical injury" | Violence |
| violence/graphic | the same "in graphic detail" | Violence |

### 2.4 WildGuard / WildGuardMix

- Card: https://huggingface.co/datasets/allenai/wildguardmix (gated). Paper: https://arxiv.org/abs/2406.18495. WildGuardTrain 86,759 rows (48,783 prompt-only); WildGuardTest 1,725 rows with three-annotator labels.
- Labels are binary (`prompt_harm_label`, `response_harm_label`, `response_refusal_label`) plus one `subcategory` string per prompt. 13 risk subcategories (paper, Appendix A.6, Table 10). The exact `subcategory` strings must be read from the gated files; names below are the paper's.

| WildGuard category | Subcategory | Closest Aegis 2.0 category |
| --- | --- | --- |
| Privacy | Sensitive Information (Organization) | PII/Privacy |
| Privacy | Private Information (Individual) | PII/Privacy |
| Privacy | Copyright Violations | Copyright/Trademark/Plagiarism |
| Misinformation | False or Misleading Information | Political/Misinformation/Conspiracy |
| Misinformation | Material Harm by Misinformation | Political/Misinformation/Conspiracy; Unauthorized Advice |
| Harmful Language | Social Stereotypes & Discrimination | Hate/Identity Hate |
| Harmful Language | Violence and Physical Harm | Violence; Threat |
| Harmful Language | Toxic Language / Hate Speech | Hate/Identity Hate; Harassment; Profanity |
| Harmful Language | Sexual Content | Sexual |
| Malicious Uses | Cyberattacks | Malware |
| Malicious Uses | Fraud & Assisting Illegal Activities | Fraud/Deception; Criminal Planning/Confessions |
| Malicious Uses | Encouraging Unethical/Unsafe Actions | Immoral/Unethical |
| Malicious Uses | Mental Health & Over-Reliance Crisis | Suicide and Self Harm (partial); Unauthorized Advice |
| Other harms / Benign | - | Other / Safe |

### 2.5 PolyGuard / PolyGuardMix

- Card: https://huggingface.co/datasets/ToxicityPrompts/PolyGuardMix. Paper: https://arxiv.org/abs/2504.04377. 1,910,372 rows. The card's language table lists 16 codes (ar, cs, de, en, es, hi, it, ja, ko, nl, pl, pt, ru, sv, zh, th) under a "17 languages" heading. No Urdu.
- Fields: `prompt_harm_label`, `response_refusal_label`, `response_harm_label`, `prompt_safety_categories`, `response_safety_categories`.
- Categories: the paper states it follows "the same safety taxonomy as Llama-Guard-3" and the MLCommons taxonomy; its prompt lists S1 to S14 with shortened names (S3 "Sex Crimes", S4 "Child Exploitation", S11 "Self-Harm"). Mapping onto Aegis 2.0 = the Llama Guard 3 table in 2.1.

## 3. Guardian v2 label set

`taxonomy_version = "urduguard-2.0"`

| Label string | Kind | Covers | Gate |
| --- | --- | --- | --- |
| `benign` | label | no harm label fires | pass |
| `violence_threats` | protective | threats, incitement or endorsement of physical violence against a person or group | block |
| `harassment` | protective | insults, abuse, bullying, intimidation, targeted profanity aimed at a person | block |
| `hate_group` | protective | demeaning or dehumanizing content aimed at a group by ethnicity, nationality, caste, gender, sexual orientation, disability or similar. Religion is excluded by data filtering, so the label never carries religious hate | block |
| `self_harm` | descriptive | suicide, self-injury, disordered eating: intent, encouragement, instructions or depiction | report only |
| `sexual` | descriptive | sexual content, including content involving minors | report only |
| `needs_caution` | boolean flag | ambiguous or context-dependent content (Aegis "Needs Caution", Qwen3Guard "Controversial") | pass at the default gate; a "defensive" run treats it as block |

- Output: multi-label over the five harm labels, plus the flag. `benign` is implied when no harm label fires.
- No religious-hate label. Religious content is removed from every training and evaluation file by the same script before mapping.
- No jailbreak label. Jailbreak rows are dropped, not relabelled.
- Why a flag and not a label: a seventh class would have no counterpart in Llama Guard 3 or omni-moderation, so it cannot be scored against them. Aegis resolves "Needs Caution" to safe in its released binary labels (section 1.2), and Qwen3Guard treats Controversial as a severity level that a policy may read as safe or unsafe. A flag reproduces both behaviours: the default (permissive) gate maps it to pass, and the defensive variant maps it to block. Dropping it would throw away 3,804 train and 243 test mentions and the chance to report the permissive/defensive pair.
- Why not more labels: criminal planning, substances, weapons, PII, fraud, malware, advice and politics are outside the project's stated scope. Rows carrying only those categories are kept for evaluation (EVAL_ONLY) and never trained as `benign`.

## 4. Mapping rules per source

Common rules:
1. A row that carries any in-scope category gets every in-scope label it matches.
2. A row whose categories are all out of scope is EVAL_ONLY: kept in the Aegis test set with its original binary label, excluded from training. It is never written as `benign`.
3. DROP removes the row from training and evaluation files.
4. The religion filter runs before mapping; rows it catches are DROP.
5. `Needs Caution` / Controversial never sets a harm label by itself; it sets the flag.

### 4.1 Aegis 2.0 train (and val/test, same rules)

| Aegis string | Guardian | Note |
| --- | --- | --- |
| Violence | `violence_threats` | |
| Threat | `violence_threats` | |
| Harassment | `harassment` | |
| Hate/Identity Hate | `hate_group` | after religion filter |
| Suicide and Self Harm | `self_harm` | descriptive |
| Sexual | `sexual` | descriptive |
| Sexual (minor) | `sexual` | descriptive |
| Profanity (with Harassment or Threat) | label of the co-category | |
| Profanity (alone) | EVAL_ONLY | 563 train, 33 test rows are Profanity-only (counted) |
| Needs Caution (alone) | `benign` + `needs_caution` | matches the released `prompt_label = safe` |
| Needs Caution (with a category) | mapped category + `needs_caution` | |
| Criminal Planning/Confessions, Controlled/Regulated Substances, PII/Privacy, Guns and Illegal Weapons, Unauthorized Advice, Political/Misinformation/Conspiracy, Fraud/Deception, Immoral/Unethical, Illegal Activity, Malware, Copyright/Trademark/Plagiarism, High Risk Gov Decision Making, Manipulation | EVAL_ONLY | out of scope |
| Other | DROP | free-text category |
| (empty, prompt_label = safe) | `benign` | |

Protective Aegis categories for the paper's gate: Violence, Threat, Harassment, Hate/Identity Hate (religion removed).
Descriptive: Suicide and Self Harm, Sexual, Sexual (minor).
All other categories: out of scope, reported in the "all categories" binary score only.

### 4.2 IndicGuard (l3cube-pune/IndicGuard)

- Card: https://huggingface.co/datasets/l3cube-pune/IndicGuard. ~33,416 rows per language, 10 Indic languages plus English; Urdu (`ur`) included. Follows the Aegis 2.0 taxonomy; `violated_categories` uses the same strings. Translated with Google Translate; `tag` in {generic, Culture_adaptive, Jailbreaking}. Card example of a culture-adaptive unsafe row: "Hate/Identity Hate".

| IndicGuard field/value | Guardian |
| --- | --- |
| `violated_categories` | same table as 4.1 |
| `tag = Jailbreaking` | DROP |
| `tag = Culture_adaptive` | map as 4.1 after the religion filter (card: this tag covers "religion, caste, social identity, and political discourse") |
| `language` not in {Urdu, English} | DROP |
| `prompt = "REDACTED"` | DROP unless reconstructed |

### 4.3 WildGuardMix

| WildGuard value | Guardian |
| --- | --- |
| `prompt_harm_label = unharmful`, `adversarial = False` | `benign` |
| `adversarial = True` | DROP (jailbreak-style prompts) |
| harmful + Violence and Physical Harm | `violence_threats` |
| harmful + Social Stereotypes & Discrimination | `hate_group` (after religion filter) |
| harmful + Toxic Language / Hate Speech | `harassment`; add `hate_group` when the target is a group (judged by the religion/group filter's target field) |
| harmful + Sexual Content | `sexual` |
| harmful + Mental Health & Over-Reliance Crisis | `self_harm` |
| harmful + any other subcategory | DROP (training source only) |
| `prompt_harm_label = None` | DROP |

### 4.4 ToxicChat (lmsys/toxic-chat, config `toxicchat0124`)

- Card: https://huggingface.co/datasets/lmsys/toxic-chat. 10,165 prompts, train and test about 5.08k rows each (card viewer). Fields: `user_input`, `model_output`, `toxicity` (0/1), `jailbreaking` (0/1), `openai_moderation` (per-category scores). 7.33% toxic, 2.01% jailbreaking.

| ToxicChat value | Guardian |
| --- | --- |
| `jailbreaking = 1` | DROP |
| `toxicity = 0` | `benign` |
| `toxicity = 1` | label from the top `openai_moderation` category using table 4.8; if that category is out of scope, DROP |

### 4.5 BeaverTails (PKU-Alignment/BeaverTails)

- Card: https://huggingface.co/datasets/PKU-Alignment/BeaverTails. 14 harm categories on QA pairs; a pair can carry several. Labels describe the response. Guardian trains on the pair as one text.

| BeaverTails category | Guardian |
| --- | --- |
| Violence, Aiding and Abetting, Incitement | `violence_threats` |
| Terrorism, Organized Crime | `violence_threats` |
| Hate Speech, Offensive Language | `harassment`; add `hate_group` when co-labelled with Discrimination, Stereotype, Injustice |
| Discrimination, Stereotype, Injustice | `hate_group` (after religion filter) |
| Self-Harm | `self_harm` |
| Sexually Explicit, Adult Content | `sexual` |
| Child Abuse | DROP (bundles physical, emotional and sexual abuse) |
| Animal Abuse | DROP |
| Controversial Topics, Politics | DROP |
| Drug Abuse, Weapons, Banned Substance | DROP |
| Financial Crime, Property Crime, Theft | DROP |
| Misinformation Regarding ethics, laws, and safety | DROP |
| Non-Violent Unethical Behavior | DROP |
| Privacy Violation | DROP |
| `is_safe = True` | `benign` |

### 4.6 PolyGuardMix

| PolyGuardMix category | Guardian |
| --- | --- |
| S1 Violent Crimes | `violence_threats` |
| S10 Hate | `hate_group` (after religion filter) |
| S11 Self-Harm | `self_harm` |
| S12 Sexual Content, S3 Sex Crimes, S4 Child Exploitation | `sexual` |
| S2, S5, S6, S7, S8, S9, S13, S14 | DROP |
| `prompt_harm_label = no` and no category | `benign` |
| languages other than `en` and `hi` | DROP |

The Llama Guard 3 and PolyGuard taxonomies have no harassment code; harassment examples in those sources can only arrive through S2 ("threats, intimidation") or S3 ("sexual harassment"), both of which are DROP or `sexual` here.

### 4.7 Urdu and Roman Urdu offensive datasets

RUHSOLD (Rizwan et al., EMNLP 2020). Paper: https://aclanthology.org/2020.emnlp-main.197/. Data: https://github.com/haroonshakeel/roman_urdu_hate_speech (10,012 Roman Urdu tweets; `label_definitions.txt`). Task 2 train counts (counted from `task_2_train.tsv`, 7,209 rows): Normal 3,851; Abusive/Offensive 1,729; Sexism 604; Religious Hate 563; Profane/Untargeted 462.

| RUHSOLD Task 2 label | Guardian |
| --- | --- |
| Normal | `benign` |
| Abusive/Offensive | `harassment` |
| Sexism | `hate_group` |
| Religious Hate | DROP |
| Profane/Untargeted | EVAL_ONLY |
| Task 1 (coarse) labels | not used; Task 2 covers the same rows |

HASOC Urdu, FIRE 2021 (Amjad et al.). Overview: https://arxiv.org/abs/2207.06710. Data: https://www.urduthreat2021.cicling.org/. Two binary datasets, Urdu script: Abusive/Non-Abusive (2,400 train, 1,100 test) and Threatening/Non-Threatening (6,000 train, 3,950 test).

| HASOC Urdu label | Guardian |
| --- | --- |
| Abusive | `harassment` |
| Non-Abusive | `benign` |
| Threatening | `violence_threats` |
| Non-Threatening | DROP (abuse status unknown) |

Urdu cyberbullying tweets (Adeeba et al., PeerJ Computer Science 2024). Paper: https://pmc.ncbi.nlm.nih.gov/articles/PMC11065408/ (doi 10.7717/peerj-cs.1963). 12,428 Urdu-script tweets: None 8,598; Insult 1,532; Offensive 995; Name-calling 738; Profane 397; Threat 92; Curse 76.

| Cyberbullying label | Guardian |
| --- | --- |
| None | `benign` |
| Insult, Name-calling, Offensive, Curse | `harassment` |
| Threat | `violence_threats` |
| Profane | EVAL_ONLY |

### 4.8 Baseline outputs read onto Guardian labels (for per-label comparison)

| System output | Guardian |
| --- | --- |
| LG3 S1 | `violence_threats` |
| LG3 S10 | `hate_group` |
| LG3 S11 | `self_harm` |
| LG3 S3, S4, S12 | `sexual` |
| LG3 S2, S5, S6, S7, S8, S9, S13, S14 | out of scope (counts as "unsafe, other") |
| Qwen Violent | `violence_threats` |
| Qwen Unethical Acts | `harassment` or `hate_group` (not separable; scored as the union) |
| Qwen Suicide & Self-Harm | `self_harm` |
| Qwen Sexual Content or Sexual Acts | `sexual` |
| Qwen Controversial | `needs_caution` |
| Qwen Jailbreak, PII, Non-violent Illegal Acts, Politically Sensitive Topics, Copyright Violation | out of scope |
| OpenAI harassment | `harassment` |
| OpenAI harassment/threatening, hate/threatening, violence, violence/graphic | `violence_threats` |
| OpenAI hate | `hate_group` |
| OpenAI self-harm, self-harm/intent, self-harm/instructions | `self_harm` |
| OpenAI sexual, sexual/minors | `sexual` |
| OpenAI illicit, illicit/violent | out of scope |

## 5. Where the taxonomies disagree in ways that change scores

| Boundary | Aegis 2.0 | Llama Guard 3 | Qwen3Guard | OpenAI omni | Guardian v2 | Effect on scoring |
| --- | --- | --- | --- | --- | --- | --- |
| Hate vs harassment | separate `Hate/Identity Hate` and `Harassment` | S10 Hate only; no harassment code | both inside `Unethical Acts` | `hate` for protected traits; non-protected targets are `harassment` | `hate_group` vs `harassment` by target type | LG3 and Qwen cannot be scored per label on this boundary; only on the union |
| Religion | inside `Hate/Identity Hate` | S10 lists "religious affiliation" | inside `Unethical Acts` | inside `hate` | no label; rows removed by script | all six systems are scored on the same religion-filtered test set, so no system gets credit or blame for religious rows |
| Threats | `Threat` is a core category (16 test mentions) | listed under S2 Non-Violent Crimes ("threats, intimidation") | `Violent` or `Unethical Acts` ("threat") | `harassment/threatening`, `hate/threatening` | `violence_threats` | LG3 marks a threat as S2, which this file reads as out of scope; LG3's threat recall is therefore measured only through its binary unsafe output |
| Violence: depiction vs incitement | `Violence` | S1 = enabling or endorsing violent crimes | `Violent` includes "depictions of violence" | `violence` = "depicts death, violence, or physical injury" | threats or incitement only | OpenAI and Qwen will flag graphic description that Guardian leaves to `benign` or `needs_caution`; expect false positives for them and misses for Guardian on depiction rows |
| Profanity only | `Profanity` is unsafe | no code | `Unethical Acts` ("offensive language") | no category | EVAL_ONLY, not trained | 33 Profanity-only test rows count against every system that passes them in the all-categories score |
| Criminal planning, drugs, weapons, PII, fraud | 509 + 118 + 62 + 102 + 14 test mentions | S2, S7, S9 | Non-violent Illegal Acts, PII | illicit, illicit/violent | out of scope | the largest Aegis test category is outside Guardian's scope; the "all categories" score will show that, the "in-scope" score will not |
| Sexual minors | `Sexual (minor)` | S4 | folded into Sexual | `sexual/minors` | folded into `sexual`, descriptive | Guardian does not gate on it; per-label comparison on minors is not possible |
| Needs Caution / Controversial | labelled; resolved to safe in the released binary | none | `Controversial` level | none | `needs_caution` flag | two Guardian numbers (permissive, defensive); baselines have one |
| Jailbreak | prompts from DAN are labelled unsafe at conversation level (paper 4.1.1) | none | `Jailbreak` (input only) | none | none; rows dropped | Aegis test keeps its jailbreak-sourced rows; Guardian has no label for them and will miss the ones without an in-scope harm |

## Decision

Guardian v2 ships `taxonomy_version = "urduguard-2.0"` with five multi-label harm labels and one flag: `violence_threats`, `harassment`, `hate_group` (protective, gated), `self_harm`, `sexual` (descriptive, reported only), and the boolean `needs_caution`; `benign` is the empty set.
`needs_caution` is a flag, not a label. The default gate maps it to pass, matching the released Aegis binary labels and the paper's permissive protocol; the paper also reports the defensive run where the flag blocks.
There is no religious-hate label and no jailbreak label. Religious rows are removed from every file by script before mapping; jailbreak rows are dropped.
Out-of-scope categories (criminal planning, substances, weapons, PII, fraud, malware, advice, politics, copyright, profanity-only) are EVAL_ONLY: kept in the Aegis 2.0 test set with their original binary label, never trained as `benign`.
On the Aegis 2.0 test split the paper reports two binary scores per system: in-scope (rows whose categories are protective, descriptive or safe) and all-categories (every row), plus per-label scores where the baseline taxonomy allows it (table 4.8).
