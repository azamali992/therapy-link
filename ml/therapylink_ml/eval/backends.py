from __future__ import annotations

import os
import time
from dataclasses import dataclass
from typing import Protocol


@dataclass
class Generation:
    text: str
    seconds: float
    tokens: int | None = None

    @property
    def tokens_per_second(self) -> float | None:
        return self.tokens / self.seconds if self.tokens and self.seconds else None


class Backend(Protocol):
    name: str

    def generate(
        self, messages: list[dict], *, max_tokens: int = 256, temperature: float = 0.7, json_schema: dict | None = None
    ) -> Generation:
        """json_schema, when given, constrains the output to that schema (the judge uses it)."""
        ...


class LlamaCppBackend:
    """Local GGUF via llama-cpp-python. Uses the template baked into the GGUF."""

    def __init__(self, model_path: str, n_ctx: int = 4096, n_gpu_layers: int = -1, name: str | None = None):
        from llama_cpp import Llama

        self.name = name or os.path.basename(model_path)
        self.llm = Llama(model_path=model_path, n_ctx=n_ctx, n_gpu_layers=n_gpu_layers, verbose=False)

    def generate(self, messages, *, max_tokens=256, temperature=0.7, json_schema=None) -> Generation:
        extra = {"response_format": {"type": "json_object", "schema": json_schema}} if json_schema else {}
        t0 = time.perf_counter()
        out = self.llm.create_chat_completion(messages=messages, max_tokens=max_tokens, temperature=temperature, **extra)
        dt = time.perf_counter() - t0
        return Generation(
            text=out["choices"][0]["message"]["content"].strip(),
            seconds=dt,
            tokens=out.get("usage", {}).get("completion_tokens"),
        )


class OpenAICompatBackend:
    """Any OpenAI-compatible chat endpoint: llama-server, vLLM, Gemini's compat API, OpenAI."""

    def __init__(
        self,
        base_url: str,
        model: str,
        api_key: str | None = None,
        name: str | None = None,
        thinking: bool = False,
    ):
        from openai import OpenAI

        self.name = name or model
        self.model = model
        self.thinking = thinking
        self.client = OpenAI(base_url=base_url, api_key=api_key or os.environ.get("OPENAI_API_KEY", "none"))

    def generate(self, messages, *, max_tokens=256, temperature=0.7, json_schema=None) -> Generation:
        # Gemma 4 reasons by default and spends the whole budget on it, leaving `content` empty.
        # Eve is trained on direct replies, so the baseline must answer directly too or the
        # comparison is meaningless.
        extra = {} if self.thinking else {"chat_template_kwargs": {"enable_thinking": False}}
        fmt = {"response_format": response_format(json_schema)} if json_schema else {}
        t0 = time.perf_counter()
        resp = self.client.chat.completions.create(
            model=self.model, messages=messages, max_tokens=max_tokens, temperature=temperature, extra_body=extra, **fmt
        )
        dt = time.perf_counter() - t0
        msg = resp.choices[0].message
        text = (msg.content or "").strip()
        if not text:
            # Never return a silent empty string — it scores as a total safety failure and looks
            # like a model result rather than a plumbing bug.
            reasoning = (getattr(msg, "reasoning_content", None) or "").strip()
            raise RuntimeError(
                f"empty content from {self.model} (finish_reason={resp.choices[0].finish_reason}, "
                f"{len(reasoning)} chars of reasoning). Raise --max-tokens or disable thinking."
            )
        usage = getattr(resp, "usage", None)
        return Generation(text=text, seconds=dt, tokens=getattr(usage, "completion_tokens", None))


class HFBackend:
    """Transformers model, optionally with a PEFT adapter. For quick checks on a GPU box."""

    def __init__(
        self,
        model_id: str,
        adapter: str | None = None,
        load_in_4bit: bool = True,
        name: str | None = None,
        dtype: str = "auto",
    ):
        import torch
        from transformers import AutoModelForCausalLM, AutoTokenizer

        self.name = name or (adapter or model_id)
        self.tokenizer = AutoTokenizer.from_pretrained(adapter or model_id)
        compute = resolve_dtype(dtype, torch)
        kwargs = {"device_map": "auto", "torch_dtype": compute}
        if load_in_4bit:
            from transformers import BitsAndBytesConfig

            kwargs["quantization_config"] = BitsAndBytesConfig(load_in_4bit=True, bnb_4bit_compute_dtype=compute)
        self.model = AutoModelForCausalLM.from_pretrained(model_id, **kwargs)
        if adapter:
            from peft import PeftModel

            self.model = PeftModel.from_pretrained(self.model, adapter)
        self.model.eval()

    def generate(self, messages, *, max_tokens=256, temperature=0.7, json_schema=None) -> Generation:
        # json_schema is not enforced here; judge through llama-server or llama-cpp instead.
        import torch

        ids = encode_chat(self.tokenizer, messages).to(self.model.device)
        t0 = time.perf_counter()
        with torch.no_grad():
            out = self.model.generate(
                ids,
                max_new_tokens=max_tokens,
                do_sample=temperature > 0,
                temperature=max(temperature, 1e-5),
                eos_token_id=stop_token_ids(self.tokenizer),
            )
        dt = time.perf_counter() - t0
        new = out[0, ids.shape[1] :]
        return Generation(text=self.tokenizer.decode(new, skip_special_tokens=True).strip(), seconds=dt, tokens=int(new.numel()))


# Gemma 4 closes a model turn with this token. Without it as a stop token, generation can run past
# the end of the reply into a made-up next turn and on to the token cap.
END_OF_TURN = "<turn|>"


def resolve_dtype(dtype: str, torch):
    """fp16 is not offered: it is broken for Gemma 4 (Unsloth warns, and the trainer avoids it)."""
    if dtype == "bf16":
        return torch.bfloat16
    if dtype == "fp32":
        return torch.float32
    if dtype == "auto":
        return torch.bfloat16 if torch.cuda.is_available() and torch.cuda.is_bf16_supported() else torch.float32
    raise ValueError(f"dtype must be bf16, fp32 or auto, not {dtype!r}")


def encode_chat(tokenizer, messages: list[dict]):
    # Gemma 4's template reasons by default; Eve is trained to answer directly.
    return tokenizer.apply_chat_template(messages, add_generation_prompt=True, return_tensors="pt", enable_thinking=False)


def stop_token_ids(tokenizer) -> list[int]:
    ids = [tokenizer.eos_token_id] if tokenizer.eos_token_id is not None else []
    turn = tokenizer.convert_tokens_to_ids(END_OF_TURN)
    if turn is not None and turn != tokenizer.unk_token_id and turn not in ids:
        ids.append(turn)
    return ids


def response_format(schema: dict) -> dict:
    # OpenAI's structured-output shape; llama-server compiles the schema into a grammar.
    return {"type": "json_schema", "json_schema": {"name": "judgement", "schema": schema, "strict": True}}


def make_backend(spec: str, **kwargs) -> Backend:
    """spec: 'llamacpp:<path.gguf>' | 'openai:<base_url>|<model>' | 'hf:<model_id>[|<adapter>]'"""
    kind, _, rest = spec.partition(":")
    if kind == "llamacpp":
        return LlamaCppBackend(rest, **kwargs)
    if kind == "openai":
        base_url, _, model = rest.partition("|")
        return OpenAICompatBackend(base_url, model or "default", **kwargs)
    if kind == "hf":
        model_id, _, adapter = rest.partition("|")
        return HFBackend(model_id, adapter or None, **kwargs)
    raise ValueError(f"unknown backend spec {spec!r}")
