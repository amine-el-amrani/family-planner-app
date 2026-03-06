"""add_push_token_to_users

Revision ID: 686e9f6b10cb
Revises: 3e85de13ac0b
Create Date: 2026-03-05 21:55:14.072259

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = '686e9f6b10cb'
down_revision: Union[str, Sequence[str], None] = '3e85de13ac0b'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # push_token is already included in the initial_schema migration.
    # This migration is kept only to preserve the revision chain for
    # existing local databases.
    pass


def downgrade() -> None:
    pass
