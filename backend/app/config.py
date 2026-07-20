from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "sqlite+aiosqlite:///./proactive_ai.db"
    open_meteo_url: str = "https://api.open-meteo.com/v1/forecast"
    jpush_app_key: str = ""
    jpush_master_secret: str = ""
    pgyer_api_key: str = ""
    pgyer_app_key: str = ""
    pgyer_download_url: str = ""
    app_latest_version: str = "0.1.0"
    app_latest_build: int = 1


settings = Settings()
