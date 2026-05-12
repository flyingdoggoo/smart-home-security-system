from __future__ import annotations

import json
import logging
from typing import Callable

import paho.mqtt.client as mqtt

from app.core.config import Settings

logger = logging.getLogger(__name__)


TelemetryHandler = Callable[[dict], None]


class MqttService:
    def __init__(self, settings: Settings, telemetry_handler: TelemetryHandler) -> None:
        self.settings = settings
        self.telemetry_handler = telemetry_handler
        self.client = self._build_client()
        self.connected = False

        if settings.mqtt_username:
            self.client.username_pw_set(settings.mqtt_username, settings.mqtt_password)

        self.client.on_connect = self._on_connect
        self.client.on_disconnect = self._on_disconnect
        self.client.on_message = self._on_message

    def _build_client(self) -> mqtt.Client:
        try:
            return mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=self.settings.mqtt_client_id)
        except TypeError:
            return mqtt.Client(client_id=self.settings.mqtt_client_id)

    def start(self) -> None:
        try:
            self.client.connect(self.settings.mqtt_host, self.settings.mqtt_port, keepalive=60)
            self.client.loop_start()
        except Exception as exc:
            logger.error("MQTT connect failed: %s", exc)

    def stop(self) -> None:
        try:
            self.client.loop_stop()
            self.client.disconnect()
        except Exception:
            return

    def publish(self, topic: str, payload: str) -> None:
        result = self.client.publish(topic, payload, qos=1, retain=False)
        if result.rc != mqtt.MQTT_ERR_SUCCESS:
            logger.warning("MQTT publish failed topic=%s rc=%s", topic, result.rc)

    def _on_connect(self, client: mqtt.Client, userdata, flags, reason_code, properties=None) -> None:
        self.connected = True
        logger.info("MQTT connected with reason code %s", reason_code)
        client.subscribe(self.settings.mqtt_topic_telemetry, qos=1)

    def _on_disconnect(self, client: mqtt.Client, userdata, flags_or_rc, reason_code=None, properties=None) -> None:
        self.connected = False
        logger.warning("MQTT disconnected")

    def _on_message(self, client: mqtt.Client, userdata, msg: mqtt.MQTTMessage) -> None:
        if msg.topic != self.settings.mqtt_topic_telemetry:
            return
        try:
            payload = json.loads(msg.payload.decode("utf-8"))
        except Exception as exc:
            logger.warning("Invalid telemetry payload: %s", exc)
            return
        self.telemetry_handler(payload)

