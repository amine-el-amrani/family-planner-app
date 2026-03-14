from datetime import date
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.database import get_db
from app.auth.deps import get_current_user
from app.users.models import User
from app.families.models import Family
from app.anniversaries.models import Anniversary

router = APIRouter(prefix="/anniversaries", tags=["Anniversaries"])


class AnniversaryCreate(BaseModel):
    title: str
    date_month: int
    date_day: int
    birth_year: Optional[int] = None
    emoji: Optional[str] = "🎂"
    is_birthday: Optional[bool] = True
    family_id: Optional[int] = None


class AnniversaryUpdate(BaseModel):
    title: Optional[str] = None
    date_month: Optional[int] = None
    date_day: Optional[int] = None
    birth_year: Optional[int] = None
    emoji: Optional[str] = None
    is_birthday: Optional[bool] = None
    family_id: Optional[int] = None


def _to_dict(a: Anniversary, today: date) -> dict:
    # Next occurrence this year or next
    year = today.year
    try:
        next_occ = date(year, a.date_month, a.date_day)
    except ValueError:
        # e.g. Feb 29 on non-leap year
        next_occ = date(year, a.date_month, 28)
    if next_occ < today:
        try:
            next_occ = date(year + 1, a.date_month, a.date_day)
        except ValueError:
            next_occ = date(year + 1, a.date_month, 28)

    days_until = (next_occ - today).days
    age = (year - a.birth_year) if a.birth_year else None
    # If anniversary hasn't happened yet this year and birth_year set, age is still year-birth_year
    # (they'll turn that age on the upcoming birthday)

    return {
        "id": a.id,
        "title": a.title,
        "date_month": a.date_month,
        "date_day": a.date_day,
        "birth_year": a.birth_year,
        "emoji": a.emoji,
        "is_birthday": a.is_birthday,
        "family_id": a.family_id,
        "family_name": a.family.name if a.family else None,
        "created_by_id": a.created_by_id,
        "created_by_name": a.created_by.full_name,
        "next_occurrence": str(next_occ),
        "days_until": days_until,
        "age": age,
    }


@router.get("/")
def list_anniversaries(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return all anniversaries the current user can see (personal + their families)."""
    family_ids = [f.id for f in current_user.families]
    anniversaries = db.query(Anniversary).filter(
        (Anniversary.created_by_id == current_user.id) |
        (Anniversary.family_id.in_(family_ids))
    ).all()
    today = date.today()
    result = [_to_dict(a, today) for a in anniversaries]
    result.sort(key=lambda x: x["days_until"])
    return result


@router.get("/upcoming")
def upcoming_anniversaries(
    days: int = 30,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return anniversaries occurring within the next N days."""
    family_ids = [f.id for f in current_user.families]
    anniversaries = db.query(Anniversary).filter(
        (Anniversary.created_by_id == current_user.id) |
        (Anniversary.family_id.in_(family_ids))
    ).all()
    today = date.today()
    result = [_to_dict(a, today) for a in anniversaries]
    result = [a for a in result if a["days_until"] <= days]
    result.sort(key=lambda x: x["days_until"])
    return result


@router.post("/")
def create_anniversary(
    data: AnniversaryCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if data.family_id:
        family = db.query(Family).filter(Family.id == data.family_id).first()
        if not family or current_user not in family.members:
            raise HTTPException(status_code=403, detail="Famille introuvable ou accès refusé")

    ann = Anniversary(
        title=data.title,
        date_month=data.date_month,
        date_day=data.date_day,
        birth_year=data.birth_year,
        emoji=data.emoji or "🎂",
        is_birthday=data.is_birthday if data.is_birthday is not None else True,
        family_id=data.family_id,
        created_by_id=current_user.id,
    )
    db.add(ann)
    db.commit()
    db.refresh(ann)
    return _to_dict(ann, date.today())


@router.patch("/{ann_id}")
def update_anniversary(
    ann_id: int,
    data: AnniversaryUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    ann = db.query(Anniversary).filter(Anniversary.id == ann_id).first()
    if not ann:
        raise HTTPException(status_code=404, detail="Anniversaire introuvable")
    if ann.created_by_id != current_user.id:
        raise HTTPException(status_code=403, detail="Accès refusé")

    if data.title is not None:
        ann.title = data.title
    if data.date_month is not None:
        ann.date_month = data.date_month
    if data.date_day is not None:
        ann.date_day = data.date_day
    if data.birth_year is not None:
        ann.birth_year = data.birth_year
    if data.emoji is not None:
        ann.emoji = data.emoji
    if data.is_birthday is not None:
        ann.is_birthday = data.is_birthday
    if data.family_id is not None:
        ann.family_id = data.family_id

    db.commit()
    db.refresh(ann)
    return _to_dict(ann, date.today())


@router.delete("/{ann_id}", status_code=204)
def delete_anniversary(
    ann_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    ann = db.query(Anniversary).filter(Anniversary.id == ann_id).first()
    if not ann:
        raise HTTPException(status_code=404, detail="Anniversaire introuvable")
    if ann.created_by_id != current_user.id:
        raise HTTPException(status_code=403, detail="Accès refusé")
    db.delete(ann)
    db.commit()
