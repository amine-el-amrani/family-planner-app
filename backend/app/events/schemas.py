from pydantic import BaseModel
from typing import Optional
from datetime import date, time


class EventCreate(BaseModel):
    title: str
    description: Optional[str] = None
    event_date: date
    time_from: Optional[time] = None
    time_to: Optional[time] = None
    family_id: int


class EventUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    event_date: Optional[date] = None
    time_from: Optional[time] = None
    time_to: Optional[time] = None
