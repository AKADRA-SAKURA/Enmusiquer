from sqlalchemy import ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.types import DBInt
from app.models.mixins import TimestampMixin


class Bookmark(TimestampMixin, Base):
    __tablename__ = "bookmarks"
    __table_args__ = (UniqueConstraint("user_id", "track_id", name="uq_bookmarks_user_track"),)

    id: Mapped[int] = mapped_column(DBInt, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        DBInt,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    track_id: Mapped[int] = mapped_column(
        DBInt,
        ForeignKey("tracks.id", ondelete="CASCADE"),
        nullable=False,
    )
