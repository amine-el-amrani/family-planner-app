"""initial_schema

Revision ID: 3e85de13ac0b
Revises:
Create Date: 2026-03-05 11:54:59.513083

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = '3e85de13ac0b'
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'users',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('email', sa.String(), nullable=False),
        sa.Column('full_name', sa.String(), nullable=False),
        sa.Column('hashed_password', sa.String(), nullable=False),
        sa.Column('profile_image', sa.String(), nullable=True),
        sa.Column('push_token', sa.String(), nullable=True),
        sa.Column('karma_total', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('daily_goal', sa.Integer(), nullable=False, server_default='5'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_users_id', 'users', ['id'], unique=False)
    op.create_index('ix_users_email', 'users', ['email'], unique=True)
    op.create_index('ix_users_full_name', 'users', ['full_name'], unique=False)

    op.create_table(
        'families',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(), nullable=True),
        sa.Column('description', sa.String(), nullable=True),
        sa.Column('family_image', sa.String(), nullable=True),
        sa.Column('created_by_id', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(['created_by_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_families_id', 'families', ['id'], unique=False)

    op.create_table(
        'user_family',
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('family_id', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(['family_id'], ['families.id']),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('user_id', 'family_id'),
    )

    op.create_table(
        'family_invitations',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('email', sa.String(), nullable=False),
        sa.Column('status', sa.Enum('PENDING', 'ACCEPTED', 'REJECTED', name='invitationstatus'), nullable=True),
        sa.Column('family_id', sa.Integer(), nullable=False),
        sa.Column('invited_by_id', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(['family_id'], ['families.id']),
        sa.ForeignKeyConstraint(['invited_by_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_family_invitations_id', 'family_invitations', ['id'], unique=False)

    op.create_table(
        'events',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(), nullable=False),
        sa.Column('description', sa.String(), nullable=True),
        sa.Column('date', sa.Date(), nullable=False),
        sa.Column('time_from', sa.Time(), nullable=True),
        sa.Column('time_to', sa.Time(), nullable=True),
        sa.Column('family_id', sa.Integer(), nullable=False),
        sa.Column('created_by_id', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(['created_by_id'], ['users.id']),
        sa.ForeignKeyConstraint(['family_id'], ['families.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_events_id', 'events', ['id'], unique=False)

    op.create_table(
        'tasks',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(), nullable=False),
        sa.Column('description', sa.String(), nullable=True),
        sa.Column('status', sa.Enum('en_attente', 'fait', 'annule', name='taskstatus'), nullable=False),
        sa.Column('priority', sa.Enum('normale', 'haute', 'urgente', name='taskpriority'), nullable=False),
        sa.Column('event_id', sa.Integer(), nullable=True),
        sa.Column('due_date', sa.Date(), nullable=True),
        sa.Column('visibility', sa.Enum('prive', 'famille', name='taskvisibility'), nullable=False),
        sa.Column('family_id', sa.Integer(), nullable=True),
        sa.Column('completed_at', sa.DateTime(), nullable=True),
        sa.Column('created_by_id', sa.Integer(), nullable=False),
        sa.Column('assigned_to_id', sa.Integer(), nullable=True),
        sa.ForeignKeyConstraint(['assigned_to_id'], ['users.id']),
        sa.ForeignKeyConstraint(['created_by_id'], ['users.id']),
        sa.ForeignKeyConstraint(['event_id'], ['events.id']),
        sa.ForeignKeyConstraint(['family_id'], ['families.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_tasks_id', 'tasks', ['id'], unique=False)

    op.create_table(
        'notifications',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('message', sa.String(), nullable=False),
        sa.Column('read', sa.Boolean(), nullable=True),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('created_by_id', sa.Integer(), nullable=True),
        sa.Column('related_entity_type', sa.String(), nullable=True),
        sa.Column('related_entity_id', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['created_by_id'], ['users.id']),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_notifications_id', 'notifications', ['id'], unique=False)


def downgrade() -> None:
    op.drop_index('ix_notifications_id', table_name='notifications')
    op.drop_table('notifications')
    op.drop_index('ix_tasks_id', table_name='tasks')
    op.drop_table('tasks')
    op.drop_index('ix_events_id', table_name='events')
    op.drop_table('events')
    op.drop_index('ix_family_invitations_id', table_name='family_invitations')
    op.drop_table('family_invitations')
    op.drop_table('user_family')
    op.drop_index('ix_families_id', table_name='families')
    op.drop_table('families')
    op.drop_index('ix_users_full_name', table_name='users')
    op.drop_index('ix_users_email', table_name='users')
    op.drop_index('ix_users_id', table_name='users')
    op.drop_table('users')
    op.execute('DROP TYPE IF EXISTS invitationstatus')
    op.execute('DROP TYPE IF EXISTS taskstatus')
    op.execute('DROP TYPE IF EXISTS taskpriority')
    op.execute('DROP TYPE IF EXISTS taskvisibility')
