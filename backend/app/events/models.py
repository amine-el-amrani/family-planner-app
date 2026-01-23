from sqlalchemy import Column, Integer, String, ForeignKey, Date, Time
from sqlalchemy.orm import relationship
from backend.app.database import Base
from backend.app.users.models import User
from backend.app.families.models import Family

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
