# 04. Architecture options for urduguard

Scope: a standalone harm classifier for text as Pakistanis write it (English, Roman Urdu, Urdu script, mixed).
Hard constraints: train (LoRA or full) and run on an RTX 2050 laptop GPU (4 GB VRAM); real training on Kaggle 2xT4 (16 GB each); ship as int8 ONNX for CPU.

All candidates are compared under the same training mix (~50k labelled rows) and the same eval harness (held-out per-form test sets plus the Roman Urdu perturbation test in section 5). Nothing below was trained; memory and time figures are arithmetic, marked "estimate" with the formula.

## 1. Tokenizer measurement (measured)

Script: [measure_tokenizers.py](measure_tokenizers.py). Run 2026-10-21 with transformers 5.18.0 / tokenizers 0.23.2, tokenizer files only (no weights).
Input: 60 hand-written chat sentences (appendix A), 20 per form. Whitespace words include attached punctuation ("yet." is one word) for every tokenizer alike.

Columns: tok/sent = mean tokens per sentence; tok/word = mean tokens per whitespace word; 3+ = % of words split into 3 or more pieces; 1-char = % of pieces whose text (markers stripped) is exactly one character.

| tokenizer | form | tok/sent | tok/word | 3+ pieces % | 1-char % | unk |
|---|---|---|---|---|---|---|
| xlm-roberta-base (SentencePiece, 250,002) | English | 12.2 | 1.25 | 4 | 20 | 0 |
| | Roman Urdu | 14.9 | 1.48 | 6 | 17 | 0 |
| | Urdu script | 12.4 | 1.22 | 4 | 10 | 0 |
| mdeberta-v3-base (SentencePiece, 250,102) | English | 13.4 | 1.38 | 6 | 17 | 0 |
| | Roman Urdu | 15.9 | 1.58 | 8 | 16 | 0 |
| | Urdu script | 18.1 | 1.77 | 15 | 20 | 0 |
| Qwen3-0.6B (byte-level BPE, 151,669) | English | 11.6 | 1.31 | 5 | 18 | 0 |
| | Roman Urdu | 17.4 | 1.81 | 17 | 27 | 0 |
| | Urdu script | 31.6 | 2.79 | 57 | n/a | 0 |
| Qwen3Guard-Gen-0.6B (same tokenizer as Qwen3-0.6B) | English | 11.6 | 1.31 | 5 | 18 | 0 |
| | Roman Urdu | 17.4 | 1.81 | 17 | 27 | 0 |
| | Urdu script | 31.6 | 2.79 | 57 | n/a | 0 |
| byt5-small (UTF-8 bytes, 384) | English | 49.9 | 4.22 | 83 | 100 | 0 |
| | Roman Urdu | 50.9 | 4.13 | 85 | 100 | 0 |
| | Urdu script | 76.6 | 6.61 | 100 | 100 | 0 |
| bert-base-multilingual-cased (WordPiece, 119,547) | English | 12.5 | 1.28 | 6 | 20 | 0 |
| | Roman Urdu | 17.1 | 1.69 | 11 | 22 | 0 |
| | Urdu script | 18.8 | 1.84 | 21 | 44 | 0 |

Notes on the measurement:

- No tokenizer produced `<unk>` on any sentence. Qwen3 and ByT5 are byte-level, so they cannot produce `<unk>`; they fall back to bytes instead. On Urdu script Qwen3 splits "بریانی" (biryani, 6 chars) into 4 byte-pieces, XLM-R into 2, mBERT into 3, ByT5 into 12 bytes.
- The 1-char column is not comparable for byte-level tokenizers: Qwen3 pieces are shown through the GPT-2 byte-to-unicode table, so a 2-byte Urdu character never counts as "one character" (hence n/a); ByT5 is 100% by construction. For the SentencePiece and WordPiece rows the figure is inflated by punctuation pieces ("." "," "?" "۔" "،").
- Qwen/Qwen3Guard-Gen-0.6B was not gated on 2026-10-21 (downloaded without a token). Its tokenizer behaves identically to Qwen3-0.6B on all 60 sentences.
- Readings that matter for the design:
  - XLM-R is the least fragmenting tokenizer on all three forms. Urdu script at 1.22 tok/word is as compact as its English.
  - Qwen3 spends 2.3x more tokens than XLM-R on Urdu script (2.79 vs 1.22 tok/word, 57% of words in 3+ pieces). At a 128-token budget that is roughly 46 Urdu words vs 105 (estimate: 128 / tok-per-word).
  - Roman Urdu costs every subword tokenizer 18-38% more tokens per word than its English, which is the fragmentation a character branch is meant to absorb.
  - mBERT is strictly worse than XLM-R on every form and is listed only as the legacy reference.
  - ByT5/bytes: 4-6.6x the sequence length; a byte model needs 512+ positions to cover what XLM-R covers in 128.

## 2. Shared arithmetic

- fp16 weights: 2 B per parameter. int8: 1 B per parameter.
- Full fine-tune with AdamW in fp32: 16 B per trainable parameter (weights 4 + grads 4 + two Adam moments 8). Mixed precision adds an fp16 copy (+2 B). Frozen parameters cost 2 B (fp16).
- LoRA ([Hu et al. 2021, arXiv 2106.09685](https://arxiv.org/abs/2106.09685)): frozen base at 2 B per parameter, plus 16 B per LoRA parameter. Activations are still stored for every frozen layer the gradient flows through.
- Activation memory per transformer layer without checkpointing, fp16 ([Korthikanti et al. 2022, arXiv 2205.05198](https://arxiv.org/abs/2205.05198), eq. 2): `s*b*h*(34 + 5*a*s/h)` bytes, s = seq len, b = batch, h = hidden, a = heads. With fused SDPA attention the `5*a*s/h` term is not materialised.
- Training FLOPs per epoch: `6 * N_nonemb * tokens` for full fine-tune, about `4 * N_nonemb * tokens` for LoRA (no weight-gradient GEMMs on frozen matrices) ([Kaplan et al. 2020, arXiv 2001.08361](https://arxiv.org/abs/2001.08361)). tokens = 50,000 rows x 128 = 6.4M.
- Effective GPU throughput assumed: T4 16 TFLOPS (25% of its 65 TFLOPS fp16 tensor peak), RTX 2050 4 TFLOPS. Both are estimates; measure on the first run.
- CUDA context + allocator slack: 0.4 GB reserved in every "fits 4 GB" check.
- CPU latency reference: XLM-R base int8 ONNX, 128 tokens, 2 threads, laptop i5: about 60 ms (reference measurement from a prior export of the same architecture). Other transformer options are scaled by non-embedding FLOPs: `60 ms * N_nonemb / 86M`, marked estimate.

## 3. Options

### 3a. Fine-tuned pretrained encoders

#### XLM-R base ([Conneau et al. 2020, arXiv 1911.02116](https://arxiv.org/abs/1911.02116), [HF card](https://huggingface.co/FacebookAI/xlm-roberta-base))

- Params: 278M = 250,002 x 768 embedding (192M) + 12-layer encoder (86M). Pretraining mix CC-100 includes Urdu script (ur); Roman Urdu is not a named language and appears only incidentally.
- fp16 inference: 0.56 GB weights, batch 1 at 128 tokens adds < 50 MB. Fits.
- Activations (s=128, b=16, h=768, a=12, 12 layers): 69 MB per layer, 0.83 GB total (estimate, formula in section 2).
- Full FT, all params: 278M x 16 B = 4.45 GB before activations. Does not fit 4 GB.
- Full FT, embedding matrix frozen: 0.38 GB (192M fp16) + 86M x 16 B = 1.38 GB + 0.83 GB activations + 0.4 GB = 3.0 GB. Fits at batch 16.
- LoRA r=8 on q,k,v,o: 4 x 2 x 768 x 8 x 12 = 0.59M trainable (9 MB of states). 0.56 GB + 0.83 GB + 0.4 GB = 1.8 GB. Fits at batch 16 with room for batch 32.
- int8 ONNX CPU, 128 tokens, 2 threads: about 60 ms (reference measurement, above). File: ~280 MB if the embedding table is quantised, ~850 MB if ORT dynamic quantisation leaves the Gather table in fp32 (default behaviour; quantise it explicitly).
- T4 epoch: 6 x 86M x 6.4M = 3.3 PFLOP / 16 TFLOPS = 206 s, about 3.5 min per epoch per T4, about 2 min on 2xT4 (estimate). RTX 2050: about 14 min per epoch (estimate).
- Main risk: Roman Urdu was never a pretraining target; spelling variants map to different subword sequences and the model has to learn each from 50k rows. Measured 1.48 tok/word on Roman Urdu vs 1.25 on English.

#### mDeBERTa-v3-base ([He et al. 2021, arXiv 2111.09543](https://arxiv.org/abs/2111.09543), [HF card](https://huggingface.co/microsoft/mdeberta-v3-base))

- Params: 278M = 86M backbone + 250,102 x 768 embedding (192M), card says "86M backbone, 190M embedding". Same CC-100 mix as XLM-R.
- fp16 inference: 0.56 GB. Fits.
- Activations: disentangled attention materialises content-to-position and position-to-content score matrices in addition to content-to-content, so take 1.5x the XLM-R figure: about 1.2 GB at s=128, b=16 (estimate).
- Full FT with frozen embeddings: 0.38 + 1.38 + 1.2 + 0.4 = 3.4 GB. Fits at batch 16 but tight; batch 8 is the safe setting.
- LoRA r=8: 0.56 + 1.2 + 0.4 = 2.2 GB. Fits.
- int8 ONNX CPU: estimate 1.4x XLM-R, about 85 ms (three attention score terms; non-embedding FLOPs otherwise equal). DeBERTa-v2 export is supported by Optimum, but the int8 path through its gather-heavy relative-position code is less exercised than BERT/RoBERTa; verify accuracy after quantisation before counting on it.
- T4 epoch: about 1.4 x 3.5 = 5 min per T4 (estimate).
- Main risk: fp16 overflow during DeBERTa-v3 fine-tuning is a recurring user report; T4 has no bf16, so the fallback is fp32 training at roughly 2x the time. Not verified here. Also: measured 1.77 tok/word on Urdu script vs XLM-R 1.22, so it is a worse fit for Urdu script despite the same vocabulary size.

#### Qwen3-0.6B as sequence classifier ([Qwen3 report, arXiv 2505.09388](https://arxiv.org/abs/2505.09388), [HF card](https://huggingface.co/Qwen/Qwen3-0.6B))

- Params: 0.6B nominal, 0.44B non-embedding (card). 28 layers, h=1024, 16 query / 8 KV heads (GQA), head dim 128, FFN 3072, tied 151,936 x 1024 embedding (156M). Decoder-only, causal attention.
- Classification head: `AutoModelForSequenceClassification` loads `Qwen3ForSequenceClassification`, which adds a `score` linear on the hidden state of the last non-pad token and drops `lm_head`. Pooling is therefore unidirectional last-token, not bidirectional CLS/mean.
- fp16 inference: 1.2 GB weights + small activations. Fits.
- Activations (s=128, b=16, h=1024, a=16, 28 layers): 92 MB per layer eager, 71 MB with SDPA; 2.0-2.6 GB total (estimate).
- Full FT: 0.6B x 16 B = 9.6 GB. Does not fit 4 GB. With embeddings frozen 0.44B x 16 B = 7.1 GB, still no. Fits on a T4 (16 GB) only with 8-bit Adam or gradient checkpointing.
- LoRA r=16 on q,k,v,o,gate,up,down: per layer r x sum(in+out) = 16 x 22,528 = 360k, x28 = 10.1M trainable (0.16 GB of states). Batch 16: 1.2 + 0.16 + 2.0-2.6 + 0.4 = 3.8-4.4 GB, does not fit reliably. Batch 8: 2.8-3.1 GB, fits. Batch 16 with gradient checkpointing (activations / ~5): about 2.3 GB, fits. QLoRA (NF4 base, 0.3 GB) fits with room but trains slower.
- int8 ONNX CPU: estimate 60 ms x (440M / 86M) = about 300 ms at 128 tokens, 2 threads. File about 0.6 GB int8.
- T4 epoch (LoRA): 4 x 0.44B x 6.4M = 11.3 PFLOP / 16 TFLOPS = 704 s, about 12 min per T4, 6 min on 2xT4 (estimate). RTX 2050: about 47 min per epoch (estimate).
- Main risk: 5x the CPU latency of XLM-R for a classifier that ships on CPU; Urdu script costs 2.79 tok/word (measured), so a 128-token window holds about 46 Urdu words; causal attention gives the first tokens no view of the rest.

#### Qwen3Guard-Gen-0.6B as a starting point ([Qwen3Guard report, arXiv 2510.14276](https://arxiv.org/abs/2510.14276), [HF card](https://huggingface.co/Qwen/Qwen3Guard-Gen-0.6B), Apache 2.0)

- Same architecture, tokenizer and memory as Qwen3-0.6B (fine-tuned from Qwen3-0.6B-Base). Trained on 1.19M prompts and responses labelled for safety; outputs text such as `Safety: Unsafe\nCategories: Violent`, tiers safe / controversial / unsafe, 9 categories including "Suicide & Self-Harm", "Unethical Acts" (covers hate, harassment, insults) and "Jailbreak". 119 languages claimed.
- As a generator: chat-template the input, `generate(max_new_tokens=128)`, regex the label. Cost per input = 1 prefill of 128+ tokens plus about 10 decode steps, each a full forward at batch 1: CPU int8 estimate 300 ms + 10 x 30-50 ms = 0.6-0.8 s. Label space is fixed to its taxonomy; no calibrated score; ONNX export of a generate loop needs KV-cache plumbing.
- Cheaper generator variant: one prefill only, read the logits at the position after `Safety: ` and softmax over the token ids of `Safe`, `Unsafe`, `Controversial`. Gives a 3-way probability at prefill cost (about 300 ms estimate) with no decoding. Still its taxonomy, not ours.
- As a classifier head: load with `Qwen3ForSequenceClassification` (score head newly initialised, lm_head dropped) and LoRA-tune on our labels. Memory and time identical to Qwen3-0.6B LoRA above. Expected benefit: representations already shaped by 1.19M safety labels. Expected cost: its policy (e.g. "Politically Sensitive Topics", "Copyright") is not ours and a tri-tier prior can bias the new head.
- Contamination: the report (section 2 of arXiv 2510.14276) says seed prompts were "collected for each target category" and expanded with Self-Instruct, responses were synthesised by Qwen2.5-72B-Base / Qwen3 / DeepSeek-R1, labels were mostly produced by Qwen2.5-72B-Instruct and Qwen3-235B-A22B with voting against a small human-annotated set, and data was translated into 15 extra languages with Qwen-MT (zh, en, ko, id, ru, ja, ar, de, fr, es, pt, it, th and "others"; Urdu not named). The report does not name the public datasets used as seeds and makes no decontamination statement. Consequence: any public English safety benchmark (ToxicChat, OpenAI moderation set, BeaverTails, WildGuardTest, etc.) may overlap its training data, so scores from this starting point on those sets are upper bounds, not held-out results. Our own Roman Urdu / Urdu test sets, written after October 2025, cannot be in it.

### 3b. Character-level model from scratch

Reference: char CNN ([Zhang, Zhao, LeCun 2015, arXiv 1509.01626](https://arxiv.org/abs/1509.01626)); alternative char BiLSTM.

- Motivation: Roman Urdu has no spelling standard. "nahi / nhi / nai / nahin", "hai / hy / he / h", "mein / me / main / mai", "bohat / bohot / bhot / buhat", "kya / kia / kiya" are one word each. A subword vocabulary gives each variant a different piece sequence (measured: 1.48-1.81 tok/word, 6-17% of words in 3+ pieces); a character model sees them as near-identical strings.
- Design (small): char vocab = characters seen 5+ times in training (about 600: ASCII, Urdu block, punctuation) + byte fallback; input 512 chars (about 100 Roman Urdu words); embedding 600 x 64; 4 x Conv1d(k=5, 256 filters) with max-pool 2 between; max-over-time; FC 256; head. Params: 38k + 82k + 3 x 328k + 66k = about 1.2M. "Large" with 512 filters: about 4.5M. The large model of Zhang et al. (1024 filters, 2048-wide FC) is about 27M and was trained on 120k-3.6M rows; too large for 50k.
- Char BiLSTM alternative: embedding 64, 2-layer BiLSTM 256: 0.66M + 1.57M = about 2.3M params; sequential over 512 steps, about 3x slower per epoch than the CNN, and ORT dynamic quantisation leaves the LSTM op in fp32. Prefer the CNN.
- fp16 inference: 2.4 MB weights. Training memory: batch 64 activations about 70 MB; total under 0.5 GB. Fits anywhere.
- int8 ONNX CPU: FLOPs about 2 x 1.07M x 512 = 1.1 GFLOP per input (upper bound, ignores pooling); estimate 5-10 ms at 2 threads.
- Training time: 3 x 1.1 GFLOP x 50k = 165 TFLOP per epoch; at 1 TFLOPS effective (small convs utilise the GPU poorly) about 3 min per epoch on the RTX 2050, 15 epochs about 45 min (estimate). T4: about 2 min per epoch.
- Main risk: no pretraining. Zhang et al. Table 4, AG News (120k rows): n-gram TF-IDF 7.64% error vs char CNN 9.85-15.65%; the char CNN only wins on the 500k+ row sets. On English with 50k rows it will almost certainly lose to XLM-R. Its only case is Roman Urdu spelling robustness, which section 5 measures; it is not adopted unless that test shows it.

### 3c. Hybrid: frozen or LoRA-tuned encoder + character branch with a per-token gate

Related work: CharacterBERT ([El Boukkouri et al. 2020, arXiv 2010.10392](https://arxiv.org/abs/2010.10392)) replaces WordPiece embeddings with a char CNN and re-pretrains; CharBERT ([Ma et al. 2020, arXiv 2011.01513](https://arxiv.org/abs/2011.01513)) adds a character channel with a heterogeneous interaction module and pretrains with an extra noisy-LM objective; CANINE ([Clark et al. 2022, arXiv 2103.06874](https://arxiv.org/abs/2103.06874)) and ByT5 ([Xue et al. 2022, arXiv 2105.13626](https://arxiv.org/abs/2105.13626)) are pretrained from scratch on characters or bytes. All four change pretraining. The hybrid here does not: it bolts a 2M-parameter character branch onto a frozen or LoRA-tuned XLM-R at classification time and trains it on the 50k labelled rows only.

Concrete design (on XLM-R base, h = 768):

1. Subword path: XLM-R last hidden states `h_sub[t]`, t over 128 tokens. Encoder frozen, or LoRA r=8 as in 3a.
2. Character path per token: the token's own characters (max 16, padded; the SentencePiece piece text with "▁" stripped), char embedding 600 x 64, three Conv1d of widths 2/3/4 with 256 filters each, max over characters, concat to 768, Linear 768 -> 768 + tanh. This is the CharCNN of [Kim et al. 2016, arXiv 1508.06615](https://arxiv.org/abs/1508.06615) applied per subword. Output `h_char[t]`.
3. Gate: `g[t] = sigmoid(W_g [h_sub[t]; h_char[t]] + b_g)`, `W_g` in R^{768 x 1536}. `h[t] = g[t] * h_sub[t] + (1 - g[t]) * h_char[t]`.
4. Masked mean pool over t, then Linear 768 -> C.
5. Initialise `b_g = +3` so the model starts as plain XLM-R (g about 0.95); training can only move away from the baseline when the char path helps. This also makes the ablation clean: the mean gate value per language form is a free diagnostic.
6. Optional: one extra transformer layer over `h[t]` so character evidence is contextualised (+7M params). Not in the first version.

Costs:
- Params added: 38k (char emb) + 64 x 9 x 256 = 147k (convs) + 590k (projection) + 1.18M (gate) + head = about 2.0M, +0.7% on XLM-R.
- Training memory added at b=16, s=128: char embeddings 16 x 128 x 16 x 64 x 2 B = 4 MB; conv maps 16 x 128 x 768 x 16 x 2 B = 50 MB; gate and projection about 9 MB. About 70 MB total (estimate). The LoRA budget from 3a becomes about 1.9 GB; the frozen-embedding full FT budget about 3.1 GB. Both fit.
- Inference added: per token 147k x 16 x 2 + 2 x 0.59M + 2 x 1.18M = about 8.3 MFLOP, x128 = 1.06 GFLOP per input, vs 22 GFLOP for the XLM-R encoder (2 x 86M x 128): +5%, about +3 ms on the 60 ms reference (estimate). Char ids are a second ONNX input computed in the same tokenizer pass.
- Export: Conv1d, Gather, Sigmoid, MatMul all quantise with ORT dynamic quantisation; nothing exotic.

Honest status: unproven. The char path is non-contextual and sees 50k rows; the plausible failure is that the gate stays at 0.95 everywhere and the branch adds nothing. Adoption rule: keep the hybrid only if, against XLM-R LoRA with identical data and seeds, the Roman Urdu perturbation recall drop (section 5) shrinks by at least 3 points absolute while clean macro-F1 stays within 0.5 points. Report the mean gate value per form either way.

### 3d. Word-level BiLSTM with fastText embeddings (cheap baseline)

- Aligned vectors ([fasttext.cc/docs/en/aligned-vectors.html](https://fasttext.cc/docs/en/aligned-vectors.html)): 44 languages, RCSLS-aligned, Wikipedia-trained. Urdu is not among them (Hindi, Persian, Arabic, Bengali, Tamil are). So the cross-lingual alignment this baseline is named for is unavailable for Urdu script.
- Fallback vectors: the 157-language Common Crawl + Wikipedia set ([Grave et al. 2018, arXiv 1802.06893](https://arxiv.org/abs/1802.06893), [crawl-vectors](https://fasttext.cc/docs/en/crawl-vectors.html)) has `cc.ur.300` and `cc.en.300`, unaligned. Roman Urdu has no fastText set at all; `cc.en.300.bin` (about 7 GB) can synthesise OOV vectors from character n-grams, but those n-grams were learned on English text.
- Model: vocab 100k (en + ur + Roman Urdu from training data) x 300 = 30M embedding (frozen, 60 MB fp16) + 1-layer BiLSTM 256: 2 x 4 x (300 + 256 + 1) x 256 = 1.14M + head. Trainable about 1.2M (frozen embeddings) or 31M (tuned, 0.5 GB AdamW states).
- Memory: training batch 64 under 1 GB. fp16 inference: 62 MB. Fits anywhere.
- int8 ONNX CPU: ORT dynamic quantisation leaves the LSTM op in fp32; estimate 10-20 ms at 128 tokens, 2 threads.
- Time: under 1 min per epoch on T4, 1-2 min on the RTX 2050 (estimate).
- Main risk: Roman Urdu OOV and no pretrained context. Expected to be the floor on all three forms. It exists to show how much the pretrained encoders buy, not as a candidate.

## 4. Comparison table

Memory columns at s=128, b=16, including 0.4 GB CUDA context. "Fits" = under 4 GB on the RTX 2050. Latency = int8 ONNX, 128 tokens, 2 CPU threads. Epoch = 50k rows, one T4.

| option | params (trainable) | fp16 infer | full FT AdamW | LoRA | int8 CPU @128 | T4 epoch | fits 4 GB (train) | main risk |
|---|---|---|---|---|---|---|---|---|
| XLM-R base | 278M (86M, emb frozen) | 0.6 GB | 3.0 GB (emb frozen); 4.45 GB+ all params: no | 1.8 GB (0.6M) | ~60 ms (reference) | ~3.5 min | yes, b=16 | Roman Urdu never a pretraining target |
| mDeBERTa-v3-base | 278M (86M, emb frozen) | 0.6 GB | 3.4 GB (emb frozen), b=8 safer | 2.2 GB | ~85 ms (est.) | ~5 min (est.) | yes, b=8-16 | fp16 instability; 1.77 tok/word on Urdu script |
| Qwen3-0.6B seq-cls | 600M (10M LoRA) | 1.4 GB | 9.6 GB: no | 2.8-3.1 GB at b=8; 2.3 GB b=16 + ckpt | ~300 ms (est.) | ~12 min LoRA (est.) | LoRA only, b=8 or checkpointing | 5x CPU latency; 2.79 tok/word Urdu script |
| Qwen3Guard-Gen-0.6B | 600M (10M LoRA) | 1.4 GB | 9.6 GB: no | same as Qwen3-0.6B | ~300 ms cls head, 0.6-0.8 s generate (est.) | ~12 min LoRA (est.) | LoRA only | unknown overlap with public benchmarks; foreign taxonomy |
| char CNN (scratch) | 1.2-4.5M | 3-9 MB | < 0.5 GB | n/a | 5-10 ms (est.) | ~2 min (est.) | yes, any batch | loses to XLM-R on English (Zhang 2015 Table 4 at 120k rows) |
| char BiLSTM (scratch) | 2.3M | 5 MB | < 0.5 GB | n/a | 30-60 ms, LSTM stays fp32 (est.) | ~6 min (est.) | yes | same as CNN, slower, worse quantisation |
| hybrid XLM-R + char gate | 280M (2.6M LoRA+char; 88M emb-frozen) | 0.6 GB | 3.1 GB (emb frozen) | 1.9 GB | ~63 ms (est.) | ~4 min (est.) | yes, b=16 | unproven; gate may stay at 0.95 |
| word BiLSTM + fastText | 31M (1.2M, emb frozen) | 62 MB | < 1 GB | n/a | 10-20 ms (est.) | < 1 min (est.) | yes | Urdu not in aligned set; Roman Urdu OOV |

Inference fits 4 GB for every row. Training fits for every row with the stated batch size; Qwen3 full fine-tune fits nowhere in this project (needs 16 GB with 8-bit Adam or checkpointing on a T4).

## 5. What the character work must prove

A from-scratch character model will probably lose to XLM-R on English (section 3b, Zhang et al. Table 4 at 120k rows; ours is 50k). Its case, and the hybrid's, is Roman Urdu spelling robustness. That is measured, not assumed, with this test in the shared harness:

Roman Urdu perturbation test

1. Set: the held-out Roman Urdu test split (hand-labelled, written after October 2025).
2. Variant map: for every word with 2+ attested spellings, the list of alternatives with counts. "Attested" = the alternative appears 3+ times in the training text as the same word under a normaliser (collapse doubled vowels, drop trailing h, ai/ay/ae/ey, ee/i, oo/u, q/k, z/j, w/v). Seed it by hand with the 200 most frequent function words (nahi/nhi/nai/nahin, hai/hy/he/h, mein/me/main/mai, kya/kia/kiya, bohat/bohot/bhot/buhat, yaar/yar, tum/tm, aur/or, kar/kr, raha/rha ...), then extend from training-set counts. The map is a versioned file in the repo.
3. Procedure: per sentence, pick 30% of the words that have variants, uniformly at random, and replace each with a random attested variant. 5 random seeds.
4. Threshold fixed on the clean dev split; never re-tuned on perturbed text.
5. Report: harmful-class recall on clean vs perturbed, drop = clean minus perturbed, mean and std over seeds; macro-F1 the same way; and the tokenizer-side figure "% of perturbed words sharing no subword piece with the original".
6. Adoption rule (same as 3c): a character or hybrid model replaces plain XLM-R only if its recall drop is at least 3 points smaller and its clean macro-F1 is within 0.5 points, on the same data and seeds.

Every option in section 3 runs through this test. No architecture is kept for narrative reasons.

## Decision

Primary: XLM-R base, LoRA r=8 on q,k,v,o (1.8 GB at batch 16 on the RTX 2050; about 2 min per epoch on 2xT4), exported to int8 ONNX with the embedding table quantised (about 60 ms at 128 tokens, 2 threads, reference measurement). If LoRA underfits on dev, switch to full fine-tune with the embedding matrix frozen (3.0 GB, same export). Reasons: least fragmentation on all three forms (1.25 / 1.48 / 1.22 tok/word), the only option with a measured CPU latency, and the only pretrained encoder whose Urdu-script tokenization is as compact as its English.

Fallback: mDeBERTa-v3-base, same recipe, if XLM-R's per-form macro-F1 on dev is more than 2 points below it (tried with fp32 training if fp16 NaNs). Experimental branch, gated on section 5: the XLM-R + character-gate hybrid (3c), adopted only if the perturbation test passes the adoption rule. Qwen3-0.6B / Qwen3Guard-Gen stay as a GPU-side upper-bound reference (LoRA, batch 8) and are not shipped on CPU at 5x the latency. Char CNN from scratch and the fastText BiLSTM run once as ablation floors on the RTX 2050.

## Appendix A. The 60 sentences

Written for this measurement (2026-10-21). Everyday topics; the last few in each block are mildly rude, none hateful. Identical to `SENTENCES` in [measure_tokenizers.py](measure_tokenizers.py).

English

1. My exam is on Monday and I have not opened the book yet.
2. Traffic on the main road was terrible again this morning.
3. Did you watch the cricket match last night? What a finish.
4. Mom is asking when you are coming home for dinner.
5. The boss wants the report by five, no idea how.
6. Biryani from that place near the office is honestly the best.
7. My phone battery dies by noon, I need a new one.
8. Can you send me the notes for chapter four?
9. The bus was so late I missed the first lecture.
10. We lost the match because our bowling was awful.
11. My cousin's wedding is next week and I have nothing to wear.
12. Work from home is fine but the internet keeps dropping.
13. Chai without sugar is just sad hot water.
14. Why does this app crash every time I open it?
15. Stop being so lazy and finish your assignment.
16. Honestly your driving is scary, slow down.
17. Shut up, you have no idea what you are talking about.
18. The teacher gave us a surprise quiz, everyone failed.
19. Petrol prices went up again, this is ridiculous.
20. Let's meet at the chai dhaba after work.

Roman Urdu

1. Kal mera paper hai aur maine abhi tak kuch parha nahi.
2. Aaj phir road pe itna traffic tha, ek ghanta lag gaya.
3. Match dekha kal raat? Last over mein kya khel hua.
4. Ammi pooch rahi hain tum khaane pe kab aa rahe ho.
5. Boss ko report paanch baje tak chahiye, pata nahi kaise hogi.
6. Office ke paas wali biryani sach mein sab se behtar hai.
7. Mera phone dopahar tak hi band ho jata hai, naya lena parega.
8. Chapter four ke notes bhej do yaar.
9. Bus itni late thi ke pehla lecture miss ho gaya.
10. Hum match haar gaye kyunke bowling bohat buri thi.
11. Agle hafte cousin ki shadi hai aur pehnne ko kuch nahi.
12. Ghar se kaam theek hai lekin net baar baar chala jata hai.
13. Cheeni ke baghair chai bas garam paani hai.
14. Ye app har dafa kholte hi band kyun ho jati hai?
15. Itne sust mat bano, apna assignment khatam karo.
16. Sach mein tumhari driving se dar lagta hai, aahista chalao.
17. Chup karo, tumhe kuch pata nahi tum kya bol rahe ho.
18. Teacher ne surprise quiz le liya, sab fail ho gaye.
19. Petrol phir mehnga ho gaya, ye to hadd hai.
20. Kaam ke baad chai ke dhabe pe milte hain.

Urdu script

1. کل میرا پرچہ ہے اور میں نے ابھی تک کچھ نہیں پڑھا۔
2. آج پھر سڑک پر اتنا ٹریفک تھا کہ ایک گھنٹہ لگ گیا۔
3. کل رات میچ دیکھا؟ آخری اوور میں کیا کھیل ہوا۔
4. امی پوچھ رہی ہیں تم کھانے پر کب آ رہے ہو۔
5. باس کو رپورٹ پانچ بجے تک چاہیے، پتہ نہیں کیسے ہوگی۔
6. دفتر کے پاس والی بریانی سچ میں سب سے بہتر ہے۔
7. میرا فون دوپہر تک ہی بند ہو جاتا ہے، نیا لینا پڑے گا۔
8. چوتھے باب کے نوٹس بھیج دو یار۔
9. بس اتنی لیٹ تھی کہ پہلا لیکچر چھوٹ گیا۔
10. ہم میچ ہار گئے کیونکہ بولنگ بہت بری تھی۔
11. اگلے ہفتے کزن کی شادی ہے اور پہننے کو کچھ نہیں۔
12. گھر سے کام ٹھیک ہے لیکن نیٹ بار بار چلا جاتا ہے۔
13. چینی کے بغیر چائے بس گرم پانی ہے۔
14. یہ ایپ ہر دفعہ کھولتے ہی بند کیوں ہو جاتی ہے؟
15. اتنے سست مت بنو، اپنا کام ختم کرو۔
16. سچ میں تمہاری ڈرائیونگ سے ڈر لگتا ہے، آہستہ چلاؤ۔
17. چپ کرو، تمہیں کچھ پتہ نہیں تم کیا بول رہے ہو۔
18. ٹیچر نے اچانک کوئز لے لیا، سب فیل ہو گئے۔
19. پیٹرول پھر مہنگا ہو گیا، یہ تو حد ہے۔
20. کام کے بعد چائے کے ڈھابے پر ملتے ہیں۔
