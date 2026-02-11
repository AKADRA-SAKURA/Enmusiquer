from collections import defaultdict

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.v1.deps import get_current_user_id
from app.api.v1.pagination import normalize_pagination
from app.api.v1.serializers import serialize_tracks
from app.db.session import get_db
from app.models.track import Track
from app.models.track_tag import TrackTag
from app.models.user_track_preference import UserTrackPreference


router = APIRouter()


@router.get("/recommendations")
def get_recommendations(
    page: int = Query(default=1, ge=1),
    per_page: int = Query(default=20, ge=1, le=50),
    current_user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> dict:
    page, per_page = normalize_pagination(page, per_page)

    liked_track_ids = db.scalars(
        select(UserTrackPreference.track_id).where(
            UserTrackPreference.user_id == current_user_id,
            UserTrackPreference.preference_type == "like",
        )
    ).all()
    liked_track_id_set = set(liked_track_ids)
    skipped_track_ids = set(
        db.scalars(
            select(UserTrackPreference.track_id).where(
                UserTrackPreference.user_id == current_user_id,
                UserTrackPreference.preference_type == "skip",
            )
        ).all()
    )

    liked_tag_ids = set()
    if liked_track_ids:
        liked_tag_ids = set(
            db.scalars(select(TrackTag.tag_id).where(TrackTag.track_id.in_(liked_track_ids))).all()
        )

    track_tag_rows = db.execute(select(TrackTag.track_id, TrackTag.tag_id)).all()
    track_to_tags: dict[int, set[int]] = defaultdict(set)
    for track_id, tag_id in track_tag_rows:
        track_to_tags[track_id].add(tag_id)

    like_count_rows = db.execute(
        select(UserTrackPreference.track_id, func.count(UserTrackPreference.id))
        .where(UserTrackPreference.preference_type == "like")
        .group_by(UserTrackPreference.track_id)
    ).all()
    like_count_map = {track_id: int(cnt) for track_id, cnt in like_count_rows}
    max_like_count = max(like_count_map.values()) if like_count_map else 0

    all_tracks = db.execute(select(Track).order_by(Track.created_at.desc())).scalars().all()
    ranked: list[dict] = []
    for track in all_tracks:
        if track.id in skipped_track_ids or track.id in liked_track_id_set:
            continue

        tags = track_to_tags.get(track.id, set())
        if liked_tag_ids:
            tag_match_score = len(tags & liked_tag_ids) / len(liked_tag_ids)
        else:
            tag_match_score = 0.0

        access_score = (like_count_map.get(track.id, 0) / max_like_count) if max_like_count else 0.0
        recommendation_score = tag_match_score * 0.8 + access_score * 0.2

        ranked.append(
            {
                "track": track,
                "recommendation_score": round(recommendation_score, 4),
                "tag_match_score": round(tag_match_score, 4),
                "access_score": round(access_score, 4),
            }
        )

    ranked.sort(
        key=lambda x: (
            x["recommendation_score"],
            x["tag_match_score"],
            x["access_score"],
            x["track"].created_at,
        ),
        reverse=True,
    )

    total = len(ranked)
    start = (page - 1) * per_page
    end = start + per_page
    paginated = ranked[start:end]

    tracks = [r["track"] for r in paginated]
    track_payloads = serialize_tracks(db, tracks)

    data = []
    for idx, item in enumerate(paginated):
        data.append(
            {
                "track": track_payloads[idx],
                "recommendation_score": item["recommendation_score"],
                "tag_match_score": item["tag_match_score"],
                "access_score": item["access_score"],
            }
        )

    return {"data": data, "meta": {"page": page, "per_page": per_page, "total": total}}
