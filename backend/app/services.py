import base64
from dataclasses import dataclass
from datetime import date, datetime
from zoneinfo import ZoneInfo

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import Device, NotificationLog, ProactiveTask
from app.schemas import WeatherConfig


@dataclass(frozen=True)
class WeatherHit:
    hour: int
    probability: int


class OpenMeteoClient:
    async def find_rain_hit(self, config: WeatherConfig, timezone: str, target_date: date) -> WeatherHit | None:
        params = {
            "latitude": config.latitude,
            "longitude": config.longitude,
            "hourly": "precipitation_probability",
            "timezone": timezone,
            "start_date": target_date.isoformat(),
            "end_date": target_date.isoformat(),
        }
        async with httpx.AsyncClient(timeout=15) as client:
            response = await client.get(settings.open_meteo_url, params=params)
            response.raise_for_status()
        hourly = response.json().get("hourly", {})
        times = hourly.get("time", [])
        probabilities = hourly.get("precipitation_probability", [])
        for timestamp, probability in zip(times, probabilities, strict=True):
            hour = datetime.fromisoformat(timestamp).hour
            probability = int(probability or 0)
            if config.start_hour <= hour <= config.end_hour and probability > config.precipitation_probability_gt:
                return WeatherHit(hour=hour, probability=probability)
        return None


class PushProvider:
    async def send(self, registration_ids: list[str], title: str, body: str, extra: dict) -> dict:
        if not settings.jpush_app_key or not settings.jpush_master_secret:
            return {"mode": "dry-run", "reason": "JPUSH credentials are not configured", "targets": len(registration_ids)}
        credentials = f"{settings.jpush_app_key}:{settings.jpush_master_secret}".encode()
        authorization = base64.b64encode(credentials).decode()
        payload = {
            "platform": ["hmos"],
            "audience": {"registration_id": registration_ids},
            "notification": {"hmos": {"alert": body, "title": title}},
            "message": {"title": title, "msg_content": body, "extras": extra},
        }
        async with httpx.AsyncClient(timeout=15) as client:
            response = await client.post(
                "https://api.jpush.cn/v3/push",
                json=payload,
                headers={"Authorization": f"Basic {authorization}", "Content-Type": "application/json"},
            )
        response.raise_for_status()
        return {"mode": "jpush", "response": response.json()}


class PgyerVersionClient:
    async def check_update(self, current_version: str, current_pgyer_build: int | None = None) -> dict:
        if not settings.pgyer_api_key or not settings.pgyer_app_key:
            return {
                "hasUpdate": False,
                "version": settings.app_latest_version,
                "build": settings.app_latest_build,
                "downloadUrl": settings.pgyer_download_url or None,
                "mode": "static",
            }
        data: dict[str, str | int] = {
            "_api_key": settings.pgyer_api_key,
            "appKey": settings.pgyer_app_key,
            "buildVersion": current_version,
        }
        if current_pgyer_build is not None:
            data["buildBuildVersion"] = current_pgyer_build
        async with httpx.AsyncClient(timeout=15) as client:
            response = await client.post("https://www.pgyer.com/apiv2/app/check", data=data)
            response.raise_for_status()
        payload = response.json()
        if payload.get("code") != 0:
            raise RuntimeError(f"Pgyer update check failed: {payload.get('message', 'unknown error')}")
        result = payload["data"]
        return {
            "hasUpdate": bool(result.get("buildHaveNewVersion")),
            "forceUpdate": bool(result.get("needForceUpdate")),
            "version": result.get("buildVersion"),
            "build": result.get("buildBuildVersion"),
            # appURl does not contain the private API key; never relay downloadURL to clients.
            "downloadUrl": result.get("appURl") or settings.pgyer_download_url or None,
            "description": result.get("buildUpdateDescription") or "发现新版本",
            "mode": "pgyer",
        }


async def run_weather_task(session: AsyncSession, task: ProactiveTask) -> NotificationLog | None:
    config = WeatherConfig.model_validate(task.config)
    local_day = datetime.now(ZoneInfo(task.timezone)).date()
    event_key = f"weather:{task.id}:{local_day.isoformat()}"
    existing = await session.scalar(select(NotificationLog).where(NotificationLog.event_key == event_key))
    if existing:
        return existing

    hit = await OpenMeteoClient().find_rain_hit(config, task.timezone, local_day)
    if hit is None:
        return None

    title = config.title
    body = config.body_template.format(hour=hit.hour, probability=hit.probability)
    devices = list(
        await session.scalars(
            select(Device).where(Device.user_id == task.user_id, Device.enabled.is_(True), Device.push_provider == "jpush")
        )
    )
    if devices:
        result = await PushProvider().send([device.registration_id for device in devices], title, body, {"taskId": task.id, "type": "weather"})
        status = "sent" if result["mode"] == "jpush" else "dry-run"
    else:
        result = {"mode": "no-device", "reason": "No enabled device is registered for this task owner."}
        status = "no-device"
    log = NotificationLog(
        task_id=task.id,
        device_id=devices[0].id if len(devices) == 1 else None,
        event_key=event_key,
        title=title,
        body=body,
        status=status,
        provider_response=result,
    )
    session.add(log)
    await session.commit()
    await session.refresh(log)
    return log
