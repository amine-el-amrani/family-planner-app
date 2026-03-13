from sqlalchemy import Column, Integer, String, Table, Enum, ForeignKey, Boolean, Date, DateTime
from sqlalchemy.orm import relationship
from app.database import Base
from datetime import datetime
import enum

user_family_table = Table(
    'user_family',
    Base.metadata,
    Column('user_id', Integer, ForeignKey('users.id'), primary_key=True),
    Column('family_id', Integer, ForeignKey('families.id'), primary_key=True)
)

class Family(Base):
    __tablename__ = "families"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=True)
    description = Column(String, nullable=True)
    family_image = Column(String, nullable=True)
    created_by_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    prayer_enabled = Column(Boolean, default=False)
    motivation_enabled = Column(Boolean, default=False)

    members = relationship(
        "User",
        secondary=user_family_table,
        backref="families"
    )
    creator = relationship("User", foreign_keys=[created_by_id])


class InvitationStatus(enum.Enum):
    PENDING = "pending"
    ACCEPTED = "accepted"
    REJECTED = "rejected"

class FamilyInvitation(Base):
    __tablename__ = "family_invitations"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, nullable=False)
    status = Column(Enum(InvitationStatus), default=InvitationStatus.PENDING)

    family_id = Column(Integer, ForeignKey("families.id"), nullable=False)
    invited_by_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    family = relationship("Family", backref="invitations")
    invited_by = relationship("User", foreign_keys=[invited_by_id])


class DailyMessage(Base):
    __tablename__ = "daily_messages"

    id = Column(Integer, primary_key=True, index=True)
    family_id = Column(Integer, ForeignKey("families.id"), nullable=False)
    message = Column(String, nullable=False)
    date = Column(Date, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    family = relationship("Family")