import base64
from datetime import datetime, timedelta
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from pydantic import BaseModel
from app.auth.deps import get_current_user
from app.users.models import User
from app.auth.schemas import UserUpdate, UserOut
from sqlalchemy.orm import Session
from app.database import get_db

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/me", response_model=UserOut)
def read_current_user(current_user: User = Depends(get_current_user)):
    return current_user


@router.put("/me", response_model=UserOut)
def update_current_user(
    user_update: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if user_update.full_name is not None:
        current_user.full_name = user_update.full_name
    if user_update.profile_image is not None:
        current_user.profile_image = user_update.profile_image
    db.commit()
    db.refresh(current_user)
    return current_user


@router.post("/me/profile-image")
def upload_profile_image(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    contents = file.file.read()
    b64 = base64.b64encode(contents).decode('utf-8')
    mime = file.content_type or 'image/jpeg'
    current_user.profile_image = f"data:{mime};base64,{b64}"
    db.commit()
    db.refresh(current_user)
    return {"profile_image": current_user.profile_image}


@router.get("/me/karma")
def get_karma(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Retourne les données karma : total, objectif quotidien, tâches du jour, tâches de la semaine."""
    from app.tasks.models import Task, TaskStatus
    # Force reload to avoid SQLAlchemy identity-map staleness
    db.refresh(current_user)

    today = datetime.utcnow().date()
    week_start = today - timedelta(days=today.weekday())  # lundi

    today_start = datetime.combine(today, datetime.min.time())
    week_start_dt = datetime.combine(week_start, datetime.min.time())

    daily_completed = db.query(Task).filter(
        Task.created_by_id == current_user.id,
        Task.status == TaskStatus.fait,
        Task.completed_at >= today_start
    ).count()

    weekly_completed = db.query(Task).filter(
        Task.created_by_id == current_user.id,
        Task.status == TaskStatus.fait,
        Task.completed_at >= week_start_dt
    ).count()

    return {
        "karma_total": current_user.karma_total or 0,
        "daily_goal": current_user.daily_goal or 5,
        "daily_completed": daily_completed,
        "weekly_completed": weekly_completed,
    }


@router.put("/me/daily-goal")
def update_daily_goal(
    goal: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Mettre à jour l'objectif quotidien de tâches."""
    if goal < 1 or goal > 50:
        raise HTTPException(status_code=400, detail="L'objectif doit être entre 1 et 50")
    current_user.daily_goal = goal
    db.commit()
    return {"daily_goal": current_user.daily_goal}


@router.put("/me/push-token")
def update_push_token(
    data: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Enregistrer le token push Expo de l'utilisateur."""
    current_user.push_token = data.get("token")
    db.commit()
    return {"ok": True}


@router.post("/me/push-subscription")
def save_push_subscription(
    data: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Save a Web Push subscription JSON for the current user."""
    current_user.push_token = data.get("subscription")
    db.commit()
    return {"ok": True}


@router.get("/push/vapid-key")
def vapid_public_key():
    """Return the VAPID public key for push subscription (no auth needed)."""
    from app.notifications.push import get_vapid_public_key
    return {"public_key": get_vapid_public_key()}


@router.get("/me/push-status")
def push_status(current_user: User = Depends(get_current_user)):
    """Check if the current user has a push subscription saved."""
    token = current_user.push_token or ""
    return {
        "has_subscription": token.startswith("{"),
        "has_expo_token": token.startswith("ExponentPushToken["),
        "endpoint_preview": token[:60] + "..." if len(token) > 60 else token,
    }


class UserSettingsBody(BaseModel):
    prayer_enabled: Optional[bool] = None
    motivation_enabled: Optional[bool] = None


@router.get("/me/settings")
def get_user_settings(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    db.refresh(current_user)
    return {
        "prayer_enabled": current_user.prayer_enabled or False,
        "motivation_enabled": current_user.motivation_enabled or False,
    }


@router.patch("/me/settings")
def update_user_settings(
    body: UserSettingsBody,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    from app.families.daily_jobs import run_prayer_tasks_for_user, run_motivation_message_for_user
    from app.tasks.models import Task, TaskStatus

    if body.prayer_enabled is not None:
        activating = body.prayer_enabled and not current_user.prayer_enabled
        deactivating = not body.prayer_enabled and current_user.prayer_enabled
        current_user.prayer_enabled = body.prayer_enabled
        if activating:
            run_prayer_tasks_for_user(current_user, db)
        elif deactivating:
            db.query(Task).filter(
                Task.created_by_id == current_user.id,
                Task.title.like("🕌 Prière%"),
                Task.status != TaskStatus.fait,
            ).delete(synchronize_session=False)

    if body.motivation_enabled is not None:
        activating = body.motivation_enabled and not current_user.motivation_enabled
        current_user.motivation_enabled = body.motivation_enabled
        if activating:
            run_motivation_message_for_user(current_user, db)

    db.commit()
    return {
        "prayer_enabled": current_user.prayer_enabled,
        "motivation_enabled": current_user.motivation_enabled,
    }


@router.post("/me/test-push")
def test_push(current_user: User = Depends(get_current_user)):
    """Send a test push notification to the current user (for debugging)."""
    from app.notifications.push import send_push
    token = current_user.push_token or ""
    if not token:
        return {"ok": False, "reason": "No push subscription saved for this user"}
    send_push(token, "Test Family Planner", "Les notifications push fonctionnent !")
    return {"ok": True, "token_preview": token[:60] + "..." if len(token) > 60 else token}
