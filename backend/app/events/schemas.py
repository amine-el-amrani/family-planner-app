from pydantic import BaseModel
from datetime import date, time

class EventCreate(BaseModel):
    title: str
    description: str | None = None
    event_date: date
    time_from: time | None = None
    time_to: time | None = None
    family_id: int
