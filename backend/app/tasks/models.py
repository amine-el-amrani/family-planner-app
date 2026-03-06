import enum
from sqlalchemy import Column, Integer, String, ForeignKey, Date, DateTime, Enum
from sqlalchemy.orm import relationship
from backend.app.database import Base


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
    assigned_to = relationship("User", foreign_keys=[assigned_to_id])
