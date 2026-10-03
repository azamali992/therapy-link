"""GET /guardian/<file>: the Guardian bundle, public, cacheable, resumable, and nothing else."""

import hashlib

import pytest

from therapylink_api.settings import get_settings

BUNDLE = {
    "guardian.int8.onnx": bytes(range(256)) * 64,
    "spm_vocab.json": b'{"pieces": ["a", "b"]}',
    "config.json": b'{"tasks": {"crisis": ["none", "suicidal"]}}',
    "thresholds.json": b'{"crisis": [0.5, 0.02]}',
}


@pytest.fixture
def bundle(tmp_path, monkeypatch):
    for name, body in BUNDLE.items():
        (tmp_path / name).write_bytes(body)
    (tmp_path / "secret.txt").write_text("not for the internet")
    monkeypatch.setenv("TL_GUARDIAN_DIR", str(tmp_path))
    get_settings.cache_clear()  # the app fixture may have read the settings already
    return tmp_path


def _etag(body: bytes) -> str:
    return f'"{hashlib.sha256(body).hexdigest()}"'


async def test_each_bundle_file_is_served_without_sign_in(client, bundle):
    for name, body in BUNDLE.items():
        r = await client.get(f"/guardian/{name}")
        assert r.status_code == 200, name
        assert r.content == body
        assert r.headers["etag"] == _etag(body)
        assert "public" in r.headers["cache-control"]
        assert "max-age=" in r.headers["cache-control"]
        assert r.headers["x-content-type-options"] == "nosniff"
    assert (await client.get("/guardian/config.json")).headers["content-type"].startswith("application/json")
    assert (await client.get("/guardian/guardian.int8.onnx")).headers["content-type"] == "application/octet-stream"


async def test_head_gives_the_size_without_the_body(client, bundle):
    r = await client.head("/guardian/guardian.int8.onnx")
    assert r.status_code == 200
    assert int(r.headers["content-length"]) == len(BUNDLE["guardian.int8.onnx"])
    assert r.content == b""


async def test_a_dropped_download_resumes_with_a_range(client, bundle):
    body = BUNDLE["guardian.int8.onnx"]
    r = await client.get("/guardian/guardian.int8.onnx", headers={"Range": "bytes=1000-"})
    assert r.status_code == 206
    assert r.content == body[1000:]
    assert r.headers["content-range"] == f"bytes 1000-{len(body) - 1}/{len(body)}"


async def test_if_range_with_the_current_etag_resumes_and_a_stale_one_sends_the_whole_file(client, bundle):
    body = BUNDLE["guardian.int8.onnx"]
    same = await client.get("/guardian/guardian.int8.onnx", headers={"Range": "bytes=10-", "If-Range": _etag(body)})
    assert same.status_code == 206
    assert same.content == body[10:]

    stale = await client.get(
        "/guardian/guardian.int8.onnx", headers={"Range": "bytes=10-", "If-Range": '"' + "0" * 64 + '"'}
    )
    assert stale.status_code == 200
    assert stale.content == body


async def test_a_cache_revalidates_with_the_etag(client, bundle):
    tag = _etag(BUNDLE["thresholds.json"])
    r = await client.get("/guardian/thresholds.json", headers={"If-None-Match": tag})
    assert r.status_code == 304
    assert r.headers["etag"] == tag
    assert r.content == b""


async def test_a_swapped_file_gets_a_new_etag(client, bundle):
    first = (await client.get("/guardian/config.json")).headers["etag"]
    (bundle / "config.json").write_bytes(b'{"tasks": {"crisis": ["none", "suicidal", "medical"]}}')
    second = (await client.get("/guardian/config.json")).headers["etag"]
    assert first != second


@pytest.mark.parametrize(
    "path",
    ["/guardian/secret.txt", "/guardian/..%2Fsecret.txt", "/guardian/verified.json", "/guardian/", "/guardian/x.onnx"],
)
async def test_nothing_outside_the_four_files_is_reachable(client, bundle, path):
    r = await client.get(path)
    assert r.status_code == 404
    assert b"not for the internet" not in r.content


async def test_without_a_configured_directory_the_route_is_404(client, monkeypatch):
    monkeypatch.delenv("TL_GUARDIAN_DIR", raising=False)
    get_settings.cache_clear()
    assert (await client.get("/guardian/config.json")).status_code == 404


async def test_a_missing_file_is_404(client, bundle):
    (bundle / "spm_vocab.json").unlink()
    assert (await client.get("/guardian/spm_vocab.json")).status_code == 404
