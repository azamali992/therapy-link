from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from therapylink_api.auth import Principal, current_principal
from therapylink_api.db import get_session
from therapylink_api.models import Assessment, Instrument, User
from therapylink_api.schemas import AssessmentIn, AssessmentOut
from therapylink_api.scoring import delta, score

router = APIRouter(prefix="/assessments", tags=["assessments"])


async def list_for(session: AsyncSession, uid: str, instrument: Instrument | None) -> list[AssessmentOut]:
    q = select(Assessment).where(Assessment.patient_uid == uid).order_by(Assessment.taken_at.asc())
    if instrument:
        q = q.where(Assessment.instrument == instrument)
    rows = (await session.scalars(q)).all()
    out: list[AssessmentOut] = []
    prev: dict[Instrument, int] = {}
    for a in rows:
        out.append(AssessmentOut.model_validate(a).model_copy(update={"delta": delta(a.score, prev.get(a.instrument))}))
        prev[a.instrument] = a.score
    out.reverse()
    return out


@router.post("", response_model=AssessmentOut, status_code=201)
async def submit(body: AssessmentIn, p: Principal = Depends(current_principal), session: AsyncSession = Depends(get_session)):
    try:
        s = score(body.instrument, body.answers)
    except ValueError as e:
        raise HTTPException(422, str(e)) from e
    previous = await session.scalar(
        select(Assessment.score)
        .where(Assessment.patient_uid == p.uid, Assessment.instrument == body.instrument)
        .order_by(Assessment.taken_at.desc())
        .limit(1)
    )
    # Use the locale from the request, falling back to the user's preferred locale.
    locale = body.locale
    if locale is None:
        user = await session.get(User, p.uid)
        locale = user.locale if user else "en"

    a = Assessment(
        patient_uid=p.uid,
        instrument=body.instrument,
        answers=body.answers,
        score=s.score,
        band=s.band,
        flags=s.flags,
        locale=locale,
    )
    session.add(a)
    await session.commit()
    await session.refresh(a)
    return AssessmentOut.model_validate(a).model_copy(update={"delta": delta(a.score, previous)})


@router.get("", response_model=list[AssessmentOut])
async def mine(instrument: Instrument | None = None, p: Principal = Depends(current_principal), session: AsyncSession = Depends(get_session)):
    return await list_for(session, p.uid, instrument)
