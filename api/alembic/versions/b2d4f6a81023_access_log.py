"""clinician access log

Revision ID: b2d4f6a81023
Revises: a1c3e5f70912
Create Date: 2026-09-24 11:00:00
"""

import sqlalchemy as sa

from alembic import op

revision = "b2d4f6a81023"
down_revision = "a1c3e5f70912"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "access_log",
        sa.Column("id", sa.String(length=32), nullable=False),
        sa.Column("clinician_uid", sa.String(length=128), nullable=False),
        sa.Column("patient_uid", sa.String(length=128), nullable=False),
        sa.Column("action", sa.String(length=16), nullable=False),
        sa.Column("sections", sa.JSON(), nullable=False),
        sa.Column("at", sa.DateTime(timezone=True), server_default=sa.text("(CURRENT_TIMESTAMP)"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("access_log", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_access_log_at"), ["at"], unique=False)
        batch_op.create_index(batch_op.f("ix_access_log_clinician_uid"), ["clinician_uid"], unique=False)
        batch_op.create_index(batch_op.f("ix_access_log_patient_uid"), ["patient_uid"], unique=False)

    # Append-only where it matters: on Postgres, UPDATE and DELETE on the log silently do nothing.
    # Pruning, if a retention period is ever agreed, means dropping these rules in a migration.
    if op.get_bind().dialect.name == "postgresql":
        op.execute("CREATE RULE access_log_no_update AS ON UPDATE TO access_log DO INSTEAD NOTHING")
        op.execute("CREATE RULE access_log_no_delete AS ON DELETE TO access_log DO INSTEAD NOTHING")


def downgrade() -> None:
    # DROP TABLE would take the rules with it, but dropping them first keeps the downgrade explicit
    # and lets it be split later without leaving a table nobody can update.
    if op.get_bind().dialect.name == "postgresql":
        op.execute("DROP RULE IF EXISTS access_log_no_delete ON access_log")
        op.execute("DROP RULE IF EXISTS access_log_no_update ON access_log")
    with op.batch_alter_table("access_log", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_access_log_patient_uid"))
        batch_op.drop_index(batch_op.f("ix_access_log_clinician_uid"))
        batch_op.drop_index(batch_op.f("ix_access_log_at"))

    op.drop_table("access_log")
