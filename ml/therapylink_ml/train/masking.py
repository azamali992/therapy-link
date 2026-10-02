"""Token-level supervision masking, done here rather than by the trainer.

Doing it ourselves buys three things:

* TRL never has to `map()` over the dataset, which is what kept failing — `datasets` hashes every
  transform with dill for its cache fingerprint, and Unsloth's patches put an unpicklable torch
  ConfigModule inside TRL's closure.
* The masking is a pure function over token ids, so it can be tested. `train_on_responses_only`
  matches marker *strings*; when those silently don't match (as Gemma 4's did) it masks the wrong
  tokens and trains a quietly bad model with no error.
* Nothing depends on the marker text at runtime — the ids are resolved once, up front.
"""

from __future__ import annotations

IGNORE = -100


def find_spans(ids: list[int], start: list[int], end: list[int], min_tokens: int = 0) -> list[tuple[int, int]]:
    """Half-open [from, to) spans that begin after each `start` run and run THROUGH the next `end`.

    The closing marker is supervised on purpose. Gemma 4's `<turn|>` is also its EOS token, and a
    model never trained to emit it never stops: v11's checkpoint excluded it and ran every one of
    48 eval replies to the 400-token cap, looping. A reply with no content is still skipped.

    An unterminated final span runs to the end of the sequence, which is what truncation leaves
    behind and is still valid supervision.
    """
    if not start:
        return []
    spans: list[tuple[int, int]] = []
    i = 0
    n = len(ids)
    while i <= n - len(start):
        if ids[i : i + len(start)] != start:
            i += 1
            continue
        begin = i + len(start)
        j = begin
        stop = content_stop = n
        while end and j <= n - len(end):
            if ids[j : j + len(end)] == end:
                content_stop, stop = j, j + len(end)
                break
            j += 1
        # min_tokens leaves short replies as context without training on them: v13 learned its
        # one-line brush-offs from exactly those turns (27% of the weighted mix was <=12 words).
        if content_stop - begin >= max(1, min_tokens):
            spans.append((begin, stop))
        i = max(stop, begin)
    return spans


def mask_to_spans(ids: list[int], spans: list[tuple[int, int]]) -> list[int]:
    """Labels that supervise only the given spans; everything else is ignored by the loss."""
    labels = [IGNORE] * len(ids)
    for begin, stop in spans:
        for k in range(begin, min(stop, len(ids))):
            labels[k] = ids[k]
    return labels


def response_labels(ids: list[int], start: list[int], end: list[int], min_tokens: int = 0) -> list[int]:
    return mask_to_spans(ids, find_spans(ids, start, end, min_tokens))
