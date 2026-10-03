"""user consent version and time

Revision ID: a1c3e5f70912
Revises: 7b1c2d3e4f50
Create Date: 2026-09-24 10:00:00
"""

import sqlalchemy as sa

from alembic import op

revision = "a1c3e5f70912"
down_revision = "7b1c2d3e4f50"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.add_column(sa.Column("consent_version", sa.String(length=32), nullable=True))
        batch_op.add_column(sa.Column("consent_accepted_at", sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.drop_column("consent_accepted_at")
        batch_op.drop_column("consent_version")
