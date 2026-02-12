AUTH = {"Authorization": "Bearer dev-user-1"}


def test_recommendations_returns_scored_items(client) -> None:
    res = client.get("/v1/recommendations", headers=AUTH)
    assert res.status_code == 200
    body = res.json()
    assert "data" in body
    assert "meta" in body
    if body["data"]:
        item = body["data"][0]
        assert "recommendation_score" in item
        assert "tag_match_score" in item
        assert "access_score" in item
