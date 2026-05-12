from __future__ import annotations

import json
import logging
from datetime import datetime, timedelta, timezone
from typing import Any

from app.core.config import Settings
from app.core.event_store import EventStore
from app.core.state import StateStore
from app.services.blynk_service import BlynkService
from app.services.face_service import VisionResult
from app.services.mqtt_service import MqttService

logger = logging.getLogger(__name__)


class SmartHomeController:
    def __init__(
        self,
        settings: Settings,
        state: StateStore,
        event_store: EventStore,
        blynk: BlynkService,
    ) -> None:
        self.settings = settings
        self.state = state
        self.event_store = event_store
        self.blynk = blynk
        self.mqtt: MqttService | None = None

        self._last_label = "no_face"
        self._last_stranger_alert = datetime.min.replace(tzinfo=timezone.utc)
        self._last_gas_alert = datetime.min.replace(tzinfo=timezone.utc)

    def attach_mqtt(self, mqtt_service: MqttService) -> None:
        self.mqtt = mqtt_service

    def handle_telemetry(self, payload: dict[str, Any]) -> None:
        gas_value = float(payload.get("gas_value", 0.0))
        gas_alert_flag = bool(payload.get("gas_alert", False)) or gas_value >= self.settings.gas_threshold
        door_state = str(payload.get("door_state", "locked")).lower()
        light_state = str(payload.get("light_state", "off")).lower()

        self.state.update_telemetry(
            gas_value=gas_value,
            gas_alert=gas_alert_flag,
            door_state=door_state,
            light_state=light_state,
            source="mqtt_telemetry",
        )

        if gas_alert_flag:
            self._handle_gas_alert(gas_value)

        self._sync_blynk()

    def handle_vision_result(self, result: VisionResult) -> None:
        label = self.state.update_vision(
            label=result.label,
            confidence=result.confidence,
            face_distance=result.face_distance,
            face_count=result.face_count,
            source="vision",
        )

        self._publish_vision_state(label, result)

        if label == self._last_label:
            return

        self._last_label = label
        if label == "owner":
            self.request_door("open", source="face_owner")
            self.state.schedule_auto_relock(self.settings.auto_relock_sec)
            self._emit_event(
                event_type="owner_detected",
                severity="info",
                message="Owner face matched. Door opened automatically.",
                payload={"confidence": result.confidence, "distance": result.face_distance},
            )
        elif label == "stranger":
            self.request_door("close", source="face_stranger")
            self._handle_stranger_alert(result)
        else:
            # no_face: no direct door action, auto-relock ticker handles lock timeout.
            pass

        self._sync_blynk()

    def request_door(self, action: str, *, source: str = "manual") -> None:
        action_norm = action.lower()
        if action_norm not in {"open", "close"}:
            raise ValueError("Invalid door action. Use open|close")

        if self.mqtt:
            payload = "OPEN" if action_norm == "open" else "CLOSE"
            self.mqtt.publish(self.settings.mqtt_topic_door_cmd, payload)

        if action_norm == "open":
            self.state.set_door_state("unlocked", source=source)
            if source != "face_owner":
                self.state.schedule_auto_relock(self.settings.auto_relock_sec)
        else:
            self.state.set_door_state("locked", source=source)
            self.state.clear_relock_timer()

        self._emit_event(
            event_type="door_command",
            severity="info",
            message=f"Door command: {action_norm}",
            payload={"source": source},
        )
        self._sync_blynk()

    def request_light(self, action: str, *, source: str = "manual") -> None:
        action_norm = action.lower()
        if action_norm not in {"on", "off"}:
            raise ValueError("Invalid light action. Use on|off")

        if self.mqtt:
            payload = "ON" if action_norm == "on" else "OFF"
            self.mqtt.publish(self.settings.mqtt_topic_light_cmd, payload)

        self.state.set_light_state(action_norm, source=source)
        self._emit_event(
            event_type="light_command",
            severity="info",
            message=f"Light command: {action_norm}",
            payload={"source": source},
        )
        self._sync_blynk()

    def tick(self) -> None:
        if self.state.should_auto_relock():
            self.request_door("close", source="auto_relock")
            self._emit_event(
                event_type="auto_relock",
                severity="info",
                message="Auto relock executed after timeout.",
                payload={"timeout_sec": self.settings.auto_relock_sec},
            )

    def _handle_stranger_alert(self, result: VisionResult) -> None:
        now = datetime.now(timezone.utc)
        cooldown = timedelta(seconds=self.settings.stranger_alert_cooldown_sec)
        if now - self._last_stranger_alert < cooldown:
            return
        self._last_stranger_alert = now

        description = "Stranger detected near door. Door locked."
        self._emit_event(
            event_type="stranger_alert",
            severity="warning",
            message=description,
            payload={"confidence": result.confidence, "distance": result.face_distance},
        )
        self.blynk.log_event("intruder_alert", description)

    def _handle_gas_alert(self, gas_value: float) -> None:
        if self.state.snapshot()["door_state"] != "unlocked":
            self.request_door("open", source="gas_escape")
        now = datetime.now(timezone.utc)
        cooldown = timedelta(seconds=self.settings.gas_alert_cooldown_sec)
        if now - self._last_gas_alert < cooldown:
            return
        self._last_gas_alert = now

        description = f"Gas concentration high ({gas_value:.1f}). Emergency door open."
        self._emit_event(
            event_type="gas_alert",
            severity="critical",
            message=description,
            payload={"gas_value": gas_value, "threshold": self.settings.gas_threshold},
        )
        self.blynk.log_event("gas_alert", description)

    def _publish_vision_state(self, label: str, result: VisionResult) -> None:
        if not self.mqtt:
            return
        payload = json.dumps(
            {
                "label": label,
                "confidence": round(result.confidence, 4),
                "distance": result.face_distance,
                "face_count": result.face_count,
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }
        )
        self.mqtt.publish(self.settings.mqtt_topic_vision_state, payload)

    def _sync_blynk(self) -> None:
        snapshot = self.state.snapshot()
        self.blynk.sync_states(
            door_state=snapshot["door_state"],
            light_state=snapshot["light_state"],
            gas_alert=bool(snapshot["gas_alert"]),
            face_label=str(snapshot["face_label"]),
        )

    def _emit_event(
        self,
        *,
        event_type: str,
        severity: str,
        message: str,
        payload: dict[str, Any] | None = None,
    ) -> None:
        logger.info("%s | %s", event_type, message)
        self.event_store.add_event(
            event_type=event_type,
            severity=severity,
            message=message,
            payload=payload,
        )
