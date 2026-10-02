from __future__ import annotations

import json
import os
import random
import statistics
import time
from collections import Counter, defaultdict
from pathlib import Path

ML_ROOT = Path(__file__).resolve().parents[2]
os.environ.setdefault("HF_HOME", str(ML_ROOT / "data" / "cache"))

import typer  # noqa: E402
from rich.console import Console  # noqa: E402
from rich.table import Table  # noqa: E402

from therapylink_ml.data import registry  # noqa: E402
from therapylink_ml.data.splits import assign_splits, dedupe  # noqa: E402
from therapylink_ml.schema import Conversation, LabeledText, normalise_messages  # noqa: E402

app = typer.Typer(add_completion=False, no_args_is_help=True)
console = Console()

MAX_CHARS = 12_000
MAX_TURNS = 40
DEFAULT_OUT = ML_ROOT / "data" / "processed"


@app.command("list")
def list_datasets() -> None:
    table = Table(title="Registered datasets")
    for col in ("key", "kind", "license", "commercial", "location"):
        table.add_column(col)
    for d in registry.all_datasets():
        table.add_row(d.key, d.kind, d.license, "yes" if d.commercial_ok else "NO", d.location)
    console.print(table)


def _trim(conv: Conversation) -> Conversation | None:
    """Normalise to the canonical shape; drop anything left too short or too long."""
    msgs = normalise_messages(conv.messages, max_turns=MAX_TURNS)
    if len(msgs) < 2 or sum(len(m.content) for m in msgs) > MAX_CHARS:
        return None
    return conv.model_copy(update={"messages": msgs})


def _write_jsonl(path: Path, items: list) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        for item in items:
            f.write(item.model_dump_json(exclude_none=True) + "\n")


@app.command("build")
def build(
    only: list[str] = typer.Option(None, "--only", help="Dataset keys to include"),
    out: Path = typer.Option(DEFAULT_OUT, "--out"),
    val_frac: float = 0.03,
    test_frac: float = 0.03,
    seed: int = 13,
    include_pending: bool = typer.Option(False, help="Include authored rows still pending clinician review (inspection only, never a shipping corpus)"),
) -> None:
    """Download every registered source, normalise, dedupe, split, and write JSONL + a data card."""
    # The default out dir is what eve_sft and the Kaggle notebooks train on. Rows pending review
    # go somewhere else, so remembering --out is not what keeps them out of a model.
    if include_pending and out.resolve() == DEFAULT_OUT.resolve():
        raise typer.BadParameter(f"--include-pending needs an --out other than {DEFAULT_OUT}, the corpus training reads")
    datasets = registry.all_datasets()
    if only:
        datasets = [d for d in datasets if d.key in set(only)]

    convs: list[Conversation] = []
    labeled: list[LabeledText] = []
    stats: dict[str, dict] = {}

    for d in datasets:
        t0 = time.time()
        with console.status(f"[bold]{d.key}[/] loading…"):
            raw = list(d.loader(include_pending=True) if include_pending and d.key == "tl_authored" else d.loader())
        loaded = len(raw)
        if d.kind == "conversation":
            kept = [c for c in (_trim(c) for c in raw) if c is not None]
            convs.extend(kept)
        else:
            kept = raw
            labeled.extend(kept)
        stats[d.key] = {"loaded": loaded, "after_filter": len(kept), "seconds": round(time.time() - t0, 1)}
        console.print(f"  {d.key}: {loaded} loaded, {len(kept)} kept ({stats[d.key]['seconds']}s)")

    convs, conv_dupes = dedupe(convs)
    labeled, lab_dupes = dedupe(labeled)
    assign_splits(convs, val_frac=val_frac, test_frac=test_frac, seed=seed)
    assign_splits(labeled, val_frac=val_frac, test_frac=test_frac, seed=seed)

    for split in ("train", "val", "test"):
        _write_jsonl(out / f"conversations.{split}.jsonl", [c for c in convs if c.split == split])
    by_task: dict[str, list[LabeledText]] = defaultdict(list)
    for item in labeled:
        by_task[item.task].append(item)
    for task, items in by_task.items():
        for split in ("train", "val", "test"):
            _write_jsonl(out / f"labeled.{task}.{split}.jsonl", [i for i in items if i.split == split])

    summary = _summarise(datasets, convs, labeled, stats, conv_dupes, lab_dupes, seed)
    (out / "stats.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    (out / "DATA_CARD.md").write_text(_data_card(datasets, summary), encoding="utf-8")
    (out / "samples.md").write_text(_samples(convs, labeled, seed), encoding="utf-8")

    console.print(f"\n[green]wrote[/] {out}")
    console.print(f"  conversations: {len(convs)} (dropped {conv_dupes} duplicates)")
    console.print(f"  labeled texts: {len(labeled)} (dropped {lab_dupes} duplicates)")


def _summarise(datasets, convs, labeled, stats, conv_dupes, lab_dupes, seed) -> dict:
    per_source: dict[str, dict] = {}
    for d in datasets:
        items = [c for c in convs if c.source == d.key] or [t for t in labeled if t.source == d.key]
        splits = Counter(i.split for i in items)
        row = {
            **stats[d.key],
            "final": len(items),
            "train": splits.get("train", 0),
            "val": splits.get("val", 0),
            "test": splits.get("test", 0),
        }
        if items and isinstance(items[0], Conversation):
            row["avg_turns"] = round(statistics.mean(len(c.messages) for c in items), 1)
            row["avg_chars"] = round(
                statistics.mean(sum(len(m.content) for m in c.messages) for c in items)
            )
            strategies = Counter(
                m.strategy for c in items for m in c.messages if m.strategy
            )
            if strategies:
                row["strategies"] = dict(strategies.most_common())
        else:
            row["labels"] = dict(Counter(lab for t in items for lab in t.labels).most_common())
        per_source[d.key] = row
    return {
        "seed": seed,
        "conversations_total": len(convs),
        "conversation_duplicates_dropped": conv_dupes,
        "labeled_total": len(labeled),
        "labeled_duplicates_dropped": lab_dupes,
        "sources": per_source,
    }


def _data_card(datasets, summary: dict) -> str:
    lines = [
        "# TherapyLink corpus — data card",
        "",
        f"Generated by `tl-data build` (seed {summary['seed']}). "
        f"{summary['conversations_total']} conversations and {summary['labeled_total']} labeled texts "
        "after exact-duplicate removal.",
        "",
        "| Source | Kind | License | Commercial use | Loaded | Final | Train / Val / Test |",
        "|---|---|---|---|---:|---:|---|",
    ]
    for d in datasets:
        s = summary["sources"][d.key]
        lines.append(
            f"| {d.key} | {d.kind} | {d.license} | {'yes' if d.commercial_ok else '**no**'} | "
            f"{s['loaded']} | {s['final']} | {s['train']} / {s['val']} / {s['test']} |"
        )
    nc = [d for d in datasets if not d.commercial_ok]
    if nc:
        lines += [
            "",
            "## Non-commercial sources",
            "",
            "The following sources carry non-commercial or unverified terms. Any model trained on this "
            "corpus inherits those restrictions and must say so in its model card:",
            "",
        ] + [f"- **{d.key}** — {d.license}" for d in nc]
    lines += ["", "## Sources", ""]
    for d in datasets:
        lines += [f"### {d.key}", "", f"- Location: `{d.location}`", f"- Citation: {d.citation}"]
        if d.notes:
            lines.append(f"- Notes: {d.notes}")
        s = summary["sources"][d.key]
        if "avg_turns" in s:
            lines.append(f"- Avg turns: {s['avg_turns']}, avg chars: {s['avg_chars']}")
        if "strategies" in s:
            top = ", ".join(f"{k} ({v})" for k, v in list(s["strategies"].items())[:8])
            lines.append(f"- Strategy labels: {top}")
        if "labels" in s:
            top = ", ".join(f"{k} ({v})" for k, v in list(s["labels"].items())[:10])
            lines.append(f"- Labels: {top}")
        lines.append("")
    return "\n".join(lines)


def _samples(convs, labeled, seed: int, per_source: int = 3) -> str:
    rng = random.Random(seed)
    lines = ["# Random samples per source", ""]
    by_source: dict[str, list] = defaultdict(list)
    for c in convs:
        by_source[c.source].append(c)
    for t in labeled:
        by_source[t.source].append(t)
    for source, items in sorted(by_source.items()):
        lines += [f"## {source}", ""]
        for item in rng.sample(items, min(per_source, len(items))):
            if isinstance(item, Conversation):
                for m in item.messages[:6]:
                    tag = f" _[{m.strategy}]_" if m.strategy else ""
                    lines.append(f"**{m.role}**{tag}: {m.content[:400]}")
                    lines.append("")
                if len(item.messages) > 6:
                    lines.append(f"_… {len(item.messages) - 6} more turns_")
            else:
                lines.append(f"`{', '.join(item.labels)}` — {item.text[:300]}")
            lines += ["", "---", ""]
    return "\n".join(lines)


if __name__ == "__main__":
    app()
