from __future__ import annotations

import threading
import time

from app.services.blynk_service import BlynkService
from app.services.controller import SmartHomeController


def _is_on(value: str | None) -> bool | None:
    if value is None:
        return None
    v = value.strip().lower()
    if v in {"1", "on", "true"}:
        return True
    if v in {"0", "off", "false"}:
        return False
    return None


class BlynkPoller:
    def __init__(self, blynk: BlynkService, controller: SmartHomeController, interval_sec: float = 2.0) -> None:
        self.blynk = blynk
        self.controller = controller
        self.interval_sec = max(1.0, interval_sec)
        self._stop_event = threading.Event()
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        if not self.blynk.enabled:
            return
        if self._thread and self._thread.is_alive():
            return
        self._stop_event.clear()
        self._thread = threading.Thread(target=self._run, name="blynk-poller", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop_event.set()
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=2)

    def _run(self) -> None:
        while not self._stop_event.is_set():
            snapshot = self.controller.state.snapshot()

            door_value = self.blynk.get_pin(self.blynk.settings.blynk_pin_door)
            light_value = self.blynk.get_pin(self.blynk.settings.blynk_pin_light)

            door_on = _is_on(door_value)
            light_on = _is_on(light_value)

            if door_on is not None:
                desired_door = "unlocked" if door_on else "locked"
                if desired_door != snapshot["door_state"]:
                    self.controller.request_door("open" if door_on else "close", source="blynk_app")

            if light_on is not None:
                desired_light = "on" if light_on else "off"
                if desired_light != snapshot["light_state"]:
                    self.controller.request_light("on" if light_on else "off", source="blynk_app")

            self._stop_event.wait(self.interval_sec)

