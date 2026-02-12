def normalize_pagination(page: int, per_page: int) -> tuple[int, int]:
    p = page if page > 0 else 1
    pp = per_page if per_page > 0 else 20
    pp = min(pp, 50)
    return p, pp
