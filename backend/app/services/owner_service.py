# ─────────────────────────────────────────────
# 상권 주인 대시보드 + 상권 분석 Agent
#
# 모든 값은 사장님이 연결한 "내 가게"(관광객 코스에 나오는 장소)에 관광객이 앱에서 실제로 남긴
# 별점·리뷰에서만 만듭니다. 시연용 고정 지표(예전 owner_data)는 쓰지 않습니다.
#  - 리뷰 주제별 반응 : GPT 가 prompts/review_topics.md 프롬프트로 리뷰를 읽고 주제별 긍정률을 JSON 으로 정리
#                       (GPT 키가 없거나 실패하면 키워드 규칙으로 대신 계산, source 로 구분)
#  - AI에게 물어보기  : 내 가게 별점·리뷰·주제 분석을 근거로 GPT 가 답변
# ─────────────────────────────────────────────
from __future__ import annotations

import json
import logging
import re
import threading
from pathlib import Path

from app import db, events
from app.data.tourist_data import KIND_LABEL, PLACES_BY_ID, REGIONS_BY_ID
from app.errors import ApiError
from app.schemas import OwnerActionOut, OwnerActionRequest, OwnerAskOut
from app.services.insight_service import linked_place
from app.services.llm_service import get_llm_service

logger = logging.getLogger("jejuitda.owner")

PROMPT_DIR = Path(__file__).resolve().parent.parent / "prompts"
STORE_KIND_LABEL = {"food": "식당", "cafe": "카페", "indoor": "실내 체험"}

ASK_SYSTEM_PROMPT = """너는 제주 상권 분석 Agent야. 아래 제공된 내 가게의 관광객 별점·리뷰·주제 분석만 근거로 답하고,
데이터에 없는 수치는 지어내지 마. 리뷰가 적으면 그렇다고 말해. 3~4문장, 한국어 존댓말로 답해."""


def _prompt(name: str) -> str:
    return (PROMPT_DIR / name).read_text(encoding="utf-8")


# ── 내 가게 정하기 ─────────────────────────────
def resolve_place(user: dict) -> str:
    pid = linked_place(user["id"])
    if not pid:
        raise ApiError(404, "PLACE_NOT_LINKED", "내 가게와 연결된 장소가 없어요. 먼저 가게를 선택해 주세요.")
    return pid


def store_info(place_id: str) -> dict:
    p = PLACES_BY_ID[place_id]
    region = REGIONS_BY_ID.get(p["region"])
    return {"id": p["id"], "no": db.place_no(p["id"]), "name": p["name"], "region": p["region"],
            "regionName": region["name"] if region else p["region"], "kind": p["kind"],
            "category": STORE_KIND_LABEL.get(p["kind"]) or KIND_LABEL.get(p["kind"], p["kind"])}


def recent_reviews(place_id: str, limit: int) -> list[dict]:
    return [{"id": r["id"], "stars": r["stars"], "text": r["text"], "profile": r["profile_code"], "createdAt": r["created_at"]}
            for r in db.reviews_for_place(place_id, limit)]


# ── 리뷰 주제별 반응 (GPT) ──────────────────────
# 같은 리뷰 묶음이면 다시 부르지 않도록 (장소, 리뷰 수, 마지막 리뷰 id) 로 캐시합니다
_topic_cache: dict[str, tuple[tuple, dict]] = {}
_topic_lock = threading.Lock()

_RULE_TOPICS = [
    ("맛", re.compile(r"맛|음식|국물|커피|디저트|빵|메뉴|간이|짜|싱겁|느끼")),
    ("친절·서비스", re.compile(r"친절|불친절|서비스|직원|사장|응대")),
    ("가격", re.compile(r"가격|비싸|저렴|싸|가성비")),
    ("분위기·뷰", re.compile(r"분위기|뷰|바다|인테리어|감성|예쁘|경치|전망")),
    ("청결", re.compile(r"깨끗|청결|더럽|위생")),
    ("대기·혼잡", re.compile(r"대기|기다|웨이팅|줄|붐비|복잡|시끄")),
    ("양", re.compile(r"양이|양도|푸짐|많아|적어")),
    ("주차·접근성", re.compile(r"주차|길 ?찾|찾아가|접근|위치|가까")),
]
_GOOD = re.compile(r"좋|맛있|친절|예쁘|최고|깨끗|추천|만족|저렴|푸짐|가성비|편하|빠르")
_BAD = re.compile(r"별로|아쉽|불친절|비싸|느리|대기|기다|더럽|좁|시끄|짜|싱겁|실망|불편|적어")


def _rule_topics(reviews: list[dict]) -> list[dict]:
    out = []
    for name, rx in _RULE_TOPICS:
        hits = [r for r in reviews if r["text"] and rx.search(r["text"])]
        if not hits:
            continue
        pos = sum(1 for r in hits if (r["stars"] >= 4 and not _BAD.search(r["text"])) or (_GOOD.search(r["text"]) and not _BAD.search(r["text"])))
        out.append({"topic": name, "pos": round(pos * 100 / len(hits)), "mentions": len(hits), "summary": ""})
    return sorted(out, key=lambda t: -t["mentions"])[:6]


def _clean_topics(raw, max_mentions: int) -> list[dict] | None:
    if not isinstance(raw, list):
        return None
    out = []
    for t in raw[:6]:
        if not isinstance(t, dict) or not str(t.get("topic") or "").strip():
            continue
        try:
            pos = max(0, min(100, round(float(t.get("pos", 0)))))
            mentions = max(1, min(max_mentions, int(t.get("mentions", 1))))
        except (TypeError, ValueError):
            continue
        out.append({"topic": str(t["topic"]).strip()[:12], "pos": pos, "mentions": mentions,
                    "summary": str(t.get("summary") or "").strip()[:40]})
    return out


def review_topics(place_id: str) -> dict:
    p = PLACES_BY_ID[place_id]
    reviews = recent_reviews(place_id, 100)
    texts = [r for r in reviews if r["text"]]
    key = (len(reviews), reviews[0]["id"] if reviews else 0)
    with _topic_lock:
        hit = _topic_cache.get(place_id)
    if hit and hit[0] == key:
        return hit[1]

    topics, source = None, "rule"
    llm = get_llm_service()
    if texts and llm.is_enabled:
        payload = {"가게": p["name"], "종류": STORE_KIND_LABEL.get(p["kind"], p["kind"]),
                   "리뷰": [{"별점": r["stars"], "내용": r["text"]} for r in texts[:60]]}
        res = llm.chat(_prompt("review_topics.md"), json.dumps(payload, ensure_ascii=False), json_mode=True, temperature=0.2)
        if res.ok and res.data is not None:
            topics = _clean_topics(res.data.get("topics"), len(texts))
            source = "gpt" if topics is not None else "rule"
        else:
            logger.info("리뷰 주제 GPT 분석 실패, 규칙으로 대신합니다: %s", res.error)
    if topics is None:
        topics, source = _rule_topics(texts), "rule"

    result = {"topics": topics, "source": source, "reviewCount": len(reviews), "textCount": len(texts),
              "createdAt": db.now_iso()}
    with _topic_lock:
        _topic_cache[place_id] = (key, result)
    return result


# ── 상권 분석 Agent ───────────────────────────
def _context_block(place_id: str) -> str:
    info = store_info(place_id)
    s = db.review_summary_for_place(place_id)
    reviews = recent_reviews(place_id, 30)
    topics = review_topics(place_id)["topics"]
    reviews_text = "\n".join(f"- {r['stars']}점: {r['text'] or '(별점만)'}" for r in reviews) or "- (아직 없음)"
    topics_text = ", ".join(f"{t['topic']} 긍정 {t['pos']}% ({t['mentions']}건)" for t in topics) or "(아직 없음)"
    return (f"[내 가게] {info['name']} · {info['category']} · {info['regionName']}\n"
            f"[관광객 평가] {s['count']}건, 평균 {s['avg']}점, 별점 분포 {s['dist']}\n"
            f"[리뷰 주제별 반응] {topics_text}\n[최근 리뷰]\n{reviews_text}")


def ask_owner_agent(place_id: str, question: str) -> OwnerAskOut:
    llm = get_llm_service()
    if not llm.is_enabled:
        return OwnerAskOut(answer="backend/.env 에 OPENAI_API_KEY를 넣으면 상권 분석 Agent가 내 가게 리뷰를 근거로 답해요.")
    res = llm.chat(ASK_SYSTEM_PROMPT, f"{_context_block(place_id)}\n\n[사장님 질문] {question}", temperature=0.4)
    return OwnerAskOut(answer=res.text if res.ok and res.text else f"지금은 답할 수 없어요 ({res.error}).")


def register_action(action: OwnerActionRequest, place_id: str, user: dict) -> OwnerActionOut:
    saved = db.insert_owner_action(action.kind, action.title, place_id, user["id"])
    events.publish(events.STORE, f"{PLACES_BY_ID[place_id]['name']} · {action.kind} \"{action.title}\"", user_id=user["id"])
    return OwnerActionOut(**saved)
