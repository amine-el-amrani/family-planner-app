import enum
from datetime import datetime, date as date_type
from sqlalchemy import Column, Integer, String, ForeignKey, Date, DateTime, Enum, Boolean
from sqlalchemy.orm import relationship
from app.database import Base


class TaskStatus(enum.Enum):
    en_attente = "en_attente"
    fait = "fait"
    annule = "annule"


class TaskVisibility(enum.Enum):
    prive = "prive"
    famille = "famille"


class TaskPriority(enum.Enum):
    normale = "normale"
    haute = "haute"
    urgente = "urgente"


class Task(Base):
    __tablename__ = "tasks"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    description = Column(String, nullable=True)

    status = Column(Enum(TaskStatus), default=TaskStatus.en_attente, nullable=False)
    priority = Column(Enum(TaskPriority), default=TaskPriority.normale, nullable=False)

    event_id = Column(Integer, ForeignKey("events.id"), nullable=True)

    due_date = Column(Date, nullable=True)
    visibility = Column(Enum(TaskVisibility), default=TaskVisibility.prive, nullable=False)
    family_id = Column(Integer, ForeignKey("families.id"), nullable=True)
    completed_at = Column(DateTime, nullable=True)

    created_by_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    assigned_to_id = Column(Integer, ForeignKey("users.id"), nullable=True)

    event = relationship("Event", backref="tasks")
    family = relationship("Family", backref="tasks")
    created_by = relationship("User", foreign_keys=[created_by_id])
    category = Column(String, nullable=True)
    assigned_to = relationship("User", foreign_keys=[assigned_to_id])
    recurring_task_id = Column(Integer, ForeignKey("recurring_tasks.id"), nullable=True)


class RecurrenceType(str, enum.Enum):
    daily = "daily"
    every_n_days = "every_n_days"
    weekly = "weekly"


class RecurringTask(Base):
    __tablename__ = "recurring_tasks"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    description = Column(String, nullable=True)
    priority = Column(Enum(TaskPriority), default=TaskPriority.normale)
    visibility = Column(Enum(TaskVisibility), default=TaskVisibility.prive)
    family_id = Column(Integer, ForeignKey("families.id"), nullable=True)
    created_by_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    assigned_to_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    category = Column(String, nullable=True)

    recurrence_type = Column(Enum(RecurrenceType), nullable=False)
    interval_days = Column(Integer, nullable=True)   # for every_n_days
    weekdays = Column(String, nullable=True)          # comma-separated 0-6 (Mon=0) for weekly
    start_date = Column(Date, default=date_type.today)
    last_generated_date = Column(Date, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    family = relationship("Family")
    created_by = relationship("User", foreign_keys=[created_by_id])
    assigned_to = relationship("User", foreign_keys=[assigned_to_id])
