from urllib.parse import parse_qsl, urlencode, urlparse, urlunparse


TRACKING_QUERY_KEYS = {
    "utm_source",
    "utm_medium",
    "utm_campaign",
    "utm_term",
    "utm_content",
    "fbclid",
    "gclid",
}


def normalize_source_url(raw_url: str) -> str:
    text = raw_url.strip()
    parsed = urlparse(text)

    if not parsed.netloc:
        raise ValueError("invalid URL")

    scheme = (parsed.scheme or "https").lower()
    netloc = parsed.netloc.lower()
    path = parsed.path.rstrip("/")

    query_items = [
        (k, v)
        for k, v in parse_qsl(parsed.query, keep_blank_values=True)
        if k.lower() not in TRACKING_QUERY_KEYS
    ]
    query_items.sort(key=lambda x: x[0])
    query = urlencode(query_items, doseq=True)

    normalized = urlunparse((scheme, netloc, path, "", query, ""))
    return normalized
