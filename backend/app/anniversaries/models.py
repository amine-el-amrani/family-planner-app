from datetime import datetime
from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Boolean
from sqlalchemy.orm import relationship
from app.database import Base


class Anniversary(Base):
    __tablename__ = "anniversaries"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)           # e.g. "Anniversaire de Lina"
    date_month = Column(Integer, nullable=False)     # 1–12
    date_day = Column(Integer, nullable=False)       # 1–31
    birth_year = Column(Integer, nullable=True)      # optional — used to compute age
    emoji = Column(String, default="🎂")
    is_birthday = Column(Boolean, default=True)      # True = birthday, False = anniversary/event
    family_id = Column(Integer, ForeignKey("families.id"), nullable=True)
    created_by_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    family = relationship("Family", backref="anniversaries")
    created_by = relationship("User", foreign_keys=[created_by_id])
