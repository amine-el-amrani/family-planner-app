from typing import Optional
from datetime import date, datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.auth.deps import get_current_user
from backend.app.users.models import User
from backend.app.families.models import Family
from backend.app.events.models import Event
from backend.app.notifications.models import Notification
from backend.app.notifications.push import send_expo_push
from backend.app.events.schemas import EventCreate, EventUpdate

router = APIRouter(prefix="/events", tags=["Events"])


def _event_to_dict(event: Event, family_name: str = None) -> dict:
    return {
        "id": event.id,
        "title": event.title,
        "description": event.description,
        "date": str(event.date),
        "time_from": str(event.time_from) if event.time_from else None,
        "time_to": str(event.time_to) if event.time_to else None,
        "family_id": event.family_id,
        "family_name": family_name or (event.family.name if event.family else None),
        "created_by_id": event.created_by_id,
        "created_by": event.created_by.full_name if event.created_by else None,
    }


# Familles de l'utilisateur courant (pour dropdown)
@router.get("/my-families")
def my_families(current_user: User = Depends(get_current_user)):
    return [
        {"id": f.id, "name": f.name}
        for f in current_user.families
    ]


# Créer un événement
@router.post("/")
def create_event(
    event_data: EventCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    family = db.query(Family).filter(
        Family.id == event_data.family_id,
        Family.members.any(id=current_user.id)
    ).first()

    if not family:
        raise HTTPException(status_code=403, detail="Vous n'êtes pas membre de cette famille")

    event = Event(
        title=event_data.title,
        description=event_data.description,
        date=event_data.event_date,
        time_from=event_data.time_from,
        time_to=event_data.time_to,
        family_id=family.id,
        created_by_id=current_user.id
    )

    db.add(event)
    push_targets = []
    for member in family.members:
        if member.id != current_user.id:
            db.add(Notification(
                message=f"Nouvel événement '{event_data.title}' dans la famille '{family.name}'",
                user_id=member.id,
                created_by_id=current_user.id,
                related_entity_type="event",
            ))
            if member.push_token:
                push_targets.append(member.push_token)
    db.commit()
    db.refresh(event)

    date_str = str(event_data.event_date)
    for push_token in push_targets:
        send_expo_push(push_token, f"Nouvel événement · {family.name}",
                       f"'{event_data.title}' le {date_str}")

    return _event_to_dict(event, family.name)


# Modifier un événement (créateur seulement)
@router.put("/{event_id}")
def update_event(
    event_id: int,
    event_data: EventUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Événement introuvable")
    if event.created_by_id != current_user.id:
        raise HTTPException(status_code=403, detail="Seul le créateur peut modifier cet événement")

    if event_data.title is not None:
        event.title = event_data.title
    if event_data.description is not None:
        event.description = event_data.description
    if event_data.event_date is not None:
        event.date = event_data.event_date
    if event_data.time_from is not None:
        event.time_from = event_data.time_from
    if event_data.time_to is not None:
        event.time_to = event_data.time_to

    db.commit()
    db.refresh(event)

    # Notify all family members of modification
    push_targets = []
    for member in event.family.members:
        if member.id != current_user.id:
            db.add(Notification(
                message=f"Événement '{event.title}' modifié par {current_user.full_name}",
                user_id=member.id,
                created_by_id=current_user.id,
                related_entity_type="event",
                related_entity_id=event.id,
            ))
            if member.push_token:
                push_targets.append((member.push_token, event.title))
    db.commit()

    for push_token, title in push_targets:
        send_expo_push(push_token, "Événement modifié",
                       f"'{title}' a été modifié par {current_user.full_name}")

    return _event_to_dict(event)


# Supprimer un événement (créateur seulement)
@router.delete("/{event_id}", status_code=204)
def delete_event(
    event_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Événement introuvable")
    if event.created_by_id != current_user.id:
        raise HTTPException(status_code=403, detail="Seul le créateur peut supprimer cet événement")

    event_title = event.title
    push_targets = []
    for member in event.family.members:
        if member.id != current_user.id:
            db.add(Notification(
                message=f"Événement '{event_title}' supprimé par {current_user.full_name}",
                user_id=member.id,
                created_by_id=current_user.id,
                related_entity_type="event",
            ))
            if member.push_token:
                push_targets.append(member.push_token)

    db.delete(event)
    db.commit()

    for push_token in push_targets:
        send_expo_push(push_token, "Événement supprimé",
                       f"'{event_title}' a été supprimé par {current_user.full_name}")


# Liste tous les événements des familles de l'utilisateur
@router.get("/my-events")
def list_my_events(
    family_id: Optional[int] = None,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    current_user: User = Depends(get_current_user)
):
    events = []
    for family in current_user.families:
        if family_id and family.id != family_id:
            continue
        for event in family.events:
            if start_date and event.date < start_date:
                continue
            if end_date and event.date > end_date:
                continue
            events.append(_event_to_dict(event, family.name))
    return events


@router.get("/upcoming")
def upcoming_events(days: int = 3, current_user: User = Depends(get_current_user)):
    today = datetime.now().date()
    end_day = today + timedelta(days=days)
    events = []
    for family in current_user.families:
        for event in family.events:
            if today <= event.date <= end_day:
                events.append({
                    "id": event.id,
                    "title": event.title,
                    "date": str(event.date),
                    "family_name": family.name,
                    "created_by_id": event.created_by_id,
                })
    return events


@router.get("/this-week")
def this_week_events(current_user: User = Depends(get_current_user)):
    today = datetime.now().date()
    start = today - timedelta(days=today.weekday())  # Monday
    end = start + timedelta(days=6)                   # Sunday
    events = []
    for family in current_user.families:
        for event in family.events:
            if start <= event.date <= end:
                events.append(_event_to_dict(event, family.name))
    return events
