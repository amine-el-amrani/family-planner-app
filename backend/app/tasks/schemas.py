from pydantic import BaseModel
from typing import Optional
from datetime import date, datetime
from enum import Enum


class TaskStatusEnum(str, Enum):
    en_attente = "en_attente"
    fait = "fait"
    annule = "annule"


class TaskVisibilityEnum(str, Enum):
    prive = "prive"
    famille = "famille"


class TaskPriorityEnum(str, Enum):
    normale = "normale"
    haute = "haute"
    urgente = "urgente"


class TaskCreate(BaseModel):
    title: str
    description: Optional[str] = None
    due_date: Optional[date] = None
    visibility: TaskVisibilityEnum = TaskVisibilityEnum.prive
    priority: TaskPriorityEnum = TaskPriorityEnum.normale
    family_id: Optional[int] = None
    event_id: Optional[int] = None
    assigned_to_id: Optional[int] = None
    category: Optional[str] = None


class TaskUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    status: Optional[TaskStatusEnum] = None
    due_date: Optional[date] = None
    visibility: Optional[TaskVisibilityEnum] = None
    priority: Optional[TaskPriorityEnum] = None
    assigned_to_id: Optional[int] = None
    family_id: Optional[int] = None
    category: Optional[str] = None


class TaskOut(BaseModel):
    id: int
    title: str
    description: Optional[str] = None
    status: TaskStatusEnum
    priority: TaskPriorityEnum = TaskPriorityEnum.normale
    due_date: Optional[date] = None
    visibility: TaskVisibilityEnum
    family_id: Optional[int] = None
    event_id: Optional[int] = None
    created_by_id: int
    created_by_name: str
    assigned_to_id: Optional[int] = None
    assigned_to_name: Optional[str] = None
    family_name: Optional[str] = None
    category: Optional[str] = None
    completed_at: Optional[datetime] = None

    class Config:
        from_attributes = True
