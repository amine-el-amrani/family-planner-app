"""add_shopping_notes_tables

Revision ID: 4e91d8f09fec
Revises: 686e9f6b10cb
Create Date: 2026-03-05 22:45:11.249987

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '4e91d8f09fec'
down_revision: Union[str, Sequence[str], None] = '686e9f6b10cb'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'shopping_lists',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('family_id', sa.Integer(), nullable=False),
        sa.Column('created_by_id', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['created_by_id'], ['users.id']),
        sa.ForeignKeyConstraint(['family_id'], ['families.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_shopping_lists_id', 'shopping_lists', ['id'], unique=False)

    op.create_table(
        'shopping_items',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('list_id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(), nullable=False),
        sa.Column('quantity', sa.String(), nullable=True),
        sa.Column('is_checked', sa.Boolean(), nullable=True),
        sa.Column('added_by_id', sa.Integer(), nullable=False),
        sa.Column('checked_by_id', sa.Integer(), nullable=True),
        sa.Column('checked_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['added_by_id'], ['users.id']),
        sa.ForeignKeyConstraint(['checked_by_id'], ['users.id']),
        sa.ForeignKeyConstraint(['list_id'], ['shopping_lists.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_shopping_items_id', 'shopping_items', ['id'], unique=False)

    op.create_table(
        'family_notes',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('family_id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(), nullable=True),
        sa.Column('content', sa.String(), nullable=False),
        sa.Column('color', sa.String(), nullable=True),
        sa.Column('created_by_id', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['created_by_id'], ['users.id']),
        sa.ForeignKeyConstraint(['family_id'], ['families.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_family_notes_id', 'family_notes', ['id'], unique=False)


def downgrade() -> None:
    op.drop_index('ix_family_notes_id', table_name='family_notes')
    op.drop_table('family_notes')
    op.drop_index('ix_shopping_items_id', table_name='shopping_items')
    op.drop_table('shopping_items')
    op.drop_index('ix_shopping_lists_id', table_name='shopping_lists')
    op.drop_table('shopping_lists')
