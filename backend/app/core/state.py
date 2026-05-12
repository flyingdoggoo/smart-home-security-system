from __future__ import annotations

import threading
from collections import deque
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from typing import Any


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass
class SystemState:
    door_state: str = "locked"
    light_state: str = "off"
    gas_value: float = 0.0
    gas_alert: bool = False
    face_label: str = "no_face"
    face_confidence: float = 0.0
    face_distance: float | None = None
    face_count: int = 0
    source: str = "bootstrap"
    last_updated: str = field(default_factory=utc_now_iso)


class StateStore:
    def __init__(self, smoothing_window: int = 5) -> None:
        self._lock = threading.Lock()
        self._state = SystemState()
        self._label_window: deque[str] = deque(maxlen=max(1, smoothing_window))
        self._door_open_until: datetime | None = None

    def snapshot(self) -> dict[str, Any]:
        with self._lock:
            return {
                "door_state": self._state.door_state,
                "light_state": self._state.light_state,
                "gas_value": self._state.gas_value,
                "gas_alert": self._state.gas_alert,
                "face_label": self._state.face_label,
                "face_confidence": self._state.face_confidence,
                "face_distance": self._state.face_distance,
                "face_count": self._state.face_count,
                "source": self._state.source,
                "last_updated": self._state.last_updated,
            }

    def update_telemetry(
        self,
        *,
        gas_value: float | None = None,
        gas_alert: bool | None = None,
        door_state: str | None = None,
        light_state: str | None = None,
        source: str = "telemetry",
    ) -> None:
        with self._lock:
            if gas_value is not None:
                self._state.gas_value = gas_value
            if gas_alert is not None:
                self._state.gas_alert = gas_alert
            if door_state is not None:
                self._state.door_state = door_state
            if light_state is not None:
                self._state.light_state = light_state
            self._state.source = source
            self._state.last_updated = utc_now_iso()

    def update_vision(
        self,
        *,
        label: str,
        confidence: float,
        face_distance: float | None,
        face_count: int,
        source: str = "vision",
    ) -> str:
        with self._lock:
            self._label_window.append(label)
            smoothed = self._majority_label()
            self._state.face_label = smoothed
            self._state.face_confidence = confidence
            self._state.face_distance = face_distance
            self._state.face_count = face_count
            self._state.source = source
            self._state.last_updated = utc_now_iso()
            return smoothed

    def set_door_state(self, state: str, *, source: str = "rule") -> None:
        with self._lock:
            self._state.door_state = state
            self._state.source = source
            self._state.last_updated = utc_now_iso()

    def set_light_state(self, state: str, *, source: str = "rule") -> None:
        with self._lock:
            self._state.light_state = state
            self._state.source = source
            self._state.last_updated = utc_now_iso()

    def schedule_auto_relock(self, seconds: int) -> None:
        with self._lock:
            self._door_open_until = datetime.now(timezone.utc) + timedelta(seconds=seconds)

    def clear_relock_timer(self) -> None:
        with self._lock:
            self._door_open_until = None

    def should_auto_relock(self) -> bool:
        with self._lock:
            return self._state.door_state == "unlocked" and self._door_open_until is not None and datetime.now(timezone.utc) >= self._door_open_until

    def _majority_label(self) -> str:
        counts: dict[str, int] = {}
        for item in self._label_window:
            counts[item] = counts.get(item, 0) + 1
        return sorted(counts.items(), key=lambda x: (-x[1], x[0]))[0][0]

