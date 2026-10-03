"""Build Guardian v1's crisis data: written batches, their augmentations, licence-clean public text
and the authored rows for training; separately written batches and the eval probes for testing.

    python -m therapylink_ml.data.guardian_v1 build      # writes data/guardian/build/
    python -m therapylink_ml.data.guardian_v1 stats      # per split, language and label counts

Layout under data/guardian/:

    LABEL_RULES.md            the rules every generated row was labelled with
    written/t*.partN.jsonl    training batches, one author brief per batch
    written/v*.partN.jsonl    validation batches (thresholds are calibrated on these)
    heldout/h*.partN.jsonl    test batches, written apart from the others; never trained or tuned on
    build/                    the built splits (gitignored; rebuilt from the above)

Every built row says where it came from: `source`, `author` (the batch or dataset), `generated`
(written for this project rather than collected), `ai_labelled` (labels assigned by a model rather
than a person) and `commercial_ok` (the source's licence allows a shipped model).
"""

from __future__ import annotations

import json
import random
import re
from collections import Counter
from pathlib import Path

import typer

from therapylink_ml.schema import clean_text, stable_id

ML_ROOT = Path(__file__).resolve().parents[2]
GUARDIAN_DIR = ML_ROOT / "data" / "guardian"
WRITTEN = GUARDIAN_DIR / "written"
HELDOUT = GUARDIAN_DIR / "heldout"
BUILD = GUARDIAN_DIR / "build"
RAW = ML_ROOT / "data" / "raw" / "guardian"
PROBES = ML_ROOT / "therapylink_ml" / "eval" / "probes"

LANGS = ("en", "ur-roman", "mixed", "ur")
SEED = 13

app = typer.Typer(add_completion=False, no_args_is_help=True)


def crisis_labels() -> tuple[str, ...]:
    from therapylink_ml.train.guardian import CRISIS_LABELS

    return CRISIS_LABELS


# --- Rows ------------------------------------------------------------------------------------------


def make_row(text: str, lang: str, labels: list[str], *, source: str, author: str, generated: bool | None,
             ai_labelled: bool | None, commercial_ok: bool, tag: str = "", derived_from: str | None = None) -> dict:
    text = clean_text(text)
    row = {
        "id": stable_id("guardian_v1", source, author, text),
        "text": text,
        "lang": lang,
        "labels": sorted(set(labels), key=crisis_labels().index),
        "source": source,
        "author": author,
        "generated": generated,
        "ai_labelled": ai_labelled,
        "commercial_ok": commercial_ok,
        "tag": tag,
    }
    if derived_from:
        row["derived_from"] = derived_from
    return row


def check_row(row: dict) -> None:
    labels = row["labels"]
    if not row["text"].strip():
        raise ValueError(f"{row['id']}: empty text")
    if row["lang"] not in LANGS:
        raise ValueError(f"{row['id']}: unknown lang {row['lang']!r}")
    if not labels or set(labels) - set(crisis_labels()):
        raise ValueError(f"{row['id']}: labels must be from {crisis_labels()}, got {labels}")
    if "none" in labels and len(labels) > 1:
        raise ValueError(f"{row['id']}: 'none' cannot be combined with {labels}")


def batch_of(path: Path) -> str:
    """`t05.part2.jsonl` → `t05`: one author brief per batch, however many files it took."""
    return path.name.split(".")[0]


# --- The clinical guide (docs/clinical/GUARDIAN_LABELS.md) -----------------------------------------
# The written batches were labelled under LABEL_RULES.md before the guide existed. Where the two
# disagree on a specific row, a decision in RELABEL (made by reading the row against the guide)
# replaces its labels; `guide_labels` then applies the one rule that holds for every row.

RELABEL = GUARDIAN_DIR / "relabel_guide_v1.jsonl"
_CHILD_PARTNERS = {"abuse", "sexual_violence", "harm_to_others"}


def guide_labels(labels: list[str]) -> list[str]:
    """`child` only with the harm done to the child (guide section 1 and rule 13): a minor's own
    suicidal thoughts or self-harm are `suicidal` / `self_harm`, and the under-18 route handles age."""
    out = set(labels)
    if "child" in out and not out & _CHILD_PARTNERS:
        out.discard("child")
    if not out:
        raise ValueError(f"labels {labels} leave nothing once a lone 'child' is dropped; label the harm")
    return sorted(out, key=crisis_labels().index)


def read_relabels(path: Path = RELABEL) -> dict[str, dict]:
    """{"t03.part1.jsonl:5": {"text": ..., "labels": [...]}} — the row key is file:0-based line."""
    if not path.exists():
        return {}
    out = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.strip():
            d = json.loads(line)
            out[d["key"]] = d
    return out


def read_batches(directory: Path, prefix: str, relabels: dict[str, dict] | None = None) -> list[dict]:
    relabels = read_relabels() if relabels is None else relabels
    rows = []
    for path in sorted(directory.glob(f"{prefix}*.jsonl")):
        with path.open(encoding="utf-8") as f:
            for n, line in enumerate(f, 1):
                if not line.strip():
                    continue
                r = json.loads(line)
                labels = r["labels"]
                fix = relabels.get(f"{path.name}:{n - 1}")
                if fix:
                    if clean_text(fix["text"]) != clean_text(r["text"]):
                        raise ValueError(f"{path.name}:{n}: relabel decision is for different text; rebuild {RELABEL.name}")
                    labels = fix["labels"]
                try:
                    labels = guide_labels(labels) if labels != ["none"] else labels
                    row = make_row(r["text"], r["lang"], labels, source="written", author=batch_of(path), generated=True,
                                   ai_labelled=True, commercial_ok=True, tag=r.get("tag", ""))
                    for k in ("acuity", "hard_negative", "distress", "who"):
                        if k in r:
                            row[k] = r[k]
                    check_row(row)
                except ValueError as e:
                    raise ValueError(f"{path.name}:{n}: {e}") from None
                rows.append(row)
    return rows


# --- The eval probes join the held-out set ---------------------------------------------------------


# Where the guide labels a probe differently from its category's mapping: s09 is a method comparison
# (rule 3: any method question is suicidal) about self-harm; s10 is the guide's example C3.
PROBE_LABELS = {"s09": ["suicidal", "self_harm"], "s10": ["child", "sexual_violence"]}


def probe_rows(probes: Path = PROBES) -> list[dict]:
    """safety.jsonl and therapeutic.jsonl as held-out rows. Crisis probes take their category's labels
    (the same mapping the authored rows use); everyday and therapeutic probes are 'none'."""
    from therapylink_ml.train.guardian import AUTHORED_CATEGORY_LABELS

    rows = []
    for name in ("safety.jsonl", "therapeutic.jsonl"):
        with (probes / name).open(encoding="utf-8") as f:
            for line in f:
                if not line.strip():
                    continue
                p = json.loads(line)
                labels = PROBE_LABELS.get(p["id"]) or (AUTHORED_CATEGORY_LABELS[p["category"]] if p.get("route") == "crisis" else ["none"])
                rows.append(make_row(p["text"], p["lang"], labels, source="eval_probe", author=f"probe:{p['id']}",
                                     generated=True, ai_labelled=False, commercial_ok=True, tag=p.get("category") or "therapeutic"))
    return rows


# --- Public, licence-clean text --------------------------------------------------------------------


def public_ok(key: str) -> bool:
    """Whether the dataset registry says `key` may train a shipped model."""
    from therapylink_ml.data.registry import get

    return get(key).commercial_ok


def mh_text_rows(n_suicidal: int, n_none: int, rng: random.Random, path: Path = RAW / "mh_text.crisis.jsonl") -> list[dict]:
    """English Reddit posts (suicidal vs not). A 'none' post the keyword floor reads as suicidal is
    dropped: the source labels by subreddit, and a depression post that says "I want to die" taught
    as 'none' would train the miss we are trying to fix."""
    from therapylink_ml.train.guardian import keyword_kind

    if not path.exists() or not public_ok("mh_text"):
        return []
    suicidal, none = [], []
    with path.open(encoding="utf-8") as f:
        for line in f:
            r = json.loads(line)
            text = r["text"][:1200]
            if r["labels"] == ["suicidal"]:
                suicidal.append(text)
            elif keyword_kind(text) is None:
                none.append(text)
    rng.shuffle(suicidal)
    rng.shuffle(none)
    rows = [make_row(t, "en", ["suicidal"], source="mh_text", author="mh_text", generated=False, ai_labelled=False,
                     commercial_ok=True, tag="reddit") for t in suicidal[:n_suicidal]]
    rows += [make_row(t, "en", ["none"], source="mh_text", author="mh_text", generated=False, ai_labelled=False,
                      commercial_ok=True, tag="reddit") for t in none[:n_none]]
    return rows


_URDU_RISK = re.compile(r"(خودکشی|خود کشی|مرنا|مر جا|مرجا|جان دے|جان لے|زہر|موت|زندگی ختم|ختم کر دو|ختم کر لو)")


def urdu_mh_rows(n: int, rng: random.Random, path: Path = RAW / "urdu_mh.jsonl") -> list[dict]:
    """Urdu-script tweets labelled anxiety/depression/neutral, used as 'none' only, minus any that
    mention dying. Mostly machine-translated (see the registry note), so they are a small share."""
    if not path.exists() or not public_ok("urdu_mh"):
        return []
    texts = []
    with path.open(encoding="utf-8") as f:
        for line in f:
            text = json.loads(line)["text"]
            if not _URDU_RISK.search(text) and len(text) >= 8:
                texts.append(text)
    rng.shuffle(texts)
    return [make_row(t, "ur", ["none"], source="urdu_mh", author="urdu_mh", generated=False, ai_labelled=False,
                     commercial_ok=True, tag="tweet") for t in texts[:n]]


def mt_rows(path: Path | None = None) -> list[dict]:
    """Machine-translated rows from guardian_mt: one Urdu-script and one rough Roman Urdu row per
    English source row, both carrying the English row's labels."""
    path = path or GUARDIAN_DIR / "mt" / "translated.jsonl"
    if not path.exists():
        return []
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        r = json.loads(line)
        human = r["from"] == "mh_text"
        if not mt_ok(r["text"], r.get("ur") or ""):
            continue
        for lang, text in (("ur", r.get("ur")), ("ur-roman", r.get("roman"))):
            if text and len(text.strip()) >= 4:
                row = make_row(text, lang, r["labels"], source="mt", author=f"mt:{r['from']}", generated=not human,
                               ai_labelled=not human, commercial_ok=True, tag=r.get("tag", ""), derived_from=r["id"])
                row["en_text"] = r["text"]
                rows.append(row)
    return rows


# opus-mt-en-ur was trained largely on scripture and sometimes answers with an unrelated, quoted
# sentence. Those keep the English row's label on text that no longer says it, so they are dropped.
_MT_JUNK = re.compile(r"[“”:«»]|یہوواہ|خدا کے کلام|بائبل")


def mt_ok(en: str, ur: str) -> bool:
    """Whether a translation looks like a translation: similar length, no scripture-style quoting."""
    if not ur.strip():
        return False
    ratio = len(ur) / max(len(en), 1)
    return 0.6 <= ratio <= 1.6 and not _MT_JUNK.search(ur)


VAL_FRAC = 0.15
# guardian_mt only translates mh_text posts up to this length, so validation posts are taken from
# longer ones: a validation post must not reach training as its own translation.
MT_MAX_CHARS = 320


def split_written(rows: list[dict], val_frac: float = VAL_FRAC) -> tuple[list[dict], list[dict]]:
    """(train, val) from the written training batches: within each (batch, label set) group a stable
    `val_frac` share by id goes to validation, so thresholds are calibrated on every label and
    language without a single row being trained on. Deterministic across runs and machines."""
    groups: dict[tuple, list[dict]] = {}
    for r in rows:
        groups.setdefault((r["author"], tuple(r["labels"])), []).append(r)
    train, val = [], []
    for group in groups.values():
        group = sorted(group, key=lambda r: r["id"])
        n_val = round(val_frac * len(group)) if len(group) >= 4 else 0
        val += group[:n_val]
        train += group[n_val:]
    return train, val


def authored_rows() -> tuple[list[dict], list[dict]]:
    """The approved authored rows (train, val), split the way guardian.py always has."""
    from therapylink_ml.train.guardian import authored_crisis_texts, split_authored

    train, val = split_authored(authored_crisis_texts())

    def conv(items):
        return [make_row(it.text, it.lang, guide_labels(it.labels) if it.labels != ["none"] else it.labels, source="tl_authored", author="tl_authored", generated=True,
                         ai_labelled=False, commercial_ok=True, tag="authored") for it in items]

    return conv(train), conv(val)


# --- Augmentation ----------------------------------------------------------------------------------
# Roman Urdu has no standard spelling, and a model that only saw "nahi" misses "nai". Each written
# training row gets a copy with words swapped for other common spellings and typing noise.

ROMAN_VARIANTS: dict[str, tuple[str, ...]] = {
    "hai": ("hy", "he", "hay", "h", "hai"),
    "hain": ("hen", "hn", "hai"),
    "nahi": ("nahin", "nai", "nhi", "ni", "nahi"),
    "nahin": ("nahi", "nhi", "nai"),
    "main": ("mai", "mein", "me", "main"),
    "mein": ("main", "me", "mai", "mei"),
    "hoon": ("hun", "hu", "hn", "hon"),
    "hun": ("hoon", "hu"),
    "kya": ("kia", "kyaa", "kiya"),
    "zindagi": ("zindgi", "zndgi", "zindagee", "zindagy"),
    "khudkushi": ("khud kushi", "khudkhushi", "khudkashi", "khud-kushi"),
    "marna": ("mrna", "marnaa"),
    "chahta": ("chahata", "chata", "chahtaa"),
    "chahti": ("chahati", "chati"),
    "bohat": ("bohot", "bht", "bahut", "bhot", "buhat"),
    "bahut": ("bohat", "bht", "bohot"),
    "kar": ("kr",),
    "raha": ("rha", "rahaa"),
    "rahi": ("rhi",),
    "mujhe": ("mujhay", "muje", "mjhe", "mujhy"),
    "sab": ("sb",),
    "kuch": ("kch", "kuchh"),
    "liye": ("liay", "lye", "liya"),
    "behtar": ("bhtr", "behter"),
    "khatam": ("khtm", "khatm"),
    "yaar": ("yar", "yr"),
    "kyun": ("kyon", "kiun", "q"),
    "kabhi": ("kbhi",),
    "lagta": ("lgta",),
    "gaya": ("gya",),
    "gayi": ("gyi", "gai", "gayee"),
    "karna": ("krna",),
    "karun": ("karoon", "krun", "karu"),
    "bhi": ("bhee", "b"),
    "pata": ("pta",),
    "koi": ("koe",),
    "maarta": ("marta", "maartaa"),
    "shohar": ("shauhar", "shoher"),
    "zabardasti": ("zabrdasti", "zbrdsti"),
    "ghalat": ("galat", "ghlt"),
    "aur": ("or", "aurr"),
    "please": ("plz", "pls"),
    "abhi": ("abi", "abhee"),
    "tha": ("thaa",),
    "thi": ("thee",),
}
_WORD = re.compile(r"[A-Za-z]+")
_EMOJI = ("😔", "😞", "💔", "🙏", "😢", "😶", "...")


def respell_roman(text: str, rng: random.Random, p: float = 0.5) -> str:
    def swap(m: re.Match) -> str:
        w = m.group(0)
        options = ROMAN_VARIANTS.get(w.lower())
        if not options or rng.random() > p:
            return w
        return rng.choice(options)

    return _WORD.sub(swap, text)


def respell_urdu(text: str, rng: random.Random) -> str:
    if rng.random() < 0.3:
        text = text.replace("ہے", "ھے")
    if rng.random() < 0.15:  # Arabic-keyboard yeh and kaf
        text = text.replace("ی", "ي").replace("ک", "ك")
    if rng.random() < 0.4:
        text = text.replace("۔", "")
    return text


def noise(text: str, rng: random.Random) -> str:
    if rng.random() < 0.3:
        text = text.lower()
    if rng.random() < 0.15:
        text = re.sub(r"[.,!?;:'\"]", "", text)
    elif rng.random() < 0.3:
        text = text.rstrip(".!?")
    if rng.random() < 0.1:
        words = text.split(" ")
        i = rng.randrange(len(words))
        words[i] = re.sub(r"([aeiouy])", lambda m: m.group(1) * rng.randint(2, 4), words[i], count=1)
        text = " ".join(words)
    if rng.random() < 0.1:
        text = f"{text} {rng.choice(_EMOJI)}"
    return text


def augment(row: dict, rng: random.Random) -> dict | None:
    text = row["text"]
    if row["lang"] in ("ur-roman", "mixed"):
        text = respell_roman(text, rng)
    elif row["lang"] == "ur":
        text = respell_urdu(text, rng)
    text = noise(text, rng)
    if clean_text(text).lower() == row["text"].lower():
        return None
    return make_row(text, row["lang"], row["labels"], source="augmented", author=row["author"], generated=True,
                    ai_labelled=row["ai_labelled"], commercial_ok=row["commercial_ok"], tag=row["tag"], derived_from=row["id"])


# --- Leakage guard ---------------------------------------------------------------------------------


def norm(text: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"[^\w\s]", " ", text.lower())).strip()


def near_duplicates(rows: list[dict], reference: list[dict], threshold: float = 0.7) -> set[str]:
    """Ids of `rows` whose word set overlaps some reference row by Jaccard ≥ `threshold`, or matches
    one exactly once punctuation and case are gone. Used to keep the test set out of training."""
    from sklearn.feature_extraction.text import CountVectorizer

    if not rows or not reference:
        return set()
    vec = CountVectorizer(binary=True, token_pattern=r"(?u)\b\w+\b", lowercase=True)
    vec.fit([norm(r["text"]) for r in reference] + [norm(r["text"]) for r in rows])
    a = vec.transform([norm(r["text"]) for r in rows])
    b = vec.transform([norm(r["text"]) for r in reference])
    inter = (a @ b.T).tocsr()
    size_a = a.sum(axis=1).A1
    size_b = b.sum(axis=1).A1
    exact = {norm(r["text"]) for r in reference}
    out = set()
    for i, row in enumerate(rows):
        if norm(row["text"]) in exact:
            out.add(row["id"])
            continue
        start, end = inter.indptr[i], inter.indptr[i + 1]
        if start == end:
            continue
        cols, vals = inter.indices[start:end], inter.data[start:end]
        jac = vals / (size_a[i] + size_b[cols] - vals)
        if jac.max() >= threshold:
            out.add(row["id"])
    return out


def dedupe(rows: list[dict]) -> list[dict]:
    seen, out = set(), []
    for r in rows:
        key = norm(r["text"])
        if key in seen:
            continue
        seen.add(key)
        out.append(r)
    return out


# --- Build -----------------------------------------------------------------------------------------


def build_splits(
    written: Path = WRITTEN,
    heldout: Path = HELDOUT,
    probes: Path = PROBES,
    n_mh_suicidal: int = 3000,
    n_mh_none: int = 5000,
    n_urdu_mh: int = 2000,
    n_mh_val: int = 300,
    augment_copies: int = 1,
    with_mt: bool = True,
    mt_path: Path | None = None,
    raw: Path = RAW,
    seed: int = SEED,
) -> dict[str, list[dict]]:
    rng = random.Random(seed)
    test = dedupe(read_batches(heldout, "h") + probe_rows(probes))
    train_written, val_written = split_written(read_batches(written, "t"))
    val_written += read_batches(written, "v")
    a_train, a_val = authored_rows()
    mh = mh_text_rows(n_mh_suicidal + n_mh_val, n_mh_none + n_mh_val, rng, raw / "mh_text.crisis.jsonl")
    mh_val = []
    for label in ("suicidal", "none"):
        mh_val += [r for r in mh if r["labels"] == [label] and len(r["text"]) > MT_MAX_CHARS][: n_mh_val // 2]
    mh_val_ids = {r["id"] for r in mh_val}

    train = list(train_written)
    for _ in range(augment_copies):
        train += [a for r in train_written if (a := augment(r, rng))]
    # A validation row's translation would hand its content to training in another script.
    val_en = {norm(r["text"]) for r in val_written}
    mt = [r for r in mt_rows(mt_path) if norm(r["en_text"]) not in val_en] if with_mt else []
    corrected = {norm(r["text"]): r["labels"] for r in train_written}
    for r in mt:
        r["labels"] = corrected.get(norm(r["en_text"]), r["labels"])
        if r["labels"] != ["none"]:
            r["labels"] = guide_labels(r["labels"])
    train += a_train + [r for r in mh if r["id"] not in mh_val_ids] + urdu_mh_rows(n_urdu_mh, rng, raw / "urdu_mh.jsonl") + mt
    val = val_written + a_val + mh_val

    # Test first: anything in train or val that is (nearly) a test row goes, never the test row.
    # Translated rows are checked on their English source too.
    leak = near_duplicates(train + val, test)
    leak |= near_duplicates([{"id": r["id"], "text": r["en_text"]} for r in mt], test)
    train = dedupe([r for r in train if r["id"] not in leak])
    val = dedupe([r for r in val if r["id"] not in leak])
    val_keys = {norm(r["text"]) for r in val}
    train = [r for r in train if norm(r["text"]) not in val_keys]
    for split, rows in (("train", train), ("val", val), ("test", test)):
        for r in rows:
            check_row(r)
            r["split"] = split
        if any(not r["commercial_ok"] for r in rows):
            raise ValueError(f"{split} has rows from a source not cleared for a shipped model")
    rng.shuffle(train)
    return {"train": train, "val": val, "test": test, "_leaked": sorted(leak)}


def stats(splits: dict[str, list[dict]]) -> dict:
    out = {}
    for split in ("train", "val", "test"):
        rows = splits[split]
        by = Counter((r["lang"], lab) for r in rows for lab in r["labels"])
        out[split] = {
            "rows": len(rows),
            "by_lang": dict(Counter(r["lang"] for r in rows)),
            "by_lang_label": {f"{lang}|{lab}": n for (lang, lab), n in sorted(by.items())},
            "by_source": dict(Counter(r["source"] for r in rows)),
            "generated": sum(1 for r in rows if r["generated"]),
            "ai_labelled": sum(1 for r in rows if r["ai_labelled"]),
        }
    return out


def markdown_table(split_stats: dict) -> str:
    labels = crisis_labels()
    lines = ["| lang | " + " | ".join(labels) + " | rows |", "|---|" + "---:|" * (len(labels) + 1)]
    for lang in LANGS:
        cells = [str(split_stats["by_lang_label"].get(f"{lang}|{lab}", 0)) for lab in labels]
        lines.append(f"| {lang} | " + " | ".join(cells) + f" | {split_stats['by_lang'].get(lang, 0)} |")
    return "\n".join(lines)


def write_splits(splits: dict[str, list[dict]], out: Path = BUILD) -> None:
    from therapylink_ml.schema import LabeledText

    out.mkdir(parents=True, exist_ok=True)
    for split in ("train", "val", "test"):
        with (out / f"rows.{split}.jsonl").open("w", encoding="utf-8") as f:
            for r in splits[split]:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
        # The shape guardian.py's TaskData reads.
        with (out / f"labeled.crisis.{split}.jsonl").open("w", encoding="utf-8") as f:
            for r in splits[split]:
                lt = LabeledText(id=r["id"], source=r["source"], lang=r["lang"], text=r["text"], task="crisis", labels=r["labels"], split=split)
                f.write(lt.model_dump_json() + "\n")
        # The held-out file shape `guardian heldout` reads.
    with (out / "heldout.jsonl").open("w", encoding="utf-8") as f:
        for r in splits["test"]:
            f.write(json.dumps({"id": r["id"], "text": r["text"], "lang": r["lang"], "labels": r["labels"], "source": r["source"]}, ensure_ascii=False) + "\n")
    (out / "stats.json").write_text(json.dumps({**stats(splits), "leaked_dropped": len(splits["_leaked"])}, indent=2), encoding="utf-8")


@app.command()
def build(out: Path = BUILD, seed: int = SEED, augment_copies: int = 1) -> None:
    splits = build_splits(seed=seed, augment_copies=augment_copies)
    write_splits(splits, out)
    s = stats(splits)
    for split in ("train", "val", "test"):
        typer.echo(f"\n{split}: {s[split]['rows']} rows  sources {s[split]['by_source']}")
        typer.echo(markdown_table(s[split]))
    typer.echo(f"\ndropped {len(splits['_leaked'])} train/val rows that nearly duplicate a test row")


@app.command("stats")
def show_stats(out: Path = BUILD) -> None:
    typer.echo((out / "stats.json").read_text(encoding="utf-8"))


if __name__ == "__main__":
    app()
