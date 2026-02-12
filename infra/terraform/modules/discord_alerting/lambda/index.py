import json
import os
import urllib.error
import urllib.request


def _send_to_discord(webhook_url: str, content: str) -> None:
    payload = json.dumps({"content": content}).encode("utf-8")
    req = urllib.request.Request(
        webhook_url,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    with urllib.request.urlopen(req, timeout=10) as resp:
        if resp.status < 200 or resp.status >= 300:
            raise RuntimeError(f"Discord webhook returned non-2xx status: {resp.status}")


def handler(event, _context):
    webhook_url = os.environ.get("DISCORD_WEBHOOK_URL")
    if not webhook_url:
        raise RuntimeError("DISCORD_WEBHOOK_URL is not configured")

    records = event.get("Records", [])
    if not records:
        return {"status": "no_records"}

    for record in records:
        sns = record.get("Sns", {})
        subject = sns.get("Subject") or "CloudWatch Alarm"
        message = sns.get("Message") or ""
        content = f"**{subject}**\n{message}"
        _send_to_discord(webhook_url, content)

    return {"status": "ok", "count": len(records)}
