# ─────────────────────────────────────────────
# 환경 변수 로딩 (.env)
# 키 값은 여기서 직접 수정하지 말고 backend/.env 에 넣으세요.
# ─────────────────────────────────────────────
from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=str(BACKEND_DIR / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # OpenAI(GPT)
    openai_api_key: str = ""
    openai_model: str = "gpt-4o-mini"
    openai_timeout_seconds: float = 20.0

    # 제주데이터허브 (실데이터 연동용, 비워두면 목업 데이터 사용)
    jeju_data_hub_api_key: str = ""
    jeju_data_hub_base_url: str = "https://open.jejudatahub.net/api/proxy"

    # 카카오맵(Kakao Local) REST API - 주소 검색, 좌표→행정동 변환
    kakao_rest_api_key: str = ""

    # 서버
    cors_origins: str = "http://localhost:5173,http://127.0.0.1:5173"
    database_path: str = "./storage/jejuitda.db"
    llm_fallback_on_error: bool = True
    # 제주데이터허브에서 받아 둔 파일 데이터 폴더 (관리 콘솔 적재 이력에 표시)
    data_dir: str = "../data"

    # 로그인 (JWT). 비워두면 storage/.jwt_secret 에 무작위 값을 만들어 씁니다.
    jwt_secret: str = ""
    access_token_minutes: int = 30
    refresh_token_days: int = 14
    # 시연 계정(user/owner/admin@jeju.kr, 비밀번호 jeju1234)을 처음 실행 때 만듭니다.
    seed_demo_accounts: bool = True

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def has_openai_key(self) -> bool:
        return bool(self.openai_api_key.strip())

    @property
    def has_kakao_key(self) -> bool:
        return bool(self.kakao_rest_api_key.strip())

    @property
    def database_file(self) -> Path:
        p = Path(self.database_path)
        if not p.is_absolute():
            p = BACKEND_DIR / p
        return p

    @property
    def data_path(self) -> Path:
        p = Path(self.data_dir)
        return (p if p.is_absolute() else BACKEND_DIR / p).resolve()

    @property
    def storage_dir(self) -> Path:
        return self.database_file.parent


@lru_cache
def get_settings() -> Settings:
    return Settings()
