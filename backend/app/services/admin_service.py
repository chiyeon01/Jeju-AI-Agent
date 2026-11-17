# ─────────────────────────────────────────────
# 제주시 Main PC 관리 콘솔 데이터
# 가능한 값은 모두 실제 상태에서 계산합니다:
#  - 오늘 집계·실시간 이벤트 : events 테이블
#  - 원천 데이터 적재 이력   : 데이터허브 API 11종(캐시·오류 상태) + data/ 폴더의 받아 둔 파일
#  - 품질 점검               : 허위 평가 의심, 좌표 범위, 허브 쿼터·오류, 파일 데이터
#  - 백업                    : SQLite 스냅샷 (storage/backups), 복구는 관리자 2인 요청 시 실행
# 지역 상권 건강 "점수"만 매장 실데이터가 없어 시연 기준값을 씁니다 (data/console_data.py).
# ─────────────────────────────────────────────
from __future__ import annotations

import sqlite3
import threading
from datetime import datetime, timedelta
from pathlib import Path

from app import db, events
from app.config import get_settings
from app.data.console_data import MASKING_RULES, REGION_SCORE_BASELINE
from app.data.datahub_catalog import DATASETS
from app.data.tourist_data import PLACES, REGIONS
from app.errors import ApiError
from app.security import public_user
from app.services.datahub_client import DAILY_QUOTA_GUARD, get_datahub_client
from app.services.datahub_service import known_latest_date, region_crowd

BACKUP_KEEP = 14
_restore_lock = threading.Lock()
_restore_requests: dict[str, tuple[str, datetime]] = {}  # 백업 id → (요청한 관리자 id, 시각)


def _fmt(ts: str | datetime | None) -> str:
    if not ts:
        return "-"
    d = datetime.fromisoformat(ts) if isinstance(ts, str) else ts
    return d.strftime("%m-%d %H:%M")


# ── 통합 현황 ─────────────────────────────────
def overview() -> dict:
    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    counts = db.event_counts_since(today)
    last_minute = sum(db.event_counts_since(datetime.now() - timedelta(seconds=60)).values())
    return {
        # 평가는 방문 인증된 장소만 가능하므로 방문 인증 수 = 오늘 평가 수
        "visits": counts.get(events.REVIEW, 0) + counts.get(events.VISIT, 0),
        "reviews": counts.get(events.REVIEW, 0),
        "courses": counts.get(events.COURSE, 0),
        "eventsPerSec": round(last_minute / 60, 2),
    }


def regions_health() -> list[dict]:
    crowd = region_crowd() or {}
    reviews = db.review_counts_by_region()
    out = []
    for r in REGIONS:
        info = (crowd.get("regions") or {}).get(r["id"]) or {}
        out.append({
            "regionId": r["id"], "name": r["name"], "lat": r["lat"], "lon": r["lon"],
            "score": REGION_SCORE_BASELINE.get(r["id"], 60),
            "visits": info.get("visitPop", 0),          # 데이터허브 D2 방문인구 (crowdDate 기준)
            "reviews": reviews.get(r["id"], 0),          # 앱 평가 누적
            "crowdIndex": info.get("index"),
            "crowdDate": crowd.get("date"),
        })
    return out


# ── 데이터 관리 ───────────────────────────────
def _cycle(spec: dict) -> str:
    if not spec.get("date_param"):
        return "기준정보 API"
    return "월 API" if spec.get("date_format") == "%Y%m" else "매일 API"


def _count_rows(path: Path) -> str:
    if path.suffix.lower() != ".csv":
        return "-"
    with path.open("rb") as f:
        n = sum(1 for _ in f)
    return f"{max(0, n - 1):,}"


def sources() -> list[dict]:
    client = get_datahub_client()
    out = []
    for key, spec in DATASETS.items():
        cache = client.cache_summary(key)
        latest = known_latest_date(key)
        err = client.last_error.get(key)
        if not client.is_enabled:
            status, note = "warn", "프로젝트 키 없음"
        elif err:
            status, note = "err", f"{err[0]} {err[1]}"
        elif cache:
            status, note = "ok", None
        else:
            status, note = "warn", "아직 받은 적 없음"
        out.append({
            "id": f"{spec['source']}-{spec['hub_id']}",
            "name": spec["title"],
            "cycle": _cycle(spec),
            "basis": latest.strftime("%Y-%m" if spec.get("date_format") == "%Y%m" else "%Y-%m-%d") if latest else "-",
            "last": _fmt(cache["fetchedAt"]) if cache else "-",
            "rows": f"{cache['total']:,}" if cache else "-",
            "status": status,
            "note": note,
        })
    data_dir = get_settings().data_path
    if data_dir.exists():
        for f in sorted(p for p in data_dir.rglob("*") if p.suffix.lower() in (".csv", ".xlsx")):
            out.append({
                "id": "FILE",
                "name": f"{f.parent.name}/{f.stem}" if f.parent != data_dir else f.stem,
                "cycle": "파일",
                "basis": "-",
                "last": _fmt(datetime.fromtimestamp(f.stat().st_mtime)),
                "rows": _count_rows(f),
                "status": "ok",
                "note": None,
            })
    return out


def derived() -> list[dict]:
    crowd = region_crowd()
    return [
        {"name": "지역 혼잡도 지수", "desc": "데이터허브 유동인구(D2) → 지역별 0~1, 코스 점수에 반영",
         "store": "서버 메모리", "lag": f"{crowd['date']} 기준" if crowd else "계산 전"},
        {"name": "고객 만족 지수", "desc": "평가가 들어올 때마다 매장 지표 재계산", "store": "SQLite", "lag": "즉시"},
        {"name": "실시간 이벤트", "desc": "코스 선택·평가·가입·조치 → 콘솔 WebSocket", "store": "SQLite + WebSocket", "lag": "즉시"},
        {"name": "데이터허브 응답 캐시", "desc": "지난 날짜는 영구, 최근 7일은 24시간 보관", "store": "storage/datahub_cache",
         "lag": "요청 시"},
    ]


def quality() -> list[dict]:
    out = []
    heavy = db.heavy_reviewers(timedelta(hours=1), 6)
    out.append({"check": "이상치", "target": "평가 이벤트",
                "result": f"1시간 내 평가 6건 초과 계정 {len(heavy)}개" if heavy else "1시간 내 과다 평가 계정 없음",
                "level": "bad" if heavy else "good"})
    bad_coords = [p["name"] for p in PLACES if not (33.0 <= p["lat"] <= 33.7 and 126.1 <= p["lon"] <= 127.0)]
    out.append({"check": "좌표 범위", "target": "추천 장소 위경도",
                "result": f"제주 범위 밖 {len(bad_coords)}곳" if bad_coords else f"{len(PLACES)}곳 모두 제주 범위 안",
                "level": "warn" if bad_coords else "good"})
    client = get_datahub_client()
    calls = client.calls_today()
    top = max(calls.items(), key=lambda x: x[1]) if calls else None
    out.append({"check": "쿼터", "target": "데이터허브 일일 호출",
                "result": f"최다 {DATASETS[top[0]]['title']} {top[1]}회 / 한도 {DAILY_QUOTA_GUARD}" if top else "오늘 호출 없음",
                "level": "warn" if top and top[1] > DAILY_QUOTA_GUARD * 0.7 else "good"})
    errs = client.last_error
    out.append({"check": "응답 오류", "target": "데이터허브 API",
                "result": ", ".join(f"{DATASETS[k]['title']}({v[1]})" for k, v in errs.items()) if errs else "최근 실패 없음",
                "level": "warn" if errs else "good"})
    data_dir = get_settings().data_path
    n_files = len([p for p in data_dir.rglob("*") if p.suffix.lower() in (".csv", ".xlsx")]) if data_dir.exists() else 0
    out.append({"check": "파일 데이터", "target": "data/ 폴더",
                "result": f"파일 {n_files}개" if n_files else "받아 둔 파일 없음", "level": "good" if n_files else "warn"})
    return out


# ── 접근·보안 ─────────────────────────────────
def users() -> list[dict]:
    return [{**public_user(u), "last": _fmt(u.get("last_login_at"))} for u in db.list_users()]


def update_user(admin: dict, user_id: str, status: str | None, role: str | None) -> dict:
    target = db.get_user(user_id)
    if not target:
        raise ApiError(404, "USER_NOT_FOUND", "없는 계정이에요.")
    if target["id"] == admin["id"] and (status not in (None, "ACTIVE") or (role and role != "ADMIN")):
        raise ApiError(400, "CANNOT_CHANGE_SELF", "자기 계정은 정지하거나 권한을 낮출 수 없어요.")
    fields = {k: v for k, v in (("status", status), ("role", role)) if v}
    db.update_user(user_id, fields)
    if status and status != "ACTIVE":
        db.revoke_user_tokens(user_id)
    action = "가입 승인" if target["status"] == "PENDING" and status == "ACTIVE" else "계정 변경"
    db.insert_access_log(admin["name"], action, f"{target['name']} ({', '.join(f'{k}={v}' for k, v in fields.items())})", True)
    if action == "가입 승인" and target["role"] == "MERCHANT":
        events.publish(events.STORE, f"{target.get('store_name') or target['name']} · 가입 승인", user_id=user_id)
    updated = db.get_user(user_id)
    return {**public_user(updated), "last": _fmt(updated.get("last_login_at"))}


def access_logs() -> list[dict]:
    return [{"at": _fmt(l["created_at"]), "who": l["who"], "action": l["action"], "target": l["target"], "ok": bool(l["ok"])}
            for l in db.recent_access_logs()]


def masking_rules() -> list[dict]:
    return MASKING_RULES


# ── 백업·복구 ─────────────────────────────────
def _backup_dir() -> Path:
    d = get_settings().storage_dir / "backups"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _backup_files() -> list[Path]:
    return sorted(_backup_dir().glob("jejuitda_*.db"), key=lambda p: p.stat().st_mtime, reverse=True)


def _backup_item(p: Path) -> dict:
    at = datetime.fromtimestamp(p.stat().st_mtime)
    return {"id": p.stem, "at": _fmt(at), "kind": "수동 스냅샷", "size": f"{p.stat().st_size / 1_048_576:.2f} MB", "ok": True}


def backups() -> list[dict]:
    return [_backup_item(p) for p in _backup_files()]


def create_backup(admin: dict) -> dict:
    path = _backup_dir() / f"jejuitda_{datetime.now():%Y%m%d_%H%M%S}.db"
    src = sqlite3.connect(get_settings().database_file)
    dst = sqlite3.connect(path)
    try:
        src.backup(dst)
    finally:
        dst.close()
        src.close()
    for old in _backup_files()[BACKUP_KEEP:]:
        old.unlink(missing_ok=True)
    db.insert_access_log(admin["name"], "백업", path.name, True)
    return {"message": f"스냅샷을 만들었어요 ({path.name})", "backup": _backup_item(path)}


def request_restore(admin: dict, backup_key: str) -> dict:
    """복구는 서로 다른 관리자 2명이 24시간 안에 같은 스냅샷을 요청해야 실행됩니다."""
    match = next((p for p in _backup_files() if backup_key in (p.stem, p.name, _backup_item(p)["at"])), None)
    if match is None:
        raise ApiError(404, "BACKUP_NOT_FOUND", "없는 스냅샷이에요.")
    with _restore_lock:
        prev = _restore_requests.get(match.stem)
        if prev and prev[0] != admin["id"] and datetime.now() - prev[1] < timedelta(hours=24):
            src = sqlite3.connect(match)
            dst = sqlite3.connect(get_settings().database_file)
            try:
                src.backup(dst)
            finally:
                dst.close()
                src.close()
            _restore_requests.pop(match.stem, None)
            db.insert_access_log(admin["name"], "복구 실행", match.name, True)
            return {"message": f"{_backup_item(match)['at']} 스냅샷으로 복구했어요 (관리자 2인 승인)."}
        _restore_requests[match.stem] = (admin["id"], datetime.now())
    db.insert_access_log(admin["name"], "복구 요청", match.name, True)
    return {"message": f"{_backup_item(match)['at']} 스냅샷 복구를 요청했어요. 다른 관리자 1명이 24시간 안에 승인하면 복구돼요."}


def retention() -> list[dict]:
    s = get_settings()
    return [
        {"what": "수동 스냅샷", "keep": f"최근 {BACKUP_KEEP}개"},
        {"what": "데이터허브 응답 캐시", "keep": "지난 날짜 영구 · 최근 7일 24시간"},
        {"what": "로그인 유지 (리프레시 토큰)", "keep": f"{s.refresh_token_days}일"},
        {"what": "실시간 이벤트·접근 기록", "keep": "삭제 없이 보관"},
    ]
