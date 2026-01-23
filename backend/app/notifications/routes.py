from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.auth.deps import get_current_user
from backend.app.notifications.models import Notification
from backend.app.notifications.schemas import NotificationCreate
from backend.app.users.models import User

router = APIRouter(prefix="/notifications", tags=["Notifications"])

# List notifications for current user
@router.get("/")
def list_notifications(current_user: User = Depends(get_current_user)):
    return [
        {
            "id": n.id,
            "message": n.message,
            "read": n.read,
            "created_by": n.created_by.full_name if n.created_by else None
        }
        for n in current_user.notifications
    ]

# Mark notification as read
@router.post("/{notification_id}/read")
def mark_read(notification_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    notif = db.query(Notification).filter(Notification.id == notification_id, Notification.user_id == current_user.id).first()
    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found")
    notif.read = True
    db.commit()
    db.refresh(notif)
    return {"status": "read"}
