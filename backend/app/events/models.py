import enum
from sqlalchemy import Column, Integer, String, ForeignKey, Date, Time, Enum as SQLEnum
from sqlalchemy.orm import relationship
from app.database import Base
from app.users.models import User
from app.families.models import Family


class EventRsvpStatus(str, enum.Enum):
    pending = "pending"
    going = "going"
    not_going = "not_going"


class Event(Base):
    __tablename__ = "events"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    description = Column(String, nullable=True)
    date = Column(Date, nullable=False)
    time_from = Column(Time, nullable=True)
    time_to = Column(Time, nullable=True)

    family_id = Column(Integer, ForeignKey("families.id"), nullable=False)
    created_by_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    family = relationship("Family", backref="events")
    created_by = relationship("User")
    attendees = relationship("EventAttendee", back_populates="event", cascade="all, delete-orphan")


class EventAttendee(Base):
    __tablename__ = "event_attendees"

    id = Column(Integer, primary_key=True)
    event_id = Column(Integer, ForeignKey("events.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    status = Column(SQLEnum(EventRsvpStatus), default=EventRsvpStatus.pending, nullable=False)

    event = relationship("Event", back_populates="attendees")
    user = relationship("User")
