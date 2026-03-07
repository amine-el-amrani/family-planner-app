import base64
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Body
from sqlalchemy.orm import Session
from app.database import get_db
from app.families.models import Family, FamilyInvitation, InvitationStatus
from app.auth.deps import get_current_user
from app.users.models import User
from app.notifications.models import Notification

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
        db.add(Notification(
            message=f"{current_user.full_name} vous a invité dans la famille '{family.name}'",
            user_id=invited_user.id,
            created_by_id=current_user.id,
            related_entity_type="invitation",
            related_entity_id=invitation.id,
        ))

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
    if family.created_by_id != current_user.id:
        notif = Notification(
            message=f"{current_user.full_name} a rejoint la famille '{family.name}'",
            user_id=family.created_by_id,
            created_by_id=current_user.id
        )
        db.add(notif)

    db.commit()
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
    db.commit()
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
        {"id": user.id, "email": user.email, "full_name": user.full_name, "profile_image": user.profile_image}
        for user in family.members
    ]

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