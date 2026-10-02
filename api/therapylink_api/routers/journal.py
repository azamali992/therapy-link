from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from therapylink_api.auth import Principal, current_principal
from therapylink_api.db import get_session
from therapylink_api.models import JournalEntry, SharedSummary
from therapylink_api.schemas import JournalIn, JournalOut, SummaryIn, SummaryOut

router = APIRouter(tags=["journal"])


async def _owned(session: AsyncSession, uid: str, entry_id: str) -> JournalEntry:
    e = await session.get(JournalEntry, entry_id)
    if e is None or e.patient_uid != uid:
        raise HTTPException(404, "entry not found")
    return e


@router.get("/journal", response_model=list[JournalOut])
async def list_entries(limit: int = 50, p: Principal = Depends(current_principal), session: AsyncSession = Depends(get_session)):
    q = select(JournalEntry).where(JournalEntry.patient_uid == p.uid).order_by(JournalEntry.created_at.desc()).limit(min(limit, 200))
    return (await session.scalars(q)).all()


@router.post("/journal", response_model=JournalOut, status_code=201)
async def create_entry(body: JournalIn, p: Principal = Depends(current_principal), session: AsyncSession = Depends(get_session)):
    e = JournalEntry(patient_uid=p.uid, **body.model_dump())
    session.add(e)
    await session.commit()
    await session.refresh(e)
    return e


@router.put("/journal/{entry_id}", response_model=JournalOut)
async def update_entry(entry_id: str, body: JournalIn, p: Principal = Depends(current_principal), session: AsyncSession = Depends(get_session)):
    e = await _owned(session, p.uid, entry_id)
    for k, v in body.model_dump().items():
        setattr(e, k, v)
    await session.commit()
    await session.refresh(e)
    return e


@router.delete("/journal/{entry_id}", status_code=204)
async def delete_entry(entry_id: str, p: Principal = Depends(current_principal), session: AsyncSession = Depends(get_session)):
    e = await _owned(session, p.uid, entry_id)
    await session.delete(e)
    await session.commit()


@router.post("/summaries", response_model=SummaryOut, status_code=201)
async def share_summary(body: SummaryIn, p: Principal = Depends(current_principal), session: AsyncSession = Depends(get_session)):
    """The device generated this; the patient is choosing to make it visible to consented clinicians."""
    s = SharedSummary(patient_uid=p.uid, **body.model_dump())
    session.add(s)
    await session.commit()
    await session.refresh(s)
    return s


@router.get("/summaries", response_model=list[SummaryOut])
async def my_summaries(p: Principal = Depends(current_principal), session: AsyncSession = Depends(get_session)):
    q = select(SharedSummary).where(SharedSummary.patient_uid == p.uid).order_by(SharedSummary.created_at.desc())
    return (await session.scalars(q)).all()
