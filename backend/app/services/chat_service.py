# ─────────────────────────────────────────────
# 코스 플래너 Agent와의 대화형 수정
# GPT에게 "자유 문장 → (의도 패치 + 한국어 답변)" 을 JSON으로 받고,
# GPT가 꺼져 있거나 실패하면 프론트 목업과 같은 규칙 기반(정규식) 응답으로 대체합니다.
# ─────────────────────────────────────────────
from __future__ import annotations

import re

from app.schemas import ChatOut, ChatPatch
from app.services.llm_service import get_llm_service

SYSTEM_PROMPT = """너는 제주 여행 코스 플래너 Agent야. 사용자가 코스를 바꿔달라고 요청하면
아래 JSON 형식으로만 답해.
{"reply": "<사용자에게 보여줄 한국어 답변, 1~2문장>",
 "patch": {"seafood": true|false|null, "removeCount": <오늘 요청으로 추가로 줄일 장소 수, 정수, 기본 0>, "weather": "clear"|"rain"|null}}
규칙:
- "해산물/회/바다 음식"으로 바꿔달라고 하면 seafood=true
- "줄여줘/빼줘/하나 빼줘" 류는 removeCount를 요청한 수만큼(기본 1)
- "비/실내"로 바꿔달라고 하면 weather="rain"
- 해당 없는 값은 null 또는 생략
- 바꿀 게 없으면 patch는 {"seafood": null, "removeCount": 0, "weather": null}로 두고, reply에 어떤 말을 알아듣는지 안내해."""


def _rule_based(message: str) -> ChatOut:
    if re.search(r"해산물|회|바다 ?음식", message):
        return ChatOut(reply="저녁을 해산물 식당으로 바꿨어요. 최근 외식업 메뉴 매출에서 해산물 비중이 높은 곳 위주로 골랐어요.",
                        patch=ChatPatch(seafood=True))
    if re.search(r"줄여|빼|하나 ?빼|1곳", message):
        return ChatOut(reply="마지막 장소 하나를 뺐어요. 이동 시간이 줄어 여유가 생겼어요.",
                        patch=ChatPatch(removeCount=1))
    if re.search(r"비|실내", message):
        return ChatOut(reply="실내 위주 코스로 바꿨어요.", patch=ChatPatch(weather="rain"))
    return ChatOut(
        reply='시연 화면에서는 "저녁은 해산물로 바꿔줘", "1곳 줄여줘", "실내로 바꿔줘"를 알아들어요. GPT API 키를 연결하면 더 자유로운 요청도 이해해요.',
        patch=None,
    )


def chat_course(message: str) -> ChatOut:
    llm = get_llm_service()
    if not llm.is_enabled:
        return _rule_based(message)

    result = llm.chat(SYSTEM_PROMPT, message, json_mode=True, temperature=0.3)
    if not result.ok or not result.data:
        return _rule_based(message)

    data = result.data
    reply = str(data.get("reply") or "").strip()
    if not reply:
        return _rule_based(message)
    patch = _parse_patch(data.get("patch"))
    return ChatOut(reply=reply, patch=patch)


def _parse_patch(raw) -> ChatPatch | None:
    """GPT가 준 patch를 검증된 ChatPatch로 변환. 이상한 값은 버리고, 바뀌는 게 없으면 None."""
    if not isinstance(raw, dict):
        return None
    seafood = raw.get("seafood")
    seafood = seafood if isinstance(seafood, bool) else None
    weather = raw.get("weather")
    weather = weather if weather in ("clear", "rain") else None
    try:
        remove = int(raw.get("removeCount") or 0)
    except (TypeError, ValueError):
        remove = 0
    remove = max(0, min(remove, 3))
    if seafood is None and weather is None and remove == 0:
        return None
    return ChatPatch(seafood=seafood, removeCount=remove or None, weather=weather)
