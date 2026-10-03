"""user email_verified

Revision ID: f6b8d0e25467
Revises: e5a7c9d14356
Create Date: 2026-09-24 15:00:00
"""

import sqlalchemy as sa

from alembic import op

revision = "f6b8d0e25467"
down_revision = "e5a7c9d14356"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Everyone starts unverified and picks up the real value from their token on the next request.
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.add_column(sa.Column("email_verified", sa.Boolean(), server_default=sa.false(), nullable=False))


def downgrade() -> None:
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.drop_column("email_verified")
