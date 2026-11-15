# ─────────────────────────────────────────────
# 성향 분석 Agent: 테스트 응답 → 4축 점수 → 16유형
# frontend/src/mock/tourist.js 의 scoreAnswers() 와 동일한 규칙(Python 포팅)으로
# 코드/이름을 계산해, 프론트가 보여주는 유형과 백엔드가 항상 일치하게 합니다.
# 설명 문구(desc)는 GPT가 있으면 성향에 맞게 한 번 더 다듬고, 없으면 기본 문구를 씁니다.
# ─────────────────────────────────────────────
from __future__ import annotations

from app.data.tourist_data import ADJ, NOUN, QUESTION_AXES, TYPE_DESC
from app.schemas import ProfileOut, ProfileRequest
from app.services.llm_service import get_llm_service

AXIS_KEYS = ["act", "space", "taste", "style"]


def score_answers(answers: dict[str, str]) -> dict:
    total = {k: 0 for k in AXIS_KEYS}
    count = {k: 0 for k in AXIS_KEYS}
    for i, axis in enumerate(QUESTION_AXES):
        ans = answers.get(str(i))
        if not ans:
            continue
        total[axis] += -1 if ans == "a" else 1
        count[axis] += 1

    scores = {k: round((total[k] / count[k]) * 100) if count[k] else 0 for k in AXIS_KEYS}

    def pick(key: str, left: str, right: str) -> str:
        return left if scores[key] <= 0 else right

    code = (
        pick("act", "A", "H")
        + pick("space", "N", "C")
        + pick("taste", "F", "P")
        + pick("style", "J", "S")
    )
    adj = ADJ[f"{code[1]}-{code[2]}"]
    noun = NOUN[f"{code[0]}-{code[3]}"]
    name = f"{adj} {noun}"
    tags = [
        "#체험" if code[0] == "A" else "#휴식",
        "#바다" if code[1] == "N" else "#골목",
        "#로컬맛집" if code[2] == "F" else "#뷰포인트",
        "#촘촘한일정" if code[3] == "J" else "#여유시간",
    ]
    return {"code": code, "name": name, "desc": TYPE_DESC[adj], "scores": scores, "tags": tags}


def _refine_desc_with_gpt(name: str, base_desc: str, tags: list[str]) -> str:
    llm = get_llm_service()
    if not llm.is_enabled:
        return base_desc
    system = (
        "너는 제주 여행 성향 테스트 결과를 한두 문장으로 설명하는 작가야. "
        "친근한 한국어 반말 아닌 존댓말로, 과장 없이 50자 내외 한 문장만 출력해."
    )
    user = f"여행 유형: {name}\n기본 설명: {base_desc}\n특징 태그: {', '.join(tags)}"
    result = llm.chat(system, user, temperature=0.6)
    if result.ok and result.text:
        return result.text.strip().strip('"')
    return base_desc


def analyze_profile(req: ProfileRequest) -> ProfileOut:
    scored = score_answers(req.answers)
    desc = _refine_desc_with_gpt(scored["name"], scored["desc"], scored["tags"])
    return ProfileOut(
        code=scored["code"],
        name=scored["name"],
        desc=desc,
        scores=scored["scores"],
        tags=scored["tags"],
        companion=req.companion,
        transport=req.transport,
        budget=req.budget,
        startTime=req.startTime,
        hours=req.hours,
    )
