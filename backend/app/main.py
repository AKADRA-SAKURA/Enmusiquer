from fastapi import FastAPI

from app.api.v1.router import api_v1_router
from app.core.config import settings


app = FastAPI(
    title="Enmusiquer API",
    version="0.1.0",
    docs_url="/docs" if settings.enable_docs else None,
    redoc_url="/redoc" if settings.enable_docs else None,
)

app.include_router(api_v1_router, prefix="/v1")


@app.get("/health", tags=["health"])
def health() -> dict[str, str]:
    return {"status": "ok"}
