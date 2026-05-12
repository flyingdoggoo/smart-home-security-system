from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from app.api.routes import router
from app.core.config import get_settings
from app.core.event_store import EventStore
from app.core.state import StateStore
from app.services.blynk_service import BlynkService
from app.services.blynk_poller import BlynkPoller
from app.services.controller import SmartHomeController
from app.services.face_service import FaceService
from app.services.mqtt_service import MqttService
from app.services.vision_service import VisionService

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    event_store = EventStore(settings.sqlite_path)
    state = StateStore(smoothing_window=settings.face_smoothing_window)
    blynk = BlynkService(settings)
    controller = SmartHomeController(settings=settings, state=state, event_store=event_store, blynk=blynk)
    face_service = FaceService(settings)
    mqtt_service = MqttService(settings, telemetry_handler=controller.handle_telemetry)
    controller.attach_mqtt(mqtt_service)
    vision_service = VisionService(settings=settings, face_service=face_service, controller=controller)
    blynk_poller = BlynkPoller(blynk=blynk, controller=controller)

    app.state.settings = settings
    app.state.event_store = event_store
    app.state.state_store = state
    app.state.controller = controller
    app.state.face_service = face_service
    app.state.mqtt_service = mqtt_service
    app.state.vision_service = vision_service
    app.state.blynk_poller = blynk_poller

    event_store.add_event(
        event_type="system_boot",
        severity="info",
        message="Smart Home backend started.",
        payload={"camera_capture_url": settings.camera_capture_url},
    )

    mqtt_service.start()
    vision_service.start()
    blynk_poller.start()

    yield

    vision_service.stop()
    blynk_poller.stop()
    mqtt_service.stop()
    event_store.add_event(
        event_type="system_shutdown",
        severity="info",
        message="Smart Home backend stopped.",
    )


app = FastAPI(title="Smart Home Guardian API", version="0.1.0", lifespan=lifespan)
app.include_router(router)

static_dir = Path(__file__).resolve().parent / "static"
app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")
