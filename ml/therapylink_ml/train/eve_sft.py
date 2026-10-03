"""Eve supervised fine-tune: Gemma 4 E4B (or E2B / Qwen3.5-4B) QLoRA with Unsloth.

Runs on Kaggle T4 (E4B ~10 GB) or an RTX 4050 for the smaller variants. Not importable on the
local CPU/2050 box — Unsloth is only in requirements-train.txt.
"""

from __future__ import annotations

import hashlib
import inspect
import json
import random
from collections import Counter
from pathlib import Path

import typer

from therapylink_ml.data import registry
from therapylink_ml.prompts import (
    EVE_SYSTEM_PROMPT,
    EVE_SYSTEM_PROMPT_V1,
    EVE_SYSTEM_PROMPT_V2,
    fold_system_into_first_user,
)
from therapylink_ml.schema import Conversation, normalise_messages
from therapylink_ml.train.distractor_notes import sample_notes
from therapylink_ml.train.lora import unfreeze_lora
from therapylink_ml.train.masking import IGNORE, response_labels
from therapylink_ml.train.reply_rules import is_listy

ML_ROOT = Path(__file__).resolve().parents[2]
DATA = ML_ROOT / "data" / "processed"

app = typer.Typer(add_completion=False)

# Gemma 4 renders turns as `<|turn>user\n … <turn|>`, NOT Gemma 2/3's `<start_of_turn>user`.
# train_on_responses_only silently masks the wrong tokens if these don't match the template, which
# produces a quietly bad model rather than an error — so _check_markers asserts they appear.
INSTRUCTION_PART = "<|turn>user\n"
RESPONSE_PART = "<|turn>model\n"
TURN_END = "<turn|>"


def _real_bf16() -> bool:
    """True only for hardware bf16 (Ampere+, compute capability 8.0+).

    torch.cuda.is_bf16_supported() counts *emulated* bf16 and so returns True on Kaggle's Turing
    T4s, while transformers requires the real thing and raises. Compute capability is unambiguous.
    """
    import torch

    if not torch.cuda.is_available():
        return False
    return torch.cuda.get_device_capability()[0] >= 8


def _pick(cls, *names: str) -> str:
    """Return the first constructor kwarg `cls` actually accepts."""
    params = inspect.signature(cls.__init__).parameters
    for n in names:
        if n in params:
            return n
    raise RuntimeError(f"{cls.__name__} accepts none of {names}; its API changed again")


def _supported(cls, **kwargs) -> dict:
    """Keep only the kwargs `cls` accepts, reporting any it doesn't so the drop isn't silent."""
    params = inspect.signature(cls.__init__).parameters
    kept = {k: v for k, v in kwargs.items() if k in params}
    dropped = set(kwargs) - set(kept)
    if dropped:
        print(f"note: {cls.__name__} does not accept {sorted(dropped)} in this version", flush=True)
    return kept


def _time_budget(hours: float):
    """Stop training cleanly once `hours` have passed, so the adapter is still saved.

    Kaggle kills sessions at 12 h. A *cancelled* session did keep /kaggle/working (v11's step-400
    and step-600 checkpoints came back), but what a timeout keeps is undocumented, and a 12 h run
    is too expensive to find out on. Stopping early leaves the cosine schedule unfinished; a
    slightly under-annealed adapter that is certainly saved beats a finished one that might not be.
    """
    import time

    from transformers import TrainerCallback

    class TimeBudget(TrainerCallback):
        def __init__(self) -> None:
            self.deadline = time.monotonic() + hours * 3600

        def on_step_end(self, args, state, control, **kwargs):
            if time.monotonic() > self.deadline:
                print(f"time budget of {hours} h reached at step {state.global_step}/{state.max_steps}; stopping and saving", flush=True)
                control.should_training_stop = True
            return control

    return TimeBudget()


def _check_markers(sample: str) -> None:
    for name, marker in (("instruction_part", INSTRUCTION_PART), ("response_part", RESPONSE_PART)):
        if marker not in sample:
            raise RuntimeError(
                f"{name}={marker!r} does not appear in the rendered chat template. Training would "
                f"mask the wrong tokens and silently produce a bad model.\nRendered sample:\n{sample[:400]!r}"
            )


def _parse_weights(spec: str) -> dict[str, float]:
    if not spec:
        return {}
    return {k: float(v) for k, v in (pair.split("=") for pair in spec.split(","))}


# Sources whose `quality` is a 0-1 rating. counselchat's is an upvote count, so a bare
# --min-quality never touches it.
QUALITY_RATED = ("annomi", "tl_authored")


def parse_min_quality(spec: str) -> dict[str, float]:
    """'1.0' applies to every rated source; 'annomi=1.0,counselchat=2' sets floors per source."""
    if not spec:
        return {}
    if "=" not in spec:
        return dict.fromkeys(QUALITY_RATED, float(spec))
    return _parse_weights(spec)


def passes_quality(conv: Conversation, floors: dict[str, float]) -> bool:
    """AnnoMI's low-quality transcripts (quality 0.0) are counselling that experts rated as poor
    practice. At annomi=3 that was 60 copies an epoch of what Eve should not do."""
    floor = floors.get(conv.source)
    return floor is None or conv.quality is None or conv.quality >= floor


def short_prose(conv: Conversation, max_words: int) -> bool:
    """Every assistant turn at most `max_words` words and none formatted as a list.

    MentalChat16k replies have a median of 331 words and 21% are lists; at any weight they taught
    v14 its essays and the "Here are a few things" replies that ran to the token cap.
    """
    return all(len(m.content.split()) <= max_words and not is_listy(m.content) for m in conv.messages if m.role == "assistant")


def stratified_sample(convs: list[Conversation], n: int, seed: int) -> list[Conversation]:
    """`n` conversations with each source in proportion (largest remainder, at least one each)."""
    if n <= 0 or n >= len(convs):
        return list(convs)
    rng = random.Random(seed)
    by_source: dict[str, list[Conversation]] = {}
    for c in convs:
        by_source.setdefault(c.source, []).append(c)
    exact = {s: n * len(items) / len(convs) for s, items in by_source.items()}
    take = {s: max(1, int(q)) for s, q in exact.items()}
    for s in sorted(exact, key=lambda s: exact[s] - int(exact[s]), reverse=True):
        if sum(take.values()) >= n:
            break
        take[s] += 1
    while sum(take.values()) > n:
        take[max(take, key=take.__getitem__)] -= 1
    out: list[Conversation] = []
    for s in sorted(by_source):
        out.extend(rng.sample(by_source[s], min(take[s], len(by_source[s]))))
    return out


def read_conversations(
    path: Path,
    *,
    exclude_nc: bool,
    min_quality: dict[str, float] | None = None,
    mentalchat_max_words: int = 0,
    include_pending: bool = False,
) -> list[Conversation]:
    """Conversations in `path` that pass the review, licence, quality and MentalChat16k filters.

    Authored rows still pending clinician review are dropped even when the corpus has them (a
    `tl-data build --include-pending`), so a model can't be trained on them by pointing at the
    wrong directory. Rows passed only by the AI clinical review are dropped the same way unless
    TL_ACCEPT_AI_CLINICAL_REVIEW=1 is set for the training run as well as the build.
    """
    from therapylink_ml.data.loaders.authored import held_back_tags

    # Pending rows, and AI-reviewed rows unless TL_ACCEPT_AI_CLINICAL_REVIEW=1 is set here too.
    held_back = held_back_tags()
    kept: list[Conversation] = []
    dropped: Counter[str] = Counter()
    with path.open(encoding="utf-8") as f:
        for line in f:
            if not line.strip():
                continue
            conv = Conversation.model_validate_json(line)
            if not include_pending and held_back & set(conv.tags):
                dropped[f"{conv.source}:pending_review"] += 1
                continue
            if exclude_nc and not registry.get(conv.source).commercial_ok:
                continue
            if not passes_quality(conv, min_quality or {}):
                dropped[f"{conv.source}:quality"] += 1
                continue
            if mentalchat_max_words and conv.source == "mentalchat16k" and not short_prose(conv, mentalchat_max_words):
                dropped[f"{conv.source}:length_or_list"] += 1
                continue
            kept.append(conv)
    if dropped:
        print(f"filtered {sum(dropped.values())} conversations: {dict(dropped)}", flush=True)
    return kept


def load_conversations(
    path: Path,
    *,
    exclude_nc: bool,
    weights: dict[str, float],
    seed: int,
    notes_frac: float = 0.0,
    min_quality: dict[str, float] | None = None,
    mentalchat_max_words: int = 0,
    sample: int = 0,
) -> list[list[dict]]:
    """Filtered, folded and weighted training conversations.

    Filters run before weighting, so a weight applies to what is left. [notes_frac] of
    conversations without notes get unrelated ones (distractor_notes.py); crisis conversations get
    them at least half the time. 0 leaves the data, and the shuffle, unchanged. `sample` > 0 keeps
    a source-stratified subset of that size (the validation split).
    """
    convs = read_conversations(path, exclude_nc=exclude_nc, min_quality=min_quality, mentalchat_max_words=mentalchat_max_words)
    if sample:
        convs = stratified_sample(convs, sample, seed)
    rng = random.Random(seed)
    out: list[list[dict]] = []
    skipped: Counter[str] = Counter()
    for conv in convs:
        msgs = [{"role": m.role, "content": m.content} for m in normalise_messages(conv.messages)]
        alternates = all(a["role"] != b["role"] for a, b in zip(msgs, msgs[1:], strict=False))
        if len(msgs) < 2 or not alternates:
            # The corpus builder enforces this, but never let one malformed row kill a run
            # that has already spent minutes loading a 10 GB model.
            skipped[conv.source] += 1
            continue
        try:
            notes = conv.notes
            if notes is None and notes_frac > 0:
                p = max(notes_frac, 0.5) if "route:crisis" in conv.tags else notes_frac
                if rng.random() < p:
                    notes = sample_notes(rng, conv.lang, allow_risk="route:crisis" in conv.tags)
            folded = fold_system_into_first_user(msgs, notes=notes)
        except ValueError:
            skipped[conv.source] += 1
            continue
        w = weights.get(conv.source, 1.0)
        copies = int(w) + (1 if rng.random() < (w - int(w)) else 0)
        out.extend([folded] * copies)
    if skipped:
        print(f"skipped {sum(skipped.values())} malformed conversations: {dict(skipped)}")
    rng.shuffle(out)
    return out


PROMPT_MANIFEST = "training_prompt.json"


def trained_prompt_manifest() -> dict:
    """Which system prompt an adapter was trained with, so eos_check (and later the app) serve it."""
    version = {EVE_SYSTEM_PROMPT_V1: "v1", EVE_SYSTEM_PROMPT_V2: "v2"}.get(EVE_SYSTEM_PROMPT, "custom")
    return {"prompt": version, "sha256": hashlib.sha256(EVE_SYSTEM_PROMPT.encode("utf-8")).hexdigest()}


def save_adapter(model, tok, path: Path) -> None:
    model.save_pretrained(str(path))
    tok.save_pretrained(str(path))
    (path / PROMPT_MANIFEST).write_text(json.dumps(trained_prompt_manifest(), indent=2), encoding="utf-8")


def eval_every(n_rows: int, batch: int, grad_accum: int) -> int:
    """Optimizer steps in half an epoch: how often the validation loss is measured."""
    return max(1, -(-n_rows // (batch * grad_accum)) // 2)


def _epoch_saver(out: Path, tok):
    """Keep every epoch's adapter as adapter-epoch{N}.

    save_total_limit=2 on step checkpoints deleted epoch 1 of a 2-epoch run, and comparing epoch 1
    against epoch 2 is the one measurement that settles how many epochs to train.
    """
    from transformers import TrainerCallback

    class EpochSaver(TrainerCallback):
        def on_epoch_end(self, args, state, control, model=None, **kwargs):
            n = round(state.epoch or 0)
            if model is not None and n > 0:
                save_adapter(model, tok, out / f"adapter-epoch{n}")
                print(f"saved {out / f'adapter-epoch{n}'} at step {state.global_step}", flush=True)
            return control

    return EpochSaver()


@app.command()
def train(
    model_name: str = "unsloth/gemma-4-E4B-it",
    data: Path = DATA / "conversations.train.jsonl",
    out: Path = ML_ROOT / "runs" / "eve-sft",
    max_seq: int = 2048,
    r: int = 32,
    alpha: int = 64,
    lr: float = 2e-4,
    epochs: float = 2.0,
    max_steps: int = -1,
    batch: int = 2,
    grad_accum: int = 8,
    warmup: float = 0.05,
    weights: str = typer.Option("", help="Per-source oversampling, e.g. esconv=2,annomi=3"),
    exclude_nc: bool = typer.Option(False, help="Drop non-commercial sources"),
    seed: int = 13,
    notes_frac: float = typer.Option(0.0, help="Share of conversations given unrelated memory notes (crisis ones at least half), so notes never displace the message"),
    resume: bool = False,
    min_reply_tokens: int = typer.Option(20, help="Replies shorter than this stay as context but are not trained on (v13 learned one-liners from them)"),
    init_adapter: Path | None = typer.Option(None, help="Continue training this LoRA adapter instead of creating a new one (its r/alpha win)"),
    single_gpu: bool = typer.Option(True, help="Keep the model on one GPU — Gemma 4 E-series per-layer embeddings cannot span devices"),
    gguf: bool = True,
    push: str = typer.Option("", help="HF repo id to push adapter + GGUF to"),
    max_hours: float = typer.Option(0.0, help="Stop training after this many hours and still save the adapter (0 = no limit). Kaggle kills sessions at 12 h."),
    min_quality: str = typer.Option("1.0", help="Quality floor: '1.0' for every rated source (drops AnnoMI's low-quality transcripts), or annomi=1.0,...; '' keeps all"),
    mentalchat_max_words: int = typer.Option(180, help="Keep MentalChat16k conversations only if every reply is this short and not a list (0 keeps all)"),
    val: Path | None = typer.Option(DATA / "conversations.val.jsonl", help="Validation conversations; a stratified --val-size subset is scored every half epoch"),
    val_size: int = typer.Option(300, help="Validation conversations kept, stratified by source (0 disables validation)"),
) -> None:
    import datasets as hf_datasets
    import torch
    from datasets import Dataset
    from trl import SFTConfig, SFTTrainer

    # datasets hashes every map() function with dill to build a cache fingerprint, even with one
    # process. Unsloth's patches put torch's ConfigModule inside TRL's transform closure, and dill
    # cannot pickle it. Nothing here benefits from the on-disk cache — the corpus is rebuilt from
    # source anyway — so turning it off removes the hash and the failure with it.
    hf_datasets.disable_caching()
    from unsloth import FastModel

    # Gemma 4's E-series keeps per-layer input embeddings, and that path indexes the embedding
    # table inside the forward pass. When accelerate shards the model across two GPUs those
    # tensors land on different devices and the forward dies with a device mismatch. Pinning the
    # whole model to one GPU is the fix; it also means E4B needs a card that fits it whole.
    # Unsloth places the model itself and ignores device_map, so this only warns — the actual fix
    # is CUDA_VISIBLE_DEVICES=0 before the process starts. See notebooks/eve_sft_kaggle.ipynb.
    if single_gpu and torch.cuda.device_count() > 1:
        print(
            f"WARNING: {torch.cuda.device_count()} GPUs visible. Gemma 4 E-series cannot shard "
            "across devices; set CUDA_VISIBLE_DEVICES=0 before launching or the forward pass will "
            "fail with a cuda:0/cuda:1 mismatch.",
            flush=True,
        )
    device_map = {"": 0} if single_gpu and torch.cuda.is_available() else "auto"
    if init_adapter:
        # Continue an existing adapter: how v12 was repaired after its masking bug without paying
        # for another 9 h epoch. Unsloth loads base + LoRA from the adapter dir, as eve_dpo does.
        model, tokenizer = FastModel.from_pretrained(
            str(init_adapter),
            max_seq_length=max_seq,
            load_in_4bit=True,
            device_map=device_map,
            use_gradient_checkpointing="unsloth",
        )
        # A saved adapter loads frozen (inference_mode=true); unfreeze_lora undoes that and checks.
        trainable = unfreeze_lora(model, str(init_adapter))
        print(f"continuing {init_adapter}: {trainable:,} trainable parameters", flush=True)
    else:
        model, tokenizer = FastModel.from_pretrained(
            model_name,
            max_seq_length=max_seq,
            load_in_4bit=True,
            full_finetuning=False,
            device_map=device_map,
        )
        model = FastModel.get_peft_model(
            model,
            finetune_vision_layers=False,
            finetune_language_layers=True,
            finetune_attention_modules=True,
            finetune_mlp_modules=True,
            r=r,
            lora_alpha=alpha,
            lora_dropout=0,
            bias="none",
            random_state=seed,
        )
    # Deliberately NOT get_chat_template(): the model ships its own template, and that is the one
    # baked into the GGUF and the .litertlm the app runs. Overriding it trains against a format
    # inference will never see — and Unsloth's bundled "gemma-4" template additionally rejects the
    # long multi-turn conversations in ESConv and AnnoMI.
    tok = getattr(tokenizer, "tokenizer", tokenizer)

    filters = dict(exclude_nc=exclude_nc, min_quality=parse_min_quality(min_quality), mentalchat_max_words=mentalchat_max_words)
    convs = load_conversations(data, weights=_parse_weights(weights), seed=seed, notes_frac=notes_frac, **filters)
    typer.echo(f"{len(convs)} training conversations")

    # Render and tokenise here, so TRL receives a finished dataset and never calls map() on it.
    start_ids = tok(INSTRUCTION_PART.replace("user", "model"), add_special_tokens=False)["input_ids"]
    end_ids = tok(TURN_END, add_special_tokens=False)["input_ids"]
    if not start_ids:
        raise RuntimeError(f"response marker {RESPONSE_PART!r} tokenised to nothing")

    def tokenise(items: list[list[dict]], label: str) -> list[dict]:
        rows: list[dict] = []
        for i, convo in enumerate(items):
            text = tok.apply_chat_template(convo, tokenize=False, add_generation_prompt=False).removeprefix("<bos>")
            if i == 0:
                _check_markers(text)
            ids = tok(text, add_special_tokens=False, truncation=True, max_length=max_seq)["input_ids"]
            labels = response_labels(ids, start_ids, end_ids, min_tokens=min_reply_tokens)
            if all(v == IGNORE for v in labels):
                continue  # nothing to learn from — a conversation whose reply fell outside max_seq
            rows.append({"input_ids": ids, "labels": labels, "attention_mask": [1] * len(ids)})
        supervised = sum(sum(1 for v in r["labels"] if v != IGNORE) for r in rows)
        print(
            f"{label}: {len(rows)} tokenised examples ({len(items) - len(rows)} dropped with no supervised tokens); "
            f"{supervised / max(1, sum(len(r['input_ids']) for r in rows)):.1%} of tokens supervised",
            flush=True,
        )
        return rows

    ds = Dataset.from_list(tokenise(convs, "train"))
    # Validation is filtered, folded and masked exactly like training, but never weighted: its loss
    # has to be comparable between epoch 1 and epoch 2, which is what decides the epoch count.
    val_ds = None
    if val is not None and val_size > 0 and val.exists():
        val_convs = load_conversations(val, weights={}, seed=seed, notes_frac=notes_frac, sample=val_size, **filters)
        val_ds = Dataset.from_list(tokenise(val_convs, "val"))
    elif val_size > 0:
        print(f"WARNING: no validation file at {val}; training without a validation loss", flush=True)

    out.mkdir(parents=True, exist_ok=True)
    # TRL renames things between releases and Kaggle's image moves without warning, so bind the
    # two that have churned (max_seq_length -> max_length, tokenizer -> processing_class) by
    # inspecting the signature instead of pinning a version we don't control.
    cfg_kwargs = dict(
        per_device_train_batch_size=batch,
        gradient_accumulation_steps=grad_accum,
        # transformers removed warmup_ratio (deprecated for v5.2), so derive the same warmup as
        # a step count: the fraction of total optimizer steps the ratio used to mean.
        warmup_steps=int((max_steps if max_steps > 0 else -(-len(ds) // (batch * grad_accum)) * epochs) * warmup),
        num_train_epochs=epochs,
        max_steps=max_steps,
        learning_rate=lr,
        lr_scheduler_type="cosine",
        optim="adamw_8bit",
        weight_decay=0.01,
        logging_steps=10,
        # Step checkpoints are for --resume across sessions; epoch adapters are kept separately by
        # _epoch_saver, so this limit no longer deletes the epoch-1 result.
        save_steps=200,
        save_total_limit=2,
        seed=seed,
        output_dir=str(out / "checkpoints"),
        report_to="none",
        packing=False,
    )
    cfg_kwargs[_pick(SFTConfig, "max_length", "max_seq_length")] = max_seq
    if val_ds is not None and len(val_ds):
        cfg_kwargs[_pick(SFTConfig, "eval_strategy", "evaluation_strategy")] = "steps"
        cfg_kwargs["eval_steps"] = eval_every(len(ds), batch, grad_accum)
        cfg_kwargs["per_device_eval_batch_size"] = batch
    # The dataset arrives already tokenised with labels, so TRL must not touch it. Its own
    # preprocessing is what kept dying: `datasets` dill-hashes every map() for a cache fingerprint,
    # and Unsloth's patches put an unpicklable torch ConfigModule inside TRL's closure.
    cfg_kwargs.update(
        _supported(
            SFTConfig,
            dataset_num_proc=1,
            completion_only_loss=False,
            dataset_kwargs={"skip_prepare_dataset": True},
        )
    )
    # Precision has to be stated, not inferred: TRL defaults bf16 on, but Kaggle's T4s are Turing
    # (no bf16), and Unsloth documents fp16 as broken for Gemma 4. On a T4 that leaves fp32 —
    # slower and heavier, but the only combination that actually runs.
    bf16_ok = _real_bf16()
    cfg_kwargs["bf16"] = bf16_ok
    cfg_kwargs["fp16"] = False
    print(f"precision: {'bf16' if bf16_ok else 'fp32'}", flush=True)
    trainer = SFTTrainer(
        model=model,
        train_dataset=ds,
        eval_dataset=val_ds if val_ds is not None and len(val_ds) else None,
        args=SFTConfig(**cfg_kwargs),
        callbacks=[_epoch_saver(out, tok)] + ([_time_budget(max_hours)] if max_hours > 0 else []),
        **{_pick(SFTTrainer, "processing_class", "tokenizer"): tok},
    )
    # No train_on_responses_only: the labels already carry the masking, from a tested pure
    # function rather than runtime string matching against the chat template.

    stats = trainer.train(resume_from_checkpoint=resume or None)
    (out / "train_stats.json").write_text(json.dumps(stats.metrics, indent=2), encoding="utf-8")

    save_adapter(model, tok, out / "adapter")
    if gguf:
        model.save_pretrained_gguf(str(out / "gguf"), tok, quantization_method="q4_k_m")
    if push:
        model.push_to_hub(push + "-adapter", tokenizer=tok)
        if gguf:
            model.push_to_hub_gguf(push + "-gguf", tok, quantization_method="q4_k_m")


if __name__ == "__main__":
    app()
