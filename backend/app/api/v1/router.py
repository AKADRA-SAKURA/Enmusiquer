from fastapi import APIRouter

from app.api.v1.endpoints.billing import router as billing_router
from app.api.v1.endpoints.system import router as system_router


api_v1_router = APIRouter()
api_v1_router.include_router(system_router, tags=["system"])
api_v1_router.include_router(billing_router, tags=["billing"])
