"""mood point client id for idempotent uploads

Revision ID: d4f6b8c03245
Revises: c3e5a7b92134
Create Date: 2026-09-24 13:00:00
"""

import sqlalchemy as sa

from alembic import op

revision = "d4f6b8c03245"
down_revision = "c3e5a7b92134"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Existing rows have no client id; NULLs never collide, so the constraint holds from the start.
    with op.batch_alter_table("mood_points", schema=None) as batch_op:
        batch_op.add_column(sa.Column("client_id", sa.String(length=64), nullable=True))
        batch_op.create_unique_constraint("uq_mood_client_id", ["patient_uid", "client_id"])


def downgrade() -> None:
    with op.batch_alter_table("mood_points", schema=None) as batch_op:
        batch_op.drop_constraint("uq_mood_client_id", type_="unique")
        batch_op.drop_column("client_id")
