# 07. Product surface: HTTP API, Python API, coverage card, privacy defaults

Scope: what `urduguard` exposes. Labels: `violence_threats`, `harassment`, `hate_group`, `self_harm`, `sexual`, `needs_caution` (flag or label; both shapes below work), `benign`. Forms: `en`, `roman_ur`, `ur`, `mixed`. Shipped as a Python package, an HTTP server with an OpenAI-compatible moderation route, and an int8 ONNX file with a coverage card.

Sources fetched 2026-10-21:

| Source | URL |
| --- | --- |
| OpenAI moderation guide | https://platform.openai.com/docs/guides/moderation (serves from developers.openai.com/api/docs/guides/moderation) |
| OpenAI moderation API reference | https://platform.openai.com/docs/api-reference/moderations/create |
| Llama Guard 3 8B model card | https://huggingface.co/meta-llama/Llama-Guard-3-8B (gated; taxonomy and scoring text visible) |
| Llama Guard 3 prompt template | https://github.com/meta-llama/llama-cookbook/blob/main/getting-started/responsible_ai/llama_guard/llama_guard_text_and_vision_inference.ipynb |
| Qwen3Guard-Gen model card | https://huggingface.co/Qwen/Qwen3Guard-Gen-8B |

## 1. OpenAI `POST /v1/moderations` as documented

Request body:

| Field | Type | Notes |
| --- | --- | --- |
| `input` | string, or array of string, or array of parts `{type:"text", text}` / `{type:"image_url", image_url:{url}}` | Required. A parts array is one input, not one input per part. |
| `model` | string, optional | Enum in the reference: `omni-moderation-latest`, `omni-moderation-2024-09-26`, `text-moderation-latest`, `text-moderation-stable`. The `text-moderation-*` names are the legacy text-only models. |

Response (reference page, "Returns"): `id: string`, `model: string`, `results: array of Moderation`. Each result:

| Field | Type |
| --- | --- |
| `flagged` | boolean, "Whether any of the below categories are flagged." |
| `categories` | object of 13 booleans. `illicit` and `illicit/violent` are typed `boolean or null`; the other 11 are `boolean`. |
| `category_scores` | object of 13 numbers in [0, 1] |
| `category_applied_input_types` | object of 13 arrays; values `"text"` and/or `"image"` |

The 13 category names, with the input types the guide lists:

| Category | Inputs |
| --- | --- |
| `harassment` | text |
| `harassment/threatening` | text |
| `hate` | text |
| `hate/threatening` | text |
| `illicit` | text |
| `illicit/violent` | text |
| `self-harm` | text, image |
| `self-harm/intent` | text, image |
| `self-harm/instructions` | text, image |
| `sexual` | text, image |
| `sexual/minors` | text |
| `violence` | text, image |
| `violence/graphic` | text, image |

Response example quoted from the API reference:

```json
{
  "id": "modr-0d9740456c391e43c445bf0f010940c7",
  "model": "omni-moderation-latest",
  "results": [
    {
      "flagged": true,
      "categories": {
        "harassment": true, "harassment/threatening": true, "sexual": false,
        "hate": false, "hate/threatening": false, "illicit": false, "illicit/violent": false,
        "self-harm/intent": false, "self-harm/instructions": false, "self-harm": false,
        "sexual/minors": false, "violence": true, "violence/graphic": true
      },
      "category_scores": {
        "harassment": 0.8189693396524255, "harassment/threatening": 0.804985420696006,
        "sexual": 1.573112165348997e-6, "hate": 0.007562942636942845,
        "hate/threatening": 0.004208854591835476, "illicit": 0.030535955153511665,
        "illicit/violent": 0.008925306722380033, "self-harm/intent": 0.00023023930975076432,
        "self-harm/instructions": 0.0002293869201073356, "self-harm": 0.012598046106750154,
        "sexual/minors": 2.212566909570261e-8, "violence": 0.9999992735124786,
        "violence/graphic": 0.843064871157054
      },
      "category_applied_input_types": {
        "harassment": ["text"], "harassment/threatening": ["text"], "sexual": ["text", "image"],
        "hate": ["text"], "hate/threatening": ["text"], "illicit": ["text"], "illicit/violent": ["text"],
        "self-harm/intent": ["text", "image"], "self-harm/instructions": ["text", "image"],
        "self-harm": ["text", "image"], "sexual/minors": ["text"], "violence": ["text", "image"],
        "violence/graphic": ["text", "image"]
      }
    }
  ]
}
```

Two facts from the guide that shape the design: unsupported categories for a given input type are returned with score 0 and an empty applied-types list (the image-only example shows `"sexual/minors": []`), and "custom policies that rely on `category_scores` may need recalibration over time". Guardian pins scores to `model_hash` for the same reason.

## 2. Llama Guard 3 and Qwen3Guard-Gen output formats

Llama Guard 3 (8B card): "it generates text in its output that indicates whether a given prompt or response is safe or unsafe, and if unsafe, it also lists the content categories violated." Scores: "we look at the probability for the first token, and use that as the 'unsafe' class probability." Categories S1..S14 (S1 Violent Crimes, S2 Non-Violent Crimes, S3 Sex-Related Crimes, S4 Child Sexual Exploitation, S5 Defamation, S6 Specialized Advice, S7 Privacy, S8 Intellectual Property, S9 Indiscriminate Weapons, S10 Hate, S11 Suicide & Self-Harm, S12 Sexual Content, S13 Elections, S14 Code Interpreter Abuse).

Prompt template, as rendered by the chat template in the llama-cookbook notebook:

```
Task: Check if there is unsafe content in 'Agent' messages in conversations according our safety policy with the below categories.

<BEGIN UNSAFE CONTENT CATEGORIES>
S1: Violent Crimes.
...
S14: Code Interpreter Abuse.
<END UNSAFE CONTENT CATEGORIES>

<BEGIN CONVERSATION>

User: ...

Agent: ...

<END CONVERSATION>

Provide your safety assessment for ONLY THE LAST Agent message in the above conversation:
 - First line must read 'safe' or 'unsafe'.
 - If unsafe, a second line must include a comma-separated list of violated categories.
```

Output: `safe` or `unsafe\nS1,S10`. Two lines, codes only, no scores in the text; the score is the first-token probability.

Qwen3Guard-Gen (card): three tiers, `Safe`, `Controversial`, `Unsafe`. Output is plain text parsed by regex in the card's quickstart:

```
Safety: Unsafe
Categories: Violent
```

Response moderation adds a third line, `Refusal: Yes|No`. Category vocabulary: `Violent`, `Non-violent Illegal Acts`, `Sexual Content or Sexual Acts`, `PII`, `Suicide & Self-Harm`, `Unethical Acts`, `Politically Sensitive Topics`, `Copyright Violation`, `Jailbreak` (input only), `None`.

| Property | OpenAI | Llama Guard 3 | Qwen3Guard-Gen | Guardian |
| --- | --- | --- | --- | --- |
| Transport | JSON | generated text | generated text | JSON |
| Per-category scores | yes, 13 floats | no (one first-token score) | no | yes, per label |
| Middle tier | no | no | `Controversial` | `needs_caution` |
| Batch | array input | one conversation per call | one per call | array input, max 32 |
| Language form reported | no | no | no | `form` + per-form coverage |

## 3. Guardian API

### 3a. `POST /v1/moderations` (OpenAI-compatible)

Request: identical to OpenAI. `input` accepts string, array of strings, or array of parts. `image_url` parts return 422 (Guardian is text only). A parts array with several `text` parts is joined with `\n` into one input, so result count matches OpenAI's. `model` is accepted and ignored; the response `model` is always Guardian's own name so callers can see what scored the text.

Mapping from Guardian labels to OpenAI categories:

| OpenAI category | Guardian source | `categories` value | `category_scores` value | `applied_input_types` |
| --- | --- | --- | --- | --- |
| `harassment` | `harassment` | bool | score | `["text"]` |
| `harassment/threatening` | `harassment` AND `violence_threats` | bool | `min(harassment, violence_threats)` | `["text"]` |
| `hate` | `hate_group` | bool | score | `["text"]` |
| `hate/threatening` | `hate_group` AND `violence_threats` | bool | `min(hate_group, violence_threats)` | `["text"]` |
| `self-harm` | `self_harm` | bool | score | `["text"]` |
| `self-harm/intent` | `self_harm` AND NOT `descriptive.self_harm` | bool | score of `self_harm` when intent, else 0.0 | `["text"]` |
| `self-harm/instructions` | not covered | `false` | `0.0` | `[]` |
| `sexual` | `sexual` | bool | score | `["text"]` |
| `sexual/minors` | not covered | `false` | `0.0` | `[]` |
| `violence` | `violence_threats` | bool | score | `["text"]` |
| `violence/graphic` | not covered | `false` | `0.0` | `[]` |
| `illicit` | not covered | `null` | `0.0` | `[]` |
| `illicit/violent` | not covered | `null` | `0.0` | `[]` |

Rule for uncovered categories: `null` only where OpenAI's own schema types the field `boolean or null` (`illicit`, `illicit/violent`); everywhere else `false`, score `0.0`, applied types `[]`, which is exactly how OpenAI itself reports a category that does not apply to the input type. The OpenAI SDKs parse this without error. `needs_caution` has no OpenAI category and never sets `flagged` on this route; use `/v1/guard` for it. `flagged` = any mapped category true.

Extra fields per result (additive; OpenAI clients ignore unknown keys):

| Field | Type | Meaning |
| --- | --- | --- |
| `form` | `"en"`, `"roman_ur"`, `"ur"`, `"mixed"` | detected language form |
| `coverage` | `{"form_tested": bool, "catch_rate": float|null, "false_alarm_rate": float|null}` | copied from the coverage card for `form` |
| `model_hash` | string, `sha256:<64 hex>` | sha256 of the ONNX file that produced the scores |
| `thresholds_mode` | `"strict"` or `"loose"` | server default is `strict`; override with header `X-Guardian-Mode: loose` |
| `taxonomy_version` | string | e.g. `"2.0"` |

JSON Schema (draft 2020-12) for the response:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://urduguard.dev/schemas/moderations-response.json",
  "type": "object",
  "required": ["id", "model", "results"],
  "properties": {
    "id": {"type": "string", "pattern": "^modr-[0-9a-f]{32}$"},
    "model": {"type": "string"},
    "results": {"type": "array", "items": {"$ref": "#/$defs/result"}}
  },
  "$defs": {
    "cat": {"enum": ["harassment", "harassment/threatening", "hate", "hate/threatening", "illicit", "illicit/violent",
                     "self-harm", "self-harm/intent", "self-harm/instructions", "sexual", "sexual/minors", "violence", "violence/graphic"]},
    "coverage": {
      "type": "object", "required": ["form_tested", "catch_rate", "false_alarm_rate"],
      "properties": {
        "form_tested": {"type": "boolean"},
        "catch_rate": {"type": ["number", "null"], "minimum": 0, "maximum": 1},
        "false_alarm_rate": {"type": ["number", "null"], "minimum": 0, "maximum": 1}
      }
    },
    "result": {
      "type": "object",
      "required": ["flagged", "categories", "category_scores", "category_applied_input_types",
                   "form", "coverage", "model_hash", "thresholds_mode", "taxonomy_version"],
      "properties": {
        "flagged": {"type": "boolean"},
        "categories": {"type": "object", "propertyNames": {"$ref": "#/$defs/cat"}, "minProperties": 13,
                       "additionalProperties": {"type": ["boolean", "null"]}},
        "category_scores": {"type": "object", "propertyNames": {"$ref": "#/$defs/cat"}, "minProperties": 13,
                            "additionalProperties": {"type": "number", "minimum": 0, "maximum": 1}},
        "category_applied_input_types": {"type": "object", "propertyNames": {"$ref": "#/$defs/cat"}, "minProperties": 13,
                                         "additionalProperties": {"type": "array", "items": {"enum": ["text"]}}},
        "form": {"enum": ["en", "roman_ur", "ur", "mixed"]},
        "coverage": {"$ref": "#/$defs/coverage"},
        "model_hash": {"type": "string", "pattern": "^sha256:[0-9a-f]{64}$"},
        "thresholds_mode": {"enum": ["strict", "loose"]},
        "taxonomy_version": {"type": "string"}
      }
    }
  }
}
```

Example request and response:

```json
POST /v1/moderations
{"model": "omni-moderation-latest", "input": ["tujhe dekh lunga kal, bach ke rehna", "aaj mausam acha hai"]}
```

```json
{
  "id": "modr-4f1c2a9e0b7d4e33a1b2c3d4e5f60718",
  "model": "urduguard-2.0-int8",
  "results": [
    {
      "flagged": true,
      "categories": {"harassment": true, "harassment/threatening": true, "hate": false, "hate/threatening": false,
                     "illicit": null, "illicit/violent": null, "self-harm": false, "self-harm/intent": false,
                     "self-harm/instructions": false, "sexual": false, "sexual/minors": false, "violence": true, "violence/graphic": false},
      "category_scores": {"harassment": 0.71, "harassment/threatening": 0.71, "hate": 0.02, "hate/threatening": 0.02,
                          "illicit": 0.0, "illicit/violent": 0.0, "self-harm": 0.01, "self-harm/intent": 0.0,
                          "self-harm/instructions": 0.0, "sexual": 0.0, "sexual/minors": 0.0, "violence": 0.93, "violence/graphic": 0.0},
      "category_applied_input_types": {"harassment": ["text"], "harassment/threatening": ["text"], "hate": ["text"], "hate/threatening": ["text"],
                                       "illicit": [], "illicit/violent": [], "self-harm": ["text"], "self-harm/intent": ["text"],
                                       "self-harm/instructions": [], "sexual": ["text"], "sexual/minors": [], "violence": ["text"], "violence/graphic": []},
      "form": "roman_ur",
      "coverage": {"form_tested": true, "catch_rate": 0.91, "false_alarm_rate": 0.06},
      "model_hash": "sha256:0000000000000000000000000000000000000000000000000000000000000000",
      "thresholds_mode": "strict",
      "taxonomy_version": "2.0"
    }
  ]
}
```

The second item ("aaj mausam acha hai") returns the same shape with every category false, all scores near 0.0, and `flagged: false`; omitted for length.

Scores and the hash above are illustrative; the hash is all zeros on purpose so nobody copies it as real.

### 3b. `POST /v1/guard` (native)

Request:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://urduguard.dev/schemas/guard-request.json",
  "type": "object", "required": ["input"], "additionalProperties": false,
  "properties": {
    "input": {"oneOf": [{"type": "string"}, {"type": "array", "minItems": 1, "maxItems": 32, "items": {"type": "string"}}]},
    "mode": {"enum": ["strict", "loose"], "default": "strict"},
    "form": {"enum": ["en", "roman_ur", "ur", "mixed"], "description": "Override the form detector; coverage is then looked up for this form."}
  }
}
```

Response: `{"results": [item, ...]}`. One item per input, in order. Item schema:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://urduguard.dev/schemas/guard-result.json",
  "type": "object",
  "required": ["flagged", "labels", "scores", "protective_flag", "needs_caution", "descriptive", "form", "form_confidence",
               "thresholds", "coverage", "model_hash", "taxonomy_version", "mode", "latency_ms"],
  "$defs": {
    "protective": {"enum": ["violence_threats", "harassment", "hate_group", "self_harm", "sexual"]},
    "label": {"enum": ["violence_threats", "harassment", "hate_group", "self_harm", "sexual", "needs_caution", "benign"]}
  },
  "properties": {
    "flagged": {"type": "boolean", "description": "protective_flag OR needs_caution"},
    "labels": {"type": "object", "propertyNames": {"$ref": "#/$defs/label"}, "additionalProperties": {"type": "boolean"}},
    "scores": {"type": "object", "propertyNames": {"$ref": "#/$defs/label"}, "additionalProperties": {"type": "number", "minimum": 0, "maximum": 1}},
    "protective_flag": {"type": "boolean", "description": "any protective label true"},
    "needs_caution": {"type": "boolean", "description": "same value as labels.needs_caution; present so a flag-only taxonomy keeps the field"},
    "descriptive": {"type": "object", "required": ["self_harm", "sexual"],
                    "properties": {"self_harm": {"type": "boolean"}, "sexual": {"type": "boolean"}},
                    "description": "true when the label fires on descriptive or third-person content rather than first-person intent or solicitation"},
    "form": {"enum": ["en", "roman_ur", "ur", "mixed"]},
    "form_confidence": {"type": "number", "minimum": 0, "maximum": 1},
    "thresholds": {"type": "object", "propertyNames": {"$ref": "#/$defs/label"}, "additionalProperties": {"type": "number"}},
    "coverage": {"$ref": "https://urduguard.dev/schemas/moderations-response.json#/$defs/coverage"},
    "model_hash": {"type": "string", "pattern": "^sha256:[0-9a-f]{64}$"},
    "taxonomy_version": {"type": "string"},
    "mode": {"enum": ["strict", "loose"]},
    "latency_ms": {"type": "number", "minimum": 0}
  }
}
```

Rules: `labels.benign` is true iff no other label is true. `thresholds` lists the per-label cut-offs actually applied for `mode` and `form`, copied from the coverage card, so a caller can reproduce `labels` from `scores`. If the taxonomy ships `needs_caution` as a flag rather than a classifier head, `scores.needs_caution` is still present (the flag's score, or 1.0/0.0).

Example:

```json
POST /v1/guard
{"input": "mujhe ab jeene ka koi faida nahi lagta", "mode": "strict"}
```

```json
{
  "results": [
    {
      "flagged": true,
      "labels": {"violence_threats": false, "harassment": false, "hate_group": false, "self_harm": true, "sexual": false, "needs_caution": false, "benign": false},
      "scores": {"violence_threats": 0.01, "harassment": 0.02, "hate_group": 0.0, "self_harm": 0.88, "sexual": 0.0, "needs_caution": 0.05, "benign": 0.09},
      "protective_flag": true,
      "needs_caution": false,
      "descriptive": {"self_harm": false, "sexual": false},
      "form": "roman_ur",
      "form_confidence": 0.97,
      "thresholds": {"violence_threats": 0.35, "harassment": 0.45, "hate_group": 0.40, "self_harm": 0.30, "sexual": 0.50, "needs_caution": 0.50, "benign": 0.50},
      "coverage": {"form_tested": true, "catch_rate": 0.91, "false_alarm_rate": 0.06},
      "model_hash": "sha256:0000000000000000000000000000000000000000000000000000000000000000",
      "taxonomy_version": "2.0",
      "mode": "strict",
      "latency_ms": 11.4
    }
  ]
}
```

### 3c. Python

```python
import urduguard

g = urduguard.load("urduguard-2.0-int8")        # name resolves to the packaged ONNX + card; or a path to a .onnx
r = g.check("tujhe dekh lunga", mode="strict")   # -> GuardResult
rs = g.check_batch(["...", "..."], mode="loose") # -> list[GuardResult], same order

urduguard.check(text, mode="strict")             # module-level, uses a lazily loaded default model
urduguard.check_batch(texts, mode="strict")
```

```python
@dataclass(frozen=True)
class GuardResult:
    flagged: bool
    labels: dict[str, bool]          # 7 keys
    scores: dict[str, float]         # 7 keys
    protective_flag: bool
    needs_caution: bool
    descriptive: dict[str, bool]     # {"self_harm", "sexual"}
    form: str                        # "en" | "roman_ur" | "ur" | "mixed"
    form_confidence: float
    thresholds: dict[str, float]
    coverage: Coverage               # form_tested, catch_rate, false_alarm_rate
    model_hash: str
    taxonomy_version: str
    mode: str
    latency_ms: float

    def to_openai(self) -> dict: ...  # one /v1/moderations result object, same mapping as 3a
```

`load()` verifies `sha256(onnx) == card.model_hash` and raises `ModelHashMismatch` otherwise. Batch over 32 items is split internally; the HTTP route rejects it instead.

## 4. Privacy defaults (design rules, not configuration)

| Rule | Detail |
| --- | --- |
| No request logging | The server has no code path that writes `input`, `labels`, `scores`, or `form` to disk, stdout, or a network sink. Not a flag; the code is absent. |
| No result storage | Nothing from a response is retained after it is sent. No cache keyed on text. |
| `self_harm` and `needs_caution` never counted | These two never appear in any metric, log line, or counter. `needs_caution` covers political and religious-sensitivity content, so this rule is what keeps a per-user political profile from being derivable from the server. |
| Metrics are counts only | `urduguard_requests_total`, `urduguard_request_latency_seconds` (histogram), `urduguard_items_total`, `urduguard_flagged_total{label}` for `violence_threats`, `harassment`, `hate_group`, `sexual` only, `urduguard_errors_total{code}`. No form label on any metric. |
| Errors carry no text | 4xx/5xx bodies and server-side exception logs contain the error code and item index, never the item. |

What an operator can turn on: the `/metrics` endpoint (off by default); an access log with method, path, status, and latency only; a `GET /healthz` that returns `model_hash`, `taxonomy_version`, and uptime. What an operator cannot turn on, because no setting exists: body logging, response logging, input sampling, a debug mode that echoes text, any per-label counter for `self_harm` or `needs_caution`, any metric with a `form` dimension.

## 5. Coverage card JSON Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://urduguard.dev/schemas/coverage-card.json",
  "type": "object",
  "required": ["taxonomy_version", "model_hash", "model_name", "date", "placeholder", "forms_tested", "forms",
               "thresholds", "gate", "form_detector", "signed_off_by", "not_tested", "eval_set"],
  "$defs": {
    "form": {"enum": ["en", "roman_ur", "ur", "mixed"]},
    "rate": {"type": "object", "required": ["value", "ci95"],
             "properties": {"value": {"type": ["number", "null"]},
                            "ci95": {"type": ["array", "null"], "items": {"type": "number"}, "minItems": 2, "maxItems": 2}}},
    "thresholds": {"type": "object", "additionalProperties": {"type": "number", "minimum": 0, "maximum": 1}},
    "gate_item": {"type": "object", "required": ["status", "measured", "required"],
                  "properties": {"status": {"enum": ["cleared", "not_cleared", "not_applicable"]},
                                 "measured": {"type": ["number", "null"]}, "required": {"type": ["number", "null"]}}}
  },
  "properties": {
    "taxonomy_version": {"type": "string"},
    "model_hash": {"type": "string", "pattern": "^sha256:[0-9a-f]{64}$"},
    "model_name": {"type": "string"},
    "date": {"type": "string", "format": "date"},
    "placeholder": {"type": "boolean", "description": "true until every rate below is measured and signed off"},
    "forms_tested": {"type": "array", "items": {"$ref": "#/$defs/form"}, "uniqueItems": true},
    "forms": {"type": "object", "propertyNames": {"$ref": "#/$defs/form"},
      "additionalProperties": {"type": "object",
        "required": ["n_items", "n_protective", "n_benign", "catch_rate", "false_alarm_rate"],
        "properties": {"n_items": {"type": "integer"}, "n_protective": {"type": "integer"}, "n_benign": {"type": "integer"},
                       "catch_rate": {"$ref": "#/$defs/rate"}, "false_alarm_rate": {"$ref": "#/$defs/rate"}}}},
    "thresholds": {"type": "object", "required": ["strict", "loose"],
                   "properties": {"strict": {"$ref": "#/$defs/thresholds"}, "loose": {"$ref": "#/$defs/thresholds"}}},
    "gate": {"type": "object", "required": ["R1", "R2", "R3", "R4", "R5"],
             "properties": {"R1": {"$ref": "#/$defs/gate_item"}, "R2": {"$ref": "#/$defs/gate_item"},
                            "R3": {"$ref": "#/$defs/gate_item"}, "R4": {"$ref": "#/$defs/gate_item"}, "R5": {"$ref": "#/$defs/gate_item"}}},
    "form_detector": {"type": "object", "required": ["accuracy", "confusion"],
                      "properties": {"accuracy": {"type": ["number", "null"]},
                                     "confusion": {"type": ["object", "null"], "description": "confusion[true_form][predicted_form] = count"}}},
    "signed_off_by": {"type": "array", "items": {"type": "object", "required": ["name", "role", "date"],
                      "properties": {"name": {"type": "string"}, "role": {"type": "string"}, "date": {"type": "string", "format": "date"}}}},
    "not_tested": {"type": "array", "items": {"type": "string"}},
    "eval_set": {"type": "object", "required": ["name", "n", "hash"],
                 "properties": {"name": {"type": "string"}, "n": {"type": "integer"}, "hash": {"type": "string"}}}
  }
}
```

Gate names used in this card are the project's parity requirement, computed per Urdu form f (roman_ur, ur, mixed) against English on the same items. R is catch rate on protective labels, F is false-alarm rate on benign items. A gate is cleared only when the whole 95% CI is inside the limit.

| Gate | Definition | `measured` | `required` |
| --- | --- | --- | --- |
| R1 | catch-rate gap: R(EN) - R(f) | upper bound of the paired bootstrap CI95 of the gap, worst form | <= 10 points |
| R2 | floor: R(f) | lower bound of the Wilson CI95, worst form | >= 70% |
| R3 | false-alarm gap: F(f) - F(EN) | upper bound of the paired bootstrap CI95 of the gap, worst form | <= 5 points |
| R4 | no Urdu regression on update: [R_f(old) - R_f(new)] - [R_EN(old) - R_EN(new)] | upper bound of CI95, worst form; `not_applicable` for a first release | <= 5 points |
| R5 | no harmful logs: the server stores no self_harm or needs_caution flags and no input text | code review, see Privacy above | true |

Filled placeholder example (what ships until the first measured run):

```json
{
  "taxonomy_version": "2.0",
  "model_hash": "sha256:0000000000000000000000000000000000000000000000000000000000000000",
  "model_name": "urduguard-2.0-int8",
  "date": "2026-10-21",
  "placeholder": true,
  "forms_tested": [],
  "forms": {
    "en":       {"n_items": 0, "n_protective": 0, "n_benign": 0, "catch_rate": {"value": null, "ci95": null}, "false_alarm_rate": {"value": null, "ci95": null}},
    "roman_ur": {"n_items": 0, "n_protective": 0, "n_benign": 0, "catch_rate": {"value": null, "ci95": null}, "false_alarm_rate": {"value": null, "ci95": null}},
    "ur":       {"n_items": 0, "n_protective": 0, "n_benign": 0, "catch_rate": {"value": null, "ci95": null}, "false_alarm_rate": {"value": null, "ci95": null}},
    "mixed":    {"n_items": 0, "n_protective": 0, "n_benign": 0, "catch_rate": {"value": null, "ci95": null}, "false_alarm_rate": {"value": null, "ci95": null}}
  },
  "thresholds": {
    "strict": {"violence_threats": 0.5, "harassment": 0.5, "hate_group": 0.5, "self_harm": 0.5, "sexual": 0.5, "needs_caution": 0.5},
    "loose":  {"violence_threats": 0.5, "harassment": 0.5, "hate_group": 0.5, "self_harm": 0.5, "sexual": 0.5, "needs_caution": 0.5}
  },
  "gate": {
    "R1": {"status": "not_cleared", "measured": null, "required": null},
    "R2": {"status": "not_cleared", "measured": null, "required": null},
    "R3": {"status": "not_cleared", "measured": null, "required": null},
    "R4": {"status": "not_applicable", "measured": null, "required": 5},
    "R5": {"status": "cleared", "measured": true, "required": true}
  },
  "form_detector": {"accuracy": null, "confusion": null},
  "signed_off_by": [],
  "not_tested": [
    "any form: no eval run yet",
    "Pashto, Sindhi, Punjabi script or romanised",
    "inputs over 2000 characters",
    "adversarial spelling (leetspeak, zero-width joiners, homoglyphs)",
    "voice transcripts"
  ],
  "eval_set": {"name": "", "n": 0, "hash": ""}
}
```

While `placeholder` is true the server still runs, but every `coverage` object it returns has `form_tested: false` and null rates, and `forms_tested` is empty, so a caller can tell at the first response that nothing is measured. Thresholds of 0.5 in the placeholder are the untuned default, not a tuned value.

## 6. Errors and limits

| Limit | Value | Error |
| --- | --- | --- |
| Request body | 1 MiB | 413 `payload_too_large` |
| Items per request (`input` array or parts array count) | 32 | 422 `too_many_items` |
| Characters per item | 2000 after NFC normalisation | 422 `item_too_long` with `index` |
| Tokens per item | 512 with the packaged tokenizer; checked after the character limit | 422 `item_too_long` with `index` and `tokens` |
| Empty item (`""` or whitespace only) | not allowed | 422 `empty_item` with `index` |
| `image_url` part | not supported | 422 `unsupported_input_type` with `index` |
| Unknown `mode` or `form` value | | 422 `invalid_value` with `field` |
| Unknown top-level field on `/v1/guard` | | 422 `unknown_field` |
| Model file hash differs from card | | server refuses to start; `load()` raises `ModelHashMismatch` |

Error body, same shape on both routes:

```json
{"error": {"code": "item_too_long", "message": "item 3 is 2417 characters; limit 2000", "index": 3}}
```

`message` names counts and indices only, never the item text. On `/v1/moderations` the body is also wrapped as OpenAI clients expect: `{"error": {"message": ..., "type": "invalid_request_error", "code": ...}}` with the same values.

`model_hash` is `"sha256:" + hex(sha256(onnx file bytes))`. It is computed at `load()`, compared to the coverage card, returned in every result, and stamped on the card by the eval script. A card whose hash does not match the file it sits next to is invalid, and a result with a hash the caller cannot find a card for is unverifiable.

## Decision

1. Two HTTP routes. `/v1/moderations` is byte-compatible with OpenAI's request and the 13-key response, with uncovered categories set to `null` only where OpenAI types them nullable (`illicit`, `illicit/violent`) and `false` / `0.0` / `[]` elsewhere, plus five additive fields (`form`, `coverage`, `model_hash`, `thresholds_mode`, `taxonomy_version`). `/v1/guard` is the native route and the only place `needs_caution`, `descriptive`, `form_confidence`, and per-label `thresholds` appear.
2. `needs_caution` is returned as both a key in `labels` and a top-level boolean, so the taxonomy can treat it as a label or a flag without changing the wire shape.
3. Python surface: `load`, `check`, `check_batch`, frozen `GuardResult` with a `to_openai()` adapter.
4. Privacy is enforced by absence of code, not by settings: no text or result ever written; `self_harm` and `needs_caution` are never counted anywhere; metrics are request, latency, item, error, and four protective-label counters.
5. The coverage card is required, hash-bound to the ONNX file, and ships with `placeholder: true` and null rates until an eval run and a non-author sign-off replace them. Gates R1 to R5 are the parity requirement above; the numbers are fixed, not per release.
6. Limits: 32 items, 2000 chars and 512 tokens per item, 1 MiB body; 413 and 422 with index-only error bodies.
