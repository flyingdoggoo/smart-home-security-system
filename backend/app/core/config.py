from __future__ import annotations

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    app_name: str = "Smart Home Guardian"
    app_host: str = "0.0.0.0"
    app_port: int = 8000
    timezone: str = "Asia/Saigon"

    esp32_cam_base_url: str = "http://esp32cam.local"
    camera_capture_path: str = "/capture"
    camera_discovery_enabled: bool = True
    camera_discovery_cooldown_sec: float = 15.0
    camera_discovery_connect_timeout_sec: float = 1.2
    camera_discovery_read_timeout_sec: float = 2.5
    camera_discovery_max_workers: int = 48
    camera_host_hints: str = "esp32cam.local,esp32-cam.local"
    camera_subnet_hints: str = ""
    vision_interval_sec: float = 1.0
    face_detector_model: str = "hog"
    face_match_threshold: float = 0.5
    face_owner_confidence_threshold: float = 0.6
    face_smoothing_window: int = 5
    owner_embeddings_file: str = "data/faces/owner_embeddings/owner_embeddings.npz"

    auto_relock_sec: int = 12
    gas_threshold: float = 1800.0
    stranger_alert_cooldown_sec: int = 20
    gas_alert_cooldown_sec: int = 20

    mqtt_host: str = "localhost"
    mqtt_port: int = 1883
    mqtt_username: str = ""
    mqtt_password: str = ""
    mqtt_client_id: str = "smart-home-server"
    mqtt_topic_door_cmd: str = "home/io/cmd/door"
    mqtt_topic_light_cmd: str = "home/io/cmd/light"
    mqtt_topic_telemetry: str = "home/io/telemetry"
    mqtt_topic_vision_state: str = "home/vision/state"

    blynk_enabled: bool = False
    blynk_server: str = "blynk.cloud"
    blynk_token: str = ""
    blynk_pin_door: str = Field(default="V0")
    blynk_pin_light: str = Field(default="V1")
    blynk_pin_gas: str = Field(default="V2")
    blynk_pin_face: str = Field(default="V3")

    sqlite_path: str = "data/smart_home.db"

    @property
    def camera_capture_url(self) -> str:
        return f"{self.esp32_cam_base_url.rstrip('/')}{self.camera_capture_path}"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
