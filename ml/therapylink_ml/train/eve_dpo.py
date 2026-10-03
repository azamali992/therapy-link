"""Eve preference tuning.

`build-pairs` makes (context, chosen, rejected) triples on-policy: the picked SFT checkpoint answers
each prompt k times through a local OpenAI-compatible server (llama-server with the LoRA GGUF), the
hard rules in reply_rules.py score every sample, and a passing sample is paired against a failing
one. Both sides come from the model being tuned, so DPO learns "be safe" rather than "sound like a
transcript". The gold AnnoMI/ESConv turns used before were a median of 12-18 words, which pulled
towards the one-line collapse that sank v13, and ESConv is non-commercial.

`train` runs DPO with Unsloth + TRL on those pairs. The SFT adapter is loaded twice: "default" is
trained, "reference" stays frozen and is the KL anchor, so the reference is the SFT policy and not
stock Gemma (which is what ref_model=None on a PEFT model means).
"""

from __future__ import annotations

import hashlib
import inspect
import json
import shutil
from collections import Counter
from collections.abc import Callable, Iterator
from pathlib import Path
from typing import NamedTuple

import typer

from therapylink_ml.prompts import fold_system_into_first_user
from therapylink_ml.train.reply_rules import ReplyScore, crisis_turn, score_reply

ML_ROOT = Path(__file__).resolve().parents[2]
DATA = ML_ROOT / "data" / "processed"

app = typer.Typer(add_completion=False, no_args_is_help=True)

# The register v14's good replies had: long enough to reflect, short enough to not be an essay.
TARGET_WORDS = 80
# Below this a reply is the one-line register v13 collapsed into; the shortest authored gold reply
# is 33 words. A short or cut-off sample can still be the rejected side, never the chosen one.
MIN_WORDS = 30
POLICY, REFERENCE = "default", "reference"


def _read_jsonl(path: Path):
    with path.open(encoding="utf-8") as f:
        for line in f:
            if line.strip():
                yield line


def authored_prompts(include_pending: bool = False) -> Iterator[dict]:
    """A pair prompt at every user turn of the authored rows (the loader's pending rule applies).

    A crisis row is scored as crisis only from the turn its risk appears (crisis_turn). Its earlier,
    ordinary turns are everyday prompts: scoring them as crisis would reward a helpline for "rough
    time since losing my job", the over-reaction the system prompt rules out.
    """
    from therapylink_ml.data.loaders.authored import rows

    for r in rows(include_pending=include_pending):
        msgs = r["messages"]
        risk_from = crisis_turn(r) if r["route"] == "crisis" else 0
        for k, m in enumerate(msgs):
            if m["role"] != "user":
                continue
            before_risk = k < risk_from
            yield {
                "id": f"{r['id']}@{k}",
                "lang": r["lang"],
                "route": "eve" if before_risk else r["route"],
                "bucket": "none" if before_risk else r["category"],
                "messages": msgs[: k + 1],
                "notes": r.get("notes"),
            }


def load_prompts(spec: str, include_pending: bool = False) -> list[dict]:
    """`authored`, or a JSONL of {id, lang, route, bucket?, messages | text, notes?, rewrite?}.

    `rewrite` is a psychologist-approved chosen reply ({content, review_status: "approved"}), used
    only when no sample passes. It is off-policy, so build-pairs caps its share.
    """
    if spec == "authored":
        return list(authored_prompts(include_pending))
    out = []
    for line in _read_jsonl(Path(spec)):
        r = json.loads(line)
        if "messages" not in r:
            r["messages"] = [{"role": "user", "content": r["text"]}]
        out.append(r)
    return out


def pick_pair(samples: list[str], scores: list[ReplyScore]) -> tuple[int, int] | None:
    """Indices (chosen, rejected), or None when the prompt teaches nothing.

    All samples passing means the model already does this; none passing means there is no
    on-policy chosen side. Chosen is the passing sample nearest TARGET_WORDS, so the pairs don't
    reward length either way; rejected is the sample breaking the most rules.
    """
    passing = [i for i, s in enumerate(scores) if s.passed]
    failing = [i for i, s in enumerate(scores) if not s.passed]
    if not passing or not failing:
        return None
    # Fewer soft flags first (an unverified "free, 24/7" claim), then length.
    chosen = min(passing, key=lambda i: (len(scores[i].soft), abs(len(samples[i].split()) - TARGET_WORDS)))
    rejected = max(failing, key=lambda i: len(scores[i].failures))
    return chosen, rejected


class Sample(NamedTuple):
    text: str
    truncated: bool = False


def score_sample(route: str, lang: str, sample: Sample, *, rubric: bool = False) -> ReplyScore:
    """score_reply plus what only matters for a chosen side: long enough, and not cut off.

    `rubric` adds the v17 checks (train/dpo_rubric.py): R1 praise, the R5 safety question,
    therapist talk, step plans, diagnosis, and unverified helpline claims as a soft flag.
    """
    score = score_reply(route, lang, sample.text)
    if len(sample.text.split()) < MIN_WORDS:
        score.failures.append("too_short")
    if sample.truncated:
        score.failures.append("truncated")
    if rubric:
        from therapylink_ml.train.dpo_rubric import rubric as v17_rubric

        hard, soft = v17_rubric(route, lang, sample.text)
        score.failures.extend(hard)
        score.soft.extend(soft)
    return score


def make_pairs(
    prompts: list[dict],
    generate: Callable[[list[dict]], str | Sample],
    *,
    k: int = 4,
    done: set[str] | None = None,
    max_rewrite_share: float = 0.25,
    rubric: bool = False,
    rewrite_statuses: tuple[str, ...] = ("approved",),
    draw: Callable[[list[dict], int], list[str | Sample]] | None = None,
    on_samples: Callable[[dict, list[Sample], list[ReplyScore]], None] | None = None,
) -> Iterator[dict]:
    """Pair rows for `prompts`, sampling `k` replies each through `generate(messages)`.

    `generate` returns the text, or a Sample that also says whether the reply hit the token cap.
    `draw(messages, k)`, when given, returns all k at once (build-pairs runs them concurrently).
    `on_samples` sees every prompt's samples and scores, paired or not (the samples log).
    A rewrite counts only when its review_status is in `rewrite_statuses`.
    """
    done = done or set()
    written = rewrites = 0
    for p in prompts:
        if p["id"] in done or p["messages"][-1]["role"] != "user":
            continue
        folded = fold_system_into_first_user(p["messages"], notes=p.get("notes"))
        raw = draw(folded, k) if draw else [generate(folded) for _ in range(k)]
        drawn = [_as_sample(d) for d in raw]
        samples = [d.text for d in drawn]
        scores = [score_sample(p["route"], p["lang"], d, rubric=rubric) for d in drawn]
        if on_samples:
            on_samples(p, drawn, scores)
        picked = pick_pair(samples, scores)
        chosen_source = "policy"
        rewritten_by = None
        if picked is None:
            rewrite = p.get("rewrite") or {}
            all_fail = not any(s.passed for s in scores)
            under_cap = rewrites + 1 <= max_rewrite_share * (written + 1)
            if not (all_fail and rewrite.get("review_status") in rewrite_statuses and under_cap):
                continue
            worst = max(range(k), key=lambda i: len(scores[i].failures))
            chosen_text, rejected = rewrite["content"], worst
            chosen_failures: list[str] = []
            chosen_source = "rewrite"
            rewritten_by = rewrite.get("rewritten_by")
            rewrites += 1
        else:
            chosen, rejected = picked
            chosen_text, chosen_failures = samples[chosen], scores[chosen].failures
        written += 1
        yield {
            "prompt_id": p["id"],
            "bucket": p.get("bucket", ""),
            "route": p["route"],
            "lang": p["lang"],
            "chosen_source": chosen_source,
            **({"rewritten_by": rewritten_by} if rewritten_by else {}),
            "prompt": folded,
            "chosen": [{"role": "assistant", "content": chosen_text}],
            "rejected": [{"role": "assistant", "content": samples[rejected]}],
            "chosen_failures": chosen_failures,
            "rejected_failures": scores[rejected].failures,
        }


def _as_sample(out: str | Sample) -> Sample:
    return Sample(out.strip()) if isinstance(out, str) else Sample(out.text.strip(), out.truncated)


def hit_cap(tokens: int | None, text: str, max_tokens: int) -> bool:
    """Whether a reply stopped at the token cap rather than finishing.

    The backend keeps no finish_reason, but it does report completion tokens; a reply that used all
    of them was cut. Without a count, a reply that doesn't end a sentence is treated as cut.
    """
    if tokens is not None:
        return tokens >= max_tokens
    return not text.rstrip().endswith((".", "!", "?", "\"", "'", ")", "۔"))


@app.command("build-pairs")
def build_pairs(
    backend: str = typer.Option(..., help="The picked SFT checkpoint behind a local server: openai:<url>|<model>"),
    prompts: str = typer.Option("authored", help="'authored' (every user turn of the authored rows) or a prompts JSONL. Never the eval probes."),
    out: Path = DATA / "dpo_pairs.jsonl",
    k: int = typer.Option(4, help="Samples per prompt"),
    temperature: float = 0.9,
    max_tokens: int = typer.Option(450, help="The app's reply cap"),
    include_pending: bool = typer.Option(False, help="Also use authored rows still pending clinician review"),
    max_rewrite_share: float = typer.Option(0.25, help="Cap on off-policy approved rewrites as the chosen side"),
    rubric: bool = typer.Option(True, help="Also score with the v17 rubric (train/dpo_rubric.py): R1 praise, R5 safety question, therapist talk, step plans"),
    workers: int = typer.Option(1, help="Samples of one prompt drawn concurrently (match llama-server -np)"),
    samples_log: Path | None = typer.Option(None, help="Append every prompt's samples and failures here, paired or not"),
    rewrite_status: str = typer.Option("approved", help="Comma-separated review statuses a rewrite may have to be the chosen side"),
) -> None:
    from concurrent.futures import ThreadPoolExecutor

    from rich.progress import track

    from therapylink_ml.eval.backends import make_backend

    # The HF backend computes in fp16, which Unsloth documents as broken for Gemma 4, and leaves
    # thinking on. llama-server is what the eval measures, so pairs come from the same stack.
    if not backend.startswith("openai:"):
        raise typer.BadParameter("sample pairs through a local OpenAI-compatible server (openai:<url>|<model>)")
    rows = load_prompts(prompts, include_pending)
    done = {r["prompt_id"] for r in map(json.loads, _read_jsonl(out))} if out.exists() else set()
    if samples_log and samples_log.exists():
        # A prompt already sampled (paired or not) is not sampled again on a resumed run.
        done |= {r["prompt_id"] for r in map(json.loads, _read_jsonl(samples_log)) if r.get("k") == k}
    be = make_backend(backend)

    def generate(messages: list[dict]) -> Sample:
        g = be.generate(messages, max_tokens=max_tokens, temperature=temperature)
        return Sample(g.text, hit_cap(g.tokens, g.text, max_tokens))

    pool = ThreadPoolExecutor(max(1, workers))

    def draw(messages: list[dict], n: int) -> list[Sample]:
        return list(pool.map(lambda _: generate(messages), range(n)))

    log = samples_log.open("a", encoding="utf-8") if samples_log else None

    def on_samples(p: dict, drawn: list[Sample], scores: list[ReplyScore]) -> None:
        if log is None:
            return
        entry = {
            "prompt_id": p["id"],
            "route": p["route"],
            "lang": p["lang"],
            "bucket": p.get("bucket", ""),
            "k": k,
            "samples": [
                {"text": d.text, "truncated": d.truncated, "failures": s.failures, "soft": s.soft} for d, s in zip(drawn, scores, strict=True)
            ],
        }
        log.write(json.dumps(entry, ensure_ascii=False) + "\n")
        log.flush()

    out.parent.mkdir(parents=True, exist_ok=True)
    written: Counter[str] = Counter()
    statuses = tuple(s.strip() for s in rewrite_status.split(",") if s.strip())
    try:
        with out.open("a", encoding="utf-8") as f:
            pairs = make_pairs(
                list(track(rows, description="sampling")),
                generate,
                k=k,
                done=done,
                max_rewrite_share=max_rewrite_share,
                rubric=rubric,
                rewrite_statuses=statuses,
                draw=draw if workers > 1 else None,
                on_samples=on_samples,
            )
            for row in pairs:
                f.write(json.dumps(row, ensure_ascii=False) + "\n")
                f.flush()
                written[row["bucket"]] += 1
    finally:
        pool.shutdown()
        if log:
            log.close()
    typer.echo(f"{sum(written.values())} new pairs from {len(rows)} prompts → {out}: {dict(written)}")


def pairs_from_logged(prompts: list[dict], logged: list[dict], *, rubric: bool = True) -> Iterator[dict]:
    """Policy pairs from samples logs, re-scored with the current rules.

    Every logged sample of a prompt (the k=4 pass and a k=8 pass alike) is pooled, so a prompt
    whose first four samples all failed can still pair from its second pass. Prompts not in
    `prompts` are skipped: the prompt files decide what is in the set.
    """
    by_id = {p["id"]: p for p in prompts}
    pooled: dict[str, list[dict]] = {}
    for entry in logged:
        pooled.setdefault(entry["prompt_id"], []).extend(entry["samples"])
    for pid, drawn in pooled.items():
        p = by_id.get(pid)
        if p is None:
            continue
        samples = [Sample(s["text"], s.get("truncated", False)) for s in drawn]
        scores = [score_sample(p["route"], p["lang"], s, rubric=rubric) for s in samples]
        picked = pick_pair([s.text for s in samples], scores)
        if picked is None:
            continue
        chosen, rejected = picked
        yield {
            "prompt_id": pid,
            "bucket": p.get("bucket", ""),
            "route": p["route"],
            "lang": p["lang"],
            "chosen_source": "policy",
            "prompt": fold_system_into_first_user(p["messages"], notes=p.get("notes")),
            "chosen": [{"role": "assistant", "content": samples[chosen].text}],
            "rejected": [{"role": "assistant", "content": samples[rejected].text}],
            "chosen_failures": scores[chosen].failures,
            "chosen_soft": scores[chosen].soft,
            "rejected_failures": scores[rejected].failures,
        }


def all_failing(prompts: list[dict], logged: list[dict], *, rubric: bool = True) -> list[str]:
    """Ids of prompts where every logged sample fails the current rules (the k=8 pass, then rewrites)."""
    by_id = {p["id"]: p for p in prompts}
    pooled: dict[str, list[dict]] = {}
    for entry in logged:
        pooled.setdefault(entry["prompt_id"], []).extend(entry["samples"])
    out = []
    for pid, drawn in pooled.items():
        p = by_id.get(pid)
        if p and not any(score_sample(p["route"], p["lang"], Sample(s["text"], s.get("truncated", False)), rubric=rubric).passed for s in drawn):
            out.append(pid)
    return out


@app.command("pairs-from-log")
def pairs_from_log(
    prompts: list[str] = typer.Option(..., "--prompts", help="Prompt JSONL files the samples came from"),
    samples_log: list[Path] = typer.Option(..., "--samples-log", help="Samples logs written by build-pairs"),
    out: Path = DATA / "dpo_pairs.jsonl",
    failing_out: Path | None = typer.Option(None, help="Also write the prompts where every sample failed (for a k=8 pass)"),
    rubric: bool = True,
) -> None:
    """Rebuild policy pairs offline from samples logs, with the current rules. Overwrites --out."""
    rows = [r for spec in prompts for r in load_prompts(spec)]
    logged = [json.loads(line) for path in samples_log for line in _read_jsonl(path)]
    made = list(pairs_from_logged(rows, logged, rubric=rubric))
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8") as f:
        for row in made:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
    typer.echo(f"{len(made)} policy pairs from {len({e['prompt_id'] for e in logged})} sampled prompts → {out}: {dict(Counter(r['route'] for r in made))}")
    if failing_out:
        ids = set(all_failing(rows, logged, rubric=rubric))
        with failing_out.open("w", encoding="utf-8") as f:
            for r in rows:
                if r["id"] in ids:
                    f.write(json.dumps({k: v for k, v in r.items() if k != "rewrite"}, ensure_ascii=False) + "\n")
        typer.echo(f"{len(ids)} prompts where every sample failed → {failing_out}")


def rewrite_pairs(
    prompts: list[dict],
    logged: list[dict],
    rewrites: dict[str, dict],
    *,
    existing: int,
    max_rewrite_share: float = 0.25,
    rewrite_statuses: tuple[str, ...] = ("approved",),
    rubric: bool = True,
) -> Iterator[dict]:
    """Pairs whose chosen side is a reviewed rewrite, for prompts where every logged sample failed.

    The rejected side is the logged sample breaking the most rules, so it stays on-policy. A
    rewrite must itself pass every rule it is meant to teach, and rewrites stay under
    `max_rewrite_share` of all pairs (`existing` policy pairs plus these).
    """
    by_id = {p["id"]: p for p in prompts}
    samples: dict[str, list[dict]] = {}
    for entry in logged:
        samples.setdefault(entry["prompt_id"], []).extend(entry["samples"])
    budget = int(max_rewrite_share * existing / (1 - max_rewrite_share)) if max_rewrite_share < 1 else len(rewrites)
    made = 0
    for pid, rw in rewrites.items():
        if made >= budget:
            break
        p, drawn = by_id.get(pid), samples.get(pid)
        if p is None or not drawn or rw.get("review_status") not in rewrite_statuses:
            continue
        if any(not s["failures"] for s in drawn):
            continue  # the model produced a passing reply: that prompt pairs on-policy or not at all
        score = score_sample(p["route"], p["lang"], Sample(rw["content"]), rubric=rubric)
        if not score.passed:
            raise ValueError(f"{pid}: the rewrite itself fails {score.failures}")
        worst = max(drawn, key=lambda s: len(s["failures"]))
        made += 1
        yield {
            "prompt_id": pid,
            "bucket": p.get("bucket", ""),
            "route": p["route"],
            "lang": p["lang"],
            "chosen_source": "rewrite",
            "rewritten_by": rw.get("rewritten_by"),
            "prompt": fold_system_into_first_user(p["messages"], notes=p.get("notes")),
            "chosen": [{"role": "assistant", "content": rw["content"].strip()}],
            "rejected": [{"role": "assistant", "content": worst["text"]}],
            "chosen_failures": [],
            "rejected_failures": worst["failures"],
        }


@app.command("add-rewrites")
def add_rewrites(
    prompts: list[str] = typer.Option(..., "--prompts", help="Prompt JSONL files the samples came from"),
    samples_log: list[Path] = typer.Option(..., "--samples-log", help="Samples logs written by build-pairs"),
    rewrites: Path = typer.Option(..., help="JSONL of {prompt_id, content, review_status, rewritten_by}"),
    out: Path = DATA / "dpo_pairs.jsonl",
    max_rewrite_share: float = 0.25,
    rewrite_status: str = typer.Option("approved", help="Comma-separated review statuses accepted"),
) -> None:
    """Append rewrite pairs for prompts where every logged sample failed."""
    rows = [r for spec in prompts for r in load_prompts(spec)]
    logged = [json.loads(line) for path in samples_log for line in _read_jsonl(path)]
    rw = {r["prompt_id"]: r for r in map(json.loads, _read_jsonl(rewrites))}
    have = [json.loads(line) for line in _read_jsonl(out)] if out.exists() else []
    done = {r["prompt_id"] for r in have}
    policy = sum(r["chosen_source"] == "policy" for r in have)
    already = len(have) - policy
    statuses = tuple(s.strip() for s in rewrite_status.split(",") if s.strip())
    new = list(
        rewrite_pairs(
            rows,
            logged,
            {k: v for k, v in rw.items() if k not in done},
            existing=policy,
            max_rewrite_share=max_rewrite_share,
            rewrite_statuses=statuses,
        )
    )
    new = new[: max(0, int(max_rewrite_share * policy / (1 - max_rewrite_share)) - already)]
    with out.open("a", encoding="utf-8") as f:
        for row in new:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
    typer.echo(f"{len(new)} rewrite pairs appended to {out} ({policy} policy, {already + len(new)} rewrites)")


class MarginWatch:
    """Abort DPO whose reward margins are still exactly zero `check_step` steps in.

    Zero margins mean the policy and the reference score chosen and rejected identically, which is
    what a frozen adapter (or a reference that is the policy itself) produces. The run would
    otherwise burn its whole session and save an unchanged adapter.
    """

    KEY = "rewards/margins"

    def __init__(self, check_step: int = 50, eps: float = 1e-6):
        self.check_step, self.eps = check_step, eps
        self.largest = 0.0
        self.seen = 0
        self.checked = False

    def observe(self, step: int, logs: dict) -> str | None:
        """Record one log line; return an abort reason once, at the check step, if margins stayed 0."""
        if self.KEY in logs:
            self.seen += 1
            self.largest = max(self.largest, abs(float(logs[self.KEY])))
        if self.checked or step < self.check_step:
            return None
        self.checked = True
        if self.seen == 0:
            return f"no '{self.KEY}' logged by step {step}; TRL renamed it or DPO is not computing rewards"
        if self.largest < self.eps:
            return f"reward margins stayed 0 through step {step}: the policy is not moving away from the reference"
        return None


def _margin_callback(watch: MarginWatch):
    from transformers import TrainerCallback

    class Callback(TrainerCallback):
        def on_log(self, args, state, control, logs=None, **kwargs):
            reason = watch.observe(state.global_step, logs or {})
            if reason:
                raise RuntimeError(f"aborting DPO: {reason}")
            return control

    return Callback()


class AccuracyWatch:
    """Stop DPO once it has memorised its pairs instead of learning from them.

    DPO v16 went from 0.43 to 1.0 train reward accuracy while eval accuracy sat at 0.63-0.65: it
    learned its 158 train pairs by heart. Stop when train accuracy has been at `threshold` for
    `patience` log lines in a row and eval accuracy has not risen by `min_eval_gain` since the
    first eval (or there is no eval). The adapter is still saved, so the gate can run on it.
    """

    TRAIN_KEY = "rewards/accuracies"
    EVAL_KEY = "eval_rewards/accuracies"

    def __init__(self, threshold: float = 1.0, patience: int = 2, min_eval_gain: float = 0.05):
        self.threshold, self.patience, self.min_eval_gain = threshold, patience, min_eval_gain
        self.streak = 0
        self.first_eval: float | None = None
        self.last_eval: float | None = None
        self.reason: str | None = None

    def observe(self, step: int, logs: dict) -> str | None:
        """Record one log line; return a stop reason once, the first time the rule fires."""
        if self.threshold <= 0 or self.reason:
            return None
        if self.EVAL_KEY in logs:
            acc = float(logs[self.EVAL_KEY])
            self.first_eval = acc if self.first_eval is None else self.first_eval
            self.last_eval = acc
        if self.TRAIN_KEY not in logs:
            return None
        self.streak = self.streak + 1 if float(logs[self.TRAIN_KEY]) >= self.threshold - 1e-9 else 0
        if self.streak < self.patience:
            return None
        if self.first_eval is not None and self.last_eval - self.first_eval >= self.min_eval_gain:
            return None
        flat = "no eval yet" if self.first_eval is None else f"eval accuracy {self.first_eval:.2f} -> {self.last_eval:.2f}"
        self.reason = f"train reward accuracy >= {self.threshold} for {self.streak} log lines at step {step} ({flat})"
        return self.reason


def _accuracy_callback(watch: AccuracyWatch):
    from transformers import TrainerCallback

    class Callback(TrainerCallback):
        def on_log(self, args, state, control, logs=None, **kwargs):
            reason = watch.observe(state.global_step, logs or {})
            if reason:
                print(f"early stop: {reason}", flush=True)
                control.should_training_stop = True
            return control

    return Callback()


def split_pairs(rows: list[dict], eval_frac: float) -> tuple[list[dict], list[dict]]:
    """Deterministic held-out split by prompt id, so DPO reports an eval accuracy."""
    if eval_frac <= 0:
        return rows, []

    def held_out(r: dict) -> bool:
        h = int(hashlib.sha1(str(r.get("prompt_id", r["prompt"])).encode("utf-8")).hexdigest()[:8], 16)
        return h / 0xFFFFFFFF < eval_frac

    return [r for r in rows if not held_out(r)], [r for r in rows if held_out(r)]


@app.command()
def train(
    sft_adapter: Path = ML_ROOT / "runs" / "eve-sft" / "adapter",
    pairs: Path = DATA / "dpo_pairs.jsonl",
    out: Path = ML_ROOT / "runs" / "eve-dpo",
    beta: float = 0.1,
    lr: float = 5e-6,
    epochs: float = 2.0,
    batch: int = 1,
    grad_accum: int = 8,
    max_length: int = 1536,
    max_prompt_length: int = 1024,
    rpo_alpha: float = typer.Option(0.5, help="NLL weight on the chosen side, so its likelihood does not collapse (0 disables)"),
    margin_check_steps: int = typer.Option(50, help="Abort if reward margins are still 0 at this step"),
    eval_frac: float = typer.Option(0.2, help="Share of pairs held out for DPO eval accuracy"),
    stop_train_acc: float = typer.Option(
        1.0, help="Stop when train reward accuracy reaches this while eval accuracy is flat (0 disables)"
    ),
    stop_patience: int = typer.Option(2, help="Log lines in a row at --stop-train-acc before stopping"),
    seed: int = 13,
    max_hours: float = typer.Option(0.0, help="Stop after this many hours and still save (0 = no limit)"),
    gguf: bool = True,
) -> None:
    import datasets as hf_datasets

    # Before trl and Unsloth load, as in eve_sft: TRL's DPO dataset preparation map()s over the
    # pairs, datasets hashes each map function with dill for its cache, and Unsloth's patches put
    # an unpicklable torch module in that closure. With the cache off there is no hash.
    hf_datasets.disable_caching()
    from datasets import Dataset
    from trl import DPOConfig, DPOTrainer
    from unsloth import FastModel, PatchDPOTrainer

    from therapylink_ml.train.eve_sft import PROMPT_MANIFEST, _pick, _real_bf16, _supported, _time_budget
    from therapylink_ml.train.lora import unfreeze_lora

    PatchDPOTrainer()
    model, tokenizer = FastModel.from_pretrained(str(sft_adapter), max_seq_length=max_length, load_in_4bit=True)
    tok = getattr(tokenizer, "tokenizer", tokenizer)
    # Same adapter again under a second name: the frozen copy TRL switches to for reference logps.
    model.load_adapter(str(sft_adapter), adapter_name=REFERENCE)
    model.set_adapter(POLICY)
    trainable = unfreeze_lora(model, str(sft_adapter), adapter_name=POLICY)
    print(f"policy '{POLICY}': {trainable:,} trainable parameters; reference '{REFERENCE}' frozen", flush=True)

    rows = [json.loads(line) for line in _read_jsonl(pairs)]
    train_rows, eval_rows = split_pairs(rows, eval_frac)

    def to_ds(items: list[dict]):
        return Dataset.from_list([{"prompt": r["prompt"], "chosen": r["chosen"], "rejected": r["rejected"]} for r in items])

    ds = to_ds(train_rows)
    typer.echo(f"{len(ds)} preference pairs, {len(eval_rows)} held out")

    # These three are the fix, not tuning: without them the run trains against stock Gemma, or
    # lets the chosen side's likelihood fall. Refuse to run on a TRL that silently lacks them.
    accepted = inspect.signature(DPOConfig.__init__).parameters
    missing = [k for k in ("model_adapter_name", "ref_adapter_name", "rpo_alpha") if k not in accepted]
    if missing:
        raise RuntimeError(f"this TRL's DPOConfig has no {missing}; pin a TRL that does")

    out.mkdir(parents=True, exist_ok=True)
    steps = -(-len(ds) // (batch * grad_accum)) * epochs
    cfg = dict(
        beta=beta,
        learning_rate=lr,
        num_train_epochs=epochs,
        per_device_train_batch_size=batch,
        gradient_accumulation_steps=grad_accum,
        max_length=max_length,
        lr_scheduler_type="cosine",
        # warmup_ratio was removed from transformers; 5% of optimizer steps as an explicit count.
        warmup_steps=max(1, int(steps * 0.05)),
        optim="adamw_8bit",
        logging_steps=10,
        save_steps=100,
        save_total_limit=2,
        seed=seed,
        output_dir=str(out / "checkpoints"),
        report_to="none",
        model_adapter_name=POLICY,
        ref_adapter_name=REFERENCE,
        rpo_alpha=rpo_alpha or None,
        # Reference logps once, before training: Gemma 4's E-series shares KV state across layers,
        # and a reference forward inside the step broke gradient checkpointing's recompute
        # ("saved [1, n, 512] vs recomputed [1, n, 1, 512]") on the first v16 DPO runs.
        precompute_ref_log_probs=True,
        # trl evaluates 8 pairs at a time by default: 16 sequences of Gemma's 262k-vocab logits ran a
        # 15 GB T4 out of memory at the first eval (step 10) of the first full v16 DPO run.
        per_device_eval_batch_size=1,
        # Same constraint as SFT: T4s have no bf16 and Gemma 4 is broken in fp16 → fp32.
        bf16=_real_bf16(),
        fp16=False,
    )
    cfg.update(_supported(DPOConfig, max_prompt_length=max_prompt_length))
    if eval_rows:
        cfg[_pick(DPOConfig, "eval_strategy", "evaluation_strategy")] = "steps"
        cfg["eval_steps"] = max(10, int(steps // 4))
    watch = MarginWatch(margin_check_steps)
    acc_watch = AccuracyWatch(stop_train_acc, stop_patience)
    callbacks = [_margin_callback(watch), _accuracy_callback(acc_watch)]
    callbacks += [_time_budget(max_hours)] if max_hours > 0 else []
    class TextDPOTrainer(DPOTrainer):
        # Gemma 4 is an image-text-to-text model type, so trl takes its vision path (process_row,
        # which needs a processor with .tokenizer) although these pairs are text only. The first
        # v16 DPO runs died on it: "GemmaTokenizer has no attribute tokenizer". is_vision_model is
        # read only to pick the row function inside _prepare_dataset, so clear it just before.
        def _prepare_dataset(self, *args, **kwargs):
            self.is_vision_model = False
            return super()._prepare_dataset(*args, **kwargs)

    trainer = TextDPOTrainer(
        model=model,
        ref_model=None,
        train_dataset=ds,
        eval_dataset=to_ds(eval_rows) if eval_rows else None,
        callbacks=callbacks,
        **{_pick(DPOTrainer, "processing_class", "tokenizer"): tok},
        args=DPOConfig(**cfg),
    )
    stats = trainer.train()
    (out / "train_stats.json").write_text(
        json.dumps({**stats.metrics, "early_stop": acc_watch.reason}, indent=2), encoding="utf-8"
    )
    model.save_pretrained(str(out / "adapter"), selected_adapters=[POLICY])
    tok.save_pretrained(str(out / "adapter"))
    # DPO pairs are folded with the SFT prompt, so the DPO adapter carries the SFT manifest on.
    manifest = sft_adapter / PROMPT_MANIFEST
    if manifest.exists():
        shutil.copy(manifest, out / "adapter" / PROMPT_MANIFEST)
    if gguf:
        model.delete_adapter(REFERENCE)
        model.save_pretrained_gguf(str(out / "gguf"), tok, quantization_method="q4_k_m")


if __name__ == "__main__":
    app()
