from datetime import date
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.database import get_db
from app.auth.deps import get_current_user
from app.users.models import User
from app.tasks.models import RecurringTask, RecurrenceType, Task, TaskStatus, TaskPriority, TaskVisibility
from app.families.models import Family

router = APIRouter(prefix="/recurring-tasks", tags=["Recurring Tasks"])


class RecurringTaskCreate(BaseModel):
    title: str
    description: Optional[str] = None
    priority: str = "normale"
    visibility: str = "prive"
    family_id: Optional[int] = None
    assigned_to_id: Optional[int] = None
    category: Optional[str] = None
    recurrence_type: str  # daily | every_n_days | weekly
    interval_days: Optional[int] = None
    weekdays: Optional[List[int]] = None  # [0,1,2,3,4,5,6] Mon=0


def _should_run_today(rt: RecurringTask, today: date) -> bool:
    if rt.recurrence_type == RecurrenceType.daily:
        return True
    if rt.recurrence_type == RecurrenceType.every_n_days:
        interval = rt.interval_days or 1
        delta = (today - rt.start_date).days
        return delta % interval == 0
    if rt.recurrence_type == RecurrenceType.weekly:
        if not rt.weekdays:
            return False
        allowed = [int(d) for d in rt.weekdays.split(",")]
        return today.weekday() in allowed
    return False


def _create_task_instance(rt: RecurringTask, today: date, db: Session) -> None:
    """Create a Task instance from a RecurringTask for today if not already done."""
    existing = db.query(Task).filter(
        Task.recurring_task_id == rt.id,
        Task.due_date == today,
    ).first()
    if existing:
        return
    db.add(Task(
        title=rt.title,
        description=rt.description,
        status=TaskStatus.en_attente,
        priority=rt.priority,
        visibility=rt.visibility,
        family_id=rt.family_id,
        created_by_id=rt.created_by_id,
        assigned_to_id=rt.assigned_to_id,
        category=rt.category,
        due_date=today,
        recurring_task_id=rt.id,
    ))
    rt.last_generated_date = today


@router.post("/")
def create_recurring_task(
    body: RecurringTaskCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if body.family_id:
        family = db.query(Family).filter(Family.id == body.family_id).first()
        if not family or current_user not in family.members:
            raise HTTPException(status_code=403, detail="Famille introuvable ou accès refusé")

    try:
        rec_type = RecurrenceType(body.recurrence_type)
    except ValueError:
        raise HTTPException(status_code=400, detail="recurrence_type invalide")

    if rec_type == RecurrenceType.every_n_days and not body.interval_days:
        raise HTTPException(status_code=400, detail="interval_days requis pour every_n_days")
    if rec_type == RecurrenceType.weekly and not body.weekdays:
        raise HTTPException(status_code=400, detail="weekdays requis pour weekly")

    weekdays_str = ",".join(str(d) for d in body.weekdays) if body.weekdays else None

    rt = RecurringTask(
        title=body.title,
        description=body.description,
        priority=TaskPriority[body.priority] if body.priority else TaskPriority.normale,
        visibility=TaskVisibility[body.visibility] if body.visibility else TaskVisibility.prive,
        family_id=body.family_id,
        created_by_id=current_user.id,
        assigned_to_id=body.assigned_to_id,
        category=body.category,
        recurrence_type=rec_type,
        interval_days=body.interval_days,
        weekdays=weekdays_str,
        start_date=date.today(),
        is_active=True,
    )
    db.add(rt)
    db.flush()

    # Generate first instance for today if applicable
    if _should_run_today(rt, date.today()):
        _create_task_instance(rt, date.today(), db)

    db.commit()
    db.refresh(rt)
    return _rt_to_dict(rt)


@router.get("/")
def list_recurring_tasks(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rts = db.query(RecurringTask).filter(
        RecurringTask.created_by_id == current_user.id,
        RecurringTask.is_active == True,  # noqa: E712
    ).order_by(RecurringTask.id.desc()).all()
    return [_rt_to_dict(rt) for rt in rts]


@router.delete("/{rt_id}")
def delete_recurring_task(
    rt_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rt = db.query(RecurringTask).filter(RecurringTask.id == rt_id).first()
    if not rt or rt.created_by_id != current_user.id:
        raise HTTPException(status_code=404, detail="Tâche récurrente introuvable")
    rt.is_active = False
    db.commit()
    return {"message": "Tâche récurrente désactivée"}


def _rt_to_dict(rt: RecurringTask) -> dict:
    weekdays = [int(d) for d in rt.weekdays.split(",")] if rt.weekdays else []
    return {
        "id": rt.id,
        "title": rt.title,
        "description": rt.description,
        "priority": rt.priority.value,
        "visibility": rt.visibility.value,
        "family_id": rt.family_id,
        "assigned_to_id": rt.assigned_to_id,
        "category": rt.category,
        "recurrence_type": rt.recurrence_type.value,
        "interval_days": rt.interval_days,
        "weekdays": weekdays,
        "start_date": rt.start_date.isoformat() if rt.start_date else None,
        "is_active": rt.is_active,
    }
