from fastapi import APIRouter


router = APIRouter()


@router.get("/system/ping")
def ping() -> dict[str, str]:
    return {"message": "pong"}
