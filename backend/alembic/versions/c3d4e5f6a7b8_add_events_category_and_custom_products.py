"""add events category image and custom products table

Revision ID: c3d4e5f6a7b8
Revises: b2c3d4e5f6a7
Down revision: 'b2c3d4e5f6a7'
Branch labels: None
Depends on: None
"""
from alembic import op
import sqlalchemy as sa

revision = 'c3d4e5f6a7b8'
down_revision = 'b2c3d4e5f6a7'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('events', sa.Column('category', sa.String(), nullable=True))
    op.add_column('events', sa.Column('image_url', sa.Text(), nullable=True))

    op.create_table(
        'custom_products',
        sa.Column('id', sa.Integer(), primary_key=True, index=True),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('image_url', sa.Text(), nullable=True),
        sa.Column('created_by_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('family_id', sa.Integer(), sa.ForeignKey('families.id'), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
    )


def downgrade():
    op.drop_table('custom_products')
    op.drop_column('events', 'image_url')
    op.drop_column('events', 'category')
