# ─────────────────────────────────────────────
# 오류 응답 형식 통일: { "error": { "code": "...", "message": "..." } }
# 프론트(React·Flutter)의 client 가 error.code / error.message 를 읽습니다.
# ─────────────────────────────────────────────
from __future__ import annotations

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

_DEFAULT_CODES = {
    400: "BAD_REQUEST", 401: "UNAUTHORIZED", 403: "FORBIDDEN", 404: "NOT_FOUND", 409: "CONFLICT",
    422: "VALIDATION_ERROR", 429: "TOO_MANY_REQUESTS", 500: "INTERNAL_ERROR", 502: "UPSTREAM_ERROR",
    503: "UNAVAILABLE",
}


class ApiError(HTTPException):
    """raise ApiError(409, "EMAIL_TAKEN", "이미 가입된 이메일이에요.")"""

    def __init__(self, status: int, code: str, message: str) -> None:
        super().__init__(status_code=status, detail={"code": code, "message": message})


def _body(status: int, detail) -> dict:
    if isinstance(detail, dict) and "code" in detail:
        return {"error": {"code": detail["code"], "message": detail.get("message", "")}}
    return {"error": {"code": _DEFAULT_CODES.get(status, "HTTP_ERROR"), "message": str(detail)}}


def install_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(StarletteHTTPException)
    async def http_error(_: Request, exc: StarletteHTTPException):
        return JSONResponse(_body(exc.status_code, exc.detail), status_code=exc.status_code,
                            headers=getattr(exc, "headers", None))

    @app.exception_handler(RequestValidationError)
    async def validation_error(_: Request, exc: RequestValidationError):
        first = exc.errors()[0] if exc.errors() else {}
        where = ".".join(str(x) for x in first.get("loc", []) if x != "body")
        msg = f"입력값을 확인해 주세요 ({where}: {first.get('msg', '')})" if where else "입력값을 확인해 주세요."
        return JSONResponse({"error": {"code": "VALIDATION_ERROR", "message": msg}}, status_code=422)
