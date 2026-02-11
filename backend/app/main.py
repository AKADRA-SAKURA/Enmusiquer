from fastapi import HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi import FastAPI
from fastapi.responses import JSONResponse

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


def _default_error_code(status_code: int) -> str:
    mapping = {
        400: "validation_error",
        401: "unauthorized",
        403: "forbidden",
        404: "not_found",
        409: "duplicate_resource",
        422: "validation_error",
        429: "rate_limited",
        500: "internal_error",
    }
    return mapping.get(status_code, "internal_error")


@app.exception_handler(HTTPException)
async def http_exception_handler(_: Request, exc: HTTPException) -> JSONResponse:
    detail = exc.detail
    if isinstance(detail, dict):
        code = detail.get("code", _default_error_code(exc.status_code))
        message = detail.get("message", "request failed")
    else:
        code = _default_error_code(exc.status_code)
        message = str(detail)

    return JSONResponse(
        status_code=exc.status_code,
        content={"error": {"code": code, "message": message}},
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(_: Request, exc: RequestValidationError) -> JSONResponse:
    return JSONResponse(
        status_code=422,
        content={
            "error": {
                "code": "validation_error",
                "message": "request validation failed",
                "details": exc.errors(),
            }
        },
    )
