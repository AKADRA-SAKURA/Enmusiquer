from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.types import DBInt
from app.models.mixins import TimestampMixin


class Tag(TimestampMixin, Base):
    __tablename__ = "tags"

    id: Mapped[int] = mapped_column(DBInt, primary_key=True)
    name: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
