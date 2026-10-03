from datetime import UTC, datetime

import pytest

from tests.conftest import as_user
from therapylink_api.ratelimit import TokenBucket
from therapylink_api.schemas import (
    MAX_BIO,
    MAX_CHAT_CHARS,
    MAX_CHAT_MESSAGES,
    MAX_JOURNAL_BODY,
    MAX_MOOD_BATCH,
    MAX_SUMMARY,
)


def _msgs(n: int, size: int) -> list[dict]:
    return [{"role": "user", "content": "x" * size} for _ in range(n)]


@pytest.mark.parametrize(
    ("method", "path", "body"),
    [
        ("post", "/journal", {"body": "x" * (MAX_JOURNAL_BODY + 1)}),
        ("post", "/summaries", {"kind": "weekly", "content": "x" * (MAX_SUMMARY + 1)}),
        ("post", "/me/clinician", {"license_no": "PMC-1", "bio": "x" * (MAX_BIO + 1)}),
        ("post", "/assessments", {"instrument": "phq9", "answers": [0] * 1000}),
        ("post", "/inference/chat", {"messages": _msgs(1, MAX_CHAT_CHARS + 1)}),
        ("post", "/inference/chat", {"messages": _msgs(MAX_CHAT_MESSAGES + 1, 1)}),
        ("post", "/inference/chat", {"messages": _msgs(5, MAX_CHAT_CHARS // 4)}),
    ],
)
async def test_oversized_bodies_are_422(client, method, path, body):
    r = await getattr(client, method)(path, json=body, headers=as_user("u"))
    assert r.status_code == 422, r.text


async def test_mood_batch_is_capped(client):
    point = {"valence": 0, "source": "manual", "recorded_at": datetime.now(UTC).isoformat()}
    assert (
        await client.post("/mood/batch", json=[point] * (MAX_MOOD_BATCH + 1), headers=as_user("u"))
    ).status_code == 422
    r = await client.post("/mood/batch", json=[point] * MAX_MOOD_BATCH, headers=as_user("u"))
    assert r.status_code == 201


async def test_bodies_at_the_limit_are_accepted(client):
    assert (
        await client.post("/journal", json={"body": "x" * MAX_JOURNAL_BODY}, headers=as_user("u"))
    ).status_code == 201
    # Within every cap; 503 because no inference server is configured in tests.
    r = await client.post("/inference/chat", json={"messages": _msgs(4, MAX_CHAT_CHARS // 4)}, headers=as_user("u"))
    assert r.status_code == 503


async def test_one_long_message_within_the_total_is_accepted(client):
    # The app's wrap-up, summary and memory requests: one user message holding the instructions, a
    # transcript window of up to 6,000 characters, the running summary and up to 20 notes.
    transcript = "\n".join(f"User: {'x' * 180}\nEve: {'y' * 180}" for _ in range(17))  # ~6,200 chars
    notes = "\n".join(f"- situation: {'z' * 190}" for _ in range(20))
    content = f"{'Read this conversation. ' * 30}\n\nExisting notes:\n{notes}\n\nConversation:\n{transcript}"
    assert 10_000 < len(content) < MAX_CHAT_CHARS
    r = await client.post(
        "/inference/chat", json={"messages": [{"role": "user", "content": content}]}, headers=as_user("u")
    )
    assert r.status_code == 503  # past validation; no inference server in tests


async def test_chat_is_rate_limited_per_uid(app, client):
    app.state.chat_limiter = TokenBucket(capacity=2, period_s=600)
    body = {"messages": _msgs(1, 5)}
    assert [(await client.post("/inference/chat", json=body, headers=as_user("a"))).status_code for _ in range(2)] == [
        503,
        503,
    ]
    r = await client.post("/inference/chat", json=body, headers=as_user("a"))
    assert r.status_code == 429 and int(r.headers["retry-after"]) > 0
    # Another uid has its own bucket.
    assert (await client.post("/inference/chat", json=body, headers=as_user("b"))).status_code == 503


def test_token_bucket_refills_over_time():
    now = [0.0]
    bucket = TokenBucket(capacity=3, period_s=30, clock=lambda: now[0])  # one token per 10 s
    assert [bucket.take("k") for _ in range(3)] == [0, 0, 0]
    assert bucket.take("k") == pytest.approx(10)
    now[0] = 5
    assert bucket.take("k") == pytest.approx(5)
    now[0] = 10
    assert bucket.take("k") == 0 and bucket.take("k") > 0
    now[0] = 1000
    assert [bucket.take("k") for _ in range(4)][:3] == [0, 0, 0]  # refills to capacity, no further
