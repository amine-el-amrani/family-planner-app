from sqlalchemy import Column, Integer, String, Boolean, DateTime
from datetime import datetime
from app.database import Base


class VerificationCode(Base):
    __tablename__ = "verification_codes"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, index=True, nullable=False)
    code = Column(String(6), nullable=False)
    # purpose: password_reset | email_change
    purpose = Column(String, nullable=False)
    # only for email_change: the new email to set after verification
    new_email = Column(String, nullable=True)
    expires_at = Column(DateTime, nullable=False)
    used = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
