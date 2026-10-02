"""Merge a LoRA adapter into its base model and save a plain safetensors checkpoint.

The merged checkpoint is what both export paths consume: litetune (→ .litertlm for the phone)
and llama.cpp's convert script (→ GGUF for eval on the 2050 box).
"""

from __future__ import annotations

import re
from pathlib import Path

import typer

app = typer.Typer(add_completion=False)

# Unsloth trains QLoRA against pre-quantised repos and records that repo as the adapter's base.
# Merging into it would bake bnb-4bit rounding into the "float" checkpoint that litetune converts
# and that `litetune verify` treats as the reference. These are the float repos they came from.
FLOAT_BASES = {
    "unsloth/gemma-4-e2b-it-unsloth-bnb-4bit": "unsloth/gemma-4-E2B-it",
    "unsloth/gemma-4-e2b-it-bnb-4bit": "unsloth/gemma-4-E2B-it",
    "unsloth/gemma-4-e4b-it-unsloth-bnb-4bit": "unsloth/gemma-4-E4B-it",
    "unsloth/gemma-4-e4b-it-bnb-4bit": "unsloth/gemma-4-E4B-it",
}
_QUANTISED = re.compile(r"(bnb|4bit|8bit|gptq|awq|gguf)", re.I)


def float_base(base_id: str) -> str:
    """The float repo to merge into, or a clear error if `base_id` is quantised and unknown."""
    mapped = FLOAT_BASES.get(base_id.lower())
    if mapped:
        return mapped
    if _QUANTISED.search(base_id):
        raise ValueError(
            f"{base_id!r} is a quantised checkpoint and merging into it would bake quantisation error "
            f"into the float model. Pass the float repo it came from with --base (for Gemma 4 E2B: "
            f"unsloth/gemma-4-E2B-it)."
        )
    return base_id


@app.command()
def merge(
    adapter: Path = typer.Argument(..., help="Directory saved by eve_sft.py (runs/eve-sft/adapter)"),
    out: Path = typer.Option(Path("runs/eve-merged"), "--out"),
    base: str = typer.Option("", help="Override the base model id recorded in the adapter config (must be a float repo)"),
    dtype: str = typer.Option("bfloat16", help="bfloat16 | float16 | float32"),
) -> None:
    import json

    import torch
    from peft import PeftModel
    from transformers import AutoConfig, AutoModelForCausalLM, AutoProcessor, AutoTokenizer

    cfg = json.loads((adapter / "adapter_config.json").read_text(encoding="utf-8"))
    recorded = base or cfg["base_model_name_or_path"]
    try:
        base_id = float_base(recorded)
    except ValueError as e:
        raise typer.BadParameter(str(e)) from None
    if base_id != recorded:
        typer.echo(f"adapter was trained on {recorded}; merging into its float repo {base_id}")
    torch_dtype = getattr(torch, dtype)
    typer.echo(f"base: {base_id}  adapter: {adapter}  dtype: {dtype}")

    model_cfg = AutoConfig.from_pretrained(base_id)
    if getattr(model_cfg, "quantization_config", None) is not None:
        raise typer.BadParameter(f"{base_id} carries a quantization_config; merge needs the float checkpoint")
    if getattr(model_cfg, "vision_config", None) is not None or getattr(model_cfg, "audio_config", None) is not None:
        from transformers import AutoModelForImageTextToText

        model = AutoModelForImageTextToText.from_pretrained(base_id, torch_dtype=torch_dtype, low_cpu_mem_usage=True)
    else:
        model = AutoModelForCausalLM.from_pretrained(base_id, torch_dtype=torch_dtype, low_cpu_mem_usage=True)

    model = PeftModel.from_pretrained(model, adapter)
    model = model.merge_and_unload()
    out.mkdir(parents=True, exist_ok=True)
    model.save_pretrained(out, safe_serialization=True)
    try:
        AutoProcessor.from_pretrained(base_id).save_pretrained(out)
    except Exception:
        AutoTokenizer.from_pretrained(base_id).save_pretrained(out)
    # Carry the prompt manifest across, so the exported model still says which prompt it needs.
    manifest = adapter / "training_prompt.json"
    if manifest.exists():
        (out / manifest.name).write_text(manifest.read_text(encoding="utf-8"), encoding="utf-8")
    typer.echo(f"merged checkpoint written to {out}")


if __name__ == "__main__":
    app()
