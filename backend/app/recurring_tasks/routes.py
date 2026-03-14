from datetime import date, timedelta
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Query
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

    # Generate instances for the next 7 days immediately
    today = date.today()
    for offset in range(7):
        target = today + timedelta(days=offset)
        if _should_run_today(rt, target):
            _create_task_instance(rt, target, db)

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


class RecurringTaskUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    priority: Optional[str] = None
    category: Optional[str] = None
    assigned_to_id: Optional[int] = None
    is_active: Optional[bool] = None


@router.patch("/{rt_id}")
def update_recurring_task(
    rt_id: int,
    body: RecurringTaskUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rt = db.query(RecurringTask).filter(RecurringTask.id == rt_id).first()
    if not rt or rt.created_by_id != current_user.id:
        raise HTTPException(status_code=404, detail="Tâche récurrente introuvable")

    if body.title is not None:
        rt.title = body.title
    if body.description is not None:
        rt.description = body.description if body.description else None
    if body.priority is not None:
        try:
            rt.priority = TaskPriority[body.priority]
        except KeyError:
            raise HTTPException(status_code=400, detail="Priorité invalide")
    if body.category is not None:
        rt.category = body.category if body.category else None
    if body.assigned_to_id is not None:
        rt.assigned_to_id = body.assigned_to_id
    if body.is_active is not None:
        rt.is_active = body.is_active

    # Propagate title/priority/category changes to future pending instances
    if any(v is not None for v in [body.title, body.priority, body.category, body.assigned_to_id]):
        today = date.today()
        future_tasks = db.query(Task).filter(
            Task.recurring_task_id == rt.id,
            Task.due_date >= today,
            Task.status == TaskStatus.en_attente,
        ).all()
        for t in future_tasks:
            if body.title is not None:
                t.title = rt.title
            if body.priority is not None:
                t.priority = rt.priority
            if body.category is not None:
                t.category = rt.category
            if body.assigned_to_id is not None:
                t.assigned_to_id = rt.assigned_to_id

    db.commit()
    db.refresh(rt)
    return _rt_to_dict(rt)


@router.delete("/{rt_id}")
def delete_recurring_task(
    rt_id: int,
    delete_future: bool = Query(default=True),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rt = db.query(RecurringTask).filter(RecurringTask.id == rt_id).first()
    if not rt or rt.created_by_id != current_user.id:
        raise HTTPException(status_code=404, detail="Tâche récurrente introuvable")
    rt.is_active = False
    if delete_future:
        today = date.today()
        db.query(Task).filter(
            Task.recurring_task_id == rt.id,
            Task.due_date > today,
            Task.status == TaskStatus.en_attente,
        ).delete(synchronize_session=False)
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
