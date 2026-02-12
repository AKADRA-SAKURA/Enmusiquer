def test_search_tracks_by_keyword(client) -> None:
    res = client.get("/v1/search/tracks?q=Song")
    assert res.status_code == 200
    body = res.json()
    assert body["meta"]["total"] >= 2


def test_search_tracks_by_tags_and_condition(client) -> None:
    res = client.post("/v1/search/tracks/by-tags", json={"tag_ids": [1, 2], "page": 1, "per_page": 20})
    assert res.status_code == 200
    data = res.json()["data"]
    ids = [x["id"] for x in data]
    assert ids == [101]


def test_search_tracks_by_tags_requires_tag_ids(client) -> None:
    res = client.post("/v1/search/tracks/by-tags", json={"tag_ids": []})
    assert res.status_code == 400
    assert res.json()["error"]["code"] == "validation_error"
