from __future__ import annotations

import logging
from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np

from app.core.config import Settings

logger = logging.getLogger(__name__)


@dataclass
class VisionResult:
    label: str
    confidence: float
    face_distance: float | None
    face_count: int


class FaceService:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.owner_embeddings: np.ndarray | None = None
        self._face_recognition = None
        self._load_backend()
        self.reload_owner_embeddings()
        self._fallback_cascade = cv2.CascadeClassifier(
            cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
        )

    def _load_backend(self) -> None:
        try:
            import face_recognition  # type: ignore

            self._face_recognition = face_recognition
            logger.info("face_recognition backend enabled")
        except Exception as exc:  # pragma: no cover - optional runtime dependency
            logger.warning("face_recognition not available, fallback to Haar cascade only: %s", exc)
            self._face_recognition = None

    def reload_owner_embeddings(self) -> None:
        path = Path(self.settings.owner_embeddings_file)
        if not path.exists():
            self.owner_embeddings = None
            logger.warning("Owner embeddings not found at %s", path)
            return

        try:
            data = np.load(path)
            embeddings = data["embeddings"]
            if embeddings.ndim != 2 or embeddings.shape[1] != 128:
                raise ValueError("Owner embeddings must have shape [N, 128]")
            self.owner_embeddings = embeddings
            logger.info("Loaded %d owner embeddings", embeddings.shape[0])
        except Exception as exc:
            self.owner_embeddings = None
            logger.error("Failed loading owner embeddings from %s: %s", path, exc)

    def classify(self, frame_bgr: np.ndarray) -> VisionResult:
        if self._face_recognition is None:
            return self._classify_fallback(frame_bgr)
        return self._classify_with_embeddings(frame_bgr)

    def _classify_fallback(self, frame_bgr: np.ndarray) -> VisionResult:
        gray = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2GRAY)
        faces = self._fallback_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5)
        face_count = int(len(faces))
        if face_count == 0:
            return VisionResult(label="no_face", confidence=1.0, face_distance=None, face_count=0)
        return VisionResult(label="stranger", confidence=0.5, face_distance=None, face_count=face_count)

    def _classify_with_embeddings(self, frame_bgr: np.ndarray) -> VisionResult:
        face_recognition = self._face_recognition
        assert face_recognition is not None

        rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
        small = cv2.resize(rgb, (0, 0), fx=0.5, fy=0.5)

        try:
            locations = face_recognition.face_locations(small, model=self.settings.face_detector_model)
        except TypeError:
            locations = face_recognition.face_locations(small)

        face_count = len(locations)
        if face_count == 0:
            return VisionResult(label="no_face", confidence=1.0, face_distance=None, face_count=0)

        encodings = face_recognition.face_encodings(small, locations)
        if not encodings:
            return VisionResult(label="no_face", confidence=0.8, face_distance=None, face_count=0)

        if self.owner_embeddings is None or len(self.owner_embeddings) == 0:
            return VisionResult(label="stranger", confidence=0.7, face_distance=None, face_count=face_count)

        min_distances: list[float] = []
        owner_votes = 0
        for encoding in encodings:
            distances = face_recognition.face_distance(self.owner_embeddings, encoding)
            min_distance = float(np.min(distances))
            min_distances.append(min_distance)
            if min_distance <= self.settings.face_match_threshold:
                owner_votes += 1

        closest_distance = min(min_distances)
        confidence = max(0.0, min(1.0, 1.0 - closest_distance))

        if (
            owner_votes == len(encodings)
            and owner_votes > 0
            and confidence > self.settings.face_owner_confidence_threshold
        ):
            return VisionResult(
                label="owner",
                confidence=confidence,
                face_distance=closest_distance,
                face_count=face_count,
            )

        return VisionResult(
            label="stranger",
            confidence=confidence,
            face_distance=closest_distance,
            face_count=face_count,
        )
