from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from fastapi import APIRouter, Body, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from therapylink_api.auth import Principal, current_principal
from therapylink_api.db import get_session
from therapylink_api.models import MoodPoint
from therapylink_api.schemas import MAX_MOOD_BATCH, MoodDay, MoodPointIn

router = APIRouter(prefix="/mood", tags=["mood"])


def zone(tz: str = Query("Asia/Karachi", max_length=64, description="IANA zone that decides where a day starts")) -> ZoneInfo:
    try:
        return ZoneInfo(tz)
    # A name that is a tzdata directory ("America") raises OSError: PermissionError on Windows,
    # IsADirectoryError on Linux.
    except (ZoneInfoNotFoundError, ValueError, OSError):
        raise HTTPException(422, f"unknown time zone {tz!r}") from None


def _utc(dt: datetime) -> datetime:
    # sqlite hands back naive datetimes; everything is stored in UTC, so naive means UTC.
    return dt.replace(tzinfo=UTC) if dt.tzinfo is None else dt.astimezone(UTC)


async def trend_for(session: AsyncSession, uid: str, days: int, tz: ZoneInfo) -> list[MoodDay]:
    """Mean valence per local day. Bucketing by UTC put Pakistan's midnight-to-5am moods, often the
    low ones, on the previous day."""
    since = datetime.now(UTC) - timedelta(days=days)
    rows = (
        await session.scalars(
            select(MoodPoint).where(MoodPoint.patient_uid == uid, MoodPoint.recorded_at >= since).order_by(MoodPoint.recorded_at)
        )
    ).all()
    by_day: dict[str, list[int]] = {}
    for r in rows:
        by_day.setdefault(_utc(r.recorded_at).astimezone(tz).date().isoformat(), []).append(r.valence)
    return [MoodDay(day=d, mean_valence=round(sum(v) / len(v), 2), n=len(v)) for d, v in sorted(by_day.items())]


@router.post("/batch", status_code=201)
async def upload(points: list[MoodPointIn] = Body(max_length=MAX_MOOD_BATCH), p: Principal = Depends(current_principal), session: AsyncSession = Depends(get_session)):
    """Points carrying a client_id already stored for this patient, or repeated in the batch, are
    skipped, so the app can resend a batch whose reply it never saw."""
    ids = {pt.client_id for pt in points if pt.client_id}
    seen = set((await session.scalars(select(MoodPoint.client_id).where(MoodPoint.patient_uid == p.uid, MoodPoint.client_id.in_(ids)))).all()) if ids else set()
    fresh: list[MoodPoint] = []
    for pt in points:
        if pt.client_id:
            if pt.client_id in seen:
                continue
            seen.add(pt.client_id)
        fresh.append(MoodPoint(patient_uid=p.uid, **(pt.model_dump() | {"recorded_at": _utc(pt.recorded_at)})))
    session.add_all(fresh)
    try:
        await session.commit()
    except IntegrityError:
        # The same batch arrived twice at once and the other copy won. Retrying is safe.
        await session.rollback()
        raise HTTPException(409, "this batch is already being saved; retry") from None
    return {"accepted": len(fresh), "duplicates": len(points) - len(fresh)}


@router.get("/trend", response_model=list[MoodDay])
async def trend(days: int = 30, tz: ZoneInfo = Depends(zone), p: Principal = Depends(current_principal), session: AsyncSession = Depends(get_session)):
    return await trend_for(session, p.uid, min(days, 365), tz)
