from collections import defaultdict
from typing import Any

from sqlalchemy import Select, select
from sqlalchemy.orm import Session

from app.models.tag import Tag
from app.models.track import Track
from app.models.track_tag import TrackTag


def _tags_map(db: Session, track_ids: list[int]) -> dict[int, list[dict[str, Any]]]:
    if not track_ids:
        return {}

    stmt: Select = (
        select(TrackTag.track_id, Tag.id, Tag.name)
        .join(Tag, Tag.id == TrackTag.tag_id)
        .where(TrackTag.track_id.in_(track_ids))
    )
    rows = db.execute(stmt).all()

    result: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for track_id, tag_id, tag_name in rows:
        result[track_id].append({"id": tag_id, "name": tag_name})
    return result


def serialize_track(track: Track, tags: list[dict[str, Any]] | None = None) -> dict[str, Any]:
    return {
        "id": track.id,
        "title": track.title,
        "artist_display_name": track.artist_display_name,
        "source_url": track.source_url,
        "source_type": track.source_type,
        "source_track_id": track.source_track_id,
        "thumbnail_url": track.thumbnail_url,
        "writer": track.writer,
        "composer": track.composer,
        "year": track.year,
        "record_info": track.record_info,
        "usage_context": track.usage_context,
        "series_name": track.series_name,
        "album_artist_name": track.album_artist_name,
        "tags": tags or [],
        "created_by": track.created_by,
        "created_at": track.created_at,
        "updated_at": track.updated_at,
    }


def serialize_tracks(db: Session, tracks: list[Track]) -> list[dict[str, Any]]:
    ids = [t.id for t in tracks]
    tags_map = _tags_map(db, ids)
    return [serialize_track(t, tags=tags_map.get(t.id, [])) for t in tracks]
