from datetime import datetime
from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from app.database import Base


class ShoppingList(Base):
    __tablename__ = "shopping_lists"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    family_id = Column(Integer, ForeignKey("families.id"), nullable=False)
    created_by_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    family = relationship("Family", backref="shopping_lists")
    created_by = relationship("User", foreign_keys=[created_by_id])
    items = relationship("ShoppingItem", back_populates="shopping_list", cascade="all, delete-orphan")


class ShoppingItem(Base):
    __tablename__ = "shopping_items"

    id = Column(Integer, primary_key=True, index=True)
    list_id = Column(Integer, ForeignKey("shopping_lists.id"), nullable=False)
    title = Column(String, nullable=False)
    quantity = Column(String, nullable=True)
    image_url = Column(String, nullable=True)
    is_checked = Column(Boolean, default=False)
    added_by_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    checked_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    checked_at = Column(DateTime, nullable=True)

    shopping_list = relationship("ShoppingList", back_populates="items")
    added_by = relationship("User", foreign_keys=[added_by_id])
    checked_by = relationship("User", foreign_keys=[checked_by_id])
