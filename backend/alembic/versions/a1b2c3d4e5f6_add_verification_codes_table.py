"""add_verification_codes_table

Revision ID: a1b2c3d4e5f6
Revises: c9f2a1b3d4e5
Create Date: 2026-03-10
"""
from alembic import op
import sqlalchemy as sa

revision = "a1b2c3d4e5f6"
down_revision = "c9f2a1b3d4e5"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "verification_codes",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("email", sa.String(), nullable=False),
        sa.Column("code", sa.String(6), nullable=False),
        sa.Column("purpose", sa.String(), nullable=False),
        sa.Column("new_email", sa.String(), nullable=True),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("used", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_verification_codes_id"), "verification_codes", ["id"], unique=False)
    op.create_index(op.f("ix_verification_codes_email"), "verification_codes", ["email"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_verification_codes_email"), table_name="verification_codes")
    op.drop_index(op.f("ix_verification_codes_id"), table_name="verification_codes")
    op.drop_table("verification_codes")
