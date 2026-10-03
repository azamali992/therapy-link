"""drop BDI-II from the instrument enum

Revision ID: a7c9e1f36578
Revises: f6b8d0e25467
Create Date: 2026-09-24 16:00:00
"""

from alembic import op

revision = "a7c9e1f36578"
down_revision = "f6b8d0e25467"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # BDI-II is Pearson-copyrighted and unlicensed here. The app never shipped its items, so no real
    # result should exist; any that do can't be kept under a type that no longer allows them.
    op.execute("DELETE FROM assessments WHERE instrument = 'bdi2'")
    if op.get_bind().dialect.name == "postgresql":
        # Postgres can't drop a value from an enum type: build the smaller type and move over.
        op.execute("ALTER TYPE instrument RENAME TO instrument_old")
        op.execute("CREATE TYPE instrument AS ENUM ('phq9', 'gad7')")
        op.execute("ALTER TABLE assessments ALTER COLUMN instrument TYPE instrument USING instrument::text::instrument")
        op.execute("DROP TYPE instrument_old")
    # sqlite stores the enum as plain VARCHAR with no CHECK constraint: nothing to change.


def downgrade() -> None:
    # The deleted rows stay deleted; only the type comes back. Rebuilt the same way as upgrade
    # rather than ALTER TYPE ... ADD VALUE, which older Postgres refuses inside a transaction and
    # which would leave the type differing from the one the initial schema made.
    if op.get_bind().dialect.name == "postgresql":
        op.execute("ALTER TYPE instrument RENAME TO instrument_old")
        op.execute("CREATE TYPE instrument AS ENUM ('phq9', 'gad7', 'bdi2')")
        op.execute("ALTER TABLE assessments ALTER COLUMN instrument TYPE instrument USING instrument::text::instrument")
        op.execute("DROP TYPE instrument_old")
