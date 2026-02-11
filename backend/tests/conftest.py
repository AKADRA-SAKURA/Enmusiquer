from collections.abc import Generator
from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.db.base import Base
from app.db.session import get_db
from app.main import app
from app.core.config import settings
from app.models.tag import Tag
from app.models.track import Track
from app.models.track_tag import TrackTag
from app.models.user import User
from app.models.user_track_preference import UserTrackPreference
from app.services.url_normalizer import normalize_source_url


@pytest.fixture(scope="session")
def engine():
    engine_ = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    return engine_


@pytest.fixture()
def db_session(engine) -> Generator[Session, None, None]:
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)

    SessionTesting = sessionmaker(bind=engine, autoflush=False, autocommit=False)
    session = SessionTesting()
    try:
        _seed_for_tests(session)
        yield session
    finally:
        session.close()


@pytest.fixture()
def client(db_session: Session) -> Generator[TestClient, None, None]:
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture(autouse=True)
def admin_token_for_tests() -> Generator[None, None, None]:
    previous = settings.admin_api_token
    settings.admin_api_token = "test-admin-token"
    try:
        yield
    finally:
        settings.admin_api_token = previous


def _seed_for_tests(session: Session) -> None:
    now = datetime.now(timezone.utc)
    user1 = User(id=1, email="u1@example.com", display_name="user1")
    user2 = User(id=2, email="u2@example.com", display_name="user2")
    session.add_all([user1, user2])

    tag1 = Tag(id=1, name="クール")
    tag2 = Tag(id=2, name="夜に聴きたい")
    session.add_all([tag1, tag2])

    track1 = Track(
        id=101,
        title="Song A",
        artist_display_name="Artist A",
        source_url=normalize_source_url("https://www.youtube.com/watch?v=test01"),
        source_type="youtube",
        created_by=1,
    )
    track2 = Track(
        id=102,
        title="Song B",
        artist_display_name="Artist B",
        source_url=normalize_source_url("https://www.youtube.com/watch?v=test02"),
        source_type="youtube",
        created_by=1,
    )
    session.add_all([track1, track2])

    session.add_all(
        [
            TrackTag(id=1001, track_id=101, tag_id=1),
            TrackTag(id=1002, track_id=101, tag_id=2),
            TrackTag(id=1003, track_id=102, tag_id=1),
        ]
    )
    session.add_all(
        [
            UserTrackPreference(
                id=2001,
                user_id=1,
                track_id=101,
                preference_type="like",
                created_at=now - timedelta(hours=2),
                updated_at=now - timedelta(hours=2),
            ),
            UserTrackPreference(
                id=2002,
                user_id=2,
                track_id=102,
                preference_type="like",
                created_at=now - timedelta(days=40),
                updated_at=now - timedelta(days=40),
            ),
        ]
    )
    session.commit()
