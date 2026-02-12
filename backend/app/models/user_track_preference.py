from sqlalchemy import Enum, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.types import DBInt
from app.models.mixins import TimestampMixin


preference_type_enum = Enum("like", "skip", name="preference_type", create_constraint=True)


class UserTrackPreference(TimestampMixin, Base):
    __tablename__ = "user_track_preferences"
    __table_args__ = (
        UniqueConstraint("user_id", "track_id", name="uq_user_track_preferences_user_track"),
    )

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
    preference_type: Mapped[str] = mapped_column(preference_type_enum, nullable=False)
