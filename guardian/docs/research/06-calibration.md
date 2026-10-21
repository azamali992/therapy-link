# 06. Calibration, per-form thresholds, form detection, confidence intervals

Scope: how `urduguard` turns raw classifier scores into probabilities, how it picks a threshold per language form (EN, Roman Urdu, Urdu script, mixed), how it decides which form a message is in, and how the release-gate numbers (R1 to R4) get their 95% CIs.

Gate reminder (per form f against EN on the same items): R1 gap R(EN) - R(f) <= 10 points; R2 floor R(f) >= 70%; R3 false-alarm gap F(f) - F(EN) <= 5 points; R4 no Urdu regression on update. A rule is cleared only when the whole 95% CI sits inside the limit.

## 1. Calibration methods

Notation: z is the logit the model emits for one label, p the probability after calibration, N the size of the held-out labelled split the calibrator is fitted on. Fitting on the training split is wrong for every method below (the model is already overconfident there).

| Method | Formula | Fitted parameters | Held-out N (per label) | Monotone | Failure modes |
|---|---|---|---|---|---|
| Temperature scaling | multi-class: p = softmax(z / T); per-label sigmoid: p_k = sigma(z_k / T) | 1 (T > 0), fit by minimising NLL on the held-out split | hundreds suffice; Guo et al. fit on full validation sets of 5k to 25k | yes | one T cannot fix a label or group that is miscalibrated in a different direction from the rest; calibration does not survive distribution shift ([Ovadia et al. 2019](https://arxiv.org/abs/1906.02530)) |
| Platt scaling | p = 1 / (1 + exp(a z + b)) | 2 per label (a, b), fit by NLL with Platt's smoothed targets (N+ + 1)/(N+ + 2) and 1/(N- + 2) | low hundreds; Platt recommends out-of-sample targets to avoid overfit | yes | assumes a sigmoid-shaped reliability curve; wrong shape stays wrong |
| Isotonic regression | p = g(z), g non-decreasing step function found by pool-adjacent-violators | one step per distinct score run, data-defined | >= ~1000; overfits below that (Niculescu-Mizil and Caruana 2005 show Platt beats isotonic on small sets) | yes (weakly: ties collapse) | piecewise constant output, so many messages share one p; no extrapolation beyond the fitted score range |
| Vector / matrix scaling | p = softmax(W z + b), W diagonal (vector) or full (matrix) | K or K^2 + K | thousands | not guaranteed for matrix | matrix scaling overfits and gets worse ECE than temperature on small sets in Guo et al. Table 1 |
| Per-label temperature (multi-label) | p_k = sigma(z_k / T_k) | one T_k per label | hundreds per label | yes per label | labels with few positives (e.g. rare harm categories) get an unstable T_k; fall back to the shared T |
| Per-group temperature | p = sigma(z / T_g), g = language form | one T per form | hundreds of items per form | yes within a form | needs a form label at inference, so it inherits form-detector errors (section 5) |

Sources: temperature scaling and the vector/matrix variants, [Guo et al. 2017, arXiv 1706.04599](https://arxiv.org/abs/1706.04599); Platt scaling, [Platt 1999](https://www.researchgate.net/publication/2594015_Probabilistic_Outputs_for_Support_Vector_Machines_and_Comparisons_to_Regularized_Likelihood_Methods); isotonic regression for classifier scores, [Zadrozny and Elkan 2002, KDD](https://doi.org/10.1145/775047.775151); comparison of Platt vs isotonic by data size, [Niculescu-Mizil and Caruana 2005, ICML](https://doi.org/10.1145/1102351.1102430).

Monotonicity fact that matters for the gate: temperature scaling divides every logit by the same positive number, so the ordering of messages by score does not change. AUC, precision at k, and recall at any given threshold are unchanged once the threshold is mapped through the same transform (t' = sigma(logit(t) / T)). Calibration changes the probability values and therefore which threshold *number* gives a given recall. It does not change the best reachable catch rate per form. Per-form gaps that exist in the ROC curves stay; only the labelling of the axis moves.

Calibration metrics to report per form and per label:

| Metric | Formula | Note |
|---|---|---|
| ECE | sum over bins m of (n_m / N) * abs(acc(B_m) - conf(B_m)) | 15 equal-width bins as in Guo et al.; report bin counts, since Urdu forms will have thinner bins |
| Brier | (1/N) * sum (p_i - y_i)^2 | proper scoring rule; decomposes into calibration + refinement |
| NLL | -(1/N) * sum [y_i log p_i + (1 - y_i) log(1 - p_i)] | the objective temperature scaling minimises |
| Reliability diagram | per bin: mean p vs observed positive rate | one per form, same bins |

Guard-model specific finding: [Liu et al. 2024, "On Calibration of LLM-based Guard Models for Reliable Content Moderation", arXiv 2410.10414](https://arxiv.org/abs/2410.10414) measured Llama Guard 1/2/3, Aegis, WildGuard, ShieldGemma and others and found them overconfident, with ECE that degrades under jailbreak-style shift; temperature scaling and contextual calibration both cut ECE. This is the closest prior work to the plan in the Decision.

## 2. Per-group thresholds and the equalized-odds results

For a guardrail the fairness quantities are the gate quantities:

| Fairness term | Guardrail term | Formula, for form f and threshold t_f |
|---|---|---|
| TPR_f | catch rate R(f) | P(p >= t_f given harmful, form f) |
| FPR_f | false-alarm rate F(f) | P(p >= t_f given benign, form f) |
| equal opportunity | R(f) = R(EN) for all f | R1 with zero slack |
| equalized odds | R(f) = R(EN) and F(f) = F(EN) | R1 and R3 with zero slack |

Results from the literature:

| Paper | Result | Consequence here |
|---|---|---|
| [Hardt, Price and Srebro 2016, arXiv 1610.02413](https://arxiv.org/abs/1610.02413) | Equalized odds and equal opportunity can be reached by post-processing any score with group-specific thresholds (randomised between two thresholds when the groups' ROC curves do not cross at the target point). Equal opportunity needs only one threshold per group. The optimal derived predictor is found by a linear program over the per-group ROC curves. | A per-form threshold table is exactly the Hardt et al. post-processing step. Equal catch rate (R1) is reachable by moving t_f alone, as long as each form's ROC reaches the target TPR at all. |
| [Pleiss et al. 2017, "On Fairness and Calibration", arXiv 1709.02012](https://arxiv.org/abs/1709.02012) | A classifier that is calibrated within each group and satisfies equalized odds exists only if the groups have equal base rates or the classifier is perfect. Calibration is compatible with one relaxed constraint (equal weighted cost of false positives and false negatives) and only by withholding predictions on a random fraction of one group, which costs accuracy. | Shipping both calibrated probabilities and an equalized-odds threshold table is not contradictory on the paired eval set (equal base rates by construction, see below) but is on live traffic where base rates differ by form. |
| [Kleinberg, Mullainathan and Raghavan 2016, arXiv 1609.05807](https://arxiv.org/abs/1609.05807) | Calibration within groups, balance for the positive class (equal mean score among positives) and balance for the negative class cannot all hold unless base rates are equal or prediction is perfect. | Same obstruction, stated on scores instead of thresholds. |
| [Chouldechova 2017, arXiv 1610.07524](https://arxiv.org/abs/1610.07524) | With equal PPV across groups and unequal base rates, FPR and FNR must differ across groups. | A guardrail that matches precision per form will not match catch rate per form. The gate chooses catch rate and false-alarm rate, not precision. |

Base rates on the eval set: every item exists in EN and in each form f (same item, translated or transliterated), so the harmful share is identical per form by construction. On that set the base-rate obstruction vanishes and per-form thresholds can satisfy R1 and R3 jointly if the per-form ROC curves are within the slack. On live traffic the share of harmful messages differs by form, so a probability that is calibrated per form will not give equal R and F per form at one global threshold. That is why the shipped artefact is a threshold table, not a single global threshold.

The trade, stated once: lowering t_f for an Urdu form raises R(f) and raises F(f) at the same time, by the slope of that form's ROC curve at t_f. R1 bounds how far R(f) may sit below R(EN); R3 bounds how far F(f) may sit above F(EN). A threshold t_f satisfying both exists only if

    TPR_f(t_f) >= TPR_EN(t_EN) - 0.10   and   FPR_f(t_f) <= FPR_EN(t_EN) + 0.05

has a solution. If the Urdu-form ROC curve lies below the EN curve by more than that band, no threshold fixes it: the model needs more or better Urdu-form training data, not a different cutoff. R2 (R(f) >= 70%) is an absolute floor that a threshold can always reach, at some false-alarm cost; R3 is what stops that cost from being hidden.

Threshold selection procedure, per form, on the validation split (never on the test split used for the gate):

1. Fix t_EN at the EN operating point (chosen for the EN catch rate target).
2. For each f, sweep t_f over the calibrated probability grid; keep the t_f values where both constraints above hold with slack; among them take the one with the lowest F(f). If the feasible set is empty, record "infeasible" in the coverage card and the release is blocked on that form.
3. Freeze the table; evaluate once on the test split with CIs (section 6).

## 3. How existing guardrails expose scores

| System | Output format | Score available | Calibrated | Modes / thresholds | Source |
|---|---|---|---|---|---|
| Llama Guard 1/2/3/4 | generated text: `safe` or `unsafe` + category codes | probability of the first generated token, read as P(unsafe) | no; overconfident per arXiv 2410.10414 | user applies own threshold to P(unsafe); default is argmax | [Llama Guard paper, arXiv 2312.06674](https://arxiv.org/abs/2312.06674); [Llama Guard 3 model card](https://huggingface.co/meta-llama/Llama-Guard-3-8B): "we look at the probability for the first token, and use that as the 'unsafe' class probability" |
| Qwen3Guard-Gen (0.6B / 4B / 8B) | generated text: `Safety: Safe` / `Controversial` / `Unsafe`, plus category and refusal fields | token logprobs obtainable, but the documented interface is the text label | not claimed | strict mode: Controversial counts as Unsafe; loose mode: Controversial counts as Safe. Report averages pick the better mode per benchmark | [Qwen3Guard technical report, arXiv 2510.14276](https://arxiv.org/abs/2510.14276); [model card](https://huggingface.co/Qwen/Qwen3Guard-Gen-8B) |
| Qwen3Guard-Stream | per-token classification heads on the last layer, emits Safe / Controversial / Unsafe for each generated token of the response, with a separate head for the user turn | per-token class probabilities from the heads | not claimed | same strict / loose reading of Controversial | same report |
| OpenAI moderation (`omni-moderation-latest`) | JSON: `flagged` bool, `categories` {name: bool}, `category_scores` {name: float 0 to 1}, `category_applied_input_types` | per-category float | docs do not call them probabilities; forum reports show `flagged=false` at violence 0.6 | `flagged` and `categories` come from OpenAI's own undisclosed per-category thresholds; the user may threshold `category_scores` instead | [moderation guide](https://platform.openai.com/docs/guides/moderation); [API reference](https://platform.openai.com/docs/api-reference/moderations) |
| WildGuard | generated text, three lines: `Harmful request: yes/no`, `Response refusal: yes/no`, `Harmful response: yes/no` | none exposed by design; yes/no token logprob can be read from the model | no | single mode | [WildGuard, arXiv 2406.18495](https://arxiv.org/abs/2406.18495); [model card](https://huggingface.co/allenai/wildguard) |
| ShieldGemma (2B / 9B / 27B) | prompted yes/no question per policy | softmax over the `Yes` and `No` logits, P(Yes) | not claimed; included in arXiv 2410.10414's miscalibrated set | user threshold on P(Yes), card suggests 0.5 | [ShieldGemma, arXiv 2407.21772](https://arxiv.org/abs/2407.21772); [model page](https://ai.google.dev/gemma/docs/shieldgemma) |
| Granite Guardian | generated `Yes` / `No` | P(Yes) from the token logits | not claimed | user threshold | [Granite Guardian, arXiv 2412.07724](https://arxiv.org/abs/2412.07724) |

Pattern: none of the generative guards ships a calibrated probability or a per-language threshold table, and the two that expose a three-way label (Qwen3Guard) make the third class a mode switch rather than a score band. OpenAI is the only one that returns a float per category alongside its own binary decision, and it does not publish the cutoffs.

## 4. Language-form detection

Four forms: `en`, `roman_ur`, `ur` (script), `mixed`. The detector is two cheap stages, script first, then a Latin-only classifier.

### Stage 1: script check (Unicode blocks)

| Block | Range | Contents |
|---|---|---|
| Arabic | U+0600 to U+06FF | base letters, Urdu-specific letters, Arabic-Indic and Extended Arabic-Indic digits, ۔ U+06D4 (Urdu full stop) |
| Arabic Supplement | U+0750 to U+077F | rare additional letters |
| Arabic Presentation Forms-A | U+FB50 to U+FDFF | ligatures, found in copy-pasted PDF text |
| Arabic Presentation Forms-B | U+FE70 to U+FEFF | positional glyph forms, same source |

Urdu-specific letters, for the record (any of these marks text as Urdu rather than Arabic; they never appear in Arabic):

| Letter | Code point | Name |
|---|---|---|
| ٹ | U+0679 | tteh |
| ڈ | U+0688 | ddal |
| ڑ | U+0691 | rreh |
| ں | U+06BA | noon ghunna |
| ھ | U+06BE | heh doachashmee |
| ہ | U+06C1 | heh goal |
| ے | U+06D2 | yeh barree |
| ۓ | U+06D3 | yeh barree with hamza |

Also distinguishing Urdu/Persian from Arabic: ک U+06A9 (keheh) and ی U+06CC (farsi yeh) instead of Arabic ك U+0643 and ي U+064A. Not needed for the form decision (any Arabic-block text routes to the `ur` threshold) but useful for a data-quality check that Urdu-script training text is actually Urdu.

Rule: let s = (letters in the four blocks) / (all letters, Latin plus Arabic-block, ignoring digits, punctuation, emoji). s >= 0.9 is `ur`; s <= 0.1 goes to stage 2; otherwise `mixed`. The 0.9 / 0.1 cutoffs are config, reported with the detector confusion matrix.

### Stage 2: Roman Urdu vs English on Latin text

Model: character n-gram (1 to 5) logistic regression, or fastText supervised ([Joulin et al. 2016, arXiv 1607.01759](https://arxiv.org/abs/1607.01759)) with the same n-gram range, trained on two classes, Roman Urdu and English. Training text: Roman Urdu from [Dakshina](https://github.com/google-research-datasets/dakshina) (Roark et al. 2020, has an `ur` romanised Wikipedia split), plus any Roman Urdu rows already in the project's own training build; English from the English rows of the same build so the domain matches. Token-level is better than message-level here because the mixed decision needs a per-word count.

Per-word label w_i in {roman_ur, en}; r = (words labelled roman_ur) / (alphabetic words). r >= 0.8 is `roman_ur`; r <= 0.2 is `en`; otherwise `mixed`. Code-mixed Latin text ("mujhe lagta hai I can't do this anymore") lands in `mixed` by this rule. Single-word messages use the word's label directly.

Why not off-the-shelf fastText `lid.176`:

| Fact | Source |
|---|---|
| `lid.176` has 176 classes keyed by ISO 639 code; `ur` is trained on Urdu-script text (Wikipedia, Tatoeba, SETimes). There is no Roman Urdu or Roman Hindi class, so romanised Urdu can only be assigned to some Latin-script class, usually `en` or a short-text neighbour. | [fastText language identification page](https://fasttext.cc/docs/en/language-identification.html) |
| Web-scale LID systems treat romanised Indic languages as a known failure case; the IndicLID authors built a separate roman-script model because CLD3, `lid.176` and NLLB-LID do not cover romanised Indic text. | [IndicLID, Madhani et al. 2023, arXiv 2305.15814](https://arxiv.org/abs/2305.15814); [Caswell et al. 2020, arXiv 2010.14571](https://arxiv.org/abs/2010.14571) |
| On a romanised Indic test set (Bhasha-Abhijnaanam), the published fastText baseline from IndicLID reaches 71.5% accuracy / 63.3 macro-F1; Urdu is among the worst languages and gains +18.0 F1 once romanised training data is added. This is IndicLID's own fastText model with a Roman Urdu class, so it is an upper bound on what `lid.176` (no such class) could do. | [Improving Informally Romanized Language Identification, arXiv 2504.21540](https://arxiv.org/abs/2504.21540) |
| A direct accuracy number for `lid.176` on Roman Urdu: not found. | |

Why the detector must be cheap: it runs on every message before the classifier, in the same process; a char n-gram model is a few MB and sub-millisecond per message.

## 5. The detector is itself a fairness surface

A Roman Urdu message detected as `en` is scored against t_EN instead of t_roman_ur. If t_roman_ur < t_EN (the usual case after section 2), that message is under-caught. Misrouting therefore moves R(roman_ur) down and shows up as an R1 failure that the classifier did not cause. The reverse error (English detected as Roman Urdu) raises F(en) and can hide an R3 failure.

Reporting, in the coverage card, every release:

| Artefact | Content |
|---|---|
| Detector confusion matrix | 4 x 4, gold form (rows) vs detected form (columns), counts and row-normalised, on the eval set; plus per-form precision and recall of the detector |
| Gate with gold form | R1 to R4 computed with the eval set's gold form label selecting the threshold. Measures the classifier alone. |
| Gate with detected form | R1 to R4 computed with the detector's output selecting the threshold. Measures what a user gets. |
| Misrouting cost | per form: R(f) and F(f) under gold minus under detected, with CI. |

Both gate runs must clear. If gold clears and detected does not, the detector is the release blocker and the fix is detector data, not classifier data.

## 6. Confidence intervals

### Single rate: Wilson score interval

For k successes in n trials, p_hat = k/n, z = 1.96:

    centre    = (p_hat + z^2 / (2n)) / (1 + z^2 / n)
    halfwidth = z * sqrt( p_hat (1 - p_hat) / n + z^2 / (4 n^2) ) / (1 + z^2 / n)

Used for R(f) alone (R2) and for any single rate shown in the card. Preferred over the Wald interval because it stays inside [0, 1] and holds coverage at small n and extreme p ([Wilson 1927, JASA](https://doi.org/10.1080/01621459.1927.10502953); [Brown, Cai and DasGupta 2001](https://doi.org/10.1214/ss/1009213286)).

Rough half-widths at p = 0.8 (1.96 * sqrt(p(1-p)/n)): n = 200 gives 5.5 points; n = 500 gives 3.5; n = 1000 gives 2.5. For R, n is the number of harmful items in that form, not the whole set. For R2 to clear with a point estimate of 80%, the lower bound must be >= 70, so n >= ~250 harmful items per form.

### Gap statistics: item-cluster bootstrap

R1 and R3 are differences between forms on the *same* items, so a CI that treats the EN and f samples as independent is too wide. The item is the cluster.

    items i = 1..n, each carrying its EN version and its f version with their labels and predictions
    for b in 1..B (B = 2000):
        draw n items with replacement
        on the drawn items compute R_b(EN), R_b(f), F_b(EN), F_b(f)
        gapR_b = R_b(EN) - R_b(f);  gapF_b = F_b(f) - F_b(EN)
    CI = [2.5th, 97.5th] percentile of the B values

Properties: resampling items keeps each item's EN and f versions together, so the correlation between R(EN) and R(f) is in the CI, which is what the pairing buys. B = 2000 gives percentile endpoints stable to about 0.5 points. Percentile intervals, not BCa, since the statistics are simple rates and the bias is negligible at these n. R4 (no regression on update) uses the same bootstrap with the old model and the new model as the two "versions" of each item.

Source: [Efron and Tibshirani 1993, An Introduction to the Bootstrap](https://doi.org/10.1201/9780429246593), chapters 6 (bootstrap standard errors), 13 (percentile intervals) and 8 (the point about resampling the sampling unit, here the item).

Pass rule, restated with the CIs: R1 cleared when the 97.5th percentile of gapR <= 10; R3 cleared when the 97.5th percentile of gapF <= 5; R2 cleared when the Wilson lower bound of R(f) >= 70; R4 cleared when the 97.5th percentile of R_old(f) - R_new(f) <= 0 for every Urdu form. A point estimate inside the limit with a CI that crosses it is a fail.

## Decision

1. **Probabilities are calibrated per label and per form with temperature scaling.** One T[f, k] for each form f and label k, fitted by NLL on the validation split, with a shared T[f] fallback for any label whose validation positives in form f number under 100. No Platt, no isotonic: the validation split per form is in the hundreds, where Guo et al. and Niculescu-Mizil and Caruana show the one-parameter method is safest. The temperature table ships as `calibration.json` and is printed in the coverage card with ECE (15 bins), Brier and NLL per form before and after.
2. **A per-form threshold table ships in the coverage card**, chosen by the procedure in section 2 on the validation split, evaluated once on the test split. Every form has two thresholds per label: t_lo[f, k] and t_hi[f, k], with t_lo <= t_hi. An infeasible form blocks release.
3. **Three-way label per output, two modes, following Qwen3Guard's strict/loose split.** Per label: p >= t_hi is `unsafe`; t_lo <= p < t_hi is `needs_caution` (the controversial band); p < t_lo is `safe`. **Strict mode** maps `needs_caution` to `unsafe` for the binary decision, so the effective threshold is t_lo. **Loose mode** maps `needs_caution` to `safe`, effective threshold t_hi. The gate is scored in strict mode (the default) because the R2 floor is a catch-rate floor; loose-mode R and F are reported alongside so a user choosing loose sees what they give up. The three-way label and both probabilities are always in the response, whichever mode selected the binary flag.
4. **Language-form detector as in section 4**: Unicode-block script ratio, then a char n-gram (1 to 5) Roman Urdu vs English classifier on Latin text, per-word, with the 0.9/0.1 script cutoffs and 0.8/0.2 word-ratio cutoffs in config. No `lid.176`. The detector output (`form`, `script_ratio`, `roman_ratio`) is returned with every classification so a caller can override the form.
5. **Both gate runs are reported**: with gold form labels and with detected form, plus the 4 x 4 detector confusion matrix and the misrouting cost table. Both must clear.
6. **CIs**: Wilson for single rates, 2000-resample item-cluster percentile bootstrap for every gap (R1, R3, R4, misrouting cost). A rule clears only when the whole interval is inside the limit. Minimum eval size to make R2 clearable at a true 80% catch rate: about 250 harmful items per form.
7. **Not done**: no equalized-odds randomisation between two thresholds (Hardt et al.'s mixed predictor); a deterministic threshold per form is enough for the slack the gate allows, and a randomised guardrail is not explainable to a user. Revisit only if a form's feasible set in step 2 is empty and the ROC gap is small.
