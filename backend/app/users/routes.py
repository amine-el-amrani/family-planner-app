import os
from fastapi import APIRouter, Depends, UploadFile, File
from backend.app.auth.deps import get_current_user
from backend.app.users.models import User
from backend.app.auth.schemas import UserUpdate, UserOut
from sqlalchemy.orm import Session
from backend.app.database import get_db

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
    static_dir = os.path.join(os.path.dirname(__file__), '..', 'static')
    os.makedirs(static_dir, exist_ok=True)
    filename = f"profile_{current_user.id}.jpg"
    file_path = os.path.join(static_dir, filename)
    with open(file_path, "wb") as f:
        f.write(file.file.read())
    current_user.profile_image = f"/static/{filename}"
    db.commit()
    db.refresh(current_user)
    return {"profile_image": current_user.profile_image}