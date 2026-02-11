from sqlalchemy import select

from app.db.session import SessionLocal
from app.models.tag import Tag
from app.models.track import Track
from app.models.track_tag import TrackTag
from app.models.user import User
from app.models.user_track_preference import UserTrackPreference
from app.services.url_normalizer import normalize_source_url


def ensure_user(session) -> User:
    user = session.scalar(select(User).where(User.id == 1))
    if user:
        return user

    user = User(id=1, email="akadra@example.com", display_name="AKADRA")
    session.add(user)
    session.flush()
    return user


def ensure_tags(session) -> list[Tag]:
    names = ["クール", "夜に聴きたい", "重低音"]
    existing = session.scalars(select(Tag).where(Tag.name.in_(names))).all()
    by_name = {t.name: t for t in existing}

    results: list[Tag] = []
    for idx, name in enumerate(names, start=1):
        tag = by_name.get(name)
        if not tag:
            tag = Tag(id=idx, name=name)
            session.add(tag)
            session.flush()
        results.append(tag)
    return results


def ensure_track(session, user_id: int, title: str, artist: str, source_url: str, source_type: str) -> Track:
    normalized = normalize_source_url(source_url)
    track = session.scalar(select(Track).where(Track.source_url == normalized))
    if track:
        return track

    track = Track(
        title=title,
        artist_display_name=artist,
        source_url=normalized,
        source_type=source_type,
        created_by=user_id,
    )
    session.add(track)
    session.flush()
    return track


def ensure_track_tag(session, track_id: int, tag_id: int) -> None:
    row = session.scalar(
        select(TrackTag).where(TrackTag.track_id == track_id, TrackTag.tag_id == tag_id)
    )
    if row:
        return
    session.add(TrackTag(track_id=track_id, tag_id=tag_id))


def ensure_like(session, user_id: int, track_id: int) -> None:
    row = session.scalar(
        select(UserTrackPreference).where(
            UserTrackPreference.user_id == user_id,
            UserTrackPreference.track_id == track_id,
        )
    )
    if row:
        row.preference_type = "like"
        session.add(row)
        return
    session.add(
        UserTrackPreference(user_id=user_id, track_id=track_id, preference_type="like")
    )


def run() -> None:
    session = SessionLocal()
    try:
        user = ensure_user(session)
        tags = ensure_tags(session)

        track1 = ensure_track(
            session,
            user_id=user.id,
            title="カイト",
            artist="嵐",
            source_url="https://www.youtube.com/watch?v=EtcSample001&utm_source=test",
            source_type="youtube",
        )
        track2 = ensure_track(
            session,
            user_id=user.id,
            title="ORICross",
            artist="AKADRA",
            source_url="https://soundcloud.com/akadra7800/oricross",
            source_type="soundcloud",
        )

        ensure_track_tag(session, track1.id, tags[0].id)
        ensure_track_tag(session, track1.id, tags[1].id)
        ensure_track_tag(session, track2.id, tags[0].id)
        ensure_track_tag(session, track2.id, tags[2].id)

        ensure_like(session, user.id, track1.id)
        ensure_like(session, user.id, track2.id)

        session.commit()
        print("seed completed")
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


if __name__ == "__main__":
    run()
