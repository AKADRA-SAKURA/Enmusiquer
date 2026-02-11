AUTH = {"Authorization": "Bearer dev-user-1"}


def test_preference_upsert_like_to_skip(client) -> None:
    res1 = client.post(
        "/v1/tracks/102/preference",
        json={"preference_type": "like"},
        headers=AUTH,
    )
    assert res1.status_code == 200
    assert res1.json()["data"]["preference_type"] == "like"

    res2 = client.post(
        "/v1/tracks/102/preference",
        json={"preference_type": "skip"},
        headers=AUTH,
    )
    assert res2.status_code == 200
    assert res2.json()["data"]["preference_type"] == "skip"


def test_bookmark_idempotent(client) -> None:
    res1 = client.post("/v1/tracks/102/bookmark", headers=AUTH)
    res2 = client.post("/v1/tracks/102/bookmark", headers=AUTH)

    assert res1.status_code == 200
    assert res2.status_code == 200
    assert res2.json()["data"]["bookmarked"] is True
