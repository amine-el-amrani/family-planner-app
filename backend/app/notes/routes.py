from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from app.database import get_db
from app.auth.deps import get_current_user
from app.users.models import User
from app.notes.models import FamilyNote

router = APIRouter(prefix="/notes", tags=["Notes"])

NOTE_COLORS = ["#fff9c4", "#c8e6c9", "#bbdefb", "#f8bbd0", "#ffe0b2", "#e1bee7"]


class NoteCreate(BaseModel):
    content: str
    title: Optional[str] = None
    color: Optional[str] = None


class NoteUpdate(BaseModel):
    content: Optional[str] = None
    title: Optional[str] = None
    color: Optional[str] = None


def _note_to_dict(note: FamilyNote) -> dict:
    return {
        "id": note.id,
        "family_id": note.family_id,
        "title": note.title,
        "content": note.content,
        "color": note.color,
        "created_by": note.created_by.full_name if note.created_by else None,
        "created_by_id": note.created_by_id,
        "created_at": str(note.created_at) if note.created_at else None,
        "updated_at": str(note.updated_at) if note.updated_at else None,
    }


@router.get("/{family_id}")
def get_notes(
    family_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    user_family_ids = [f.id for f in current_user.families]
    if family_id not in user_family_ids:
        raise HTTPException(status_code=403, detail="Accès refusé")
    notes = db.query(FamilyNote).filter(
        FamilyNote.family_id == family_id
    ).order_by(FamilyNote.updated_at.desc()).all()
    return [_note_to_dict(n) for n in notes]


@router.post("/{family_id}")
def create_note(
    family_id: int,
    data: NoteCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    user_family_ids = [f.id for f in current_user.families]
    if family_id not in user_family_ids:
        raise HTTPException(status_code=403, detail="Accès refusé")
    note = FamilyNote(
        family_id=family_id,
        title=data.title,
        content=data.content.strip(),
        color=data.color or "#fff9c4",
        created_by_id=current_user.id,
    )
    db.add(note)
    db.commit()
    db.refresh(note)
    return _note_to_dict(note)


@router.patch("/{note_id}")
def update_note(
    note_id: int,
    data: NoteUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    note = db.query(FamilyNote).filter(FamilyNote.id == note_id).first()
    if not note:
        raise HTTPException(status_code=404, detail="Note introuvable")
    user_family_ids = [f.id for f in current_user.families]
    if note.family_id not in user_family_ids:
        raise HTTPException(status_code=403, detail="Accès refusé")
    if data.content is not None:
        note.content = data.content.strip()
    if data.title is not None:
        note.title = data.title
    if data.color is not None:
        note.color = data.color
    note.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(note)
    return _note_to_dict(note)


@router.delete("/{note_id}", status_code=204)
def delete_note(
    note_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    note = db.query(FamilyNote).filter(FamilyNote.id == note_id).first()
    if not note:
        raise HTTPException(status_code=404, detail="Note introuvable")
    user_family_ids = [f.id for f in current_user.families]
    if note.family_id not in user_family_ids:
        raise HTTPException(status_code=403, detail="Accès refusé")
    db.delete(note)
    db.commit()
