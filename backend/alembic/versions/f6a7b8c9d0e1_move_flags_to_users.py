"""move prayer/motivation flags to users, daily_messages to user_id

Revision ID: f6a7b8c9d0e1
Revises: e5f6a7b8c9d0
Down revision: 'e5f6a7b8c9d0'
Branch labels: None
Depends on: None
"""
from alembic import op
import sqlalchemy as sa

revision = 'f6a7b8c9d0e1'
down_revision = 'e5f6a7b8c9d0'
branch_labels = None
depends_on = None


def upgrade():
    # Add flags to users
    op.add_column('users', sa.Column('prayer_enabled', sa.Boolean(), nullable=True, server_default='false'))
    op.add_column('users', sa.Column('motivation_enabled', sa.Boolean(), nullable=True, server_default='false'))

    # Remove flags from families
    op.drop_column('families', 'prayer_enabled')
    op.drop_column('families', 'motivation_enabled')

    # Replace daily_messages.family_id with user_id
    op.add_column('daily_messages', sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=True))
    # Drop FK constraint on family_id then column (PostgreSQL requires explicit constraint drop)
    op.drop_constraint('daily_messages_family_id_fkey', 'daily_messages', type_='foreignkey')
    op.drop_column('daily_messages', 'family_id')


def downgrade():
    op.add_column('daily_messages', sa.Column('family_id', sa.Integer(), sa.ForeignKey('families.id'), nullable=True))
    op.drop_column('daily_messages', 'user_id')
    op.add_column('families', sa.Column('prayer_enabled', sa.Boolean(), nullable=True, server_default='false'))
    op.add_column('families', sa.Column('motivation_enabled', sa.Boolean(), nullable=True, server_default='false'))
    op.drop_column('users', 'motivation_enabled')
    op.drop_column('users', 'prayer_enabled')
