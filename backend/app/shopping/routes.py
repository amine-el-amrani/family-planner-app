import logging
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Query

logger = logging.getLogger(__name__)
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from app.database import get_db
from app.auth.deps import get_current_user
from app.users.models import User
from app.families.models import Family
from app.shopping.models import ShoppingList, ShoppingItem

router = APIRouter(prefix="/shopping", tags=["Shopping"])


class ListCreate(BaseModel):
    family_id: int
    name: str


class ItemCreate(BaseModel):
    title: str
    quantity: Optional[str] = None


def _list_to_dict(lst: ShoppingList) -> dict:
    return {
        "id": lst.id,
        "name": lst.name,
        "family_id": lst.family_id,
        "family_name": lst.family.name if lst.family else None,
        "created_by": lst.created_by.full_name if lst.created_by else None,
        "created_at": str(lst.created_at) if lst.created_at else None,
        "item_count": len(lst.items),
        "checked_count": sum(1 for i in lst.items if i.is_checked),
    }


def _item_to_dict(item: ShoppingItem) -> dict:
    return {
        "id": item.id,
        "list_id": item.list_id,
        "title": item.title,
        "quantity": item.quantity,
        "is_checked": item.is_checked,
        "added_by": item.added_by.full_name if item.added_by else None,
        "checked_by": item.checked_by.full_name if item.checked_by else None,
        "checked_at": str(item.checked_at) if item.checked_at else None,
    }


@router.get("/my-lists")
def get_my_lists(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Return all shopping lists for the current user's families."""
    user_family_ids = [f.id for f in current_user.families]
    lists = db.query(ShoppingList).filter(
        ShoppingList.family_id.in_(user_family_ids)
    ).order_by(ShoppingList.created_at.desc()).all()
    return [_list_to_dict(lst) for lst in lists]


@router.post("/lists")
def create_list(
    data: ListCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    family = db.query(Family).filter(
        Family.id == data.family_id,
        Family.members.any(id=current_user.id)
    ).first()
    if not family:
        raise HTTPException(status_code=403, detail="Famille introuvable ou accès refusé")

    lst = ShoppingList(
        name=data.name.strip(),
        family_id=data.family_id,
        created_by_id=current_user.id,
    )
    db.add(lst)
    db.commit()
    db.refresh(lst)
    return _list_to_dict(lst)


@router.delete("/lists/{list_id}", status_code=204)
def delete_list(
    list_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    lst = db.query(ShoppingList).filter(ShoppingList.id == list_id).first()
    if not lst:
        raise HTTPException(status_code=404, detail="Liste introuvable")
    user_family_ids = [f.id for f in current_user.families]
    if lst.family_id not in user_family_ids:
        raise HTTPException(status_code=403, detail="Accès refusé")
    db.delete(lst)
    db.commit()


@router.get("/lists/{list_id}/items")
def get_items(
    list_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    lst = db.query(ShoppingList).filter(ShoppingList.id == list_id).first()
    if not lst:
        raise HTTPException(status_code=404, detail="Liste introuvable")
    user_family_ids = [f.id for f in current_user.families]
    if lst.family_id not in user_family_ids:
        raise HTTPException(status_code=403, detail="Accès refusé")
    # Unchecked first, then checked
    items = sorted(lst.items, key=lambda i: (i.is_checked, i.id))
    return [_item_to_dict(i) for i in items]


@router.post("/lists/{list_id}/items")
def add_item(
    list_id: int,
    data: ItemCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    lst = db.query(ShoppingList).filter(ShoppingList.id == list_id).first()
    if not lst:
        raise HTTPException(status_code=404, detail="Liste introuvable")
    user_family_ids = [f.id for f in current_user.families]
    if lst.family_id not in user_family_ids:
        raise HTTPException(status_code=403, detail="Accès refusé")

    item = ShoppingItem(
        list_id=list_id,
        title=data.title.strip(),
        quantity=data.quantity,
        added_by_id=current_user.id,
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return _item_to_dict(item)


@router.patch("/items/{item_id}/toggle")
def toggle_item(
    item_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    item = db.query(ShoppingItem).filter(ShoppingItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Article introuvable")
    user_family_ids = [f.id for f in current_user.families]
    if item.shopping_list.family_id not in user_family_ids:
        raise HTTPException(status_code=403, detail="Accès refusé")

    item.is_checked = not item.is_checked
    if item.is_checked:
        item.checked_by_id = current_user.id
        item.checked_at = datetime.utcnow()
    else:
        item.checked_by_id = None
        item.checked_at = None
    db.commit()
    db.refresh(item)
    return _item_to_dict(item)


@router.delete("/items/{item_id}", status_code=204)
def delete_item(
    item_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    item = db.query(ShoppingItem).filter(ShoppingItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Article introuvable")
    user_family_ids = [f.id for f in current_user.families]
    if item.shopping_list.family_id not in user_family_ids:
        raise HTTPException(status_code=403, detail="Accès refusé")
    db.delete(item)
    db.commit()


@router.get("/search-products")
def search_products(
    q: str = Query(default="", min_length=0),
    current_user: User = Depends(get_current_user),
):
    """Search products via Open Food Facts (server-side proxy to avoid CORS)."""
    import requests as _requests
    q = q.strip()
    if len(q) < 2:
        return []
    try:
        resp = _requests.get(
            "https://world.openfoodfacts.org/api/v2/search",
            params={
                "search_terms": q,
                "fields": "product_name,product_name_fr,generic_name,image_small_url,brands",
                "page_size": "20",
                "page": "1",
            },
            headers={"User-Agent": "FamilyPlannerApp/1.0 (https://family-planner-sage.vercel.app)"},
            timeout=10,
        )
        resp.raise_for_status()
        data = resp.json()

        results = []
        for p in data.get("products", []):
            name = (
                (p.get("product_name_fr") or "").strip()
                or (p.get("product_name") or "").strip()
                or (p.get("generic_name") or "").strip()
            )
            if not name:
                continue
            results.append({
                "name": name,
                "brand": ((p.get("brands") or "").split(",")[0]).strip(),
                "image": p.get("image_small_url") or "",
            })
        logger.info(f"Product search '{q}': {len(results)} results (total={data.get('count', '?')})")
        return results
    except Exception as e:
        logger.error(f"Product search '{q}' failed: {e}")
        return []


@router.delete("/lists/{list_id}/checked", status_code=204)
def clear_checked(
    list_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Delete all checked items from a list."""
    lst = db.query(ShoppingList).filter(ShoppingList.id == list_id).first()
    if not lst:
        raise HTTPException(status_code=404, detail="Liste introuvable")
    user_family_ids = [f.id for f in current_user.families]
    if lst.family_id not in user_family_ids:
        raise HTTPException(status_code=403, detail="Accès refusé")
    for item in list(lst.items):
        if item.is_checked:
            db.delete(item)
    db.commit()
