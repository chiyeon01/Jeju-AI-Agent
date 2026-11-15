# ─────────────────────────────────────────────
# GPT(OpenAI) 호출 래퍼
#
# - OPENAI_API_KEY 가 backend/.env 에 없으면 is_enabled=False → 호출하는 쪽에서
#   규칙 기반(fallback) 응답을 쓰도록 합니다. 서버가 키 없이도 항상 켜져 있어야 하므로
#   여기서 예외를 던지지 않고 (ok=False, error) 형태로 결과를 돌려줍니다.
# - 숫자 계산(점수·지표)은 이 모듈을 쓰지 않습니다. 기획서 "LLM 사용 원칙": LLM은
#   계획·설명 생성에만 사용 → 코스 점수·상권 지표는 course_service/owner_data 에서
#   순수 Python으로 계산합니다.
# ─────────────────────────────────────────────
from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from typing import Any

from openai import APIError, APITimeoutError, OpenAI

from app.config import get_settings

logger = logging.getLogger("jejuitda.llm")


@dataclass
class LLMResult:
    ok: bool
    text: str = ""
    data: dict[str, Any] | None = None
    error: str | None = None


class LLMService:
    def __init__(self) -> None:
        settings = get_settings()
        self._settings = settings
        self._client: OpenAI | None = (
            OpenAI(api_key=settings.openai_api_key, timeout=settings.openai_timeout_seconds)
            if settings.has_openai_key
            else None
        )

    @property
    def is_enabled(self) -> bool:
        return self._client is not None

    def chat(
        self,
        system_prompt: str,
        user_prompt: str,
        *,
        json_mode: bool = False,
        temperature: float = 0.4,
    ) -> LLMResult:
        """GPT Chat Completion 호출. json_mode=True 면 JSON 객체 문자열을 돌려줍니다."""
        if not self._client:
            return LLMResult(ok=False, error="OPENAI_API_KEY가 설정되지 않았습니다 (backend/.env 확인)")
        try:
            kwargs: dict[str, Any] = {
                "model": self._settings.openai_model,
                "temperature": temperature,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
            }
            if json_mode:
                kwargs["response_format"] = {"type": "json_object"}
            resp = self._client.chat.completions.create(**kwargs)
            content = (resp.choices[0].message.content or "").strip()
            if json_mode:
                try:
                    return LLMResult(ok=True, text=content, data=json.loads(content))
                except json.JSONDecodeError as e:
                    return LLMResult(ok=False, error=f"GPT가 JSON이 아닌 응답을 줬어요: {e}")
            return LLMResult(ok=True, text=content)
        except APITimeoutError:
            logger.warning("OpenAI 요청 타임아웃")
            return LLMResult(ok=False, error="GPT 응답 시간이 초과됐어요")
        except APIError as e:
            logger.warning("OpenAI API 오류: %s", e)
            return LLMResult(ok=False, error=f"GPT 호출 중 오류: {e}")
        except Exception as e:  # noqa: BLE001 - 외부 API 호출이라 폭넓게 방어
            logger.exception("OpenAI 호출 중 예상치 못한 오류")
            return LLMResult(ok=False, error=f"GPT 호출 중 알 수 없는 오류: {e}")


_llm_service: LLMService | None = None


def get_llm_service() -> LLMService:
    global _llm_service
    if _llm_service is None:
        _llm_service = LLMService()
    return _llm_service
