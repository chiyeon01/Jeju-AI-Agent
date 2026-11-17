# ─────────────────────────────────────────────
# 코스 플래너 Agent와의 대화형 수정
#
# 1) GPT에게 "자유 문장 + 지금 코스 → (patch + prefs + 한국어 답변)" 을 JSON으로 받습니다.
#    GPT가 꺼져 있거나 실패하면 규칙 기반(정규식) 해석으로 대체합니다.
#    - patch : 프론트가 들고 있는 코스 옵션 (seafood / removeCount / weather)
#    - prefs : 프론트 옵션에 없는 요청 (바다 보이는 곳, 특정 장소·종류 빼기) → 서버가 사용자별로 기억
# 2) 마지막 코스 요청에 이번 변경을 적용해 코스를 미리 계산해 보고, 실제로 바뀌는 게 없으면
#    "이미 최소 2곳이에요" 처럼 솔직하게 답하고 patch 를 보내지 않습니다.
# 3) prefs 만 바뀐 경우에도 프론트가 코스를 다시 부르도록 patch {"removeCount": 0} 을 보냅니다.
# ─────────────────────────────────────────────
from __future__ import annotations

import json
import re
from dataclasses import dataclass, field

from app.data.tourist_data import KIND_LABEL, PLACES, PLACES_BY_ID
from app.schemas import ChatOut, ChatPatch, CourseOptions
from app.services import course_session
from app.services.course_service import plan_course
from app.services.course_session import CoursePrefs
from app.services.llm_service import get_llm_service

MIN_STOPS = 2
KINDS = list(KIND_LABEL)  # cafe | spot | sunset | food | indoor

SYSTEM_PROMPT = """너는 제주 여행 코스 플래너 Agent야. 사용자가 지금 코스를 바꿔달라고 하면
아래 JSON 형식으로만 답해.
{"reply": "<사용자에게 보여줄 한국어 답변, 1~2문장>",
 "patch": {"seafood": true|false|null, "removeCount": <줄일 장소 수, 정수, 기본 0>, "weather": "clear"|"rain"|null},
 "prefs": {"oceanView": [<바다가 보이는 곳으로 바꿀 장소 종류>],
           "excludePlaces": [<빼 달라고 한 장소의 id (지금 코스 또는 후보 목록의 id)>],
           "excludeKinds": [<통째로 빼 달라고 한 장소 종류>],
           "reset": true|false}}
장소 종류: cafe(카페), spot(산책·관광), sunset(노을 명소), food(저녁 식사), indoor(실내 체험)
규칙:
- "해산물/회/바다 음식"으로 바꿔달라고 하면 patch.seafood=true, 해산물 말고 다른 걸 원하면 false
- "줄여줘/하나 빼줘"처럼 개수만 줄이라고 하면 patch.removeCount (기본 1)
- 특정 장소를 빼거나 다른 곳으로 바꿔달라고 하면 그 장소 id를 prefs.excludePlaces 에 (removeCount 는 0)
- "노을은 빼줘", "카페는 안 갈래"처럼 종류를 빼면 prefs.excludeKinds
- "바다 보이는/오션뷰 카페로" 같은 요청은 prefs.oceanView 에 해당 종류 (종류를 말하지 않으면 cafe)
- "비/실내"로 바꿔달라고 하면 patch.weather="rain", "맑은 날/야외"면 "clear"
- "처음 코스로/원래대로"면 prefs.reset=true
- 해당 없는 값은 null 또는 빈 배열
- 위 방법으로 바꿀 수 없는 요청이면 patch·prefs 를 비우고, reply 에서 할 수 있는 요청
  (해산물, 장소 줄이기/빼기, 바다 보이는 곳, 실내 코스)을 안내해.
- reply 에서 구체적인 새 장소 이름은 지어내지 마. 서버가 실제 바뀐 장소를 덧붙여 줘."""


@dataclass
class Intent:
    reply: str = ""
    seafood: bool | None = None
    remove: int = 0
    weather: str | None = None
    ocean_kinds: set[str] = field(default_factory=set)
    exclude_ids: set[str] = field(default_factory=set)
    exclude_kinds: set[str] = field(default_factory=set)
    reset: bool = False

    @property
    def empty(self) -> bool:
        return (self.seafood is None and not self.remove and self.weather is None and not self.reset
                and not self.ocean_kinds and not self.exclude_ids and not self.exclude_kinds)


def _josa(word: str, pair: str) -> str:
    """받침에 맞는 조사: _josa("카페", "이가") → "카페가", _josa("노을 명소", "은는") → "노을 명소는"."""
    last = word.strip()[-1:] or " "
    has_final = "가" <= last <= "힣" and (ord(last) - ord("가")) % 28 != 0
    return word + (pair[0] if has_final else pair[1])


def _label(kinds: set[str]) -> str:
    return "·".join(KIND_LABEL[k] for k in KINDS if k in kinds)


# ── 해석: 규칙 기반 ─────────────────────────────
_KIND_WORDS = {
    "cafe": r"카페|커피|브런치",
    "food": r"식당|저녁|밥|맛집|식사",
    "sunset": r"노을|일몰|석양",
    "spot": r"산책|명소|해변|관광",
    "indoor": r"실내 ?체험|체험|공방|책방",
}


def _kinds_in(message: str) -> set[str]:
    return {k for k, pat in _KIND_WORDS.items() if re.search(pat, message)}


def _rule_based(message: str, current_ids: list[str]) -> Intent:
    if re.search(r"원래대로|처음 ?코스|초기화", message):
        return Intent(reply="처음 코스로 되돌릴게요.", reset=True, seafood=False)
    if re.search(r"바다 ?(가 )?보이|오션 ?뷰|바다 ?전망|바다 ?뷰", message):
        kinds = _kinds_in(message) - {"spot", "indoor"} or {"cafe"}
        return Intent(reply=f"{_josa(_label(kinds), '을를')} 바다가 보이는 곳으로 골라 볼게요.", ocean_kinds=kinds)
    named = [pid for pid in current_ids if PLACES_BY_ID[pid]["name"].replace(" ", "") in message.replace(" ", "")]
    if named and re.search(r"빼|말고|제외|바꿔|싫", message):
        names = ", ".join(PLACES_BY_ID[pid]["name"] for pid in named)
        return Intent(reply=f"{_josa(names, '을를')} 빼고 다시 골라 볼게요.", exclude_ids=set(named))
    if re.search(r"해산물|회 |회로|바다 ?음식", message):
        return Intent(reply="저녁을 해산물 식당으로 바꿀게요. 외식업 메뉴 매출에서 해산물 비중이 높은 곳 위주로 골라요.",
                      seafood=True)
    if re.search(r"줄여|하나 ?빼|1곳|한 ?곳", message):
        return Intent(reply="마지막 장소 하나를 뺄게요. 이동 시간이 줄어 여유가 생겨요.", remove=1)
    if re.search(r"비 |비가|비와|실내", message):
        return Intent(reply="실내 위주 코스로 바꿀게요.", weather="rain")
    kinds = _kinds_in(message)
    if kinds and re.search(r"빼|말고|안 ?갈|싫", message):
        return Intent(reply=f"{_josa(_label(kinds), '은는')} 빼고 다시 짤게요.", exclude_kinds=kinds)
    return Intent(reply='"저녁은 해산물로 바꿔줘", "1곳 줄여줘", "실내로 바꿔줘", "카페는 바다 보이는 곳으로", '
                        '"(장소 이름) 빼줘" 같은 요청을 알아들어요.')


# ── 해석: GPT ─────────────────────────────────
def _course_context(current_ids: list[str]) -> str:
    cur = [{"id": pid, "name": PLACES_BY_ID[pid]["name"], "kind": PLACES_BY_ID[pid]["kind"]}
           for pid in current_ids if pid in PLACES_BY_ID]
    names = [{"id": p["id"], "name": p["name"]} for p in PLACES]
    return json.dumps({"지금 코스": cur, "후보 장소": names}, ensure_ascii=False)


def _str_set(v, allowed) -> set[str]:
    if isinstance(v, str):
        v = [v]
    return {x for x in v if isinstance(x, str) and x in allowed} if isinstance(v, list) else set()


def _from_llm(data: dict) -> Intent | None:
    reply = str(data.get("reply") or "").strip()
    if not reply:
        return None
    patch = data.get("patch") if isinstance(data.get("patch"), dict) else {}
    prefs = data.get("prefs") if isinstance(data.get("prefs"), dict) else {}
    try:
        remove = max(0, min(int(patch.get("removeCount") or 0), 3))
    except (TypeError, ValueError):
        remove = 0
    seafood = patch.get("seafood")
    weather = patch.get("weather")
    return Intent(
        reply=reply,
        seafood=seafood if isinstance(seafood, bool) else None,
        remove=remove,
        weather=weather if weather in ("clear", "rain") else None,
        ocean_kinds=_str_set(prefs.get("oceanView"), KINDS),
        exclude_ids=_str_set(prefs.get("excludePlaces"), PLACES_BY_ID),
        exclude_kinds=_str_set(prefs.get("excludeKinds"), KINDS),
        reset=prefs.get("reset") is True,
    )


def _understand(message: str, current_ids: list[str]) -> Intent:
    llm = get_llm_service()
    if llm.is_enabled:
        result = llm.chat(SYSTEM_PROMPT, f"{_course_context(current_ids)}\n\n사용자: {message}",
                          json_mode=True, temperature=0.3)
        if result.ok and result.data:
            intent = _from_llm(result.data)
            if intent:
                return intent
    return _rule_based(message, current_ids)


# ── 적용 · 확인 ─────────────────────────────────
def _new_prefs(old: CoursePrefs, it: Intent) -> CoursePrefs:
    p = CoursePrefs() if it.reset else old.copy()
    p.ocean_kinds |= it.ocean_kinds
    p.exclude_ids |= it.exclude_ids
    p.exclude_kinds |= it.exclude_kinds
    return p


def _no_change_reply(it: Intent, current_ids: list[str]) -> str:
    if it.remove and len(current_ids) <= MIN_STOPS:
        return f"지금 코스가 이미 최소 {MIN_STOPS}곳이라 더 줄일 수 없어요. 특정 장소를 다른 곳으로 바꿔 드릴 수는 있어요."
    if it.ocean_kinds:
        return f"지금 코스의 {_josa(_label(it.ocean_kinds), '이가')} 이미 바다가 보이는 곳이거나, 근처에 바다 보이는 다른 후보가 없어요."
    if it.exclude_ids or it.exclude_kinds:
        return "말씀하신 장소는 지금 코스에 없거나, 대신 넣을 후보가 없어 코스가 그대로예요."
    if it.seafood:
        return "지금 코스의 식사가 이미 해산물 식당이에요."
    if it.weather == "rain":
        return "지금 코스가 이미 실내 위주예요."
    return "요청을 반영해 봤지만 지금 조건에서는 바뀌는 장소가 없어요."


def _diff_text(before: list[str], after: list[str]) -> str:
    removed = [PLACES_BY_ID[i]["name"] for i in before if i not in after]
    added = [PLACES_BY_ID[i]["name"] for i in after if i not in before]
    parts = []
    if removed and added:
        parts.append(f"{', '.join(removed)} → {', '.join(added)}")
    elif removed:
        parts.append(f"{', '.join(removed)} 제외")
    elif added:
        parts.append(f"{', '.join(added)} 추가")
    else:
        parts.append("방문 순서 조정")
    return f"(바뀐 곳: {parts[0]})"


def chat_course(message: str, user_id: str) -> ChatOut:
    session = course_session.get(user_id)
    current_ids = list(session.last_stop_ids)
    it = _understand(message, current_ids)
    if it.empty:
        return ChatOut(reply=it.reply, patch=None)

    # 바다 보이는 곳 요청: 지금 코스에서 그 종류인데 바다가 안 보이는 장소는 빼고 다시 고름
    for pid in current_ids:
        place = PLACES_BY_ID[pid]
        if place["kind"] in it.ocean_kinds and not place.get("ocean"):
            it.exclude_ids.add(pid)

    prefs = _new_prefs(session.prefs, it)
    req = session.last_req
    # 프론트는 patch.removeCount 를 누적해서 더하므로, 되돌릴 땐 지금까지 줄인 만큼 음수로 보냄
    remove = -(req.options.removeCount if req else 0) if it.reset else it.remove
    weather = it.weather
    if it.reset and req and session.first_weather and session.first_weather != req.weather:
        weather = session.first_weather  # 처음 코스를 짤 때의 날씨로 되돌림
    patch = ChatPatch(seafood=it.seafood, removeCount=remove, weather=weather)

    if req is None:
        # 서버 재시작 등으로 마지막 코스를 모름 → 확인 없이 반영
        course_session.save_prefs(user_id, prefs)
        return ChatOut(reply=it.reply, patch=patch)

    # 프론트와 같은 방식으로 옵션을 합쳐 코스를 미리 계산해 봄
    opts = req.options
    trial = req.model_copy(update={
        "weather": weather or req.weather,
        "options": CourseOptions(
            seafood=opts.seafood if it.seafood is None else it.seafood,
            removeCount=opts.removeCount + remove,
        ),
    })
    after = [s.id for s in plan_course(trial, prefs).stops]
    if after == current_ids:
        return ChatOut(reply=_no_change_reply(it, current_ids), patch=None)

    course_session.save_prefs(user_id, prefs)
    return ChatOut(reply=f"{it.reply} {_diff_text(current_ids, after)}", patch=patch)
