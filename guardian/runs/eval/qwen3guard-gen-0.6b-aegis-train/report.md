# Qwen/Qwen3Guard-Gen-0.6B:strict

891 rows, 513.5 s, 2026-10-21.

| Form | n protective | catch rate | CI95 | n benign | false-alarm rate | CI95 |
|---|---:|---:|---|---:|---:|---|
| en | 91 | 93.4% | [86.4, 96.9] | 195 | 23.6% | [18.2, 30.0] |
| roman_ur | 96 | 34.4% | [25.6, 44.3] | 200 | 32.5% | [26.4, 39.3] |
| ur | 98 | 81.6% | [72.8, 88.1] | 211 | 42.2% | [35.7, 48.9] |

| Form | R(EN) - R(f) | CI95 | F(f) - F(EN) | CI95 | R1 | R2 | R3 | R4 |
|---|---:|---|---:|---|---|---|---|---|
| roman_ur | +59.0 | [+47.3, +69.8] | +8.9 | [+0.4, +17.3] | not_cleared | not_cleared | not_cleared | not_applicable |
| ur | +11.8 | [+4.7, +20.3] | +18.6 | [+11.2, +25.8] | not_cleared | cleared | not_cleared | not_applicable |

| Label | n | flagged (any) | flagged with the same label |
|---|---:|---:|---:|
| violence_threats | 137 | 75.9% | 38.0% |
| harassment | 115 | 69.6% | 0.0% |
| hate_group | 122 | 65.6% | 0.0% |
| self_harm | 5 | 60.0% | 20.0% |
| sexual | 23 | 87.0% | 60.9% |
