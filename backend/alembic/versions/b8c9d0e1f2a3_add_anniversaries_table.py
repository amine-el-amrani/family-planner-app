"""add_anniversaries_table

Revision ID: b8c9d0e1f2a3
Revises: a7b8c9d0e1f2
Create Date: 2026-03-14

"""
from alembic import op
import sqlalchemy as sa

revision = 'b8c9d0e1f2a3'
down_revision = 'a7b8c9d0e1f2'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'anniversaries',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(), nullable=False),
        sa.Column('date_month', sa.Integer(), nullable=False),
        sa.Column('date_day', sa.Integer(), nullable=False),
        sa.Column('birth_year', sa.Integer(), nullable=True),
        sa.Column('emoji', sa.String(), nullable=True),
        sa.Column('is_birthday', sa.Boolean(), nullable=True),
        sa.Column('family_id', sa.Integer(), sa.ForeignKey('families.id'), nullable=True),
        sa.Column('created_by_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_anniversaries_id', 'anniversaries', ['id'], unique=False)


def downgrade():
    op.drop_index('ix_anniversaries_id', table_name='anniversaries')
    op.drop_table('anniversaries')
