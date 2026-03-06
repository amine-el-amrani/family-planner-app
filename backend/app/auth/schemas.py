from pydantic import BaseModel, EmailStr
from typing import Optional


class UserCreate(BaseModel):
    email: EmailStr
    password: str
    full_name: str


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    profile_image: Optional[str] = None


class UserOut(BaseModel):
    id: int
    email: EmailStr
    full_name: str
    profile_image: Optional[str] = None
    karma_total: int = 0
    daily_goal: int = 5

    class Config:
        from_attributes = True
