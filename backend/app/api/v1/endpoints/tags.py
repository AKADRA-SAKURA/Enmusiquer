from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.v1.pagination import normalize_pagination
from app.api.v1.schemas import TagsListResponse
from app.db.session import get_db
from app.models.tag import Tag


router = APIRouter()


@router.get("/tags", response_model=TagsListResponse)
def list_tags(
    q: str | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    per_page: int = Query(default=20, ge=1, le=50),
    db: Session = Depends(get_db),
) -> TagsListResponse:
    page, per_page = normalize_pagination(page, per_page)
    offset = (page - 1) * per_page

    stmt = select(Tag)
    count_stmt = select(func.count(Tag.id))

    if q:
        pattern = f"%{q.strip()}%"
        stmt = stmt.where(Tag.name.ilike(pattern))
        count_stmt = count_stmt.where(Tag.name.ilike(pattern))

    stmt = stmt.order_by(Tag.name.asc()).offset(offset).limit(per_page)

    tags = db.execute(stmt).scalars().all()
    total = db.scalar(count_stmt) or 0

    data = [{"id": t.id, "name": t.name} for t in tags]
    return {"data": data, "meta": {"page": page, "per_page": per_page, "total": total}}
