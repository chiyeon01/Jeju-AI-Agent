# ─────────────────────────────────────────────
# 상권 분석 Agent + 사장님 대시보드 데이터
#
# 매장은 로그인한 계정의 storeId 로 정합니다. 지금 지표가 준비된 매장은 시연 매장
# (st-aewol-0142, 애월 돌담국수) 하나이고, 관리자(ADMIN)는 이 매장을 봅니다.
# 새로 승인된 매장은 지표가 계산되기 전까지 STORE_NOT_READY 를 돌려줍니다.
#
# 질문에 답할 때 매장 지표·리뷰를 프롬프트에 근거로 넣어 GPT가 "근거와 함께" 답하게 하고,
# 숫자는 바꾸지 않고 인용만 하게 해 기획서의 "LLM 사용 원칙"(계산은 도구, 설명은 LLM)을 지킵니다.
# ─────────────────────────────────────────────
from __future__ import annotations

from app import db, events
from app.data.owner_data import (
    INDICATORS,
    OWNER_QA_FALLBACK,
    RECENT_REVIEWS,
    REVIEW_TOPICS,
    SCORE_TREND,
    STORE,
    WEEKLY_REPORT,
)
from app.errors import ApiError
from app.schemas import OwnerActionOut, OwnerActionRequest, OwnerAskOut
from app.services.llm_service import get_llm_service

READY_STORES = {STORE["id"]}

SYSTEM_PROMPT = """너는 제주 상권 분석 Agent야. 아래 제공된 매장 지표·리뷰 데이터만 근거로 답하고,
데이터에 없는 수치는 지어내지 마. 답변에는 반드시 괄호로 근거 데이터 코드(예: D1, D2, 자체)를 포함해.
3~4문장, 한국어 존댓말로 답해."""


# ── 매장 정하기 ───────────────────────────────
def resolve_store(user: dict) -> str:
    store_id = STORE["id"] if user["role"] == "ADMIN" else user.get("store_id")
    if not store_id:
        raise ApiError(404, "STORE_NOT_FOUND", "계정에 연결된 매장이 없어요.")
    if store_id not in READY_STORES:
        raise ApiError(404, "STORE_NOT_READY", "매장 지표를 계산하는 중이에요. 데이터가 모이면 대시보드가 열려요.")
    return store_id


# ── 대시보드 ──────────────────────────────────
def store_info() -> dict:
    return {"id": STORE["id"], "name": STORE["name"], "category": STORE["category"], "dong": STORE["dong"]}


def score() -> dict:
    return {"score": STORE["score"], "delta": STORE["scoreDelta"], "percentile": STORE["percentile"],
            "peers": STORE["peers"], "basis": STORE["basis"]}


def score_trend(weeks: int) -> dict:
    values = SCORE_TREND[-weeks:]
    n = len(values)
    labels = ["이번 주" if i == n - 1 else f"{n - 1 - i}주 전" for i in range(n)]
    return {"values": values, "labels": labels}


def indicators() -> list[dict]:
    return INDICATORS


def weekly_report() -> dict:
    return WEEKLY_REPORT


def review_topics() -> list[dict]:
    return REVIEW_TOPICS


def recent_reviews(limit: int) -> list[dict]:
    return RECENT_REVIEWS[:limit]


# ── 상권 분석 Agent ───────────────────────────
def _context_block() -> str:
    indicators_text = "\n".join(
        f"- {v['name']}: {v['value']}{v['unit']} (전기간 대비 {v['delta']}, 근거 {v['src']}, {v['desc']})"
        for v in INDICATORS
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
        "지금은 예시 질문에만 답할 수 있어요. backend/.env 에 유효한 OPENAI_API_KEY를 넣으면 "
        "상권 분석 Agent가 매장 지표·리뷰를 근거로 자유 질문에 답합니다.",
    )
    return OwnerAskOut(answer=fallback)


def register_action(action: OwnerActionRequest, store_id: str, user: dict) -> OwnerActionOut:
    saved = db.insert_owner_action(action.kind, action.title, store_id, user["id"])
    events.publish(events.STORE, f"{STORE['name'] if store_id == STORE['id'] else store_id} · "
                                 f"{action.kind} \"{action.title}\"", user_id=user["id"])
    return OwnerActionOut(**saved)
