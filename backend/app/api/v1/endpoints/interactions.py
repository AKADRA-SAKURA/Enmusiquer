from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.v1.deps import get_current_user_id
from app.api.v1.schemas import BookmarkResponse, PreferenceResponse
from app.db.session import get_db
from app.models.bookmark import Bookmark
from app.models.track import Track
from app.models.user_track_preference import UserTrackPreference


router = APIRouter()


class PreferenceRequest(BaseModel):
    preference_type: str


@router.post("/tracks/{track_id}/preference", response_model=PreferenceResponse)
def upsert_preference(
    track_id: int,
    payload: PreferenceRequest,
    current_user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> PreferenceResponse:
    if payload.preference_type not in {"like", "skip"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"code": "validation_error", "message": "preference_type must be like or skip"},
        )

    track = db.get(Track, track_id)
    if not track:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "not_found", "message": "track not found"},
        )

    pref = db.scalar(
        select(UserTrackPreference).where(
            UserTrackPreference.user_id == current_user_id,
            UserTrackPreference.track_id == track_id,
        )
    )
    if pref is None:
        pref = UserTrackPreference(
            user_id=current_user_id, track_id=track_id, preference_type=payload.preference_type
        )
        db.add(pref)
    else:
        pref.preference_type = payload.preference_type
        db.add(pref)

    db.commit()
    return PreferenceResponse.model_validate(
        {"data": {"track_id": track_id, "preference_type": payload.preference_type}}
    )


@router.post("/tracks/{track_id}/bookmark", response_model=BookmarkResponse)
def create_bookmark(
    track_id: int,
    current_user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> BookmarkResponse:
    track = db.get(Track, track_id)
    if not track:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "not_found", "message": "track not found"},
        )

    bookmark = db.scalar(
        select(Bookmark).where(
            Bookmark.user_id == current_user_id,
            Bookmark.track_id == track_id,
        )
    )
    if bookmark is None:
        db.add(Bookmark(user_id=current_user_id, track_id=track_id))
        db.commit()

    return BookmarkResponse.model_validate({"data": {"track_id": track_id, "bookmarked": True}})
