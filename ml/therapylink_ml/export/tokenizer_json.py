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

# Bases and combining marks whose pairs NFKC composes into one letter (Urdu آ, ئ, ۂ; Latin é). The
# single-character table misses these because each half on its own maps to itself.
_PAIR_BASES = [*range(0x41, 0x5B), *range(0x61, 0x7B), *range(0xC0, 0x250), *range(0x600, 0x700), *range(0x750, 0x780)]
_PAIR_MARKS = [*range(0x300, 0x370), *range(0x610, 0x61B), *range(0x64B, 0x660), 0x670, *range(0x6D6, 0x6EE)]


def normalizer_table(sp) -> dict[str, dict[str, str]]:
    """SentencePiece's own normaliser (nmt_nfkc for XLM-R) as lookup tables for the Dart tokenizer.

    `single` maps every code point the normaliser changes to what it becomes ("…" → "...",
    "ﻻ" → "لا", NBSP and ZWNJ → " "); `pairs` maps base + combining mark sequences it composes.
    Measured by normalising each character between two #s, so the dummy-prefix space and
    whitespace collapsing are not part of the table: the Dart side applies those itself.
    """

    def norm(t: str) -> str:
        # '#' neither composes with a following mark nor folds, so it brackets t cleanly.
        out = sp.normalize("#" + t + "#")
        assert out.startswith("▁#") and out.endswith("#"), repr(t)
        return out[2:-1].replace("▁", " ")

    single = {}
    for cp in range(0x110000):
        if 0xD800 <= cp <= 0xDFFF:
            continue
        c = chr(cp)
        if (n := norm(c)) != c:
            single[c] = n
    pairs = {}
    for b in _PAIR_BASES:
        for m in _PAIR_MARKS:
            t = chr(b) + chr(m)
            n = norm(t)
            if n != single.get(chr(b), chr(b)) + single.get(chr(m), chr(m)):
                pairs[t] = n
    return {"single": single, "pairs": pairs}


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
        "normalizer": normalizer_table(sp),
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    typer.echo(f"{n} pieces → {out} ({out.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    app()
