"""care link shared_from

Revision ID: c3e5a7b92134
Revises: b2d4f6a81023
Create Date: 2026-09-24 12:00:00
"""

import sqlalchemy as sa

from alembic import op

revision = "c3e5a7b92134"
down_revision = "b2d4f6a81023"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("care_links", schema=None) as batch_op:
        batch_op.add_column(sa.Column("shared_from", sa.DateTime(timezone=True), nullable=True))
    # Existing links share from when they were made, not from the start of the patient's history.
    # Links that are already active stay active: turning them back into requests would cut off care
    # already under way.
    op.execute("UPDATE care_links SET shared_from = created_at WHERE shared_from IS NULL")


def downgrade() -> None:
    with op.batch_alter_table("care_links", schema=None) as batch_op:
        batch_op.drop_column("shared_from")
