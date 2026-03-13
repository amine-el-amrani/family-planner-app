"""add recurring tasks table

Revision ID: e5f6a7b8c9d0
Revises: d4e5f6a7b8c9
Down revision: 'd4e5f6a7b8c9'
Branch labels: None
Depends on: None
"""
from alembic import op
import sqlalchemy as sa

revision = 'e5f6a7b8c9d0'
down_revision = 'd4e5f6a7b8c9'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'recurring_tasks',
        sa.Column('id', sa.Integer(), primary_key=True, index=True),
        sa.Column('title', sa.String(), nullable=False),
        sa.Column('description', sa.String(), nullable=True),
        sa.Column('priority', sa.String(), nullable=True, server_default='normale'),
        sa.Column('visibility', sa.String(), nullable=True, server_default='prive'),
        sa.Column('family_id', sa.Integer(), sa.ForeignKey('families.id'), nullable=True),
        sa.Column('created_by_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('assigned_to_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=True),
        sa.Column('category', sa.String(), nullable=True),
        sa.Column('recurrence_type', sa.String(), nullable=False),
        sa.Column('interval_days', sa.Integer(), nullable=True),
        sa.Column('weekdays', sa.String(), nullable=True),
        sa.Column('start_date', sa.Date(), nullable=True),
        sa.Column('last_generated_date', sa.Date(), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=True, server_default='true'),
        sa.Column('created_at', sa.DateTime(), nullable=True),
    )
    op.add_column('tasks', sa.Column('recurring_task_id', sa.Integer(), sa.ForeignKey('recurring_tasks.id'), nullable=True))


def downgrade():
    op.drop_column('tasks', 'recurring_task_id')
    op.drop_table('recurring_tasks')
