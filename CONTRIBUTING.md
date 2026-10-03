# Contributing

## Branches

One branch per workstream, each in its own git worktree next to the main checkout:

```powershell
git worktree add D:\therapylink-v3-wt\<workstream> -b <workstream> main
```

Current workstreams: `app-core`, `app-platform`, `l10n`, `api-hardening`, `ml-serving`, `ci-security`, `qa-plan`. Name a new one after what it delivers, not after who's on it.

- Stay inside your workstream's folders. If you need a change in someone else's area, ask them or note it in your PR, rather than editing it on your branch.
- `main` only moves through reviewed merges. Nobody pushes to it directly.
- Rebase on `main` before asking for review, and keep the branch short-lived.

## Commits

- Small commits, each one a single change that builds and passes its tests.
- Subject in the imperative, under about 72 characters, no trailing full stop: `Add the crisis card for self-harm turns`, not `added crisis card` or `Crisis card changes`.
- A body when the why isn't obvious from the diff: what broke, what the change does about it, what you checked.
- Never commit secrets, `.env` files, `key.properties`, keystores, service-account JSON or model weights. `.gitignore` covers all of them, and CI also fails on any credential file that gets through.

## Tests are required

A PR that changes behaviour comes with tests for it. CI runs these, and `ci-ok` has to be green before merge:

| Area | What must pass |
| --- | --- |
| `app/` | `flutter analyze` with no issues, `flutter test` |
| `api/` | `ruff check`, `ruff format --check`, `pytest`, and the alembic migrations on SQLite and Postgres 16 |
| `ml/` | `ruff check`, `pytest` (including prompt parity with the app) |
| everything | gitleaks over the full history |

The exact commands are in the [README](README.md#tests). Some tests are rules, not just checks, and must never be loosened to get a PR through:

- crisis routing, helplines and the output guard in the app
- `api/tests/test_consent.py`: what a clinician can see and when
- `ml/tests/test_prompt_parity.py`: the app sends exactly the prompt Eve was trained on
- `api/tests/test_migrations.py`: the models match what alembic builds

New API routes that a clinician can reach need tests for 401 (no token), 403 (not linked) and 403 (linked, but the patient didn't share that section).

A schema change ships with its alembic migration in the same PR, and `alembic check` must come back clean.

## Before you push

Optional, but it catches most CI failures in seconds:

```powershell
pip install pre-commit
pre-commit install
pre-commit run --all-files
```

## Reporting security or safety issues

Not in a public issue. See [SECURITY.md](SECURITY.md).
