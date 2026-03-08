"""add_event_attendees

Revision ID: c9f2a1b3d4e5
Revises: 401bff20322f
Create Date: 2026-03-08
"""
from alembic import op
import sqlalchemy as sa

revision = 'c9f2a1b3d4e5'
down_revision = '401bff20322f'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'event_attendees',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('event_id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column(
            'status',
            sa.Enum('pending', 'going', 'not_going', name='eventrsvpstatus'),
            nullable=False,
            server_default='pending',
        ),
        sa.ForeignKeyConstraint(['event_id'], ['events.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_event_attendees_event_id', 'event_attendees', ['event_id'])
    op.create_index('ix_event_attendees_user_id', 'event_attendees', ['user_id'])


def downgrade() -> None:
    op.drop_index('ix_event_attendees_user_id', table_name='event_attendees')
    op.drop_index('ix_event_attendees_event_id', table_name='event_attendees')
    op.drop_table('event_attendees')
    op.execute("DROP TYPE IF EXISTS eventrsvpstatus")
