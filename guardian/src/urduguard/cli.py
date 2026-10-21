"""urduguard check "text" [--mode loose] [--model DIR]   |   urduguard serve [--port 8000]   |   urduguard eval ..."""

from __future__ import annotations

import argparse
import json
import sys


def main(argv: list[str] | None = None) -> None:
    ap = argparse.ArgumentParser(prog="urduguard")
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("check")
    c.add_argument("text", nargs="+")
    c.add_argument("--mode", default="strict", choices=("strict", "loose"))
    c.add_argument("--model")
    s = sub.add_parser("serve")
    s.add_argument("--host", default="127.0.0.1")
    s.add_argument("--port", type=int, default=8000)
    s.add_argument("--model")
    e = sub.add_parser("eval", add_help=False)
    a, rest = ap.parse_known_args(argv)
    if a.cmd == "check":
        from . import api

        m = api.load(a.model) if a.model else None
        for r in api.check_batch(a.text, mode=a.mode, model=m):
            print(json.dumps(r.to_dict(), ensure_ascii=False))
    elif a.cmd == "serve":
        import os

        import uvicorn

        if a.model:
            os.environ["URDUGUARD_MODEL_DIR"] = a.model
        uvicorn.run("urduguard.server:app", host=a.host, port=a.port, access_log=False)
    elif a.cmd == "eval":
        from .eval.harness import main as eval_main

        eval_main(rest)


if __name__ == "__main__":
    main(sys.argv[1:])
