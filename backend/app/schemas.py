from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator


class DeviceCreate(BaseModel):
    platform: Literal["harmony"]
    registration_id: str = Field(min_length=1, max_length=256)
    push_provider: Literal["jpush"] = "jpush"
    user_id: str = Field(default="local-user", min_length=1, max_length=64)


class WeatherConfig(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    start_hour: int = Field(default=8, ge=0, le=23)
    end_hour: int = Field(default=19, ge=0, le=23)
    precipitation_probability_gt: int = Field(default=0, ge=0, le=100)
    title: str = Field(default="带伞提醒", max_length=120)
    body_template: str = Field(default="今天 {hour}:00 有 {probability}% 降雨概率，记得带伞。", max_length=300)

    @field_validator("end_hour")
    @classmethod
    def validate_window(cls, end_hour: int, info):
        if "start_hour" in info.data and end_hour < info.data["start_hour"]:
            raise ValueError("end_hour must not be earlier than start_hour")
        return end_hour


class TaskCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    type: Literal["weather"] = "weather"
    timezone: str = "Asia/Shanghai"
    schedule_time: str = "00:05"
    user_id: str = Field(default="local-user", min_length=1, max_length=64)
    config: WeatherConfig

    @field_validator("schedule_time")
    @classmethod
    def validate_schedule(cls, value: str):
        try:
            hour, minute = (int(part) for part in value.split(":"))
        except ValueError as exc:
            raise ValueError("schedule_time must be HH:MM") from exc
        if not 0 <= hour <= 23 or not 0 <= minute <= 59:
            raise ValueError("schedule_time must be HH:MM")
        return value


class TaskPatch(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    enabled: bool | None = None
    schedule_time: str | None = None
    config: WeatherConfig | None = None


class TaskOut(BaseModel):
    id: str
    name: str
    type: str
    enabled: bool
    timezone: str
    schedule_time: str
    config: dict

    model_config = {"from_attributes": True}


class NotificationOut(BaseModel):
    id: str
    task_id: str
    event_key: str
    title: str
    body: str
    status: str
    provider_response: dict
    created_at: datetime

    model_config = {"from_attributes": True}
