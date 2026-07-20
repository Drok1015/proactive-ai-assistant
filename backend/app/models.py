import uuid
from datetime import datetime

from sqlalchemy import JSON, Boolean, DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def new_id() -> str:
    return str(uuid.uuid4())


class Device(Base):
    __tablename__ = "devices"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(String(64), index=True, default="local-user")
    platform: Mapped[str] = mapped_column(String(16))
    push_provider: Mapped[str] = mapped_column(String(24), default="jpush")
    registration_id: Mapped[str] = mapped_column(String(256), unique=True, index=True)
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class ProactiveTask(Base):
    __tablename__ = "proactive_tasks"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(String(64), index=True, default="local-user")
    name: Mapped[str] = mapped_column(String(120))
    type: Mapped[str] = mapped_column(String(32), default="weather")
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    timezone: Mapped[str] = mapped_column(String(64), default="Asia/Shanghai")
    schedule_time: Mapped[str] = mapped_column(String(5), default="00:05")
    config: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class NotificationLog(Base):
    __tablename__ = "notification_logs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    task_id: Mapped[str] = mapped_column(ForeignKey("proactive_tasks.id"), index=True)
    device_id: Mapped[str | None] = mapped_column(ForeignKey("devices.id"), nullable=True)
    event_key: Mapped[str] = mapped_column(String(160), unique=True, index=True)
    title: Mapped[str] = mapped_column(String(120))
    body: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(32))
    provider_response: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
