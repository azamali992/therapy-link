"""LoRA bookkeeping shared by the SFT and DPO trainers."""

from __future__ import annotations


def unfreeze_lora(model, source: str, adapter_name: str | None = None) -> int:
    """Make a loaded adapter trainable and return its trainable parameter count.

    A saved adapter says inference_mode=true, and PEFT then loads its weights frozen. Training a
    frozen adapter "succeeds" with a flat loss and changes nothing; v12's continuation found this
    the expensive way. With `adapter_name`, only that adapter's LoRA weights are unfrozen and any
    other adapter on the model (a DPO reference copy) is frozen explicitly.
    """
    for name, param in model.named_parameters():
        if "lora_" not in name:
            continue
        mine = adapter_name is None or f".{adapter_name}." in name
        param.requires_grad_(mine)
    trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
    if trainable == 0:
        raise RuntimeError(f"no trainable LoRA parameters found in {source}")
    return trainable
