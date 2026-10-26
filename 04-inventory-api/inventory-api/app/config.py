from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str
    jwt_secret: str = Field(min_length=32)
    jwt_expire_minutes: int = Field(default=30, ge=1, le=1440)
    app_name: str = "Inventory Management API"
    db_pool_size: int = 5
    db_max_overflow: int = 5

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
