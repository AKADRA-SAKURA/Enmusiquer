def test_rankings_weekly_excludes_old_likes(client) -> None:
    res = client.get("/v1/rankings?period=weekly&limit=10")
    assert res.status_code == 200
    data = res.json()["data"]
    assert len(data) >= 1
    assert data[0]["track"]["id"] == 101


def test_rankings_monthly_excludes_40_days_old_like(client) -> None:
    res = client.get("/v1/rankings?period=monthly&limit=10")
    assert res.status_code == 200
    ids = [item["track"]["id"] for item in res.json()["data"]]
    assert 101 in ids
    assert 102 not in ids
