"""assessment locale

Revision ID: e5a7c9d14356
Revises: d4f6b8c03245
Create Date: 2026-09-24 14:00:00
"""

import sqlalchemy as sa

from alembic import op

revision = "e5a7c9d14356"
down_revision = "d4f6b8c03245"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Past results stay NULL: which language they were answered in was never recorded, and
    # guessing from the user's current setting could be wrong.
    with op.batch_alter_table("assessments", schema=None) as batch_op:
        batch_op.add_column(sa.Column("locale", sa.String(length=8), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("assessments", schema=None) as batch_op:
        batch_op.drop_column("locale")
