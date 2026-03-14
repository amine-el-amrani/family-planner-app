"""add prayer_city to users

Revision ID: a7b8c9d0e1f2
Revises: f6a7b8c9d0e1
Down revision: 'f6a7b8c9d0e1'
Branch labels: None
Depends on: None
"""
from alembic import op
import sqlalchemy as sa

revision = 'a7b8c9d0e1f2'
down_revision = 'f6a7b8c9d0e1'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('users', sa.Column('prayer_city', sa.String(), nullable=True, server_default='Paris'))


def downgrade():
    op.drop_column('users', 'prayer_city')
