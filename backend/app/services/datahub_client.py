# ─────────────────────────────────────────────
# 제주데이터허브 API 클라이언트
#
# 허브 API의 특성(2026-11 실제 호출로 확인)에 맞춘 처리:
#  - 같은 요청도 가끔 500/502를 돌려줌 → 짧은 간격으로 재시도
#  - 한 번에 최대 100건 (limit 100 초과 시 5xx) → number(페이지)로 이어 받기
#  - 데이터마다 하루 1,000회 쿼터 → 호출 수를 세서 950회에서 멈춤
#  - 지난 날짜 데이터는 바뀌지 않음 → 디스크에 캐시해 쿼터를 아낌
#    (지난 날짜: 영구 보관 / 날짜 없는 기준정보: 24시간 / 빈 결과: 6시간)
# ─────────────────────────────────────────────
from __future__ import annotations

import hashlib
import json
import logging
import threading
import time
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any

import httpx

from app.config import get_settings
from app.data.datahub_catalog import DATASETS

logger = logging.getLogger("jejuitda.datahub")

PAGE_LIMIT = 100
MAX_RETRIES = 6  # 허브의 5xx는 몇 초씩 몰려서 나와 넉넉히 재시도
DAILY_QUOTA_GUARD = 950
TTL_UNDATED = timedelta(hours=24)
TTL_EMPTY = timedelta(hours=6)


class DataHubError(Exception):
    """허브 호출 실패. status 는 FastAPI 응답 코드로 그대로 씁니다."""

    def __init__(self, message: str, status: int = 502) -> None:
        super().__init__(message)
        self.status = status


@dataclass
class FetchResult:
    rows: list[dict]
    total: int
    complete: bool  # max_rows 로 잘렸으면 False
    cached: bool


class DataHubClient:
    def __init__(self) -> None:
        settings = get_settings()
        self._key = settings.jeju_data_hub_api_key.strip()
        self._base = settings.jeju_data_hub_base_url.rstrip("/")
        self._cache_dir = settings.database_file.parent / "datahub_cache"
        self._lock = threading.Lock()
        self._calls: dict[tuple[str, str], int] = {}  # (dataset, YYYYMMDD) → 호출 수
        self._load_quota()

    @property
    def is_enabled(self) -> bool:
        return bool(self._key)

    # ── 쿼터 (서버를 다시 켜도 오늘 호출 수가 유지되도록 파일에 저장) ──
    def _quota_file(self) -> Path:
        return self._cache_dir / f"quota_{date.today().strftime('%Y%m%d')}.json"

    def _load_quota(self) -> None:
        try:
            saved = json.loads(self._quota_file().read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return
        today = date.today().strftime("%Y%m%d")
        self._calls.update({(ds, today): n for ds, n in saved.items()})

    def _save_quota(self) -> None:
        try:
            self._cache_dir.mkdir(parents=True, exist_ok=True)
            self._quota_file().write_text(json.dumps(self.calls_today(), ensure_ascii=False), encoding="utf-8")
        except OSError:
            pass

    def calls_today(self) -> dict[str, int]:
        today = date.today().strftime("%Y%m%d")
        return {ds: n for (ds, d), n in list(self._calls.items()) if d == today}

    def _count_call(self, dataset: str) -> None:
        today = date.today().strftime("%Y%m%d")
        with self._lock:
            n = self._calls.get((dataset, today), 0)
            if n >= DAILY_QUOTA_GUARD:
                raise DataHubError(f"'{DATASETS[dataset]['title']}' 오늘 호출 한도에 가까워 멈췄어요 ({n}회)", status=429)
            self._calls[(dataset, today)] = n + 1
        self._save_quota()

    # ── 캐시 ───────────────────────────────────
    def _cache_path(self, dataset: str, params: dict, max_rows: int | None) -> Path:
        raw = json.dumps([dataset, sorted(params.items()), max_rows], ensure_ascii=False)
        return self._cache_dir / f"{dataset}_{hashlib.sha1(raw.encode()).hexdigest()[:16]}.json"

    @staticmethod
    def _is_past_dated(dataset: str, params: dict) -> bool:
        spec = DATASETS[dataset]
        dp = spec.get("date_param")
        if not dp or dp not in params:
            return False
        fmt = spec["date_format"]
        today = date.today()
        for k in ("startDate", "endDate", "searchDate"):
            if k in params:
                d = datetime.strptime(str(params[k]), fmt).date()
                # 월 단위는 지난달까지만, 일 단위는 7일 전까지만 "확정"으로 봄
                # (최근 며칠은 허브에 데이터가 덜 들어와 있을 수 있어 24시간만 캐시)
                limit = today.replace(day=1) if fmt == "%Y%m" else today - timedelta(days=7)
                if d >= limit:
                    return False
        return True

    def _read_cache(self, path: Path, dataset: str, params: dict) -> FetchResult | None:
        if not path.exists():
            return None
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return None
        age = datetime.now() - datetime.fromisoformat(payload["fetched_at"])
        if not payload["rows"] and age > TTL_EMPTY:
            return None
        if payload["rows"] and not self._is_past_dated(dataset, params) and age > TTL_UNDATED:
            return None
        return FetchResult(rows=payload["rows"], total=payload["total"], complete=payload["complete"], cached=True)

    def _write_cache(self, path: Path, result: FetchResult) -> None:
        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(
                json.dumps({"fetched_at": datetime.now().isoformat(), "rows": result.rows,
                            "total": result.total, "complete": result.complete}, ensure_ascii=False),
                encoding="utf-8",
            )
        except OSError as e:
            logger.warning("허브 캐시 저장 실패: %s", e)

    # ── 호출 ───────────────────────────────────
    def _get_page(self, dataset: str, params: dict, page: int) -> dict:
        spec = DATASETS[dataset]
        url = f"{self._base}/{spec['code']}/{self._key}"
        query = {**params, "limit": PAGE_LIMIT, "number": page}
        last = ""
        for attempt in range(MAX_RETRIES):
            self._count_call(dataset)
            try:
                resp = httpx.get(url, params=query, timeout=30.0)
            except httpx.HTTPError as e:
                last = f"연결 실패 ({e.__class__.__name__})"
            else:
                if resp.status_code == 200:
                    try:
                        return resp.json()
                    except ValueError:
                        last = "JSON이 아닌 응답"
                elif resp.status_code == 403:
                    raise DataHubError("데이터허브가 키를 거부했어요. 프로젝트 키와 '프로젝트 담기' 여부를 확인하세요", status=502)
                else:
                    last = f"HTTP {resp.status_code}"
            time.sleep(1.0 * (attempt + 1))
        raise DataHubError(f"'{spec['title']}' 호출이 {MAX_RETRIES}번 모두 실패했어요 ({last})")

    def fetch(self, dataset: str, params: dict[str, Any] | None = None, *, max_rows: int | None = None) -> FetchResult:
        """조건에 맞는 행을 페이지를 넘기며 모두(또는 max_rows까지) 가져옵니다."""
        if dataset not in DATASETS:
            raise DataHubError(f"알 수 없는 데이터: {dataset}", status=404)
        if not self.is_enabled:
            raise DataHubError("JEJU_DATA_HUB_API_KEY가 설정되지 않았습니다 (backend/.env 확인)", status=503)
        spec = DATASETS[dataset]
        params = {k: str(v) for k, v in (params or {}).items() if v not in (None, "") and k in spec["params"]}
        missing = [p for p in spec["required"] if p not in params]
        if missing:
            raise DataHubError(f"필수 값이 빠졌어요: {', '.join(missing)}", status=422)

        path = self._cache_path(dataset, params, max_rows)
        cached = self._read_cache(path, dataset, params)
        if cached:
            return cached

        rows: list[dict] = []
        total = 0
        page = 1
        while True:
            body = self._get_page(dataset, params, page)
            data = body.get("data") or []
            total = int(body.get("totCnt") or len(data))
            rows.extend(data)
            if max_rows is not None and len(rows) >= max_rows:
                rows = rows[:max_rows]
                break
            if not body.get("hasMore") or not data:
                break
            page += 1

        result = FetchResult(rows=rows, total=total, complete=len(rows) >= total, cached=False)
        self._write_cache(path, result)
        return result

    def has_data(self, dataset: str, day: date) -> bool | None:
        """그 날짜(월 단위 데이터는 그 달)에 데이터가 1건이라도 있는지.
        허브가 특정 날짜에 계속 5xx를 주는 경우가 있어, 그때는 None(모름)을 돌려줍니다."""
        spec = DATASETS[dataset]
        d = day.strftime(spec["date_format"])
        if spec["date_param"] == "searchDate":
            params = {"searchDate": d}
        else:
            params = {"startDate": d, "endDate": d}
        try:
            return bool(self.fetch(dataset, params, max_rows=1).rows)
        except DataHubError as e:
            if e.status in (429, 503):
                raise
            logger.info("%s %s 확인 실패 (모름으로 처리): %s", dataset, d, e)
            return None


_client: DataHubClient | None = None


def get_datahub_client() -> DataHubClient:
    global _client
    if _client is None:
        _client = DataHubClient()
    return _client
