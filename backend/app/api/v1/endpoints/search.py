from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.api.v1.pagination import normalize_pagination
from app.api.v1.serializers import serialize_tracks
from app.db.session import get_db
from app.models.track import Track
from app.models.track_tag import TrackTag


router = APIRouter()


class SearchByTagsRequest(BaseModel):
    tag_ids: list[int] = Field(default_factory=list)
    page: int = Field(default=1, ge=1)
    per_page: int = Field(default=20, ge=1, le=50)


@router.get("/search/tracks")
def search_tracks(
    q: str = Query(min_length=1),
    page: int = Query(default=1, ge=1),
    per_page: int = Query(default=20, ge=1, le=50),
    db: Session = Depends(get_db),
) -> dict:
    page, per_page = normalize_pagination(page, per_page)
    offset = (page - 1) * per_page
    keyword = f"%{q.strip()}%"

    cond = or_(
        Track.title.ilike(keyword),
        Track.artist_display_name.ilike(keyword),
        Track.writer.ilike(keyword),
        Track.composer.ilike(keyword),
        Track.record_info.ilike(keyword),
        Track.usage_context.ilike(keyword),
        Track.series_name.ilike(keyword),
        Track.album_artist_name.ilike(keyword),
    )

    stmt = select(Track).where(cond).order_by(Track.created_at.desc()).offset(offset).limit(per_page)
    count_stmt = select(func.count(Track.id)).where(cond)

    tracks = db.execute(stmt).scalars().all()
    total = db.scalar(count_stmt) or 0
    return {
        "data": serialize_tracks(db, tracks),
        "meta": {"page": page, "per_page": per_page, "total": total},
    }


@router.post("/search/tracks/by-tags")
def search_tracks_by_tags(payload: SearchByTagsRequest, db: Session = Depends(get_db)) -> dict:
    page, per_page = normalize_pagination(payload.page, payload.per_page)
    offset = (page - 1) * per_page
    tag_ids = list(dict.fromkeys(payload.tag_ids))

    if not tag_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"code": "validation_error", "message": "tag_ids is required"},
        )

    matched_track_ids_subq = (
        select(TrackTag.track_id)
        .where(TrackTag.tag_id.in_(tag_ids))
        .group_by(TrackTag.track_id)
        .having(func.count(func.distinct(TrackTag.tag_id)) == len(tag_ids))
        .subquery()
    )

    stmt = (
        select(Track)
        .where(Track.id.in_(select(matched_track_ids_subq.c.track_id)))
        .order_by(Track.created_at.desc())
        .offset(offset)
        .limit(per_page)
    )

    count_stmt = select(func.count()).select_from(matched_track_ids_subq)

    tracks = db.execute(stmt).scalars().all()
    total = db.scalar(count_stmt) or 0

    return {
        "data": serialize_tracks(db, tracks),
        "meta": {"page": page, "per_page": per_page, "total": total},
    }
