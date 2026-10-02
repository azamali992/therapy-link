"""Stage 3: rewrite each turn into natural, code-switched Roman Urdu with an open LLM.

Point --base-url at any OpenAI-compatible server (llama-server / vLLM on Kaggle or the 2050 box).
Use an open-weights model here, not a hosted API, so the whole pipeline is reproducible and
free of terms-of-service questions about training on outputs.
"""

from __future__ import annotations

import random
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import typer

from therapylink_ml.urdu.common import URDU_DIR, console, read_jsonl, run_resumable

app = typer.Typer(add_completion=False)

SYSTEM = """You rewrite Urdu text as Roman Urdu — the way young people in Pakistan actually type on their phones.

Rules:
- Keep the meaning exactly. Do not add, drop, soften or intensify anything.
- Casual, natural register. Mix in common English words where a real person would (feel, stress, office, exam, family, sorry, honestly).
- No diacritics, no Urdu script, no transliteration tables. Spell words the way people commonly do (hai, nahi, bohat, mujhe, yaar, acha).
- Keep roughly the same length as the original. Keep line breaks.
- Output only the rewritten text. No quotes, no notes."""


def _prompt(ur: str, seed: str, exemplars: list[str]) -> list[dict]:
    style = "\n".join(f"- {e}" for e in exemplars)
    user = (
        "Examples of real Roman Urdu from social media, for style only (do not copy their content):\n"
        f"{style}\n\n"
        f"Urdu text:\n{ur}\n\n"
        f"A rough romanisation, for reference (may be stiff or wrong):\n{seed}\n\n"
        "Rewrite the Urdu text as natural Roman Urdu:"
    )
    return [{"role": "system", "content": SYSTEM}, {"role": "user", "content": user}]


@app.command()
def run(
    base_url: str = typer.Option(..., help="OpenAI-compatible endpoint, e.g. http://localhost:8080/v1"),
    model: str = typer.Option("default"),
    api_key: str = typer.Option("none"),
    exemplars: Path = URDU_DIR / "exemplars.txt",
    source: Path = URDU_DIR / "stage2_romanised.jsonl",
    out: Path = URDU_DIR / "stage3_restyled.jsonl",
    shots: int = 12,
    workers: int = 4,
    temperature: float = 0.6,
    seed: int = 13,
) -> None:
    from openai import OpenAI

    pool = [line.strip() for line in exemplars.read_text(encoding="utf-8").splitlines() if line.strip() and not line.startswith("#")]
    if len(pool) < shots:
        raise typer.BadParameter(f"{exemplars} has {len(pool)} exemplars; need at least {shots}. See urdu/README.md.")
    rng = random.Random(seed)
    client = OpenAI(base_url=base_url, api_key=api_key)

    def rewrite(ur: str, seed_text: str) -> str:
        resp = client.chat.completions.create(
            model=model,
            messages=_prompt(ur, seed_text, rng.sample(pool, shots)),
            temperature=temperature,
            max_tokens=max(64, int(len(seed_text.split()) * 2.5)),
        )
        return (resp.choices[0].message.content or "").strip().strip('"')

    def fn(conv: dict) -> dict | None:
        try:
            with ThreadPoolExecutor(workers) as ex:
                results = list(ex.map(lambda m: rewrite(m["ur"], m["ur_roman_seed"]), conv["messages"]))
        except Exception as e:  # noqa: BLE001
            console.print(f"[yellow]skip {conv['id']}: {e}")
            return None
        for m, r in zip(conv["messages"], results, strict=True):
            m["ur_roman"] = r
        return conv

    run_resumable(read_jsonl(source), out, fn, label="restyle")


if __name__ == "__main__":
    app()
