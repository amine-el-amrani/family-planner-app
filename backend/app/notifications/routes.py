from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.auth.deps import get_current_user
from backend.app.notifications.models import Notification
from backend.app.users.models import User

router = APIRouter(prefix="/notifications", tags=["Notifications"])


def _notif_to_dict(n: Notification) -> dict:
    return {
        "id": n.id,
        "message": n.message,
        "read": n.read,
        "created_by": n.created_by.full_name if n.created_by else None,
        "related_entity_type": n.related_entity_type,
        "related_entity_id": n.related_entity_id,
        "created_at": str(n.created_at) if n.created_at else None,
    }


@router.get("/")
def list_notifications(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """List all notifications for current user, newest first."""
    notifs = (
        db.query(Notification)
        .filter(Notification.user_id == current_user.id)
        .order_by(Notification.created_at.desc())
        .all()
    )
    return [_notif_to_dict(n) for n in notifs]


@router.get("/unread-count")
def unread_count(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    count = db.query(Notification).filter(
        Notification.user_id == current_user.id,
        Notification.read == False
    ).count()
    return {"count": count}


@router.post("/{notification_id}/read", status_code=204)
def mark_read_and_delete(
    notification_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Mark as read = delete the notification."""
    notif = db.query(Notification).filter(
        Notification.id == notification_id,
        Notification.user_id == current_user.id
    ).first()
    if not notif:
        raise HTTPException(status_code=404, detail="Notification introuvable")
    db.delete(notif)
    db.commit()


@router.post("/mark-all-read", status_code=204)
def mark_all_read_and_delete(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Delete all notifications for the user."""
    db.query(Notification).filter(
        Notification.user_id == current_user.id
    ).delete()
    db.commit()
