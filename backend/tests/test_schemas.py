import pytest
from pydantic import ValidationError

from app.schemas import TaskCreate


def weather_payload(**overrides):
    payload = {
        "name": "天气带伞提醒",
        "config": {"latitude": 36.0671, "longitude": 120.3826, "start_hour": 8, "end_hour": 19},
    }
    payload.update(overrides)
    return payload


def test_weather_task_defaults_match_product_rule():
    task = TaskCreate.model_validate(weather_payload())
    assert task.schedule_time == "00:05"
    assert task.config.precipitation_probability_gt == 0
    assert (task.config.start_hour, task.config.end_hour) == (8, 19)


def test_weather_window_rejects_an_inverted_range():
    with pytest.raises(ValidationError):
        TaskCreate.model_validate(weather_payload(config={"latitude": 36.0671, "longitude": 120.3826, "start_hour": 19, "end_hour": 8}))
