"""Encode the eval probes with the real HF tokenizer so the Dart unigram tokenizer can be checked against it."""

from __future__ import annotations

import json
from pathlib import Path

import typer

ML_ROOT = Path(__file__).resolve().parents[2]
PROBES = ML_ROOT / "therapylink_ml" / "eval" / "probes"

EXTRA = [
    "hello",
    "I feel low today.",
    "mujhe bohat udaas lag raha hai yaar",
    "Exam kal hai and I can't breathe properly, kya karun?",
    "میں بہت اداس ہوں",
    "   spaces   everywhere   ",
    "emoji 😔 and punctuation!!! ...",
]

app = typer.Typer(add_completion=False)


def probe_texts(probes: Path = PROBES) -> list[str]:
    """The text of every released probe, file by file in name order. Drafts (*_draft.jsonl) are
    left out: they change while under review, and a fixture built from them would change with them."""
    texts: list[str] = []
    for f in sorted(probes.glob("*.jsonl")):
        if f.name.endswith("_draft.jsonl"):
            continue
        with f.open(encoding="utf-8") as fh:
            texts.extend(json.loads(line)["text"] for line in fh if line.strip())
    return texts


@app.command()
def dump(
    model: str = typer.Argument("FacebookAI/xlm-roberta-base"),
    out: Path = typer.Option(Path("runs/guardian/tokenizer_reference.json"), "--out"),
    max_len: int = 128,
) -> None:
    from transformers import AutoTokenizer

    tok = AutoTokenizer.from_pretrained(model)
    texts = EXTRA + probe_texts()
    rows = [{"text": t, "ids": tok(t, truncation=True, max_length=max_len)["input_ids"]} for t in texts]
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({"model": model, "max_len": max_len, "cases": rows}, ensure_ascii=False, indent=0), encoding="utf-8")
    typer.echo(f"{len(rows)} reference encodings → {out}")


if __name__ == "__main__":
    app()
