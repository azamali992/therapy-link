"""initial schema

Revision ID: 4d9a35f16344
Revises:
Create Date: 2026-09-01 00:00:00
"""

import sqlalchemy as sa

from alembic import op

revision = "4d9a35f16344"
down_revision = None
branch_labels = None
depends_on = None

# Use named Enum types that match the ORM model definitions.  SQLAlchemy on Postgres creates a
# real ENUM type; on SQLite it falls back to VARCHAR, which is what compare_metadata also sees
# when it inspects the live database. Using the same Enum() here means the autogenerate diff
# comes out empty after a full upgrade.
_role = sa.Enum("patient", "clinician", "admin", name="role")
_linkstatus = sa.Enum("pending", "active", "revoked", name="linkstatus")
_instrument = sa.Enum("phq9", "gad7", "bdi2", name="instrument")


def upgrade() -> None:
    bind = op.get_bind()
    dialect = bind.dialect.name

    # On Postgres, enum types must exist before any table column references them.
    if dialect == "postgresql":
        _role.create(bind, checkfirst=True)
        _linkstatus.create(bind, checkfirst=True)
        _instrument.create(bind, checkfirst=True)

    op.create_table(
        "users",
        sa.Column("uid", sa.String(128), nullable=False),
        sa.Column("email", sa.String(320), nullable=True),
        sa.Column("display_name", sa.String(120), nullable=True),
        sa.Column(
            "role",
            sa.Enum("patient", "clinician", "admin", name="role", create_constraint=False),
            nullable=False,
            server_default="patient",
        ),
        sa.Column("locale", sa.String(8), nullable=False, server_default="en"),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.text("(CURRENT_TIMESTAMP)"), nullable=False
        ),
        sa.PrimaryKeyConstraint("uid"),
    )

    op.create_table(
        "clinician_profiles",
        sa.Column("uid", sa.String(128), nullable=False),
        sa.Column("license_no", sa.String(64), nullable=True),
        sa.Column("specialty", sa.String(120), nullable=True),
        sa.Column("bio", sa.Text, nullable=True),
        sa.Column("verified_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.text("(CURRENT_TIMESTAMP)"), nullable=False
        ),
        sa.ForeignKeyConstraint(["uid"], ["users.uid"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("uid"),
    )

    op.create_table(
        "care_links",
        sa.Column("id", sa.String(32), nullable=False),
        sa.Column("patient_uid", sa.String(128), nullable=False),
        sa.Column("clinician_uid", sa.String(128), nullable=False),
        sa.Column(
            "status",
            sa.Enum("pending", "active", "revoked", name="linkstatus", create_constraint=False),
            nullable=False,
            server_default="pending",
        ),
        sa.Column("share_assessments", sa.Boolean, nullable=False, server_default=sa.false()),
        sa.Column("share_mood_trend", sa.Boolean, nullable=False, server_default=sa.false()),
        sa.Column("share_summaries", sa.Boolean, nullable=False, server_default=sa.false()),
        sa.Column("share_journal", sa.Boolean, nullable=False, server_default=sa.false()),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.text("(CURRENT_TIMESTAMP)"), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.text("(CURRENT_TIMESTAMP)"), nullable=False
        ),
        sa.ForeignKeyConstraint(["clinician_uid"], ["users.uid"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["patient_uid"], ["users.uid"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("patient_uid", "clinician_uid", name="uq_care_pair"),
    )
    op.create_index("ix_care_links_patient_uid", "care_links", ["patient_uid"])
    op.create_index("ix_care_links_clinician_uid", "care_links", ["clinician_uid"])

    op.create_table(
        "assessments",
        sa.Column("id", sa.String(32), nullable=False),
        sa.Column("patient_uid", sa.String(128), nullable=False),
        sa.Column(
            "instrument", sa.Enum("phq9", "gad7", "bdi2", name="instrument", create_constraint=False), nullable=False
        ),
        sa.Column("answers", sa.JSON, nullable=False),
        sa.Column("score", sa.Integer, nullable=False),
        sa.Column("band", sa.String(32), nullable=False),
        sa.Column("flags", sa.JSON, nullable=False),
        sa.Column(
            "taken_at", sa.DateTime(timezone=True), server_default=sa.text("(CURRENT_TIMESTAMP)"), nullable=False
        ),
        sa.ForeignKeyConstraint(["patient_uid"], ["users.uid"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_assessments_patient_uid", "assessments", ["patient_uid"])
    op.create_index("ix_assessments_taken_at", "assessments", ["taken_at"])

    op.create_table(
        "mood_points",
        sa.Column("id", sa.String(32), nullable=False),
        sa.Column("patient_uid", sa.String(128), nullable=False),
        sa.Column("valence", sa.Integer, nullable=False),
        sa.Column("emotion", sa.String(32), nullable=True),
        sa.Column("source", sa.String(16), nullable=False),
        sa.Column("recorded_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["patient_uid"], ["users.uid"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_mood_points_patient_uid", "mood_points", ["patient_uid"])
    op.create_index("ix_mood_points_recorded_at", "mood_points", ["recorded_at"])

    op.create_table(
        "journal_entries",
        sa.Column("id", sa.String(32), nullable=False),
        sa.Column("patient_uid", sa.String(128), nullable=False),
        sa.Column("title", sa.String(200), nullable=True),
        sa.Column("body", sa.Text, nullable=False),
        sa.Column("mood", sa.Integer, nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.text("(CURRENT_TIMESTAMP)"), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.text("(CURRENT_TIMESTAMP)"), nullable=False
        ),
        sa.ForeignKeyConstraint(["patient_uid"], ["users.uid"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_journal_entries_patient_uid", "journal_entries", ["patient_uid"])
    op.create_index("ix_journal_entries_created_at", "journal_entries", ["created_at"])

    op.create_table(
        "shared_summaries",
        sa.Column("id", sa.String(32), nullable=False),
        sa.Column("patient_uid", sa.String(128), nullable=False),
        sa.Column("kind", sa.String(16), nullable=False),
        sa.Column("content", sa.Text, nullable=False),
        sa.Column("period_start", sa.DateTime(timezone=True), nullable=True),
        sa.Column("period_end", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.text("(CURRENT_TIMESTAMP)"), nullable=False
        ),
        sa.ForeignKeyConstraint(["patient_uid"], ["users.uid"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_shared_summaries_patient_uid", "shared_summaries", ["patient_uid"])
    op.create_index("ix_shared_summaries_created_at", "shared_summaries", ["created_at"])


def downgrade() -> None:
    bind = op.get_bind()
    dialect = bind.dialect.name

    op.drop_table("shared_summaries")
    op.drop_table("journal_entries")
    op.drop_table("mood_points")
    op.drop_table("assessments")
    op.drop_table("care_links")
    op.drop_table("clinician_profiles")
    op.drop_table("users")

    if dialect == "postgresql":
        op.execute("DROP TYPE IF EXISTS instrument")
        op.execute("DROP TYPE IF EXISTS linkstatus")
        op.execute("DROP TYPE IF EXISTS role")
