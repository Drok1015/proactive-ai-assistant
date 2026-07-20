from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import Base, engine, get_session
from app.models import Device, NotificationLog, ProactiveTask
from app.scheduler import task_scheduler
from app.schemas import DeviceCreate, NotificationOut, TaskCreate, TaskOut, TaskPatch
from app.services import PgyerVersionClient, run_weather_task


@asynccontextmanager
async def lifespan(_: FastAPI):
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    task_scheduler.start()
    await task_scheduler.sync()
    yield
    task_scheduler.shutdown()
    await engine.dispose()


app = FastAPI(title="Proactive AI Assistant API", version="0.1.0", lifespan=lifespan)


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/api/v1/devices", status_code=status.HTTP_201_CREATED)
async def register_device(payload: DeviceCreate, session: AsyncSession = Depends(get_session)):
    device = await session.scalar(select(Device).where(Device.registration_id == payload.registration_id))
    if device is None:
        device = Device(**payload.model_dump())
        session.add(device)
    else:
        device.platform = payload.platform
        device.push_provider = payload.push_provider
        device.user_id = payload.user_id
        device.enabled = True
    await session.commit()
    await session.refresh(device)
    return {"id": device.id, "enabled": device.enabled}


@app.get("/api/v1/tasks", response_model=list[TaskOut])
async def list_tasks(session: AsyncSession = Depends(get_session)):
    return list(await session.scalars(select(ProactiveTask).order_by(ProactiveTask.created_at.desc())))


@app.post("/api/v1/tasks", response_model=TaskOut, status_code=status.HTTP_201_CREATED)
async def create_task(payload: TaskCreate, session: AsyncSession = Depends(get_session)):
    task = ProactiveTask(**payload.model_dump(mode="json"))
    session.add(task)
    await session.commit()
    await session.refresh(task)
    await task_scheduler.sync()
    return task


@app.patch("/api/v1/tasks/{task_id}", response_model=TaskOut)
@app.put("/api/v1/tasks/{task_id}", response_model=TaskOut)
async def update_task(task_id: str, payload: TaskPatch, session: AsyncSession = Depends(get_session)):
    task = await session.get(ProactiveTask, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="task not found")
    for field, value in payload.model_dump(exclude_unset=True, mode="json").items():
        setattr(task, field, value)
    await session.commit()
    await session.refresh(task)
    await task_scheduler.sync()
    return task


@app.post("/api/v1/tasks/{task_id}/run", response_model=NotificationOut | None)
async def run_task_now(task_id: str, session: AsyncSession = Depends(get_session)):
    task = await session.get(ProactiveTask, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="task not found")
    if task.type != "weather":
        raise HTTPException(status_code=400, detail="unsupported task type")
    return await run_weather_task(session, task)


@app.get("/api/v1/notifications", response_model=list[NotificationOut])
async def list_notifications(session: AsyncSession = Depends(get_session)):
    return list(await session.scalars(select(NotificationLog).order_by(NotificationLog.created_at.desc()).limit(100)))


@app.get("/api/v1/app/version/check")
async def check_version(version: str, pgyer_build: int | None = None):
    return await PgyerVersionClient().check_update(version, pgyer_build)
