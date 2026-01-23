from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.families.models import Family, FamilyInvitation, InvitationStatus
from backend.app.auth.deps import get_current_user
from backend.app.users.models import User
import os

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
    name: str = None,
    description: str = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    family = db.query(Family).filter(Family.id == family_id).first()
    if not family or family.created_by_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")
    if name:
        family.name = name
    if description:
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
    if not family or family.created_by_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")
    static_dir = os.path.join(os.path.dirname(__file__), '..', 'static')
    os.makedirs(static_dir, exist_ok=True)
    filename = f"family_{family_id}.jpg"
    file_path = os.path.join(static_dir, filename)
    with open(file_path, "wb") as f:
        f.write(file.file.read())
    family.family_image = f"/static/{filename}"
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
    invitation.family.members.append(current_user)
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
        {"id": user.id, "email": user.email, "full_name": user.full_name}
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