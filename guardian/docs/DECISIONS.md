# Decisions made without Azam

Each entry: date, what was decided, why, what to revisit. Newest at the bottom.

## 2026-10-21

1. **Repo.** The brief was opened from the recovery repo (D:\therapylink, branch rebuild/v2), but every v1 file it lists only exists in D:\therapylink-v3. Guardian v2 is built in D:\therapylink-v3 on branch `guardian-v2`. The recovery repo is untouched.
2. **Package name: `urduguard`.** `urduguard`, `guardian-urdu`, `urdu-guard` and `guardrail-urdu` were all free on PyPI on 2026-10-21 (404 on `/pypi/<name>/json`). `urduguard` is one word, imports cleanly (`import urduguard`), and says what it is. Nothing is published yet; the name is only reserved in `pyproject.toml`.
3. **Python environment.** D:\therapylink-v3 had no venv; the only one (D:\therapylink\ml\.venv) has CPU-only torch. A new venv was made at D:\therapylink-v3\ml\.venv with the CUDA 12.6 torch wheel plus the `requirements-local.txt` set, pip cache and temp on D:. Nothing was installed on C:. `HF_HOME=D:\dev\hf` for every run so model downloads stay off C:.
4. **Eval-split exclusion scope.** Hard rule 1 hashes every Aegis 2.0 *test* prompt. IndicGuard's `ur_test` rows are machine translations of the same prompts, so their English source column is also hashed where present, and the Urdu text itself is hashed too, so a row that arrives via IndicGuard is refused as well as one that arrives via Aegis.
5. **Religious filter.** Keyword list (Urdu script, Roman Urdu, English) plus any source category whose name contains religion/blasphemy. Applied in `guardian/data/filters.py` before a file is written to `guardian/data/build/`; counts go to the manifest, rows are dropped in memory.
6. **v1 audit scope.** The v1 files the brief lists under `ml/releases/guardian-v1c/` and `ml/registry.json` guardian entries do not exist in either repo: only `ml/releases/guardian-v1b/` exists, and the registry has no guardian entry. The audit says so and reports v1b.
