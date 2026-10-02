"""HFBackend's template call, stop tokens and dtype, with stubs: no model is loaded."""

from types import SimpleNamespace

import pytest

from therapylink_ml.eval import backends


class StubTokenizer:
    eos_token_id = 1
    unk_token_id = 3

    def __init__(self, vocab=None):
        self.vocab = vocab if vocab is not None else {"<turn|>": 106}
        self.template_calls = []

    def apply_chat_template(self, messages, **kwargs):
        self.template_calls.append((messages, kwargs))
        return "IDS"

    def convert_tokens_to_ids(self, token):
        return self.vocab.get(token, self.unk_token_id)


def test_template_is_called_with_thinking_off_and_a_generation_prompt():
    tok = StubTokenizer()
    msgs = [{"role": "user", "content": "hi"}]
    assert backends.encode_chat(tok, msgs) == "IDS"
    assert tok.template_calls == [(msgs, {"add_generation_prompt": True, "return_tensors": "pt", "enable_thinking": False})]


def test_end_of_turn_is_a_stop_token():
    assert backends.stop_token_ids(StubTokenizer()) == [1, 106]
    # A tokenizer without the token must not add unk as a stop token.
    assert backends.stop_token_ids(StubTokenizer(vocab={})) == [1]


def _torch(cuda: bool, bf16: bool):
    return SimpleNamespace(
        bfloat16="bf16",
        float32="fp32",
        float16="fp16",
        cuda=SimpleNamespace(is_available=lambda: cuda, is_bf16_supported=lambda: bf16),
    )


def test_dtype_never_falls_back_to_fp16():
    assert backends.resolve_dtype("bf16", _torch(True, True)) == "bf16"
    assert backends.resolve_dtype("fp32", _torch(True, True)) == "fp32"
    assert backends.resolve_dtype("auto", _torch(True, True)) == "bf16"
    assert backends.resolve_dtype("auto", _torch(True, False)) == "fp32"  # a T4 has no bf16
    assert backends.resolve_dtype("auto", _torch(False, False)) == "fp32"
    with pytest.raises(ValueError):
        backends.resolve_dtype("fp16", _torch(True, True))


def test_generate_passes_the_stop_tokens_to_the_model():
    torch = pytest.importorskip("torch")

    class StubModel:
        device = "cpu"

        def generate(self, ids, **kwargs):
            self.kwargs = kwargs
            return torch.cat([ids, torch.tensor([[7, 8]])], dim=1)

    class Tok(StubTokenizer):
        def apply_chat_template(self, messages, **kwargs):
            super().apply_chat_template(messages, **kwargs)
            return torch.tensor([[5, 6]])

        def decode(self, ids, skip_special_tokens=True):
            return " reply "

    be = backends.HFBackend.__new__(backends.HFBackend)
    be.tokenizer, be.model = Tok(), StubModel()
    g = be.generate([{"role": "user", "content": "hi"}], max_tokens=10, temperature=0.0)
    assert g.text == "reply" and g.tokens == 2
    assert be.model.kwargs["eos_token_id"] == [1, 106]
    assert be.model.kwargs["do_sample"] is False
    assert be.tokenizer.template_calls[0][1]["enable_thinking"] is False
