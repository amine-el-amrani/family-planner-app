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
from backend.app.events.schemas import EventCreate

router = APIRouter(prefix="/events", tags=["Events"])

# Get families of current user (for dropdown / mobile app)
@router.get("/my-families")
def my_families(current_user: User = Depends(get_current_user)):
    return [
        {"id": f.id, "name": f.name}
        for f in current_user.families
    ]

# Create event
@router.post("/")
def create_event(
    event_data: EventCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Only allow user to pick their own families
    family = db.query(Family).filter(
        Family.id == event_data.family_id,
        Family.members.any(id=current_user.id)
    ).first()

    if not family:
        raise HTTPException(
            status_code=403,
            detail="You are not a member of this family or family does not exist"
        )

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
    for member in family.members:
        if member.id != current_user.id:  # don't notify creator
            notif = Notification(
                message=f"New event '{event.title}' in family '{family.name}'",
                user_id=member.id,
                created_by_id=current_user.id
            )
            db.add(notif)
    db.commit()
    db.refresh(event)

    return {
        "id": event.id,
        "title": event.title,
        "description": event.description,
        "date": str(event.date),
        "time_from": str(event.time_from) if event.time_from else None,
        "time_to": str(event.time_to) if event.time_to else None,
        "family_id": event.family_id,
        "created_by": current_user.full_name
    }

# List all events for current user's families
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
            continue  # skip if filtering by a specific family
        for event in family.events:
            if start_date and event.date < start_date:
                continue
            if end_date and event.date > end_date:
                continue
            events.append({
                "id": event.id,
                "title": event.title,
                "description": event.description,
                "date": str(event.date),
                "time_from": str(event.time_from) if event.time_from else None,
                "time_to": str(event.time_to) if event.time_to else None,
                "family_name": family.name,
                "created_by": event.created_by.full_name
            })
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
                    "family_name": family.name
                })
    return events

