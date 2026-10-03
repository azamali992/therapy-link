from datetime import UTC, datetime, timedelta, timezone

from sqlalchemy import func, select

from tests.conftest import as_user, linked, verified_clinician
from therapylink_api import db
from therapylink_api.models import MoodPoint


def _point(at: datetime, valence: int = 0, client_id: str | None = None) -> dict:
    p = {"valence": valence, "source": "manual", "recorded_at": at.isoformat()}
    return p | ({"client_id": client_id} if client_id else {})


async def _stored(uid: str = "u") -> int:
    async with db.sessionmaker()() as s:
        return await s.scalar(select(func.count()).select_from(MoodPoint).where(MoodPoint.patient_uid == uid))


async def test_resending_a_batch_does_not_double_count(client):
    now = datetime.now(UTC)
    batch = [_point(now, 1, "a"), _point(now, -1, "b")]
    r = await client.post("/mood/batch", json=batch, headers=as_user("u"))
    assert r.status_code == 201 and r.json() == {"accepted": 2, "duplicates": 0}

    r = await client.post("/mood/batch", json=batch + [_point(now, 2, "c")], headers=as_user("u"))
    assert r.json() == {"accepted": 1, "duplicates": 2}
    assert await _stored() == 3


async def test_duplicates_inside_one_batch_and_across_users(client):
    now = datetime.now(UTC)
    r = await client.post("/mood/batch", json=[_point(now, 1, "a"), _point(now, 1, "a")], headers=as_user("u"))
    assert r.json() == {"accepted": 1, "duplicates": 1}
    # Client ids are per patient: someone else's "a" is a different reading.
    r = await client.post("/mood/batch", json=[_point(now, 1, "a")], headers=as_user("v"))
    assert r.json() == {"accepted": 1, "duplicates": 0}


async def test_points_without_a_client_id_are_always_stored(client):
    now = datetime.now(UTC)
    for _ in range(2):
        await client.post("/mood/batch", json=[_point(now)], headers=as_user("u"))
    assert await _stored() == 2


async def test_trend_buckets_by_local_day_defaulting_to_karachi(client):
    # 21:30 UTC is 02:30 the next morning in Karachi (UTC+5).
    late = (datetime.now(UTC) - timedelta(days=2)).replace(hour=21, minute=30, second=0, microsecond=0)
    evening = late.replace(hour=12)
    await client.post("/mood/batch", json=[_point(late, -2), _point(evening, 2)], headers=as_user("u"))

    pk = (await client.get("/mood/trend", headers=as_user("u"))).json()
    local_late = (late + timedelta(hours=5)).date().isoformat()
    assert [(d["day"], d["mean_valence"]) for d in pk] == [(evening.date().isoformat(), 2.0), (local_late, -2.0)]

    utc = (await client.get("/mood/trend", params={"tz": "UTC"}, headers=as_user("u"))).json()
    assert [(d["day"], d["n"]) for d in utc] == [(late.date().isoformat(), 2)]


async def test_offsets_on_upload_are_respected(client):
    # 22:00 in Karachi is 17:00 UTC, same day. Stored as a bare wall time and read back as UTC, it
    # would move to 03:00 the next day.
    local = (
        (datetime.now(UTC) - timedelta(days=1))
        .astimezone(timezone(timedelta(hours=5)))
        .replace(hour=22, minute=0, second=0, microsecond=0)
    )
    await client.post("/mood/batch", json=[_point(local, 1)], headers=as_user("u"))
    [day] = (await client.get("/mood/trend", params={"tz": "Asia/Karachi"}, headers=as_user("u"))).json()
    assert day["day"] == local.date().isoformat()


async def test_unknown_time_zone_is_422(client):
    assert (await client.get("/mood/trend", params={"tz": "Mars/Olympus"}, headers=as_user("u"))).status_code == 422
    assert (await client.get("/mood/trend", params={"tz": "../etc"}, headers=as_user("u"))).status_code == 422
    # Directories inside tzdata, not zones.
    for tz in ("America", "Asia"):
        assert (await client.get("/mood/trend", params={"tz": tz}, headers=as_user("u"))).status_code == 422


async def test_clinician_trend_uses_the_same_local_days(client):
    await verified_clinician(client)
    await linked(client, "pat", mood_trend=True)
    late = (datetime.now(UTC) - timedelta(days=2)).replace(hour=21, minute=30, second=0, microsecond=0)
    await client.post("/mood/batch", json=[_point(late, -1)], headers=as_user("pat"))
    body = (await client.get("/clinician/patients/pat", headers=as_user("doc"))).json()
    assert [d["day"] for d in body["mood_trend"]] == [(late + timedelta(hours=5)).date().isoformat()]
