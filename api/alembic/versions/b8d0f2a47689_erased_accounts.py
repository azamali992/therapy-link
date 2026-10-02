"""erased accounts

Revision ID: b8d0f2a47689
Revises: a7c9e1f36578
Create Date: 2026-09-24 18:00:00
"""
import sqlalchemy as sa

from alembic import op

revision = 'b8d0f2a47689'
down_revision = 'a7c9e1f36578'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'erased_accounts',
        sa.Column('uid_sha256', sa.String(length=64), nullable=False),
        sa.Column('erased_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
        sa.PrimaryKeyConstraint('uid_sha256'),
    )


def downgrade() -> None:
    op.drop_table('erased_accounts')
