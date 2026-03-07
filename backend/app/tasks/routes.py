from typing import Optional, List
from datetime import datetime, timedelta, date as date_type
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import or_
from app.database import get_db
from app.auth.deps import get_current_user
from app.users.models import User
from app.events.models import Event
from app.families.models import Family
from app.tasks.models import Task, TaskStatus, TaskVisibility, TaskPriority
from app.notifications.models import Notification
from app.notifications.push import send_push
from app.tasks.schemas import TaskCreate, TaskUpdate

router = APIRouter(prefix="/tasks", tags=["Tasks"])


def _task_to_dict(task: Task) -> dict:
    return {
        "id": task.id,
        "title": task.title,
        "description": task.description,
        "status": task.status.value,
        "priority": task.priority.value if task.priority else "normale",
        "due_date": str(task.due_date) if task.due_date else None,
        "visibility": task.visibility.value,
        "family_id": task.family_id,
        "event_id": task.event_id,
        "created_by_id": task.created_by_id,
        "created_by_name": task.created_by.full_name,
        "assigned_to_id": task.assigned_to_id,
        "assigned_to_name": task.assigned_to.full_name if task.assigned_to else None,
        "family_name": task.family.name if task.family else None,
        "completed_at": str(task.completed_at) if task.completed_at else None,
    }


def _get_user_family_ids(current_user: User) -> List[int]:
    return [f.id for f in current_user.families]


@router.post("/")
def create_task(
    task_data: TaskCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if task_data.event_id:
        event = db.query(Event).filter(Event.id == task_data.event_id).first()
        if not event:
            raise HTTPException(status_code=404, detail="Événement introuvable")
        if current_user not in event.family.members:
            raise HTTPException(status_code=403, detail="Vous n'êtes pas membre de cette famille")

    family = None
    if task_data.family_id:
        family = db.query(Family).filter(Family.id == task_data.family_id).first()
        if not family or current_user not in family.members:
            raise HTTPException(status_code=403, detail="Famille introuvable ou accès refusé")

    assigned_user = None
    if task_data.assigned_to_id:
        assigned_user = db.query(User).filter(User.id == task_data.assigned_to_id).first()
        if not assigned_user:
            raise HTTPException(status_code=404, detail="Utilisateur introuvable")
        if family and assigned_user not in family.members:
            raise HTTPException(status_code=403, detail="L'utilisateur assigné n'est pas membre de cette famille")

    task = Task(
        title=task_data.title,
        description=task_data.description,
        due_date=task_data.due_date,
        visibility=task_data.visibility,
        priority=TaskPriority[task_data.priority.value] if task_data.priority else TaskPriority.normale,
        family_id=task_data.family_id,
        event_id=task_data.event_id,
        created_by_id=current_user.id,
        assigned_to_id=assigned_user.id if assigned_user else None
    )
    db.add(task)

    if assigned_user and assigned_user.id != current_user.id:
        db.add(Notification(
            message=f"Tâche '{task_data.title}' vous a été assignée par {current_user.full_name}",
            user_id=assigned_user.id,
            created_by_id=current_user.id,
            related_entity_type="task",
        ))
    elif family and task_data.visibility == "famille" and not assigned_user:
        for member in family.members:
            if member.id != current_user.id:
                db.add(Notification(
                    message=f"Nouvelle tâche famille '{task_data.title}' créée par {current_user.full_name}",
                    user_id=member.id,
                    created_by_id=current_user.id,
                    related_entity_type="task",
                ))

    db.commit()
    db.refresh(task)

    # Push to assignee on creation
    if assigned_user and assigned_user.id != current_user.id and assigned_user.push_token:
        send_push(
            assigned_user.push_token,
            "Nouvelle tâche assignée",
            f"{current_user.full_name} vous a assigné : '{task_data.title}'"
        )

    return _task_to_dict(task)


@router.get("/today")
def today_tasks(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    today = datetime.now().date()
    tomorrow = today + timedelta(days=1)
    user_family_ids = _get_user_family_ids(current_user)

    # User's own private tasks
    personal = db.query(Task).filter(
        Task.created_by_id == current_user.id,
        Task.visibility == TaskVisibility.prive,
        Task.status != TaskStatus.annule,
        or_(Task.due_date == today, Task.due_date == None)
    ).all()

    # Tasks assigned to user by someone else (any visibility)
    assigned_to_me = db.query(Task).filter(
        Task.assigned_to_id == current_user.id,
        Task.created_by_id != current_user.id,
        Task.status != TaskStatus.annule,
        or_(Task.due_date == today, Task.due_date == None)
    ).all()

    # Family-visible tasks: created by user OR unassigned family tasks (no duplicate with assigned_to_me)
    family_tasks = db.query(Task).filter(
        Task.visibility == TaskVisibility.famille,
        Task.status != TaskStatus.annule,
        or_(
            Task.created_by_id == current_user.id,
            (Task.assigned_to_id == None) & Task.family_id.in_(user_family_ids)
        ),
        or_(Task.due_date == today, Task.due_date == None)
    ).all()

    tomorrow_urgent = db.query(Task).filter(
        or_(
            Task.created_by_id == current_user.id,
            Task.assigned_to_id == current_user.id,
            (Task.assigned_to_id == None) & Task.family_id.in_(user_family_ids)
        ),
        Task.due_date == tomorrow,
        Task.priority.in_([TaskPriority.haute, TaskPriority.urgente]),
        Task.status != TaskStatus.annule
    ).all()

    return {
        "personal": [_task_to_dict(t) for t in personal],
        "assigned_to_me": [_task_to_dict(t) for t in assigned_to_me],
        "famille": [_task_to_dict(t) for t in family_tasks],
        "tomorrow_urgent": [_task_to_dict(t) for t in tomorrow_urgent],
    }


@router.patch("/{task_id}")
def update_task(
    task_id: int,
    task_data: TaskUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    task = db.query(Task).filter(Task.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="Tâche introuvable")
    if task.created_by_id != current_user.id and task.assigned_to_id != current_user.id:
        raise HTTPException(status_code=403, detail="Accès refusé")

    content_changed = False

    if task_data.title is not None:
        task.title = task_data.title
        content_changed = True
    if task_data.description is not None:
        task.description = task_data.description
    if task_data.due_date is not None:
        task.due_date = task_data.due_date
        content_changed = True
    if task_data.visibility is not None:
        task.visibility = task_data.visibility
    if task_data.priority is not None:
        task.priority = TaskPriority[task_data.priority.value]
        content_changed = True
    if task_data.assigned_to_id is not None:
        task.assigned_to_id = task_data.assigned_to_id
    if task_data.family_id is not None:
        task.family_id = task_data.family_id

    if task_data.status is not None:
        new_status = task_data.status.value
        old_completed_at = task.completed_at
        task.status = task_data.status

        # Karma goes to assignee if the task is assigned to someone other than the updater
        is_assigned_to_other = task.assigned_to_id and task.assigned_to_id != current_user.id
        karma_recipient = task.assigned_to if is_assigned_to_other else current_user

        if new_status == "fait":
            task.completed_at = datetime.utcnow()
            karma_recipient.karma_total = (karma_recipient.karma_total or 0) + 10
        elif new_status in ("en_attente", "annule") and old_completed_at is not None:
            karma_recipient.karma_total = max(0, (karma_recipient.karma_total or 0) - 10)
            task.completed_at = None

    # Notify assignee when creator modifies task content
    assignee_push = None
    if (content_changed
            and task.created_by_id == current_user.id
            and task.assigned_to_id
            and task.assigned_to_id != current_user.id):
        db.add(Notification(
            message=f"La tâche '{task.title}' a été modifiée par {current_user.full_name}",
            user_id=task.assigned_to_id,
            created_by_id=current_user.id,
            related_entity_type="task",
            related_entity_id=task.id,
        ))
        assignee_push = task.assigned_to.push_token if task.assigned_to else None

    # Notify creator when assignee marks task done (or un-done)
    creator_push = None
    if (task_data.status is not None
            and task.assigned_to_id
            and task.assigned_to_id == current_user.id
            and task.created_by_id != current_user.id):
        creator = db.query(User).filter(User.id == task.created_by_id).first()
        if creator:
            status_msg = "terminée ✓" if task_data.status.value == "fait" else "remise en attente"
            db.add(Notification(
                message=f"'{task.title}' a été {status_msg} par {current_user.full_name}",
                user_id=creator.id,
                created_by_id=current_user.id,
                related_entity_type="task",
                related_entity_id=task.id,
            ))
            creator_push = creator.push_token

    db.commit()
    db.refresh(task)

    if assignee_push:
        send_push(assignee_push, "Tâche modifiée",
                       f"'{task.title}' a été modifiée par {current_user.full_name}")

    if creator_push:
        status_msg = "terminée ✓" if task_data.status.value == "fait" else "remise en attente"
        send_push(creator_push, "Tâche mise à jour",
                       f"'{task.title}' {status_msg} par {current_user.full_name}")

    return _task_to_dict(task)


@router.delete("/{task_id}", status_code=204)
def delete_task(
    task_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    task = db.query(Task).filter(Task.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="Tâche introuvable")
    if task.created_by_id != current_user.id:
        raise HTTPException(status_code=403, detail="Seul le créateur peut supprimer cette tâche")

    task_title = task.title
    assignee_id = task.assigned_to_id
    assignee_push = task.assigned_to.push_token if task.assigned_to else None

    if assignee_id and assignee_id != current_user.id:
        db.add(Notification(
            message=f"La tâche '{task_title}' a été supprimée par {current_user.full_name}",
            user_id=assignee_id,
            created_by_id=current_user.id,
            related_entity_type="task",
        ))

    db.delete(task)
    db.commit()

    if assignee_id and assignee_id != current_user.id and assignee_push:
        send_push(assignee_push, "Tâche supprimée",
                       f"'{task_title}' a été supprimée par {current_user.full_name}")


@router.get("/agenda")
def agenda_tasks(
    start_date: date_type,
    end_date: date_type,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    user_family_ids = _get_user_family_ids(current_user)
    tasks = db.query(Task).filter(
        or_(
            Task.assigned_to_id == current_user.id,
            Task.created_by_id == current_user.id,
            (Task.assigned_to_id == None) & Task.family_id.in_(user_family_ids)
        ),
        Task.due_date >= start_date,
        Task.due_date <= end_date,
        Task.status != TaskStatus.annule
    ).all()
    return [_task_to_dict(t) for t in tasks]


@router.get("/my-tasks")
def list_my_tasks(
    due_date: Optional[date_type] = None,
    status: Optional[str] = None,
    event_id: Optional[int] = None,
    done: Optional[bool] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    user_family_ids = _get_user_family_ids(current_user)
    query = db.query(Task).filter(
        or_(
            Task.created_by_id == current_user.id,
            Task.assigned_to_id == current_user.id,
            (Task.assigned_to_id == None) & Task.family_id.in_(user_family_ids)
        )
    )
    if due_date:
        query = query.filter(Task.due_date == due_date)
    if status:
        query = query.filter(Task.status == status)
    if event_id:
        query = query.filter(Task.event_id == event_id)
    if done is not None:
        if done:
            query = query.filter(Task.status == TaskStatus.fait)
        else:
            query = query.filter(Task.status == TaskStatus.en_attente)
    return [_task_to_dict(t) for t in query.all()]


@router.get("/upcoming-tasks")
def upcoming_tasks(
    days: int = 7,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    today = datetime.now().date()
    end_day = today + timedelta(days=days)
    user_family_ids = _get_user_family_ids(current_user)
    tasks = db.query(Task).filter(
        or_(
            Task.created_by_id == current_user.id,
            Task.assigned_to_id == current_user.id,
            (Task.assigned_to_id == None) & Task.family_id.in_(user_family_ids)
        ),
        Task.due_date >= today,
        Task.due_date <= end_day,
        Task.status != TaskStatus.annule
    ).all()
    return [_task_to_dict(t) for t in tasks]
