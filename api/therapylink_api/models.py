"""Schema. Deliberately absent: a chat-messages table. Conversations stay on the device;
the server only ever sees what the patient explicitly shares (assessments, mood points without
text, journal entries, and summaries generated on-device)."""

from __future__ import annotations

import enum
import uuid
from datetime import datetime

from sqlalchemy import JSON, Boolean, DateTime, Enum, ForeignKey, Integer, String, Text, UniqueConstraint, false, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from therapylink_api.db import Base


def _uuid() -> str:
    return uuid.uuid4().hex


def _now():
    return func.now()


def _now_utc() -> datetime:
    from datetime import UTC
    return datetime.now(UTC)


class Role(str, enum.Enum):
    patient = "patient"
    clinician = "clinician"
    admin = "admin"


class LinkStatus(str, enum.Enum):
    pending = "pending"
    active = "active"
    revoked = "revoked"


class Instrument(str, enum.Enum):
    phq9 = "phq9"
    gad7 = "gad7"
    bdi2 = "bdi2"


class User(Base):
    __tablename__ = "users"

    uid: Mapped[str] = mapped_column(String(128), primary_key=True)
    email: Mapped[str | None] = mapped_column(String(320))
    # Copied from the Firebase token on every sign-in. Clinician approval requires it.
    email_verified: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false(), nullable=False)
    display_name: Mapped[str | None] = mapped_column(String(120))
    role: Mapped[Role] = mapped_column(Enum(Role), default=Role.patient, nullable=False)
    locale: Mapped[str] = mapped_column(String(8), default="en", nullable=False)
    # Which version of the terms/privacy consent screen the user accepted, and when. Null: not yet.
    consent_version: Mapped[str | None] = mapped_column(String(32))
    consent_accepted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=_now())

    clinician: Mapped[ClinicianProfile | None] = relationship(back_populates="user", uselist=False)


class ClinicianProfile(Base):
    __tablename__ = "clinician_profiles"

    uid: Mapped[str] = mapped_column(ForeignKey("users.uid", ondelete="CASCADE"), primary_key=True)
    license_no: Mapped[str | None] = mapped_column(String(64))
    specialty: Mapped[str | None] = mapped_column(String(120))
    bio: Mapped[str | None] = mapped_column(Text)
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    # Short alphanumeric code printed on cards; patients type this to link.
    invite_code: Mapped[str | None] = mapped_column(String(12), index=True, unique=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=_now())

    user: Mapped[User] = relationship(back_populates="clinician")


class CareLink(Base):
    """A patient ↔ clinician relationship. Consent flags are the only thing that opens patient data."""

    __tablename__ = "care_links"
    __table_args__ = (UniqueConstraint("patient_uid", "clinician_uid", name="uq_care_pair"),)

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=_uuid)
    patient_uid: Mapped[str] = mapped_column(ForeignKey("users.uid", ondelete="CASCADE"), index=True)
    clinician_uid: Mapped[str] = mapped_column(ForeignKey("users.uid", ondelete="CASCADE"), index=True)
    status: Mapped[LinkStatus] = mapped_column(Enum(LinkStatus), default=LinkStatus.pending, nullable=False)
    share_assessments: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    share_mood_trend: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    share_summaries: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    share_journal: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    # The point in time from which patient data is visible to the clinician. Set when the clinician
    # accepts; null means the link has not been accepted yet.
    shared_from: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=_now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=_now(), onupdate=_now())


class Assessment(Base):
    __tablename__ = "assessments"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=_uuid)
    patient_uid: Mapped[str] = mapped_column(ForeignKey("users.uid", ondelete="CASCADE"), index=True)
    instrument: Mapped[Instrument] = mapped_column(Enum(Instrument), nullable=False)
    answers: Mapped[list[int]] = mapped_column(JSON, nullable=False)
    score: Mapped[int] = mapped_column(Integer, nullable=False)
    band: Mapped[str] = mapped_column(String(32), nullable=False)
    flags: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    # Language the questions were shown in. Null for results recorded before this column was added.
    locale: Mapped[str | None] = mapped_column(String(8))
    taken_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=_now(), index=True)


class MoodPoint(Base):
    """A valence/emotion reading. No text — the client sends only the classifier's output."""

    __tablename__ = "mood_points"
    # A resent batch (the reply was lost, the app retried) must not count the same reading twice.
    __table_args__ = (UniqueConstraint("patient_uid", "client_id", name="uq_mood_client_id"),)

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=_uuid)
    patient_uid: Mapped[str] = mapped_column(ForeignKey("users.uid", ondelete="CASCADE"), index=True)
    valence: Mapped[int] = mapped_column(Integer, nullable=False)  # -2 .. +2
    emotion: Mapped[str | None] = mapped_column(String(32))
    source: Mapped[str] = mapped_column(String(16), nullable=False)  # chat | journal | manual
    # The app's own id for the reading. Optional so older clients keep working, without the dedupe.
    client_id: Mapped[str | None] = mapped_column(String(64))
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)


class JournalEntry(Base):
    __tablename__ = "journal_entries"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=_uuid)
    patient_uid: Mapped[str] = mapped_column(ForeignKey("users.uid", ondelete="CASCADE"), index=True)
    title: Mapped[str | None] = mapped_column(String(200))
    body: Mapped[str] = mapped_column(Text, nullable=False)
    mood: Mapped[int | None] = mapped_column(Integer)
    # Python-side default gives microsecond precision so the SQLAlchemy SQLite bind_processor
    # formats both this column and shared_from with the same 'YYYY-MM-DD HH:MM:SS.ffffff'
    # pattern. CURRENT_TIMESTAMP (second precision) would be shorter, making the >= comparison
    # against shared_from fail for same-second entries (string prefix ordering in SQLite).
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now_utc, server_default=_now(), index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=_now(), onupdate=_now())


class SharedSummary(Base):
    """A summary the patient chose to share. Generated on-device; the server never saw the chat."""

    __tablename__ = "shared_summaries"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=_uuid)
    patient_uid: Mapped[str] = mapped_column(ForeignKey("users.uid", ondelete="CASCADE"), index=True)
    kind: Mapped[str] = mapped_column(String(16), nullable=False)  # weekly | session
    content: Mapped[str] = mapped_column(Text, nullable=False)
    period_start: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    period_end: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    # Python-side default for microsecond precision: see JournalEntry.created_at comment.
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now_utc, server_default=_now(), index=True)


class AccessLog(Base):
    """A record of each time a clinician accessed a patient's data. Append-only: never updated or
    deleted. On Postgres, rules enforce this; on sqlite, the application must not call UPDATE/DELETE."""

    __tablename__ = "access_log"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=_uuid)
    clinician_uid: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    patient_uid: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    action: Mapped[str] = mapped_column(String(16), nullable=False)  # overview | caseload
    sections: Mapped[list[str]] = mapped_column(JSON, nullable=False)
    # Python-side default gives microsecond precision so ORDER BY at DESC is stable in sqlite.
    at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now_utc, server_default=_now(), index=True)


class ErasedAccount(Base):
    """A SHA-256 tombstone left after account deletion. Tokens valid for up to one hour after
    deletion cannot recreate the account because every auth path checks this table first."""

    __tablename__ = "erased_accounts"

    uid_sha256: Mapped[str] = mapped_column(String(64), primary_key=True)
    erased_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=_now())
