"""Stage 4: back-translate the Roman Urdu to English and check the meaning survived.

Then `build-corpus` writes the bilingual training file eve_sft.py consumes.
"""

from __future__ import annotations

import json
import statistics
from pathlib import Path

import typer

from therapylink_ml.urdu.common import PROCESSED, URDU_DIR, append_jsonl, console, read_jsonl, run_resumable

app = typer.Typer(add_completion=False)

BACK = "Translate this Roman Urdu into plain English. Keep the meaning exact. Output only the translation."


@app.command()
def run(
    base_url: str = typer.Option(..., help="OpenAI-compatible endpoint for back-translation"),
    model: str = typer.Option("default"),
    api_key: str = typer.Option("none"),
    source: Path = URDU_DIR / "stage3_restyled.jsonl",
    out: Path = URDU_DIR / "stage4_verified.jsonl",
    threshold: float = 0.62,
    embedder: str = "sentence-transformers/all-MiniLM-L6-v2",
) -> None:
    from openai import OpenAI
    from sentence_transformers import SentenceTransformer, util

    client = OpenAI(base_url=base_url, api_key=api_key)
    st = SentenceTransformer(embedder)
    sims: list[float] = []

    def back(text: str) -> str:
        r = client.chat.completions.create(
            model=model,
            messages=[{"role": "system", "content": BACK}, {"role": "user", "content": text}],
            temperature=0.0,
            max_tokens=max(64, int(len(text.split()) * 2.5)),
        )
        return (r.choices[0].message.content or "").strip()

    def fn(conv: dict) -> dict | None:
        for m in conv["messages"]:
            m["back_en"] = back(m["ur_roman"])
            e = st.encode([m["en"], m["back_en"]], convert_to_tensor=True, normalize_embeddings=True)
            m["similarity"] = float(util.cos_sim(e[0], e[1]))
            sims.append(m["similarity"])
        conv["min_similarity"] = min(m["similarity"] for m in conv["messages"])
        conv["kept"] = conv["min_similarity"] >= threshold
        return conv

    run_resumable(read_jsonl(source), out, fn, label="verify")
    rows = list(read_jsonl(out))
    kept = sum(r["kept"] for r in rows)
    all_sims = [m["similarity"] for r in rows for m in r["messages"]]
    stats = {
        "conversations": len(rows),
        "kept": kept,
        "dropped": len(rows) - kept,
        "threshold": threshold,
        "similarity_mean": round(statistics.mean(all_sims), 3) if all_sims else None,
        "similarity_p10": round(sorted(all_sims)[len(all_sims) // 10], 3) if all_sims else None,
    }
    (URDU_DIR / "stage4_stats.json").write_text(json.dumps(stats, indent=2), encoding="utf-8")
    console.print(stats)


@app.command("build-corpus")
def build_corpus(
    verified: Path = URDU_DIR / "stage4_verified.jsonl",
    english: Path = PROCESSED / "conversations.train.jsonl",
    out: Path = PROCESSED / "conversations.bilingual.train.jsonl",
    urdu_weight: float = typer.Option(1.0, help="Repeat Roman Urdu conversations this many times"),
) -> None:
    """English train set + verified Roman Urdu conversations, in the schema eve_sft.py reads."""
    if out.exists():
        out.unlink()
    n_en = n_ur = 0
    for r in read_jsonl(english):
        append_jsonl(out, r)
        n_en += 1
    for r in read_jsonl(verified):
        if not r.get("kept"):
            continue
        conv = {
            "id": f"{r['id']}-ur",
            "source": f"{r['source']}-ur-roman",
            "lang": "ur-roman",
            "messages": [{"role": m["role"], "content": m["ur_roman"]} for m in r["messages"]],
            "synthetic": True,
            "split": "train",
        }
        for _ in range(max(1, round(urdu_weight))):
            append_jsonl(out, conv)
            n_ur += 1
    console.print(f"wrote {out}: {n_en} English + {n_ur} Roman Urdu conversations")


if __name__ == "__main__":
    app()
