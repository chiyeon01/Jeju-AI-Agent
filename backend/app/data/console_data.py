# ─────────────────────────────────────────────
# 관리 콘솔 기준값
# 지역 상권 건강 점수는 매장 단위 실데이터가 쌓이기 전까지 쓰는 시연용 기준값입니다
# (frontend/src/mock/console.js 의 REGION_HEALTH 와 같은 값). 방문·평가 수는 실데이터로 채웁니다.
# ─────────────────────────────────────────────
from __future__ import annotations

REGION_SCORE_BASELINE = {
    "jeju-city": 71, "aewol": 68, "hallim": 63, "daejeong": 57, "jungmun": 66,
    "seogwipo": 70, "namwon": 54, "seongsan": 74, "gujwa": 61, "jocheon": 65,
}

# 개인 식별 위험 마스킹 규칙 (정책)
MASKING_RULES = [
    {"rule": "방문 인증 위경도", "how": "100m 격자로 일반화"},
    {"rule": "평가 계정 ID", "how": "해시 처리, 원본은 관리자만"},
    {"rule": "셀 단위 집계", "how": "5건 미만 셀은 공개하지 않음 (k ≥ 5)"},
    {"rule": "리뷰 본문", "how": "전화번호·차량번호 자동 제거"},
    {"rule": "데이터허브 원천 데이터", "how": "서버 밖·LLM으로 원본 행을 보내지 않고 집계값만 사용"},
]
