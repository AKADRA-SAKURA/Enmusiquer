from fastapi import APIRouter

from app.api.v1.schemas import MessageResponse


router = APIRouter()


@router.get("/system/ping", response_model=MessageResponse)
def ping() -> MessageResponse:
    return MessageResponse(message="pong")
