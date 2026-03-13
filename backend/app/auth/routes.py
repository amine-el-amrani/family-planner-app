import random
import string
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from app.database import get_db
from app.users.models import User
from app.auth.models import VerificationCode
from app.auth.schemas import UserCreate, UserLogin, Token
from app.auth.security import hash_password, verify_password, create_access_token
from app.auth.email_service import send_verification_email
from app.auth.deps import get_current_user

router = APIRouter(prefix="/auth", tags=["Auth"])

CODE_TTL_MINUTES = 15


def _generate_code() -> str:
    return "".join(random.choices(string.digits, k=6))


def _invalidate_old_codes(db: Session, email: str, purpose: str) -> None:
    db.query(VerificationCode).filter(
        VerificationCode.email == email,
        VerificationCode.purpose == purpose,
        VerificationCode.used == False,
    ).update({"used": True})
    db.commit()


# ─── Existing endpoints ────────────────────────────────────────────────────────

@router.post("/register", status_code=201)
def register(user_data: UserCreate, db: Session = Depends(get_db)):
    existing_user = db.query(User).filter(User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    user = User(
        email=user_data.email,
        full_name=user_data.full_name,
        hashed_password=hash_password(user_data.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return {"message": "User created successfully"}


@router.post("/login", response_model=Token)
def login(user_data: UserLogin, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == user_data.email).first()
    if not user or not verify_password(user_data.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    access_token = create_access_token(data={"sub": str(user.id)})
    return {"access_token": access_token}


# ─── Forgot password ───────────────────────────────────────────────────────────

class ForgotPasswordRequest(BaseModel):
    email: str


class ResetPasswordRequest(BaseModel):
    email: str
    code: str
    new_password: str


@router.post("/forgot-password")
def forgot_password(body: ForgotPasswordRequest, db: Session = Depends(get_db)):
    # Always return success to avoid email enumeration
    user = db.query(User).filter(User.email == body.email.lower().strip()).first()
    if user:
        _invalidate_old_codes(db, user.email, "password_reset")
        code = _generate_code()
        vc = VerificationCode(
            email=user.email,
            code=code,
            purpose="password_reset",
            expires_at=datetime.utcnow() + timedelta(minutes=CODE_TTL_MINUTES),
        )
        db.add(vc)
        db.commit()
        send_verification_email(user.email, code, "password_reset")  # fire-and-forget — don't leak existence
    return {"message": "Si cet email existe, un code a été envoyé."}


@router.post("/reset-password")
def reset_password(body: ResetPasswordRequest, db: Session = Depends(get_db)):
    email = body.email.lower().strip()
    vc = (
        db.query(VerificationCode)
        .filter(
            VerificationCode.email == email,
            VerificationCode.code == body.code,
            VerificationCode.purpose == "password_reset",
            VerificationCode.used == False,
            VerificationCode.expires_at > datetime.utcnow(),
        )
        .first()
    )
    if not vc:
        raise HTTPException(status_code=400, detail="Code invalide ou expiré")

    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    if len(body.new_password) < 6:
        raise HTTPException(status_code=400, detail="Le mot de passe doit contenir au moins 6 caractères")

    user.hashed_password = hash_password(body.new_password)
    vc.used = True
    db.commit()
    return {"message": "Mot de passe réinitialisé avec succès"}


# ─── Change password (authenticated) ──────────────────────────────────────────

class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str


@router.post("/change-password")
def change_password(
    body: ChangePasswordRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not verify_password(body.current_password, current_user.hashed_password):
        raise HTTPException(status_code=400, detail="Mot de passe actuel incorrect")
    if len(body.new_password) < 6:
        raise HTTPException(status_code=400, detail="Le nouveau mot de passe doit contenir au moins 6 caractères")
    current_user.hashed_password = hash_password(body.new_password)
    db.commit()
    return {"message": "Mot de passe modifié avec succès"}


# ─── Change email (authenticated) ─────────────────────────────────────────────

class ChangeEmailRequest(BaseModel):
    new_email: str
    current_password: str


@router.post("/change-email")
def change_email(
    body: ChangeEmailRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not verify_password(body.current_password, current_user.hashed_password):
        raise HTTPException(status_code=400, detail="Mot de passe incorrect")
    new_email = body.new_email.lower().strip()
    if not new_email:
        raise HTTPException(status_code=400, detail="Email invalide")
    existing = db.query(User).filter(User.email == new_email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Cet email est déjà utilisé")
    current_user.email = new_email
    db.commit()
    return {"message": "Email mis à jour avec succès"}
