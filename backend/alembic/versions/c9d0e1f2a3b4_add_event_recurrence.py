"""add_event_recurrence

Revision ID: c9d0e1f2a3b4
Revises: b8c9d0e1f2a3
Create Date: 2026-03-14

"""
from alembic import op
import sqlalchemy as sa

revision = 'c9d0e1f2a3b4'
down_revision = 'b8c9d0e1f2a3'
branch_labels = None
depends_on = None


def upgrade():
    # Add recurrence_type as a string column (simpler than enum for migration)
    op.add_column('events', sa.Column('recurrence_type', sa.String(), nullable=True, server_default='none'))
    op.add_column('events', sa.Column('recurrence_end_date', sa.Date(), nullable=True))


def downgrade():
    op.drop_column('events', 'recurrence_end_date')
    op.drop_column('events', 'recurrence_type')
