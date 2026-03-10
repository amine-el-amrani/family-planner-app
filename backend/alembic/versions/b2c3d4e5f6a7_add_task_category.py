"""add task category column

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
Down revision: 'a1b2c3d4e5f6'
Branch labels: None
Depends on: None
"""
from alembic import op
import sqlalchemy as sa

revision = 'b2c3d4e5f6a7'
down_revision = 'a1b2c3d4e5f6'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('tasks', sa.Column('category', sa.String(), nullable=True))


def downgrade():
    op.drop_column('tasks', 'category')
