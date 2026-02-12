from fastapi import APIRouter

from app.api.v1.endpoints.billing import router as billing_router
from app.api.v1.endpoints.interactions import router as interactions_router
from app.api.v1.endpoints.rankings import router as rankings_router
from app.api.v1.endpoints.recommendations import router as recommendations_router
from app.api.v1.endpoints.search import router as search_router
from app.api.v1.endpoints.system import router as system_router
from app.api.v1.endpoints.tags import router as tags_router
from app.api.v1.endpoints.tracks import router as tracks_router


api_v1_router = APIRouter()
api_v1_router.include_router(system_router, tags=["system"])
api_v1_router.include_router(billing_router, tags=["billing"])
api_v1_router.include_router(tracks_router, tags=["tracks"])
api_v1_router.include_router(tags_router, tags=["tags"])
api_v1_router.include_router(search_router, tags=["search"])
api_v1_router.include_router(interactions_router, tags=["interactions"])
api_v1_router.include_router(recommendations_router, tags=["recommendations"])
api_v1_router.include_router(rankings_router, tags=["rankings"])
