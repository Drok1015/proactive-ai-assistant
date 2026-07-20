from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from sqlalchemy import select

from app.database import SessionLocal
from app.models import ProactiveTask
from app.services import run_weather_task


class TaskScheduler:
    def __init__(self):
        self._scheduler = AsyncIOScheduler()

    async def sync(self) -> None:
        async with SessionLocal() as session:
            tasks = list(await session.scalars(select(ProactiveTask).where(ProactiveTask.enabled.is_(True))))
        desired_ids = {task.id for task in tasks}
        for job in self._scheduler.get_jobs():
            if job.id not in desired_ids:
                self._scheduler.remove_job(job.id)
        for task in tasks:
            hour, minute = task.schedule_time.split(":")
            self._scheduler.add_job(
                self.execute,
                CronTrigger(hour=hour, minute=minute, timezone=task.timezone),
                args=[task.id],
                id=task.id,
                replace_existing=True,
                misfire_grace_time=300,
            )

    async def execute(self, task_id: str) -> None:
        async with SessionLocal() as session:
            task = await session.get(ProactiveTask, task_id)
            if task and task.enabled and task.type == "weather":
                await run_weather_task(session, task)

    def start(self) -> None:
        self._scheduler.start()

    def shutdown(self) -> None:
        self._scheduler.shutdown(wait=False)


task_scheduler = TaskScheduler()
