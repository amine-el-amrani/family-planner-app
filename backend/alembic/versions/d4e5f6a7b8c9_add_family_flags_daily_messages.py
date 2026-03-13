"""add family flags and daily messages table

Revision ID: d4e5f6a7b8c9
Revises: c3d4e5f6a7b8
Down revision: 'c3d4e5f6a7b8'
Branch labels: None
Depends on: None
"""
from alembic import op
import sqlalchemy as sa

revision = 'd4e5f6a7b8c9'
down_revision = 'c3d4e5f6a7b8'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('families', sa.Column('prayer_enabled', sa.Boolean(), nullable=True, server_default='false'))
    op.add_column('families', sa.Column('motivation_enabled', sa.Boolean(), nullable=True, server_default='false'))

    op.create_table(
        'daily_messages',
        sa.Column('id', sa.Integer(), primary_key=True, index=True),
        sa.Column('family_id', sa.Integer(), sa.ForeignKey('families.id'), nullable=False),
        sa.Column('message', sa.String(), nullable=False),
        sa.Column('date', sa.Date(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=True),
    )


def downgrade():
    op.drop_table('daily_messages')
    op.drop_column('families', 'motivation_enabled')
    op.drop_column('families', 'prayer_enabled')
