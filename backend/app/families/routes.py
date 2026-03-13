import base64
from datetime import date
from typing import Optional
import requests as _requests
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Body, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.database import get_db
from app.families.models import Family, FamilyInvitation, InvitationStatus, DailyMessage
from app.auth.deps import get_current_user
from app.users.models import User
from app.notifications.models import Notification
from app.notifications.push import send_push
from app.families.daily_jobs import run_prayer_tasks_for_family, run_motivation_message_for_family
from app.tasks.models import Task, TaskStatus

router = APIRouter(prefix="/families", tags=["Families"])

@router.post("/")
def create_family(
    name: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    family = Family(name=name, created_by_id=current_user.id)
    family.members.append(current_user)
    db.add(family)
    db.commit()
    db.refresh(family)
    return {
        "id": family.id,
        "name": family.name,
        "members": [user.full_name for user in family.members],
        "created_by": current_user.full_name
    }

@router.get("/")
def list_families(current_user: User = Depends(get_current_user)):
    return [
        {"id": family.id, "name": family.name, "description": family.description, "family_image": family.family_image}
        for family in current_user.families
    ]

@router.put("/{family_id}")
def update_family(
    family_id: int,
    name: str = Body(None),
    description: str = Body(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    family = db.query(Family).filter(Family.id == family_id).first()
    if not family or current_user not in family.members:
        raise HTTPException(status_code=403, detail="Not a member of this family")
    if name is not None:
        family.name = name
    if description is not None:
        family.description = description
    db.commit()
    return {"message": "Family updated"}

@router.post("/{family_id}/family-image")
def upload_family_image(
    family_id: int,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    family = db.query(Family).filter(Family.id == family_id).first()
    if not family or current_user not in family.members:
        raise HTTPException(status_code=403, detail="Not a member of this family")
    contents = file.file.read()
    b64 = base64.b64encode(contents).decode('utf-8')
    mime = file.content_type or 'image/jpeg'
    family.family_image = f"data:{mime};base64,{b64}"
    db.commit()
    return {"family_image": family.family_image}

@router.post("/{family_id}/invite-member")
def invite_member(
    family_id: int,
    email: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    family = db.query(Family).filter(Family.id == family_id).first()
    if not family or current_user not in family.members:
        raise HTTPException(status_code=403, detail="Not a member of this family")
    existing_invitation = db.query(FamilyInvitation).filter(
        FamilyInvitation.family_id == family_id,
        FamilyInvitation.email == email,
        FamilyInvitation.status == InvitationStatus.PENDING
    ).first()
    if existing_invitation:
        raise HTTPException(status_code=400, detail="Invitation already sent")
    user = db.query(User).filter(User.email == email).first()
    if user and user in family.members:
        raise HTTPException(status_code=400, detail="User already in family")
    invitation = FamilyInvitation(
        email=email,
        family_id=family_id,
        invited_by_id=current_user.id
    )
    db.add(invitation)
    db.flush()  # get invitation.id before commit

    # Notify invited user if they have an account
    invited_user = db.query(User).filter(User.email == email).first()
    if invited_user:
        msg = f"{current_user.full_name} vous a invité dans la famille '{family.name}'"
        db.add(Notification(
            message=msg,
            user_id=invited_user.id,
            created_by_id=current_user.id,
            related_entity_type="invitation",
            related_entity_id=invitation.id,
        ))
        db.commit()
        if invited_user.push_token:
            send_push(invited_user.push_token, f"📬 {current_user.full_name}",
                      f"Vous invite dans '{family.name}' — rejoignez l'aventure ! 🏠",
                      url="/invitations")
    else:
        db.commit()
    return {"message": "Invitation sent"}

@router.get("/my-invitations")
def list_my_invitations(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    invitations = db.query(FamilyInvitation).filter(
        FamilyInvitation.email == current_user.email,
        FamilyInvitation.status == InvitationStatus.PENDING
    ).all()
    return [
        {
            "id": inv.id,
            "family_name": inv.family.name,
            "invited_by": inv.invited_by.full_name
        }
        for inv in invitations
    ]


@router.get("/my-sent-invitations")
def list_my_sent_invitations(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    invitations = db.query(FamilyInvitation).filter(
        FamilyInvitation.invited_by_id == current_user.id
    ).order_by(FamilyInvitation.id.desc()).all()
    return [
        {
            "id": inv.id,
            "email": inv.email,
            "family_id": inv.family_id,
            "family_name": inv.family.name,
            "status": inv.status.value,
        }
        for inv in invitations
    ]

@router.get("/public-holidays")
def get_public_holidays_early(year: int = Query(default=None)):
    """Alias registered before /{family_id} so FastAPI matches it correctly."""
    if year is None:
        year = date.today().year
    url = f"https://calendrier.api.gouv.fr/jours-feries/metropole/{year}.json"
    try:
        resp = _requests.get(url, timeout=5.0)
        resp.raise_for_status()
        return resp.json()
    except Exception:
        return {}


@router.get("/my-daily-message")
def get_daily_message_early(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Alias registered before /{family_id} so FastAPI matches it correctly."""
    today = date.today()
    family_ids = [f.id for f in current_user.families]
    if not family_ids:
        return {"message": None}
    msg = (
        db.query(DailyMessage)
        .filter(DailyMessage.family_id.in_(family_ids), DailyMessage.date == today)
        .order_by(DailyMessage.id.desc())
        .first()
    )
    if msg:
        return {"message": msg.message}
    return {"message": None}


@router.get("/{family_id}")
def get_family(
    family_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    family = db.query(Family).filter(Family.id == family_id).first()
    if not family or current_user not in family.members:
        raise HTTPException(status_code=404, detail="Family not found")
    return {
        "id": family.id,
        "name": family.name,
        "description": family.description,
        "family_image": family.family_image,
        "created_by_id": family.created_by_id,
    }

@router.post("/invitations/{invitation_id}/accept")
def accept_invitation(
    invitation_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    invitation = db.query(FamilyInvitation).filter(
        FamilyInvitation.id == invitation_id,
        FamilyInvitation.email == current_user.email,
        FamilyInvitation.status == InvitationStatus.PENDING
    ).first()
    if not invitation:
        raise HTTPException(status_code=404, detail="Invitation not found")
    invitation.status = InvitationStatus.ACCEPTED
    family = invitation.family
    family.members.append(current_user)

    # Notifier le créateur de la famille
    creator_push = None
    if family.created_by_id != current_user.id:
        msg = f"{current_user.full_name} a rejoint la famille '{family.name}'"
        notif = Notification(
            message=msg,
            user_id=family.created_by_id,
            created_by_id=current_user.id
        )
        db.add(notif)
        creator = db.query(User).filter(User.id == family.created_by_id).first()
        if creator and creator.push_token:
            creator_push = (creator.push_token, msg)

    db.commit()
    if creator_push:
        send_push(creator_push[0], f"🎉 L'équipe s'agrandit !",
                  f"{current_user.full_name} a rejoint '{family.name}' — bienvenue !",
                  url=f"/families/{family.id}")
    return {"message": "Invitation accepted"}

@router.post("/invitations/{invitation_id}/reject")
def reject_invitation(
    invitation_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    invitation = db.query(FamilyInvitation).filter(
        FamilyInvitation.id == invitation_id,
        FamilyInvitation.email == current_user.email,
        FamilyInvitation.status == InvitationStatus.PENDING
    ).first()
    if not invitation:
        raise HTTPException(status_code=404, detail="Invitation not found")
    invitation.status = InvitationStatus.REJECTED

    # Notify the person who sent the invitation
    inviter_push = None
    inviter = db.query(User).filter(User.id == invitation.invited_by_id).first()
    if inviter:
        msg = f"{current_user.full_name} a refusé votre invitation dans la famille '{invitation.family.name}'"
        db.add(Notification(
            message=msg,
            user_id=inviter.id,
            created_by_id=current_user.id,
            related_entity_type="family",
            related_entity_id=invitation.family_id,
        ))
        if inviter.push_token:
            inviter_push = (inviter.push_token, msg)

    db.commit()
    if inviter_push:
        send_push(inviter_push[0], f"😔 Invitation déclinée",
                  f"{current_user.full_name} n'a pas pu rejoindre '{invitation.family.name}' cette fois",
                  url="/families")
    return {"message": "Invitation rejected"}

@router.post("/{family_id}/leave")
def leave_family(
    family_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    family = db.query(Family).filter(Family.id == family_id).first()
    if not family or current_user not in family.members:
        raise HTTPException(status_code=404, detail="Family not found")
    if current_user.id == family.created_by_id:
        raise HTTPException(status_code=400, detail="Creator cannot leave the family")
    family.members.remove(current_user)
    db.commit()
    return {"message": "Left the family"}

@router.get("/{family_id}/members")
def list_members(
    family_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    family = db.query(Family).filter(Family.id == family_id).first()
    if not family or current_user not in family.members:
        raise HTTPException(status_code=404, detail="Family not found or access denied")
    return [
        {"id": user.id, "email": user.email, "full_name": user.full_name,
         "profile_image": user.profile_image, "karma_total": user.karma_total or 0}
        for user in family.members
    ]

class FamilySettingsBody(BaseModel):
    prayer_enabled: Optional[bool] = None
    motivation_enabled: Optional[bool] = None


@router.patch("/{family_id}/settings")
def update_family_settings(
    family_id: int,
    body: FamilySettingsBody,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    family = db.query(Family).filter(Family.id == family_id).first()
    if not family:
        raise HTTPException(status_code=404, detail="Family not found")
    if family.created_by_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the family creator can change settings")
    if body.prayer_enabled is not None:
        activating_prayer = body.prayer_enabled and not family.prayer_enabled
        deactivating_prayer = not body.prayer_enabled and family.prayer_enabled
        family.prayer_enabled = body.prayer_enabled
        if activating_prayer:
            run_prayer_tasks_for_family(family, db)
        elif deactivating_prayer:
            db.query(Task).filter(
                Task.family_id == family_id,
                Task.title.like("🕌 Prière%"),
                Task.status != TaskStatus.fait,
            ).delete(synchronize_session=False)
    if body.motivation_enabled is not None:
        activating_motivation = body.motivation_enabled and not family.motivation_enabled
        family.motivation_enabled = body.motivation_enabled
        if activating_motivation:
            run_motivation_message_for_family(family, db)
    db.commit()
    return {"prayer_enabled": family.prayer_enabled, "motivation_enabled": family.motivation_enabled}


@router.get("/{family_id}/settings")
def get_family_settings(
    family_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    family = db.query(Family).filter(Family.id == family_id).first()
    if not family or current_user not in family.members:
        raise HTTPException(status_code=404, detail="Family not found")
    return {
        "prayer_enabled": family.prayer_enabled or False,
        "motivation_enabled": family.motivation_enabled or False,
        "is_creator": family.created_by_id == current_user.id,
    }


@router.post("/{family_id}/remove-member")
def remove_member(
    family_id: int,
    user_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    family = db.query(Family).filter(Family.id == family_id).first()
    if not family:
        raise HTTPException(status_code=404, detail="Family not found")
    if family.created_by_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the family creator can remove members")
    user = db.query(User).filter(User.id == user_id).first()
    if not user or user not in family.members:
        raise HTTPException(status_code=404, detail="User not in family")
    if user.id == family.created_by_id:
        raise HTTPException(status_code=400, detail="Creator cannot remove themselves")
    family.members.remove(user)
    db.commit()
    return {"message": f"{user.full_name} removed from family"}