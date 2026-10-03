"""clinician invite codes

Revision ID: 7b1c2d3e4f50
Revises: 4d9a35f16344
Create Date: 2026-09-15 06:10:00
"""

import secrets

import sqlalchemy as sa

from alembic import op

revision = "7b1c2d3e4f50"
down_revision = "4d9a35f16344"
branch_labels = None
depends_on = None

# A copy of therapylink_api.invite.ALPHABET: a migration must keep working after app code changes.
_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"


def upgrade() -> None:
    with op.batch_alter_table("clinician_profiles", schema=None) as batch_op:
        batch_op.add_column(sa.Column("invite_code", sa.String(length=12), nullable=True))
        batch_op.create_index(batch_op.f("ix_clinician_profiles_invite_code"), ["invite_code"], unique=True)

    # Existing clinicians get a code now rather than on their next sign-up call.
    conn = op.get_bind()
    taken: set[str] = set()
    for (uid,) in conn.execute(sa.text("SELECT uid FROM clinician_profiles WHERE invite_code IS NULL")).all():
        code = "".join(secrets.choice(_ALPHABET) for _ in range(6))
        while code in taken:
            code = "".join(secrets.choice(_ALPHABET) for _ in range(6))
        taken.add(code)
        conn.execute(
            sa.text("UPDATE clinician_profiles SET invite_code = :code WHERE uid = :uid"), {"code": code, "uid": uid}
        )


def downgrade() -> None:
    with op.batch_alter_table("clinician_profiles", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_clinician_profiles_invite_code"))
        batch_op.drop_column("invite_code")
