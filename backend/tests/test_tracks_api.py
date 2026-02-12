AUTH = {"Authorization": "Bearer dev-user-1"}


def test_list_tracks(client) -> None:
    res = client.get("/v1/tracks")
    assert res.status_code == 200
    body = res.json()
    assert "data" in body
    assert body["meta"]["total"] >= 2


def test_get_track(client) -> None:
    res = client.get("/v1/tracks/101")
    assert res.status_code == 200
    assert res.json()["data"]["id"] == 101


def test_create_track_duplicate_url_returns_409(client) -> None:
    payload = {
        "source_url": "https://www.youtube.com/watch?v=test01&utm_source=dup",
        "title": "Duplicated",
        "artist_display_name": "Artist",
        "source_type": "youtube",
        "tag_ids": [1],
    }
    res = client.post("/v1/tracks", json=payload, headers=AUTH)
    assert res.status_code == 409
    assert res.json()["error"]["code"] == "duplicate_track_source_url"
