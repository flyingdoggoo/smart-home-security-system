from __future__ import annotations

import logging
import threading
import time

import cv2
import numpy as np
import requests

from app.core.config import Settings
from app.services.controller import SmartHomeController
from app.services.face_service import FaceService

logger = logging.getLogger(__name__)


class VisionService:
    def __init__(
        self,
        settings: Settings,
        face_service: FaceService,
        controller: SmartHomeController,
    ) -> None:
        self.settings = settings
        self.face_service = face_service
        self.controller = controller
        self._thread: threading.Thread | None = None
        self._stop_event = threading.Event()

    def start(self) -> None:
        if self._thread and self._thread.is_alive():
            return
        self._stop_event.clear()
        self._thread = threading.Thread(target=self._run_loop, name="vision-service", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop_event.set()
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=2)

    def _run_loop(self) -> None:
        logger.info("Vision worker started: %s", self.settings.camera_capture_url)
        interval = max(0.2, self.settings.vision_interval_sec)

        while not self._stop_event.is_set():
            started = time.time()
            try:
                frame = self._fetch_frame()
                if frame is not None:
                    result = self.face_service.classify(frame)
                    self.controller.handle_vision_result(result)
            except Exception as exc:
                logger.warning("Vision cycle failed: %s", exc)

            try:
                self.controller.tick()
            except Exception as exc:
                logger.warning("Tick failed: %s", exc)

            elapsed = time.time() - started
            sleep_time = max(0.01, interval - elapsed)
            self._stop_event.wait(sleep_time)

        logger.info("Vision worker stopped")

    def _fetch_frame(self) -> np.ndarray | None:
        try:
            response = requests.get(self.settings.camera_capture_url, timeout=3)
            response.raise_for_status()
        except requests.RequestException as exc:
            logger.warning("Camera capture request failed: %s", exc)
            return None

        image_array = np.frombuffer(response.content, dtype=np.uint8)
        frame = cv2.imdecode(image_array, cv2.IMREAD_COLOR)
        if frame is None:
            logger.warning("Failed decoding camera JPEG frame")
            return None
        return frame

