from sqlalchemy import ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.types import DBInt
from app.models.mixins import TimestampMixin


class Track(TimestampMixin, Base):
    __tablename__ = "tracks"

    id: Mapped[int] = mapped_column(DBInt, primary_key=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    artist_display_name: Mapped[str] = mapped_column(String(255), nullable=False)
    source_url: Mapped[str] = mapped_column(String(2048), unique=True, nullable=False)
    source_type: Mapped[str] = mapped_column(String(50), nullable=False)
    source_track_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    thumbnail_url: Mapped[str | None] = mapped_column(String(2048), nullable=True)

    writer: Mapped[str | None] = mapped_column(String(255), nullable=True)
    composer: Mapped[str | None] = mapped_column(String(255), nullable=True)
    year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    record_info: Mapped[str | None] = mapped_column(Text, nullable=True)
    usage_context: Mapped[str | None] = mapped_column(Text, nullable=True)
    series_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    album_artist_name: Mapped[str | None] = mapped_column(String(255), nullable=True)

    created_by: Mapped[int] = mapped_column(
        DBInt,
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
    )
