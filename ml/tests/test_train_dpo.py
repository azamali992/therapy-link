import itertools

import pytest
import typer

from therapylink_ml.train.eve_dpo import (
    AccuracyWatch,
    MarginWatch,
    Sample,
    build_pairs,
    hit_cap,
    load_prompts,
    make_pairs,
    pick_pair,
    split_pairs,
)
from therapylink_ml.train.lora import unfreeze_lora
from therapylink_ml.train.reply_rules import score_reply

GOOD = (
    "I'm really glad you told me, and I'm worried about you. Carrying this alone sounds exhausting. "
    "Umang has psychologists you can talk to on 0311-7786264, and if you might act on this tonight "
    "please call 1122. Is there someone who can be with you right now?"
)
BAD = "That sounds hard. You could call 988, the Suicide and Crisis Lifeline."


def _saved_adapter(tmp_path):
    from peft import LoraConfig, get_peft_model
    from torch import nn

    peft = get_peft_model(nn.Sequential(nn.Linear(4, 4), nn.ReLU(), nn.Linear(4, 2)), LoraConfig(r=2, target_modules=["0", "2"]))
    peft.save_pretrained(tmp_path)
    return tmp_path


def test_a_reloaded_adapter_is_frozen_until_unfrozen_and_the_reference_stays_frozen(tmp_path):
    from peft import PeftModel
    from torch import nn

    path = _saved_adapter(tmp_path)
    model = PeftModel.from_pretrained(nn.Sequential(nn.Linear(4, 4), nn.ReLU(), nn.Linear(4, 2)), path)
    # The bug eve_dpo had: a saved adapter loads with inference_mode=true, i.e. nothing trainable.
    assert sum(p.numel() for p in model.parameters() if p.requires_grad) == 0
    model.load_adapter(path, adapter_name="reference")

    trainable = unfreeze_lora(model, str(path), adapter_name="default")

    assert trainable > 0
    grads = {n: p.requires_grad for n, p in model.named_parameters() if "lora_" in n}
    assert all(v for n, v in grads.items() if ".default." in n)
    assert not any(v for n, v in grads.items() if ".reference." in n)


def test_unfreeze_fails_loudly_when_there_is_no_adapter():
    from torch import nn

    model = nn.Linear(4, 4)
    for p in model.parameters():
        p.requires_grad_(False)
    with pytest.raises(RuntimeError, match="no trainable LoRA"):
        unfreeze_lora(model, "somewhere")


def test_margins_stuck_at_zero_abort_at_the_check_step():
    watch = MarginWatch(check_step=50)
    for step in range(10, 50, 10):
        assert watch.observe(step, {"rewards/margins": 0.0}) is None
    assert "stayed 0" in watch.observe(50, {"rewards/margins": 0.0})
    assert watch.observe(60, {"rewards/margins": 0.0}) is None  # reported once


def test_moving_margins_do_not_abort_and_a_missing_metric_does():
    watch = MarginWatch(check_step=50)
    watch.observe(10, {"rewards/margins": 0.02})
    assert watch.observe(50, {"rewards/margins": 0.0}) is None
    assert "no 'rewards/margins'" in MarginWatch(check_step=50).observe(50, {"loss": 0.7})


def test_memorised_pairs_stop_the_run_while_eval_accuracy_is_flat():
    # DPO v16's curve: train accuracy climbed to 1.0, eval stayed at 0.63-0.65.
    watch = AccuracyWatch(threshold=1.0, patience=2)
    assert watch.observe(10, {"rewards/accuracies": 0.43}) is None
    assert watch.observe(10, {"eval_rewards/accuracies": 0.63}) is None
    assert watch.observe(20, {"rewards/accuracies": 1.0}) is None  # one line is not a streak
    assert watch.observe(30, {"rewards/accuracies": 0.9}) is None  # streak resets
    assert watch.observe(30, {"eval_rewards/accuracies": 0.65}) is None
    assert watch.observe(40, {"rewards/accuracies": 1.0}) is None
    reason = watch.observe(50, {"rewards/accuracies": 1.0})
    assert reason and "0.63 -> 0.65" in reason
    assert watch.observe(60, {"rewards/accuracies": 1.0}) is None  # reported once


def test_perfect_train_accuracy_with_rising_eval_accuracy_keeps_training():
    watch = AccuracyWatch(threshold=1.0, patience=2)
    watch.observe(10, {"eval_rewards/accuracies": 0.60})
    watch.observe(20, {"eval_rewards/accuracies": 0.72})
    assert watch.observe(30, {"rewards/accuracies": 1.0}) is None
    assert watch.observe(40, {"rewards/accuracies": 1.0}) is None


def test_accuracy_stop_can_be_turned_off():
    watch = AccuracyWatch(threshold=0)
    assert all(watch.observe(s, {"rewards/accuracies": 1.0}) is None for s in range(10, 100, 10))


def test_pick_pair_needs_a_pass_and_a_fail():
    samples = [GOOD, BAD, GOOD + " I am here with you." * 30]  # the long one passes too, but is an essay
    scores = [score_reply("crisis", "en", s) for s in samples]
    assert pick_pair(samples, scores) == (0, 1)
    assert pick_pair([GOOD, GOOD], [scores[0], scores[0]]) is None
    assert pick_pair([BAD, BAD], [scores[1], scores[1]]) is None


def _prompt(i, **extra):
    return {"id": f"p{i}", "lang": "en", "route": "crisis", "messages": [{"role": "user", "content": f"message {i}"}], **extra}


def test_make_pairs_samples_on_policy_and_skips_prompts_it_already_handles():
    replies = itertools.cycle([GOOD, BAD])
    rows = list(make_pairs([_prompt(1)], lambda msgs: next(replies), k=4))
    assert len(rows) == 1
    row = rows[0]
    assert row["chosen"][0]["content"] == GOOD and row["rejected"][0]["content"] == BAD
    assert row["chosen_source"] == "policy" and "foreign_number" in row["rejected_failures"]
    # The system prompt is folded exactly as in SFT, so the pair is in the served format.
    assert row["prompt"][0]["content"].endswith("message 1") and "You are Eve" in row["prompt"][0]["content"]
    assert not list(make_pairs([_prompt(2)], lambda msgs: GOOD, k=4))
    assert not list(make_pairs([_prompt(1)], lambda msgs: next(replies), k=4, done={"p1"}))


def test_rewrites_are_used_only_when_approved_and_capped():
    replies = itertools.cycle([GOOD, BAD])
    policy = [_prompt(i) for i in range(3)]
    pending = _prompt(10, rewrite={"content": GOOD, "review_status": "pending_clinician"})
    approved = [_prompt(20 + i, rewrite={"content": GOOD, "review_status": "approved"}) for i in range(3)]

    def gen(msgs):
        # Prompts 10 and up only ever get failing samples; the rest alternate.
        return BAD if int(msgs[0]["content"].rsplit(" ", 1)[1]) >= 10 else next(replies)

    rows = list(make_pairs(policy + [pending] + approved, gen, k=2, max_rewrite_share=0.25))
    sources = [r["chosen_source"] for r in rows]
    assert "p10" not in {r["prompt_id"] for r in rows}
    assert sources.count("rewrite") == 1 and sources.count("rewrite") / len(sources) <= 0.25


def test_split_is_deterministic():
    rows = [{"prompt_id": f"p{i}", "prompt": []} for i in range(200)]
    train, held = split_pairs(rows, 0.2)
    assert (train, held) == split_pairs(rows, 0.2)
    assert 20 < len(held) < 60 and len(train) + len(held) == 200
    assert split_pairs(rows, 0) == (rows, [])


def test_authored_prompts_leave_out_rows_pending_review():
    ids = {p["id"].split("@")[0] for p in load_prompts("authored")}
    with_pending = {p["id"].split("@")[0] for p in load_prompts("authored", include_pending=True)}
    assert ids <= with_pending
    from therapylink_ml.data.loaders.authored import is_pending, rows

    pending = {r["id"] for r in rows(include_pending=True) if is_pending(r)}
    assert not ids & pending


def test_pairs_are_never_sampled_through_the_fp16_hf_backend():
    with pytest.raises(typer.BadParameter):
        build_pairs(backend="hf:unsloth/gemma-4-E2B-it|adapter")


def _cycling(items):
    it = itertools.cycle(items)
    return lambda msgs: next(it)


def test_a_one_liner_or_a_cut_off_reply_is_never_the_chosen_side():
    # v13 collapsed into one-liners; a short sample that breaks no rule must not become "chosen".
    short = "I'm here for you. Call 1122 or Umang 0311-7786264 if it gets worse."
    assert score_reply("crisis", "en", short).passed
    assert not list(make_pairs([_prompt(1)], _cycling([short, BAD]), k=4))
    cut = Sample(GOOD, truncated=True)
    assert not list(make_pairs([_prompt(2)], _cycling([cut, Sample(BAD)]), k=4))
    rows = list(make_pairs([_prompt(3)], _cycling([GOOD, short]), k=2))
    assert rows[0]["chosen"][0]["content"] == GOOD and "too_short" in rows[0]["rejected_failures"]


def test_a_reply_that_used_every_token_counts_as_cut_off():
    assert hit_cap(450, "anything", 450)
    assert not hit_cap(120, "It stopped mid", 450)  # the count wins over punctuation
    assert hit_cap(None, "and then I think that the", 450)
    assert not hit_cap(None, "Is there someone with you?", 450)


def test_the_ordinary_opening_of_a_crisis_row_is_scored_as_everyday():
    prompts = {p["id"]: p for p in load_prompts("authored", include_pending=True)}
    # The risk arrives in the second user turn; the first is an ordinary message.
    for row_id in ("en-crisis-017", "ur-crisis-017", "mx-crisis-004", "rl-ind-en-04"):
        assert prompts[f"{row_id}@0"]["route"] == "eve" and prompts[f"{row_id}@0"]["bucket"] == "none"
        assert prompts[f"{row_id}@2"]["route"] == "crisis"
    assert prompts["en-crisis-001@0"]["route"] == "crisis"  # single-turn rows are crisis from the start


def test_every_authored_gold_reply_passes_the_route_its_turn_is_scored_on():
    # The row's own gold reply is the reference for what a passing sample looks like.
    from therapylink_ml.data.loaders.authored import rows

    gold = {f"{r['id']}@{k}": r["messages"][k + 1]["content"] for r in rows(include_pending=True) for k in range(len(r["messages"]) - 1)}
    for p in load_prompts("authored", include_pending=True):
        if p["id"] in gold and p["route"] == "crisis":
            failures = score_reply("crisis", p["lang"], gold[p["id"]]).failures
            assert not {"no_acknowledge", "no_allowed_number"} & set(failures), (p["id"], failures)
        elif p["id"] in gold:
            assert "overreaction" not in score_reply("eve", p["lang"], gold[p["id"]]).failures, p["id"]
