from typing import Optional
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.auth.deps import get_current_user
from backend.app.users.models import User
from backend.app.events.models import Event
from backend.app.tasks.models import Task
from backend.app.notifications.models import Notification
from backend.app.tasks.schemas import TaskCreate, TaskUpdate

router = APIRouter(prefix="/tasks", tags=["Tasks"])


@router.post("/")
def create_task(
    task_data: TaskCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    event = db.query(Event).filter(Event.id == task_data.event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    if current_user not in event.family.members:
        raise HTTPException(status_code=403, detail="Not a member of this family")

    if task_data.assigned_to_id:
        assigned_user = db.query(User).filter(User.id == task_data.assigned_to_id).first()
        if assigned_user not in event.family.members:
            raise HTTPException(status_code=403, detail="Assigned user is not a member of this family")
    else:
        assigned_user = None

    task = Task(
        title=task_data.title,
        description=task_data.description,
        event_id=event.id,
        created_by_id=current_user.id,
        assigned_to_id=assigned_user.id if assigned_user else None
    )
    if assigned_user:
        notif = Notification(
            message=f"Task '{task.title}' assigned to you in event '{event.title}'",
            user_id=assigned_user.id,
            created_by_id=current_user.id
        )
        db.add(notif)
    db.add(notif)
    db.commit()

    db.add(task)
    db.commit()
    db.refresh(task)

    return {
        "id": task.id,
        "title": task.title,
        "description": task.description,
        "done": task.done,
        "event_id": task.event_id,
        "created_by": current_user.full_name,
        "assigned_to": assigned_user.full_name if assigned_user else None
    }


@router.get("/my-tasks")
def list_my_tasks(
    event_id: Optional[int] = None,
    done: Optional[bool] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    tasks = []
    for family in current_user.families:
        for event in family.events:
            if event_id and event.id != event_id:
                continue
            for task in event.tasks:
                if done is not None and task.done != done:
                    continue
                tasks.append({
                    "id": task.id,
                    "title": task.title,
                    "description": task.description,
                    "done": task.done,
                    "event_title": event.title,
                    "assigned_to": task.assigned_to.full_name if task.assigned_to else None,
                    "created_by": task.created_by.full_name
                })
    return tasks


@router.get("/upcoming-tasks")
def upcoming_tasks(days: int = 2, current_user: User = Depends(get_current_user)):
    today = datetime.now().date()
    end_day = today + timedelta(days=days)
    tasks = []
    for family in current_user.families:
        for event in family.events:
            if today <= event.date <= end_day:
                for task in event.tasks:
                    tasks.append({
                        "id": task.id,
                        "title": task.title,
                        "event_title": event.title,
                        "assigned_to": task.assigned_to.full_name if task.assigned_to else None,
                        "done": task.done
                    })
    return tasks


