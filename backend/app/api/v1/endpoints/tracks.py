from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import Select, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.v1.deps import get_current_user_id
from app.api.v1.pagination import normalize_pagination
from app.api.v1.schemas import TrackResponse, TracksListResponse
from app.api.v1.serializers import serialize_tracks
from app.db.session import get_db
from app.models.tag import Tag
from app.models.track import Track
from app.models.track_tag import TrackTag
from app.models.user import User
from app.models.user_track_preference import UserTrackPreference
from app.services.url_normalizer import normalize_source_url


router = APIRouter()


class TrackCreateRequest(BaseModel):
    source_url: str = Field(min_length=3, max_length=2048)
    title: str = Field(min_length=1, max_length=255)
    artist_display_name: str = Field(min_length=1, max_length=255)
    source_type: Literal["youtube", "spotify", "apple_music", "soundcloud", "other"]
    source_track_id: str | None = Field(default=None, max_length=255)
    thumbnail_url: str | None = Field(default=None, max_length=2048)
    writer: str | None = Field(default=None, max_length=255)
    composer: str | None = Field(default=None, max_length=255)
    year: int | None = None
    record_info: str | None = None
    usage_context: str | None = None
    series_name: str | None = Field(default=None, max_length=255)
    album_artist_name: str | None = Field(default=None, max_length=255)
    tag_ids: list[int] = Field(default_factory=list)


def _popular_query() -> Select:
    likes_subq = (
        select(
            UserTrackPreference.track_id.label("track_id"),
            func.count(UserTrackPreference.id).label("like_count"),
        )
        .where(UserTrackPreference.preference_type == "like")
        .group_by(UserTrackPreference.track_id)
        .subquery()
    )
    return (
        select(Track)
        .outerjoin(likes_subq, Track.id == likes_subq.c.track_id)
        .order_by(func.coalesce(likes_subq.c.like_count, 0).desc(), Track.created_at.desc())
    )


@router.get("/tracks", response_model=TracksListResponse)
def list_tracks(
    page: int = Query(default=1, ge=1),
    per_page: int = Query(default=20, ge=1, le=50),
    sort: Literal["newest", "popular"] = Query(default="newest"),
    db: Session = Depends(get_db),
) -> TracksListResponse:
    page, per_page = normalize_pagination(page, per_page)
    offset = (page - 1) * per_page

    if sort == "popular":
        stmt = _popular_query()
    else:
        stmt = select(Track).order_by(Track.created_at.desc())

    tracks = db.execute(stmt.offset(offset).limit(per_page)).scalars().all()
    total = db.scalar(select(func.count(Track.id))) or 0

    return {
        "data": serialize_tracks(db, tracks),
        "meta": {"page": page, "per_page": per_page, "total": total},
    }


@router.get("/tracks/{track_id}", response_model=TrackResponse)
def get_track(track_id: int, db: Session = Depends(get_db)) -> TrackResponse:
    track = db.get(Track, track_id)
    if not track:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "not_found", "message": "track not found"},
        )

    data = serialize_tracks(db, [track])[0]
    return TrackResponse.model_validate({"data": data})


@router.post("/tracks", response_model=TrackResponse, status_code=status.HTTP_201_CREATED)
def create_track(
    payload: TrackCreateRequest,
    current_user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> TrackResponse:
    user_exists = db.scalar(select(User.id).where(User.id == current_user_id))
    if not user_exists:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "unauthorized", "message": "user not found"},
        )

    try:
        normalized_url = normalize_source_url(payload.source_url)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"code": "validation_error", "message": "invalid source_url"},
        )

    exists = db.scalar(select(Track.id).where(Track.source_url == normalized_url))
    if exists:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "duplicate_track_source_url", "message": "track already exists"},
        )

    unique_tag_ids = list(dict.fromkeys(payload.tag_ids))
    if unique_tag_ids:
        existing_tag_ids = set(
            db.scalars(select(Tag.id).where(Tag.id.in_(unique_tag_ids))).all()
        )
        missing = [tid for tid in unique_tag_ids if tid not in existing_tag_ids]
        if missing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"code": "validation_error", "message": f"tag not found: {missing}"},
            )

    track = Track(
        source_url=normalized_url,
        title=payload.title,
        artist_display_name=payload.artist_display_name,
        source_type=payload.source_type,
        source_track_id=payload.source_track_id,
        thumbnail_url=payload.thumbnail_url,
        writer=payload.writer,
        composer=payload.composer,
        year=payload.year,
        record_info=payload.record_info,
        usage_context=payload.usage_context,
        series_name=payload.series_name,
        album_artist_name=payload.album_artist_name,
        created_by=current_user_id,
    )
    db.add(track)
    db.flush()

    for tag_id in unique_tag_ids:
        db.add(TrackTag(track_id=track.id, tag_id=tag_id))

    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "duplicate_resource", "message": "resource conflict"},
        )

    db.refresh(track)
    data = serialize_tracks(db, [track])[0]
    return TrackResponse.model_validate({"data": data})
