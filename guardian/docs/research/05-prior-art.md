# 05. Prior art: harm classifiers and guardrail models

Checked 2026-10-21 against the papers and model cards linked below. "not found" means the source does not say it, not that it is false.

## Comparison table

| Model | Base / size | Languages claimed | Urdu? | Roman Urdu or any romanised script? | How non-English data was made | Numbers for Urdu / romanised | What it skips |
|---|---|---|---|---|---|---|---|
| [Llama Guard 1](https://arxiv.org/abs/2312.06674) | Llama 2 7B | English | no | no | n/a (English only; human-labelled prompts and responses) | none | no per-language numbers, no CIs, no thresholds per form |
| [Llama Guard 2](https://huggingface.co/meta-llama/Meta-Llama-Guard-2-8B) | Llama 3 8B | English (card: "multilingual capability may be limited by its training data") | no | no | n/a; hard samples made by prompting Llama 2 70B to flip labels | none | same as LG1 |
| [Llama Guard 3 8B](https://huggingface.co/meta-llama/Llama-Guard-3-8B) | Llama 3.1 8B | "English, French, German, Hindi, Italian, Portuguese, Spanish, Thai" | no (not on card) | no | "additional human and synthetically generated data" (tool not named) | Hindi F1 0.871 / FPR 0.050 (card, multilingual table). Urdu: none | no CIs, one global threshold, no romanised scripts |
| [Llama Guard 3 1B](https://huggingface.co/meta-llama/Llama-Guard-3-1B) | Llama 3.2 1B pruned to 12 layers (~1.12B), distilled from 8B | same 8 languages | no | no | same as 8B | Hindi F1 0.680 / FPR 0.057 (card). Urdu: none | same; Hindi is its weakest listed language |
| [Llama Guard 4](https://huggingface.co/meta-llama/Llama-Guard-4-12B) | pruned from Llama 4 Scout, 12B, text+image | "the languages supported by Llama Guard 3"; eval on French, German, Hindi, Italian, Portuguese, Spanish, Thai | no | no | not stated | Urdu: none | same as LG3 |
| [Qwen3Guard Gen 0.6B/4B/8B, Stream](https://arxiv.org/abs/2510.14276) | Qwen3 base, 0.6B / 4B / 8B; Stream adds a token-level head | "119 languages and dialects" (no list in report or [card](https://huggingface.co/Qwen/Qwen3Guard-Gen-8B)) | unclear: Urdu never named; at best inside "Others" | no | Qwen-MT translated "the original content into 15 additional languages", checked by "language mixing detection, LLM judge, and random sampling followed by manual review" | none for Urdu. Tables 5 (RTP-LX) and 6 (PolyGuard-Response) break out En, Zh, Ar, Es, Fr, Id, It, Ja, Ko, Ru; "Others indicates the average score on other 30 languages" | no per-language numbers beyond 10, no CIs, no per-language thresholds, no romanised scripts |
| [WildGuard](https://arxiv.org/abs/2406.18495) | Mistral 7B v0.3 | English | no | no | n/a (WildGuardMix: synthetic + human) | none | English only |
| [PolyGuard](https://arxiv.org/abs/2504.04377) | Qwen2.5 7B, Ministral 8B, Qwen2.5 0.5B (Smol) | 17: ar, zh, cs, nl, en, fr, de, hi, th, it, ja, ko, pl, pt, ru, es, sv | no | no | "human-verified machine translations" of WildGuardMix with TowerInstruct-7B-v0.2 and NLLB-3.3B; test split via GPT-4o | Hindi is in; Urdu: none | no Urdu, no romanised scripts, no CIs |
| [ShieldGemma 1](https://huggingface.co/google/shieldgemma-2b) | Gemma 2, 2B / 9B / 27B | "available in English" | no | no | "synthetically generated internal data and publicly available datasets" (generator not named) | none | English only, no per-form anything |
| [ShieldGemma 2](https://huggingface.co/google/shieldgemma-2-4b-it) | Gemma 3 4B IT, image classifier | not listed; synthetic images "in English only" | no | no | WebLI subset + internal synthetic images | none | images only; internal benchmark (~500 per policy) |
| [IndicGuard](https://arxiv.org/abs/2606.22841) (L3Cube Pune) | Gemma 3 4B IT | 10 Indic + English: Hindi, Bengali, Gujarati, Marathi, Punjabi, Tamil, Telugu, Kannada, Malayalam, Urdu | yes (training language) | no; only "code-mixed multilingual interactions" mentioned, nothing on romanised text | Nemotron-Safety-Guard-Dataset-v3 corpus; "The translation process utilized the Google Translate API" (Sec. 3.1.2); responses from an unnamed LLM | Urdu F1, Table 2 (User Safety): Generic 0.8605, CA 0.8542, Jailbreak 0.9089, Combined 0.8737. Table 3 (Response Safety): Generic 0.8666, CA 0.8217, Jailbreak 0.9380, Combined 0.8833. Test = 1,964 translated entries per language | Urdu test is machine-translated, not native; no CIs, no per-language thresholds, no Roman Urdu |
| [BanglaVeilGuard](https://arxiv.org/abs/2608.21880) | TF-IDF (char + word) multinomial logistic classifier, no LLM | Bangla in six written forms: "standard Bangla, Romanized Bangla, Banglish, code-mixed Bangla-English, noisy Bangla, and dialectal Bangla" | no | yes (Romanized Bangla, Banglish) | prompts harmonised from XSafety, MultiJail, Multilingual-Vuln-LLMs, BIDWESH; variants by "rule-based transliteration, noun-only English substitution, and spelling-noise transformations"; no human annotation | guard: 88.5% unsafe recall, 20.0% safe FPR (Table 6, no per-form split). Table 7 gives per-form ASR with "95% Wilson confidence intervals" | no per-form recall/FPR, "same research threshold profile across all guarded conditions", 2,366 prompts, no Urdu |
| [CultureGuard](https://arxiv.org/abs/2508.01710) (NVIDIA) | pipeline + guard model; base not stated on the abstract page | English + 8: Arabic, German, Spanish, French, Hindi, Japanese, Thai, Chinese | no | no | four-stage synthetic pipeline on Nemotron-Content-Safety-Dataset-V2: "cultural data segregation, cultural data adaptation, machine translation, and quality filtering" (tool not named) | none | no Urdu, no romanised, no CIs |
| [Nemotron Safety Guard 8B v3](https://huggingface.co/nvidia/Llama-3.1-Nemotron-Safety-Guard-8B-v3) (NVIDIA) | Llama 3.1 8B Instruct, LoRA r=8 | "9 languages: English, Spanish, Mandarin, German, French, Hindi, Japanese, Arabic, and Thai"; zero-shot "over 20" (en, ar, de, es, fr, hi, ja, th, zh, it, ko, nl, cs, da, fi, iw, pt-BR, pl, ru, sv) | no | no | "Samples from Nemotron Content Safety Dataset V2 [the Aegis 2.0 data], translated to target languages" (tool not named) + Mixtral 8x7B/8x22B synthetic, labelled by Qwen3-235B; card: "all data was synthetically generated" | one aggregate row, no metric named: v3 test 85.32, PolyGuardPrompts 76.07, RTP-LX 91.49, MultiJail 95.36, XSafety 66.97, Aya Red-teaming 96.79 | no per-language table, no CIs, no thresholds, no Urdu |
| [OpenAI omni-moderation-2024-09-26](https://openai.com/index/upgrading-the-moderation-api-with-our-new-multimodal-moderation-model/) | GPT-4o based, size not public | "a test of 40 languages" (list not published); names Khmer, Swati, Telugu, Bengali, Marathi, plus 10 high-resource ones | unclear: not named in announcement or [docs](https://platform.openai.com/docs/guides/moderation) | no | not disclosed | none for Urdu. Only relative: "improved 42% on our internal multilingual eval", "Telugu (6.4x), Bengali (5.6x), and Marathi (4.6x)" | closed model, closed eval set, no per-language absolute numbers, scores may drift ("may need recalibration over time") |
| [Aegis 2.0 defensive](https://huggingface.co/nvidia/Aegis-AI-Content-Safety-LlamaGuard-Defensive-1.0) (NVIDIA) | Llama Guard (Llama 2 7B), PEFT | English | no | no | ~10,800 human prompts (Anthropic HH) + Mistral-7B responses, human annotated | none | English only, prompt classification only |
| [Granite Guardian 3.3 8B](https://huggingface.co/ibm-granite/granite-guardian-3.3-8b) (IBM) | Granite 3.3 8B | "only trained and tested on English data" | no | no | human-annotated (DataForce) + synthetic (Granite, Mixtral) | none | English only |

## The five specific checks

1. Qwen3Guard and Urdu: not found. The report's per-language tables (Tables 5 and 6) list ten languages; everything else is "Others indicates the average score on other 30 languages". No XSTest-multilingual table; XSTest appears only in the English table and a Qwen3-MT-translated Chinese set. The 119-language list is not printed in the report or the HF card.
2. IndicGuard and Urdu: yes. Urdu is one of ten training languages. Test data is Nemotron-Safety-Guard-Dataset-v3 content translated with "the Google Translate API" (not Aegis directly; Aegis 2.0 is cited for taxonomy). Urdu Combined F1: 0.8737 user safety (Table 2), 0.8833 response safety (Table 3).
3. PolyGuard: Hindi yes, Urdu no. Full 17 above.
4. Llama Guard 3: Hindi yes, Urdu no. 8B Hindi F1 0.871, 1B Hindi F1 0.680 (model cards).
5. OpenAI omni-moderation: 40-language list not published; Urdu not named anywhere found. Eval method: "our internal multilingual eval", weighted AUPRC on a "hard multilingual eval set"; construction not disclosed.

## Gaps common to the table

- Romanised scripts: only BanglaVeilGuard covers any (Romanized Bangla, Banglish). Nothing above covers Roman Urdu or Hinglish.
- Urdu: only IndicGuard reports a number, and it is on machine-translated test data.
- Confidence intervals: only BanglaVeilGuard (Table 7, Wilson 95%, for ASR, not for the guard's own recall/FPR).
- Per-language or per-form thresholds: none found.
- A stated release gate (numbers that must hold before a version ships): none found.

## What Guardian v2 does differently

- Ships a coverage card per language form (English, Roman Urdu, Urdu script, mixed) with catch rate and false-alarm rate, each with a 95% CI.
- Uses a separate threshold per language form instead of one global cut-off.
- Tests on text written the way Pakistanis write, not on machine-translated English sets.
- Treats Roman Urdu as a first-class form, not a fallback of Urdu script.
- Exposes the same decision through a Python package, an OpenAI-moderation-compatible HTTP API, and an int8 ONNX file.
- Publishes the numbers it would need to see before a version is released.
