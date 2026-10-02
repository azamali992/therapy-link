"""Dump a SentencePiece unigram vocabulary to JSON for the Dart tokenizer in the app.

XLM-RoBERTa's tokenizer is a unigram model; Dart has no SentencePiece runtime, so the app
re-implements unigram Viterbi over this vocabulary (app/lib/core/ml/tokenizer/sentencepiece.dart).
Written as `spm_vocab.json` so it never collides with Hugging Face's own `tokenizer.json`.
"""

from __future__ import annotations

import json
from pathlib import Path

import typer

app = typer.Typer(add_completion=False)


@app.command()
def dump(
    model: str = typer.Argument("FacebookAI/xlm-roberta-base"),
    out: Path = typer.Option(Path("runs/guardian/spm_vocab.json"), "--out"),
    spm_file: str = typer.Option("sentencepiece.bpe.model", help="SentencePiece model filename in the HF repo"),
) -> None:
    import sentencepiece as spm
    from huggingface_hub import hf_hub_download
    from transformers import AutoTokenizer

    sp = spm.SentencePieceProcessor(model_file=hf_hub_download(model, spm_file))
    tok = AutoTokenizer.from_pretrained(model)
    n = sp.get_piece_size()
    # XLM-R prepends <s>, <pad>, </s>, <unk> and shifts every SentencePiece id by one.
    data = {
        "model": model,
        "fairseq_offset": 1,
        "special": {"bos": tok.bos_token_id, "eos": tok.eos_token_id, "unk": tok.unk_token_id, "pad": tok.pad_token_id},
        "pieces": [sp.id_to_piece(i) for i in range(n)],
        "scores": [sp.get_score(i) for i in range(n)],
        "max_len": 128,
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    typer.echo(f"{n} pieces → {out} ({out.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    app()
