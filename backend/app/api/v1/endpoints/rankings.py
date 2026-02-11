from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.v1.schemas import RankingsResponse
from app.api.v1.serializers import serialize_tracks
from app.db.session import get_db
from app.models.track import Track
from app.models.user_track_preference import UserTrackPreference


router = APIRouter()


def _period_cutoff(period: Literal["daily", "weekly", "monthly"]) -> datetime:
    now = datetime.now(timezone.utc)
    if period == "daily":
        return now - timedelta(days=1)
    if period == "monthly":
        return now - timedelta(days=30)
    return now - timedelta(days=7)


@router.get("/rankings", response_model=RankingsResponse)
def get_rankings(
    period: Literal["daily", "weekly", "monthly"] = Query(default="weekly"),
    limit: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db),
) -> RankingsResponse:
    cutoff = _period_cutoff(period)

    likes_subq = (
        select(
            UserTrackPreference.track_id.label("track_id"),
            func.count(UserTrackPreference.id).label("score"),
        )
        .where(
            UserTrackPreference.preference_type == "like",
            UserTrackPreference.created_at >= cutoff,
        )
        .group_by(UserTrackPreference.track_id)
        .subquery()
    )

    rows = db.execute(
        select(Track, likes_subq.c.score)
        .join(likes_subq, Track.id == likes_subq.c.track_id)
        .order_by(likes_subq.c.score.desc(), Track.created_at.desc())
        .limit(limit)
    ).all()

    tracks = [row[0] for row in rows]
    serialized_tracks = serialize_tracks(db, tracks)

    data = []
    for idx, row in enumerate(rows, start=1):
        data.append({"rank": idx, "track": serialized_tracks[idx - 1], "score": int(row[1] or 0)})

    return {"data": data, "meta": {"period": period, "limit": limit}}
