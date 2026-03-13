from sqlalchemy import Column, Integer, String, Boolean
from app.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    full_name = Column(String, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    profile_image = Column(String, nullable=True)
    push_token = Column(String, nullable=True)

    # Système de karma/récompenses
    karma_total = Column(Integer, default=0, nullable=False)
    daily_goal = Column(Integer, default=5, nullable=False)

    # Préférences personnelles
    prayer_enabled = Column(Boolean, default=False)
    motivation_enabled = Column(Boolean, default=False)
