from __future__ import annotations

from typing import Any

import requests

from app.core.config import Settings


class BlynkService:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.enabled = bool(settings.blynk_enabled and settings.blynk_token)

    def update_pin(self, pin: str, value: Any) -> None:
        if not self.enabled:
            return
        pin_key = pin.lower()
        url = f"https://{self.settings.blynk_server}/external/api/update"
        params = {"token": self.settings.blynk_token, pin_key: value}
        try:
            requests.get(url, params=params, timeout=3)
        except requests.RequestException:
            return

    def sync_states(
        self,
        *,
        door_state: str,
        light_state: str,
        gas_alert: bool,
        face_label: str,
    ) -> None:
        self.update_pin(self.settings.blynk_pin_door, 1 if door_state == "unlocked" else 0)
        self.update_pin(self.settings.blynk_pin_light, 1 if light_state == "on" else 0)
        self.update_pin(self.settings.blynk_pin_gas, 1 if gas_alert else 0)
        self.update_pin(self.settings.blynk_pin_face, face_label)

    def log_event(self, code: str, description: str) -> None:
        if not self.enabled:
            return
        url = f"https://{self.settings.blynk_server}/external/api/logEvent"
        params = {
            "token": self.settings.blynk_token,
            "code": code,
            "description": description[:300],
        }
        try:
            requests.get(url, params=params, timeout=3)
        except requests.RequestException:
            return

    def get_pin(self, pin: str) -> str | None:
        if not self.enabled:
            return None
        pin_key = pin.lower()
        url = (
            f"https://{self.settings.blynk_server}/external/api/get"
            f"?token={self.settings.blynk_token}&{pin_key}"
        )
        try:
            response = requests.get(url, timeout=3)
            response.raise_for_status()
        except requests.RequestException:
            return None
        return response.text.strip()
