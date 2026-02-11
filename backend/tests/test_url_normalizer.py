from app.services.url_normalizer import normalize_source_url


def test_normalize_source_url_removes_tracking_params() -> None:
    url = "https://www.youtube.com/watch?v=abc123&utm_source=x&utm_campaign=y"
    normalized = normalize_source_url(url)
    assert normalized == "https://www.youtube.com/watch?v=abc123"


def test_normalize_source_url_sorts_query() -> None:
    url = "https://example.com/path?b=2&a=1"
    normalized = normalize_source_url(url)
    assert normalized == "https://example.com/path?a=1&b=2"
