import os
import uuid
import base64
from typing import Optional, List
from datetime import date, datetime, timedelta
from dateutil.relativedelta import relativedelta
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.database import get_db
from app.auth.deps import get_current_user
from app.users.models import User
from app.families.models import Family
from app.events.models import Event, EventAttendee, EventRsvpStatus
from app.notifications.models import Notification
from app.notifications.push import send_push
from app.events.schemas import EventCreate, EventUpdate

router = APIRouter(prefix="/events", tags=["Events"])


class RsvpUpdate(BaseModel):
    status: str  # "going" | "not_going" | "pending"


def _event_to_dict(event: Event, family_name: str = None, override_date: date = None) -> dict:
    attendees = event.attendees or []
    going = [a for a in attendees if a.status == EventRsvpStatus.going]
    not_going = [a for a in attendees if a.status == EventRsvpStatus.not_going]
    pending_att = [a for a in attendees if a.status == EventRsvpStatus.pending]
    recurrence = event.recurrence_type.value if event.recurrence_type else "none"
    return {
        "id": event.id,
        "title": event.title,
        "description": event.description,
        "date": str(override_date or event.date),
        "time_from": str(event.time_from) if event.time_from else None,
        "time_to": str(event.time_to) if event.time_to else None,
        "category": event.category,
        "image_url": event.image_url,
        "family_id": event.family_id,
        "family_name": family_name or (event.family.name if event.family else None),
        "created_by_id": event.created_by_id,
        "created_by": event.created_by.full_name if event.created_by else None,
        "going_count": len(going),
        "not_going_count": len(not_going),
        "pending_count": len(pending_att),
        "recurrence_type": recurrence,
        "recurrence_end_date": str(event.recurrence_end_date) if event.recurrence_end_date else None,
        "attendees": [
            {
                "user_id": a.user_id,
                "user_name": a.user.full_name if a.user else None,
                "status": a.status.value,
            }
            for a in attendees
        ],
    }


def _expand_recurring(event: Event, start: date, end: date) -> List[dict]:
    """Return all occurrences of a recurring event within [start, end]."""
    recurrence = event.recurrence_type or "none"
    if recurrence == "none":
        if start <= event.date <= end:
            return [_event_to_dict(event)]
        return []

    end_boundary = min(end, event.recurrence_end_date) if event.recurrence_end_date else end
    occurrences = []
    current = event.date

    while current <= end_boundary:
        if current >= start:
            occurrences.append(_event_to_dict(event, override_date=current))
        # Advance
        if recurrence == "daily":
            current = current + timedelta(days=1)
        elif recurrence == "weekly":
            current = current + timedelta(weeks=1)
        elif recurrence == "monthly":
            current = current + relativedelta(months=1)
        elif recurrence == "yearly":
            current = current + relativedelta(years=1)
        else:
            break
        # Safety cap: avoid infinite loop
        if len(occurrences) > 366:
            break

    return occurrences


@router.get("/my-families")
def my_families(current_user: User = Depends(get_current_user)):
    return [{"id": f.id, "name": f.name} for f in current_user.families]


@router.post("/")
def create_event(
    event_data: EventCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    family = db.query(Family).filter(
        Family.id == event_data.family_id,
        Family.members.any(id=current_user.id),
    ).first()
    if not family:
        raise HTTPException(status_code=403, detail="Vous n'êtes pas membre de cette famille")

    event = Event(
        title=event_data.title,
        description=event_data.description,
        date=event_data.event_date,
        time_from=event_data.time_from,
        time_to=event_data.time_to,
        category=event_data.category,
        family_id=family.id,
        created_by_id=current_user.id,
        recurrence_type=event_data.recurrence_type or "none",
        recurrence_end_date=event_data.recurrence_end_date,
    )
    db.add(event)
    db.flush()  # get event.id before creating attendees

    # Creator is automatically "going"; all other family members start as "pending"
    for member in family.members:
        db.add(EventAttendee(
            event_id=event.id,
            user_id=member.id,
            status=EventRsvpStatus.going if member.id == current_user.id else EventRsvpStatus.pending,
        ))

    push_targets = []
    date_str = str(event_data.event_date)
    for member in family.members:
        if member.id != current_user.id:
            db.add(Notification(
                message=f"Nouvel événement '{event_data.title}' le {date_str} dans '{family.name}' — Serez-vous présent(e) ?",
                user_id=member.id,
                created_by_id=current_user.id,
                related_entity_type="event",
                related_entity_id=event.id,
            ))
            if member.push_token:
                push_targets.append(member.push_token)

    db.commit()
    db.refresh(event)

    for push_token in push_targets:
        send_push(
            push_token,
            f"📅 {family.name}",
            f"'{event_data.title}' le {date_str} — vous venez ? 👀",
        )

    return _event_to_dict(event, family.name)


@router.put("/{event_id}")
def update_event(
    event_id: int,
    event_data: EventUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Événement introuvable")
    is_event_creator = event.created_by_id == current_user.id
    is_family_creator = event.family and event.family.created_by_id == current_user.id
    if not is_event_creator and not is_family_creator:
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
    if event_data.category is not None:
        event.category = event_data.category

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
    db.refresh(event)

    for push_token, title in push_targets:
        send_push(push_token, f"✏️ {current_user.full_name}", f"A modifié '{title}' — vérifiez les nouvelles infos 📌")

    return _event_to_dict(event)


@router.delete("/{event_id}", status_code=204)
def delete_event(
    event_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Événement introuvable")
    is_event_creator = event.created_by_id == current_user.id
    is_family_creator = event.family and event.family.created_by_id == current_user.id
    if not is_event_creator and not is_family_creator:
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
        send_push(push_token, "Événement supprimé", f"'{event_title}' supprimé par {current_user.full_name}")


@router.post("/{event_id}/image")
def upload_event_image(
    event_id: int,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Événement introuvable")
    if event.created_by_id != current_user.id:
        raise HTTPException(status_code=403, detail="Seul le créateur peut modifier cet événement")
    data = file.file.read()
    b64 = base64.b64encode(data).decode("utf-8")
    mime = file.content_type or "image/jpeg"
    event.image_url = f"data:{mime};base64,{b64}"
    db.commit()
    db.refresh(event)
    return {"image_url": event.image_url}


@router.patch("/{event_id}/rsvp")
def update_rsvp(
    event_id: int,
    data: RsvpUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Set the current user's RSVP status for an event."""
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Événement introuvable")

    user_family_ids = [f.id for f in current_user.families]
    if event.family_id not in user_family_ids:
        raise HTTPException(status_code=403, detail="Accès refusé")

    try:
        new_status = EventRsvpStatus(data.status)
    except ValueError:
        raise HTTPException(status_code=400, detail="Statut invalide. Valeurs acceptées: going, not_going, pending")

    attendee = db.query(EventAttendee).filter(
        EventAttendee.event_id == event_id,
        EventAttendee.user_id == current_user.id,
    ).first()
    if not attendee:
        attendee = EventAttendee(event_id=event_id, user_id=current_user.id)
        db.add(attendee)
    attendee.status = new_status

    # Notify the creator when a member answers (but not when they reset to pending)
    creator_push = None
    if event.created_by_id != current_user.id and new_status != EventRsvpStatus.pending:
        if new_status == EventRsvpStatus.going:
            msg = f"{current_user.full_name} sera là pour '{event.title}' ! 🎉"
        else:
            msg = f"{current_user.full_name} ne pourra pas venir à '{event.title}' 😔"
        db.add(Notification(
            message=msg,
            user_id=event.created_by_id,
            created_by_id=current_user.id,
            related_entity_type="event",
            related_entity_id=event.id,
        ))
        creator = db.query(User).filter(User.id == event.created_by_id).first()
        if creator and creator.push_token:
            creator_push = (creator.push_token, msg)

    db.commit()
    db.refresh(event)

    if creator_push:
        if new_status == EventRsvpStatus.going:
            send_push(creator_push[0], f"🎉 Bonne nouvelle !", creator_push[1])
        else:
            send_push(creator_push[0], f"😔 Absent(e)", creator_push[1])

    return _event_to_dict(event)


@router.get("/my-events")
def list_my_events(
    family_id: Optional[int] = None,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    current_user: User = Depends(get_current_user),
):
    query_start = start_date or date(2020, 1, 1)
    query_end = end_date or date(2099, 12, 31)
    events = []
    for family in current_user.families:
        if family_id and family.id != family_id:
            continue
        for event in family.events:
            # Include event if it starts before query_end and (no end or ends after query_start)
            if event.date > query_end:
                continue
            if event.recurrence_type and event.recurrence_type != "none":
                end_boundary = event.recurrence_end_date or query_end
                if end_boundary < query_start:
                    continue
            elif start_date and event.date < start_date:
                continue
            events.extend(_expand_recurring(event, query_start, query_end))
    return events


@router.get("/upcoming")
def upcoming_events(days: int = 3, current_user: User = Depends(get_current_user)):
    today = datetime.now().date()
    end_day = today + timedelta(days=days)
    events = []
    for family in current_user.families:
        for event in family.events:
            for occ in _expand_recurring(event, today, end_day):
                events.append({
                    "id": occ["id"],
                    "title": occ["title"],
                    "date": occ["date"],
                    "family_name": family.name,
                    "created_by_id": occ["created_by_id"],
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
            events.extend(_expand_recurring(event, start, end))
    return events
