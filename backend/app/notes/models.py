from datetime import datetime
from sqlalchemy import Column, Integer, String, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from backend.app.database import Base


class FamilyNote(Base):
    __tablename__ = "family_notes"

    id = Column(Integer, primary_key=True, index=True)
    family_id = Column(Integer, ForeignKey("families.id"), nullable=False)
    title = Column(String, nullable=True)
    content = Column(String, nullable=False)
    color = Column(String, default="#fff9c4")  # Post-it yellow by default
    created_by_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    family = relationship("Family", backref="notes")
    created_by = relationship("User", foreign_keys=[created_by_id])
