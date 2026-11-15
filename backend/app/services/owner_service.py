# ─────────────────────────────────────────────
# 상권 분석 Agent
# 질문에 답할 때 매장 지표·리뷰 데이터를 프롬프트에 근거로 넣어(RAG 방식) GPT가
# "근거 데이터와 함께" 답하도록 합니다. 숫자 자체는 바꾸지 않고 그대로 인용하게 해
# 기획서의 "LLM 사용 원칙"(계산은 도구, 설명은 LLM)을 지킵니다.
# ─────────────────────────────────────────────
from __future__ import annotations

from app import db
from app.data.owner_data import (
    INDICATORS,
    OWNER_QA_FALLBACK,
    RECENT_REVIEWS,
    REVIEW_TOPICS,
    STORE,
    WEEKLY_REPORT,
)
from app.schemas import OwnerActionRequest, OwnerAskOut
from app.services.llm_service import get_llm_service

SYSTEM_PROMPT = """너는 제주 상권 분석 Agent야. 아래 제공된 매장 지표·리뷰 데이터만 근거로 답하고,
데이터에 없는 수치는 지어내지 마. 답변에는 반드시 괄호로 근거 데이터 코드(예: D1, D2, 자체)를 포함해.
3~4문장, 한국어 존댓말로 답해."""


def _context_block() -> str:
    indicators_text = "\n".join(
        f"- {v['name']}: {v['value']}{v['unit']} (전기간 대비 {v['delta']}, 근거 {v['src']}, {v['desc']})"
        for v in INDICATORS.values()
    )
    reviews_text = "\n".join(f"- {r['stars']}점: {r['text']} ({r['type']})" for r in RECENT_REVIEWS)
    topics_text = ", ".join(f"{t['topic']} 긍정 {t['pos']}% ({t['mentions']}건)" for t in REVIEW_TOPICS)
    return (
        f"[매장] {STORE['name']} · {STORE['category']} · {STORE['dong']} · 종합점수 {STORE['score']} "
        f"(백분위 {STORE['percentile']}, 동일업종 {STORE['peers']}곳 중)\n"
        f"[지표]\n{indicators_text}\n"
        f"[리뷰 주제별 긍정률] {topics_text}\n"
        f"[최근 리뷰]\n{reviews_text}\n"
        f"[주간 리포트] {WEEKLY_REPORT['summary']}"
    )


def ask_owner_agent(question: str) -> OwnerAskOut:
    llm = get_llm_service()
    if llm.is_enabled:
        prompt = f"{_context_block()}\n\n[사장님 질문] {question}"
        result = llm.chat(SYSTEM_PROMPT, prompt, temperature=0.4)
        if result.ok and result.text:
            return OwnerAskOut(answer=result.text)

    fallback = OWNER_QA_FALLBACK.get(
        question,
        "시연 화면에서는 아래 예시 질문에 답해요. backend/.env 에 OPENAI_API_KEY를 넣으면 "
        "상권 분석 Agent가 매장 지표·리뷰를 근거로 자유 질문에 답합니다.",
    )
    return OwnerAskOut(answer=fallback)


def register_action(action: OwnerActionRequest) -> int:
    return db.insert_owner_action(action.kind, action.title)
