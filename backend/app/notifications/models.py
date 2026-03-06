from datetime import datetime
from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from backend.app.database import Base
from backend.app.users.models import User


class Notification(Base):
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True)
    message = Column(String, nullable=False)
    read = Column(Boolean, default=False)

    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)

    # For clickable navigation in the app
    related_entity_type = Column(String, nullable=True)   # "family" | "task" | "event" | "invitation"
    related_entity_id = Column(Integer, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=True)

    user = relationship("User", foreign_keys=[user_id], backref="notifications")
    created_by = relationship("User", foreign_keys=[created_by_id])
