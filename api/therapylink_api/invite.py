"""Clinician invite codes: short enough to read aloud or copy off a card, and rotatable."""

from __future__ import annotations

import re
import secrets

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from therapylink_api.models import ClinicianProfile

# No 0/O or 1/I/L: codes get read out over the phone and copied by hand. 31^6 is ~887M codes.
ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
LENGTH = 6


def new_code() -> str:
    return "".join(secrets.choice(ALPHABET) for _ in range(LENGTH))


def normalise_code(raw: str) -> str:
    """'abc-234', 'ABC 234' and 'abc234' are the same code."""
    return re.sub(r"[^A-Z0-9]", "", raw.upper())


async def unique_code(session: AsyncSession) -> str:
    for _ in range(20):
        code = new_code()
        taken = await session.scalar(select(ClinicianProfile.uid).where(ClinicianProfile.invite_code == code))
        if taken is None:
            return code
    raise RuntimeError("could not find an unused invite code")
