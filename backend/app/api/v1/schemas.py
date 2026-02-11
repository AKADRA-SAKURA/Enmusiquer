from datetime import datetime
from typing import Literal

from pydantic import BaseModel


class MessageResponse(BaseModel):
    message: str


class TagOut(BaseModel):
    id: int
    name: str


class TrackOut(BaseModel):
    id: int
    title: str
    artist_display_name: str
    source_url: str
    source_type: Literal["youtube", "spotify", "apple_music", "soundcloud", "other"]
    source_track_id: str | None = None
    thumbnail_url: str | None = None
    writer: str | None = None
    composer: str | None = None
    year: int | None = None
    record_info: str | None = None
    usage_context: str | None = None
    series_name: str | None = None
    album_artist_name: str | None = None
    tags: list[TagOut]
    created_by: int
    created_at: datetime
    updated_at: datetime


class PageMeta(BaseModel):
    page: int
    per_page: int
    total: int


class LimitMeta(BaseModel):
    period: Literal["daily", "weekly", "monthly"]
    limit: int


class TracksListResponse(BaseModel):
    data: list[TrackOut]
    meta: PageMeta


class TrackResponse(BaseModel):
    data: TrackOut


class TagsListResponse(BaseModel):
    data: list[TagOut]
    meta: PageMeta


class PreferenceData(BaseModel):
    track_id: int
    preference_type: Literal["like", "skip"]


class PreferenceResponse(BaseModel):
    data: PreferenceData


class BookmarkData(BaseModel):
    track_id: int
    bookmarked: bool


class BookmarkResponse(BaseModel):
    data: BookmarkData


class RecommendationItem(BaseModel):
    track: TrackOut
    recommendation_score: float
    tag_match_score: float
    access_score: float


class RecommendationsResponse(BaseModel):
    data: list[RecommendationItem]
    meta: PageMeta


class RankingItem(BaseModel):
    rank: int
    track: TrackOut
    score: int


class RankingsResponse(BaseModel):
    data: list[RankingItem]
    meta: LimitMeta
