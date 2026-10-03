#!/usr/bin/env python3
"""Measure how fast a running Eve llama-server answers, with the real served prompt.

    TL_LLM_API_KEY=... python3 ops/free/bench.py --url http://127.0.0.1:8080 [--parallel 1 2] [--out FILE]

Stdlib only, so it runs on a fresh VM with nothing but python3. It sends the four non-crisis
conversations from ops/serving/smoke.py (V2 system prompt folded into the first user turn, exactly
as the app sends it), greedy, max 450 tokens, then a second turn of one of them (to show the prompt
cache at work), then N requests at once for each --parallel value. Reports, per reply: prompt
tokens, prompt-processing tok/s, generation tok/s, completion tokens and wall time.

It prints no reply text unless --show is passed: on a shared box the terminal scrollback is a log.
Safety scoring is smoke.py's job; this only measures speed.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import statistics
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
MAX_TOKENS = 450


def load_prompts():
    path = REPO / "ml" / "therapylink_ml" / "prompts.py"
    spec = importlib.util.spec_from_file_location("tl_prompts", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


PROMPTS = [
    ("greeting-en", "Hi Eve, I'm new here. Not sure what to say, honestly."),
    ("venting-roman-urdu", "yaar aaj kal ghar mein sab mujh se naraz rehte hain. ammi har baat pe taunt karti hain aur lagta hai main kuch bhi theek nahi kar sakti."),
    ("stress-en", "My boss keeps piling work on me and this deadline is literally killing me. How do I deal with it?"),
    ("sleep-en", "Couldn't sleep again last night. Exams are getting closer and my head just won't switch off."),
]  # fmt: skip
FOLLOW_UP = "Yeah, it's mostly at night. I lie there replaying everything I still haven't done."


def post(url: str, key: str, messages: list[dict], timeout: float) -> dict:
    body = json.dumps({
        "model": "eve",
        "messages": messages,
        "max_tokens": MAX_TOKENS,
        "temperature": 0.0,
        "seed": 0,
        "chat_template_kwargs": {"enable_thinking": False},
    }).encode()  # fmt: skip
    req = urllib.request.Request(
        url.rstrip("/") + "/v1/chat/completions",
        data=body,
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {key}"},
    )
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=timeout) as r:
        j = json.loads(r.read())
    wall = time.time() - t0
    t = j.get("timings", {})
    u = j.get("usage", {})
    return {
        "reply": j["choices"][0]["message"].get("content") or "",
        "finish": j["choices"][0].get("finish_reason"),
        "prompt_tokens": u.get("prompt_tokens"),
        "prompt_cached": t.get("cache_n"),
        "prompt_tps": round(t.get("prompt_per_second", 0), 1),
        "completion_tokens": u.get("completion_tokens"),
        "gen_tps": round(t.get("predicted_per_second", 0), 2),
        "wall_s": round(wall, 2),
    }


def line(name: str, g: dict) -> str:
    return (f"  {name:<22} prompt {g['prompt_tokens']:>4} tok (cached {g['prompt_cached']}) @ {g['prompt_tps']:>6} tok/s | "
            f"reply {g['completion_tokens']:>3} tok @ {g['gen_tps']:>5} tok/s | {g['wall_s']:>6} s | {g['finish']}")  # fmt: skip


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default="http://127.0.0.1:8080")
    ap.add_argument("--parallel", type=int, nargs="*", default=[2])
    ap.add_argument("--timeout", type=float, default=900)
    ap.add_argument("--label", default="")
    ap.add_argument("--out", type=Path)
    ap.add_argument("--show", action="store_true", help="print the replies too")
    args = ap.parse_args()
    key = os.environ.get("TL_LLM_API_KEY") or os.environ.get("TL_INFERENCE_API_KEY")
    if not key:
        print("set TL_LLM_API_KEY (the llama-server key)", file=sys.stderr)
        return 2

    p = load_prompts()
    fold = p.fold_system_into_first_user
    report: dict = {"label": args.label, "url": args.url, "max_tokens": MAX_TOKENS, "single": [], "parallel": {}}

    print("warm-up ...", flush=True)
    post(args.url, key, [{"role": "user", "content": "hello"}], args.timeout)

    print("one at a time:")
    for name, text in PROMPTS:
        g = post(args.url, key, fold([{"role": "user", "content": text}]), args.timeout)
        report["single"].append({"id": name, **{k: v for k, v in g.items() if k != "reply"}})
        print(line(name, g), flush=True)
        if args.show:
            print("   ", g["reply"].replace("\n", " "))
        if name == "sleep-en":
            convo = fold([{"role": "user", "content": text}]) + [
                {"role": "assistant", "content": g["reply"]},
                {"role": "user", "content": FOLLOW_UP},
            ]
            g2 = post(args.url, key, convo, args.timeout)
            report["single"].append({"id": "sleep-en-turn2", **{k: v for k, v in g2.items() if k != "reply"}})
            print(line("sleep-en turn 2", g2), flush=True)

    for n in args.parallel:
        msgs = [fold([{"role": "user", "content": PROMPTS[i % len(PROMPTS)][1]}]) for i in range(n)]
        t0 = time.time()
        with ThreadPoolExecutor(n) as pool:
            res = list(pool.map(lambda m: post(args.url, key, m, args.timeout), msgs))
        wall = time.time() - t0
        toks = sum(r["completion_tokens"] or 0 for r in res)
        report["parallel"][str(n)] = {
            "wall_s": round(wall, 2),
            "completion_tokens": toks,
            "aggregate_gen_tps": round(toks / wall, 2),
            "per_request_gen_tps": [r["gen_tps"] for r in res],
            "per_request_wall_s": [r["wall_s"] for r in res],
        }
        print(f"{n} at once: {toks} tokens in {wall:.1f} s = {toks / wall:.2f} tok/s overall, "
              f"each {[r['gen_tps'] for r in res]} tok/s, slowest reply {max(r['wall_s'] for r in res)} s", flush=True)  # fmt: skip

    first = [r for r in report["single"] if r["id"] != "sleep-en-turn2"]
    report["summary"] = {
        "gen_tps_mean": round(statistics.mean(r["gen_tps"] for r in first), 2),
        "prompt_tps_mean": round(statistics.mean(r["prompt_tps"] for r in first), 1),
        "completion_tokens_mean": round(statistics.mean(r["completion_tokens"] for r in first), 1),
        "wall_s_mean": round(statistics.mean(r["wall_s"] for r in first), 2),
        "wall_s_max": max(r["wall_s"] for r in first),
    }
    print(json.dumps(report["summary"]))
    if args.out:
        args.out.write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
