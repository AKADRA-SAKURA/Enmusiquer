from datetime import datetime, timedelta, timezone


def test_get_billing_status_default(client) -> None:
    res = client.get("/v1/system/billing-status")
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["billing_enabled"] is False
    assert data["can_charge_now"] is False


def test_patch_billing_settings_requires_admin_token(client) -> None:
    res = client.patch(
        "/v1/admin/billing-settings",
        json={"billing_enabled": True, "changed_by": "akadra"},
    )
    assert res.status_code == 403
    assert res.json()["error"]["code"] == "forbidden"


def test_patch_billing_settings_with_admin_token(client) -> None:
    effective_at = (datetime.now(timezone.utc) + timedelta(days=1)).isoformat()
    res = client.patch(
        "/v1/admin/billing-settings",
        headers={"X-Admin-Token": "test-admin-token"},
        json={
            "billing_enabled": True,
            "effective_at": effective_at,
            "changed_by": "akadra",
            "change_reason": "release prep",
        },
    )
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["billing_enabled"] is True

    status_res = client.get("/v1/system/billing-status")
    assert status_res.status_code == 200
    assert status_res.json()["data"]["can_charge_now"] is False
