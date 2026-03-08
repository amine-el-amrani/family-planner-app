"""add_image_url_to_shopping_items

Revision ID: 401bff20322f
Revises: 4e91d8f09fec
Create Date: 2026-03-08
"""
from alembic import op
import sqlalchemy as sa

revision = '401bff20322f'
down_revision = '4e91d8f09fec'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('shopping_items', sa.Column('image_url', sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column('shopping_items', 'image_url')
