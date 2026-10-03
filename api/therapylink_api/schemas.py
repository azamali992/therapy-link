from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, model_validator

from therapylink_api.models import Instrument, LinkStatus, Role

# Size caps. Generous for a person typing, small enough that one request can't hog memory or the
# model's context. The proxy should also cap the raw request size.
MAX_BIO = 2_000
MAX_JOURNAL_BODY = 20_000
MAX_SUMMARY = 8_000
MAX_CHAT_MESSAGES = 60
# The whole conversation, not each message: the app sends its summary, memory and wrap-up requests
# as one user message holding a preamble, a transcript window of up to 6,000 characters and the
# existing notes, so a single message can legitimately run past 10,000.
MAX_CHAT_CHARS = 16_000
MAX_MOOD_BATCH = 500
MAX_ANSWERS = 30


class ORM(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class MeOut(ORM):
    uid: str
    email: str | None
    display_name: str | None
    role: Role
    locale: str
    clinician_verified: bool = False
    invite_code: str | None = None
    consent_version: str | None = None
    consent_accepted_at: datetime | None = None


class MePatch(BaseModel):
    display_name: str | None = Field(default=None, max_length=120)
    locale: str | None = Field(default=None, pattern="^(en|ur)$")


class ConsentIn(BaseModel):
    consent_version: str = Field(min_length=1, max_length=32)
    # Client-reported acceptance time. Accepted and ignored: the server's own timestamp is
    # always authoritative for consent_accepted_at. Present so the request is not rejected
    # when the app sends it.
    accepted_at: datetime | None = None


class BecomeClinician(BaseModel):
    license_no: str = Field(max_length=64)
    specialty: str | None = Field(default=None, max_length=120)
    bio: str | None = Field(default=None, max_length=MAX_BIO)


class AssessmentIn(BaseModel):
    instrument: Instrument
    answers: list[int] = Field(max_length=MAX_ANSWERS)
    locale: str | None = Field(default=None, pattern="^(en|ur)$")


class AssessmentOut(ORM):
    id: str
    instrument: Instrument
    score: int
    band: str
    flags: list[str]
    locale: str | None = None
    taken_at: datetime
    delta: int | None = None


class MoodPointIn(BaseModel):
    valence: int = Field(ge=-2, le=2)
    emotion: str | None = Field(default=None, max_length=32)
    source: str = Field(pattern="^(chat|journal|manual)$")
    recorded_at: datetime
    client_id: str | None = Field(default=None, min_length=1, max_length=64)


class MoodDay(BaseModel):
    day: str
    mean_valence: float
    n: int


class JournalIn(BaseModel):
    title: str | None = Field(default=None, max_length=200)
    body: str = Field(min_length=1, max_length=MAX_JOURNAL_BODY)
    mood: int | None = Field(default=None, ge=-2, le=2)


class JournalOut(ORM):
    id: str
    title: str | None
    body: str
    mood: int | None
    created_at: datetime
    updated_at: datetime


class SummaryIn(BaseModel):
    kind: str = Field(pattern="^(weekly|session)$")
    content: str = Field(min_length=1, max_length=MAX_SUMMARY)
    period_start: datetime | None = None
    period_end: datetime | None = None


class SummaryOut(ORM):
    id: str
    kind: str
    content: str
    period_start: datetime | None
    period_end: datetime | None
    created_at: datetime


class Consent(BaseModel):
    share_assessments: bool | None = None
    share_mood_trend: bool | None = None
    share_summaries: bool | None = None
    share_journal: bool | None = None


class CareLinkIn(BaseModel):
    code: str = Field(min_length=1, max_length=64)


class CareLinkOut(ORM):
    id: str
    patient_uid: str
    clinician_uid: str
    status: LinkStatus
    share_assessments: bool
    share_mood_trend: bool
    share_summaries: bool
    share_journal: bool
    shared_from: datetime | None = None
    # Enriched from the clinician's profile; not stored on the CareLink row itself.
    clinician_name: str | None = None
    clinician_verified: bool = False


class CaseloadRow(BaseModel):
    patient: MeOut
    latest: list[AssessmentOut]
    attention: list[str]
    shares_assessments: bool


class RequestOut(BaseModel):
    link_id: str
    patient: MeOut


class PatientOverview(BaseModel):
    patient: MeOut
    consent: CareLinkOut
    assessments: list[AssessmentOut] | None = None
    mood_trend: list[MoodDay] | None = None
    summaries: list[SummaryOut] | None = None
    journal: list[JournalOut] | None = None


class ChatMessage(BaseModel):
    # system is allowed so the app can send its registered prompt as the first message.
    role: str = Field(pattern="^(user|assistant|system)$")
    content: str = Field(max_length=MAX_CHAT_CHARS)


class ChatIn(BaseModel):
    messages: list[ChatMessage] = Field(min_length=1, max_length=MAX_CHAT_MESSAGES)
    max_tokens: int = Field(default=256, le=1024)
    temperature: float = Field(default=0.7, ge=0, le=1.5)
    # When true, the server streams an SSE response instead of waiting for the full reply.
    stream: bool = False

    @model_validator(mode="after")
    def _fits_context(self) -> ChatIn:
        # An oversized history would overflow llama-server's context and come back as a vague 502.
        if sum(len(m.content) for m in self.messages) > MAX_CHAT_CHARS:
            raise ValueError(f"conversation is longer than {MAX_CHAT_CHARS} characters; send less history")
        return self


class ChatOut(BaseModel):
    reply: str
    model: str
