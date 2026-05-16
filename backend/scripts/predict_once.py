from __future__ import annotations

import argparse
import sys
from pathlib import Path

import cv2
import numpy as np
import requests

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.core.config import get_settings
from app.services.face_service import FaceService


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Predict face label from one ESP32-CAM capture.")
    parser.add_argument("--capture-url", required=True, help="Example: http://172.20.10.2/capture")
    parser.add_argument(
        "--embeddings",
        default=str(ROOT / "data/faces/owner_embeddings/owner_embeddings.npz"),
        help="Owner embeddings NPZ file.",
    )
    return parser.parse_args()


def fetch_frame(url: str) -> np.ndarray:
    response = requests.get(url, timeout=5)
    response.raise_for_status()
    arr = np.frombuffer(response.content, dtype=np.uint8)
    frame = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if frame is None:
        raise RuntimeError("Cannot decode JPEG frame")
    return frame


def main() -> None:
    args = parse_args()
    settings = get_settings()
    settings.owner_embeddings_file = args.embeddings
    face_service = FaceService(settings)

    frame = fetch_frame(args.capture_url)
    result = face_service.classify(frame)
    print(f"label={result.label}")
    print(f"confidence={result.confidence:.4f}")
    print(f"distance={result.face_distance}")
    print(f"face_count={result.face_count}")


if __name__ == "__main__":
    main()

