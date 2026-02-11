from sqlalchemy import BigInteger, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.mixins import TimestampMixin


class TrackTag(TimestampMixin, Base):
    __tablename__ = "track_tags"
    __table_args__ = (UniqueConstraint("track_id", "tag_id", name="uq_track_tags_track_tag"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    track_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("tracks.id", ondelete="CASCADE"),
        nullable=False,
    )
    tag_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("tags.id", ondelete="CASCADE"),
        nullable=False,
    )
