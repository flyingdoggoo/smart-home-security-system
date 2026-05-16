from __future__ import annotations

import argparse
import time
from pathlib import Path

import cv2
import numpy as np
import requests

BASE_DIR = Path(__file__).resolve().parents[1]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Capture owner dataset from ESP32-CAM /capture endpoint.")
    parser.add_argument("--capture-url", required=True, help="Example: http://10.104.86.173/capture")
    parser.add_argument(
        "--output-dir",
        default=str(BASE_DIR / "data/faces/owner_raw"),
        help="Folder to save accepted images.",
    )
    parser.add_argument("--target-count", type=int, default=60, help="Number of accepted images to save.")
    parser.add_argument("--interval", type=float, default=1.2, help="Seconds between captures.")
    parser.add_argument("--min-face-size", type=int, default=50, help="Minimum face width/height in pixels.")
    parser.add_argument("--min-blur-score", type=float, default=60.0, help="Laplacian variance threshold.")
    parser.add_argument("--min-brightness", type=float, default=40.0, help="Minimum average gray value.")
    parser.add_argument("--max-brightness", type=float, default=220.0, help="Maximum average gray value.")
    return parser.parse_args()


def detect_faces(gray: np.ndarray) -> list[tuple[int, int, int, int]]:
    cascade = cv2.CascadeClassifier(cv2.data.haarcascades + "haarcascade_frontalface_default.xml")
    faces = cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5)
    return [(int(x), int(y), int(w), int(h)) for x, y, w, h in faces]


def quality_ok(gray: np.ndarray, faces: list[tuple[int, int, int, int]], args: argparse.Namespace) -> bool:
    if len(faces) != 1:
        return False
    _, _, w, h = faces[0]
    if w < args.min_face_size or h < args.min_face_size:
        return False

    brightness = float(gray.mean())
    if brightness < args.min_brightness or brightness > args.max_brightness:
        return False

    blur_score = float(cv2.Laplacian(gray, cv2.CV_64F).var())
    return blur_score >= args.min_blur_score


def fetch_frame(url: str) -> np.ndarray | None:
    try:
        r = requests.get(url, timeout=3)
        r.raise_for_status()
    except requests.RequestException:
        return None
    arr = np.frombuffer(r.content, dtype=np.uint8)
    return cv2.imdecode(arr, cv2.IMREAD_COLOR)


def main() -> None:
    args = parse_args()
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    accepted = 0
    sampled = 0
    consecutive_fetch_failed = 0
    print(f"Start capture. Press Ctrl+C to stop.")
    print(f"Saving accepted images to: {output_dir.resolve()}")

    try:
        while accepted < args.target_count:
            frame = fetch_frame(args.capture_url)
            sampled += 1
            if frame is None:
                consecutive_fetch_failed += 1
                print(f"[{sampled}] frame fetch failed")
                if consecutive_fetch_failed >= 3:
                    print("Camera may be unstable/stuck. Check power/cable and avoid opening /stream in browser while capturing.")
                time.sleep(args.interval)
                continue
            consecutive_fetch_failed = 0

            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            faces = detect_faces(gray)
            if quality_ok(gray, faces, args):
                ts = int(time.time() * 1000)
                filename = output_dir / f"owner_{ts}.jpg"
                cv2.imwrite(str(filename), frame)
                accepted += 1
                print(f"[{sampled}] accepted={accepted}/{args.target_count} -> {filename.name}")
            else:
                print(f"[{sampled}] rejected faces={len(faces)}")

            time.sleep(args.interval)
    except KeyboardInterrupt:
        print("Capture interrupted by user.")

    print(f"Done. accepted={accepted}, sampled={sampled}")
    if accepted == 0:
        print("No accepted images were saved. Try lower thresholds or move face closer to camera.")


if __name__ == "__main__":
    main()
