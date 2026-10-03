from datetime import UTC, datetime

import pytest
from firebase_admin.exceptions import UnknownError
from sqlalchemy import func, select

from tests.conftest import as_user, linked, verified_clinician
from therapylink_api import db, firebase
from therapylink_api.auth import Identity, signed_in
from therapylink_api.models import (
    Assessment,
    CareLink,
    ClinicianProfile,
    ErasedAccount,
    JournalEntry,
    MoodPoint,
    SharedSummary,
    User,
)

_TABLES = (User, Assessment, MoodPoint, JournalEntry, SharedSummary, CareLink)


async def _counts(uid: str) -> dict[str, int]:
    async with db.sessionmaker()() as s:
        out = {}
        for model in _TABLES:
            col = model.uid if model is User else model.patient_uid
            out[model.__tablename__] = await s.scalar(select(func.count()).select_from(model).where(col == uid))
        return out


async def _patient_with_everything(client, uid: str = "pat") -> None:
    await verified_clinician(client)
    await client.post("/assessments", json={"instrument": "phq9", "answers": [1] * 9}, headers=as_user(uid))
    now = datetime.now(UTC).isoformat()
    await client.post(
        "/mood/batch", json=[{"valence": 1, "source": "manual", "recorded_at": now}], headers=as_user(uid)
    )
    await client.post("/journal", json={"body": "a day"}, headers=as_user(uid))
    await client.post("/summaries", json={"kind": "weekly", "content": "a week"}, headers=as_user(uid))
    await linked(client, uid)


async def test_delete_me_cascades_to_every_patient_table(client):
    await _patient_with_everything(client)
    assert all(n == 1 for n in (await _counts("pat")).values())

    r = await client.delete("/me", headers=as_user("pat"))
    assert r.status_code == 204 and r.content == b""
    assert all(n == 0 for n in (await _counts("pat")).values())
    # The clinician on the other end of the link is untouched.
    async with db.sessionmaker()() as s:
        assert await s.get(User, "doc") is not None and await s.get(ClinicianProfile, "doc") is not None


async def test_deleting_a_clinician_removes_their_profile_and_links(client):
    await _patient_with_everything(client)
    assert (await client.delete("/me", headers=as_user("doc"))).status_code == 204
    async with db.sessionmaker()() as s:
        assert await s.get(ClinicianProfile, "doc") is None
        assert await s.scalar(select(func.count()).select_from(CareLink)) == 0
        assert await s.get(User, "pat") is not None


def _as_firebase_user(app, uid: str) -> None:
    """A caller whose token Firebase verified, rather than one using the dev bypass."""

    async def identity() -> Identity:
        return Identity(uid, None, None, False)

    app.dependency_overrides[signed_in] = identity


async def test_delete_me_removes_the_firebase_user(app, client, monkeypatch):
    deleted: list[str] = []
    monkeypatch.setattr(firebase, "delete_user", deleted.append)
    _as_firebase_user(app, "fb-uid")
    await client.post("/journal", json={"body": "x"})
    assert (await client.delete("/me")).status_code == 204
    assert deleted == ["fb-uid"]
    assert (await _counts("fb-uid"))["journal_entries"] == 0


async def test_an_erased_accounts_token_cannot_recreate_it(app, client, monkeypatch):
    deleted: list[str] = []
    monkeypatch.setattr(firebase, "delete_user", deleted.append)
    _as_firebase_user(app, "fb-uid")
    await client.post("/journal", json={"body": "x"})
    assert (await client.delete("/me")).status_code == 204
    # The ID token is still valid for up to an hour: a queued upload must not bring the user back.
    now = datetime.now(UTC).isoformat()
    r = await client.post("/mood/batch", json=[{"valence": 1, "source": "manual", "recorded_at": now}])
    assert r.status_code == 401 and r.json() == {"detail": "account deleted"}
    assert (await client.get("/me")).status_code == 401
    assert all(n == 0 for n in (await _counts("fb-uid")).values())
    # The tombstone holds a hash, not the uid.
    async with db.sessionmaker()() as s:
        assert "fb-uid" not in [e.uid_sha256 for e in (await s.scalars(select(ErasedAccount))).all()]
    # Deleting again, as the app does after a 502, still reaches Firebase.
    assert (await client.delete("/me")).status_code == 204
    assert deleted == ["fb-uid", "fb-uid"]
    assert (await _counts("fb-uid"))["users"] == 0


async def test_dev_bypass_users_have_no_firebase_account_to_delete(client, monkeypatch):
    monkeypatch.setattr(firebase, "delete_user", lambda uid: pytest.fail("called Firebase for a dev uid"))
    assert (await client.delete("/me", headers=as_user("dev-only"))).status_code == 204


async def test_firebase_failure_is_reported_after_the_data_is_gone(app, client, monkeypatch):
    def boom(uid: str) -> None:
        raise UnknownError("identitytoolkit.googleapis.com said no")

    monkeypatch.setattr(firebase, "delete_user", boom)
    _as_firebase_user(app, "fb-uid")
    await client.post("/journal", json={"body": "x"})
    r = await client.delete("/me")
    assert r.status_code == 502 and "googleapis" not in r.text
    assert (await _counts("fb-uid"))["journal_entries"] == 0
    monkeypatch.setattr(firebase, "delete_user", lambda uid: None)
    assert (await client.delete("/me")).status_code == 204  # the retry


async def test_export_returns_all_server_data_for_the_caller_only(client):
    await _patient_with_everything(client)
    await client.post("/journal", json={"body": "someone else's"}, headers=as_user("other"))

    r = await client.get("/me/export", headers=as_user("pat"))
    assert r.status_code == 200
    body = r.json()
    assert body["user"]["uid"] == "pat" and body["clinician_profile"] is None
    assert [a["answers"] for a in body["assessments"]] == [[1] * 9]
    assert [m["valence"] for m in body["mood_points"]] == [1]
    assert [j["body"] for j in body["journal_entries"]] == ["a day"]
    assert [s["content"] for s in body["shared_summaries"]] == ["a week"]
    assert [link["clinician_uid"] for link in body["care_links"]] == ["doc"]

    doc = (await client.get("/me/export", headers=as_user("doc"))).json()
    assert doc["clinician_profile"]["license_no"] == "PMC-1"
    assert [link["patient_uid"] for link in doc["care_links"]] == ["pat"]
    assert doc["journal_entries"] == []


async def test_consent_is_recorded_with_version_and_time(client):
    me = (await client.get("/me", headers=as_user("pat"))).json()
    assert me["consent_version"] is None and me["consent_accepted_at"] is None

    r = await client.put("/me/consent", json={"consent_version": "2026-09"}, headers=as_user("pat"))
    assert r.status_code == 200 and r.json()["consent_version"] == "2026-09"
    first = r.json()["consent_accepted_at"]
    assert first is not None

    again = (await client.put("/me/consent", json={"consent_version": "2026-09"}, headers=as_user("pat"))).json()
    # Re-accepting the same text keeps the original time. sqlite drops the zone on reload, hence rstrip.
    assert again["consent_accepted_at"].rstrip("Z") == first.rstrip("Z")

    newer = (await client.put("/me/consent", json={"consent_version": "2026-10"}, headers=as_user("pat"))).json()
    assert newer["consent_version"] == "2026-10"
    assert (await client.get("/me", headers=as_user("pat"))).json()["consent_version"] == "2026-10"


async def test_consent_version_is_validated(client):
    for bad in ({}, {"consent_version": ""}, {"consent_version": "x" * 33}):
        assert (await client.put("/me/consent", json=bad, headers=as_user("pat"))).status_code == 422
