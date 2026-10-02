"""Stage 1: English → Urdu script with opus-mt-en-ur, sentence by sentence so nothing is truncated."""

from __future__ import annotations

import re
from pathlib import Path

import typer

from therapylink_ml.urdu.common import PROCESSED, URDU_DIR, console, read_jsonl, run_resumable

MODEL = "Helsinki-NLP/opus-mt-en-ur"
_SENT = re.compile(r"(?<=[.!?])\s+(?=[A-Z\"'(])")

app = typer.Typer(add_completion=False)


def _sentences(text: str) -> list[str]:
    parts: list[str] = []
    for para in text.split("\n"):
        para = para.strip()
        if para:
            parts.extend(s for s in _SENT.split(para) if s.strip())
    return parts or [text]


class Translator:
    def __init__(self, device: str | None = None, max_len: int = 256):
        import torch
        from transformers import MarianMTModel, MarianTokenizer

        self.device = device or ("cuda" if torch.cuda.is_available() else "cpu")
        self.tok = MarianTokenizer.from_pretrained(MODEL)
        self.model = MarianMTModel.from_pretrained(MODEL).to(self.device).eval()
        self.max_len = max_len

    def __call__(self, texts: list[str], batch: int = 16) -> list[str]:
        import torch

        out: list[str] = []
        for i in range(0, len(texts), batch):
            chunk = texts[i : i + batch]
            enc = self.tok(chunk, return_tensors="pt", padding=True, truncation=True, max_length=self.max_len).to(self.device)
            with torch.no_grad():
                gen = self.model.generate(**enc, max_new_tokens=self.max_len, num_beams=4)
            out.extend(self.tok.batch_decode(gen, skip_special_tokens=True))
        return out


@app.command()
def run(
    source: Path = PROCESSED / "conversations.train.jsonl",
    out: Path = URDU_DIR / "stage1_translated.jsonl",
    sources: str = typer.Option("mentalchat16k,esconv,counselchat", help="Comma-separated source keys to include"),
    limit: int = typer.Option(0, help="Cap conversations (0 = all)"),
    max_turns: int = 8,
    batch: int = 16,
) -> None:
    keep = set(sources.split(","))
    rows = [r for r in read_jsonl(source) if r["source"] in keep]
    if limit:
        rows = rows[:limit]
    console.print(f"{len(rows)} conversations from {sorted(keep)}")
    translate = Translator()

    def fn(conv: dict) -> dict:
        messages = conv["messages"][-max_turns:]
        while messages and messages[0]["role"] != "user":
            messages = messages[1:]
        out_msgs = []
        for m in messages:
            sents = _sentences(m["content"])
            ur = " ".join(translate(sents, batch=batch))
            out_msgs.append({"role": m["role"], "en": m["content"], "ur": ur})
        return {"id": conv["id"], "source": conv["source"], "messages": out_msgs}

    run_resumable(rows, out, fn, label="translate en→ur")


if __name__ == "__main__":
    app()
