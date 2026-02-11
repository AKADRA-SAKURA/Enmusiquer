from fastapi import Header, HTTPException, status


def get_current_user_id(authorization: str | None = Header(default=None)) -> int:
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "unauthorized", "message": "Authorization header is required"},
        )

    prefix = "Bearer "
    if not authorization.startswith(prefix):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "unauthorized", "message": "Bearer token is required"},
        )

    token = authorization[len(prefix) :].strip()
    # MVP local rule: Bearer dev-user-<id>
    if token.startswith("dev-user-"):
        id_part = token.replace("dev-user-", "", 1)
        if id_part.isdigit():
            return int(id_part)

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail={"code": "unauthorized", "message": "Invalid access token"},
    )
