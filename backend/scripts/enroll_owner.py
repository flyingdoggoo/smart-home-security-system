from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np

BASE_DIR = Path(__file__).resolve().parents[1]


def _load_face_recognition():
    try:
        import face_recognition  # type: ignore
    except Exception as exc:
        raise RuntimeError(
            "face_recognition is required for enrollment. Install backend/requirements.txt first."
        ) from exc
    return face_recognition


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate owner face embeddings from image folder.")
    parser.add_argument(
        "--source-dir",
        default=str(BASE_DIR / "data/faces/owner_raw"),
        help="Folder that contains owner JPG/PNG images.",
    )
    parser.add_argument(
        "--output",
        default=str(BASE_DIR / "data/faces/owner_embeddings/owner_embeddings.npz"),
        help="Output NPZ file path.",
    )
    parser.add_argument(
        "--model",
        default="hog",
        choices=["hog", "cnn"],
        help="Face detector model.",
    )
    parser.add_argument(
        "--min-count",
        type=int,
        default=10,
        help="Minimum number of valid embeddings required to save.",
    )
    return parser.parse_args()


def image_paths(source_dir: Path) -> list[Path]:
    exts = {".jpg", ".jpeg", ".png"}
    return sorted([p for p in source_dir.rglob("*") if p.suffix.lower() in exts])


def main() -> None:
    args = parse_args()
    source_dir = Path(args.source_dir)
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    if not source_dir.exists():
        raise FileNotFoundError(f"Source dir not found: {source_dir}")

    face_recognition = _load_face_recognition()
    files = image_paths(source_dir)
    if not files:
        raise RuntimeError(f"No images found in {source_dir}")

    embeddings: list[np.ndarray] = []
    accepted_files: list[str] = []
    rejected: dict[str, str] = {}

    for fp in files:
        try:
            image = face_recognition.load_image_file(str(fp))
            locations = face_recognition.face_locations(image, model=args.model)
            if len(locations) != 1:
                rejected[str(fp)] = f"expected exactly 1 face, got {len(locations)}"
                continue
            enc = face_recognition.face_encodings(image, known_face_locations=locations, num_jitters=1)
            if not enc:
                rejected[str(fp)] = "cannot encode face"
                continue
            embeddings.append(enc[0])
            accepted_files.append(str(fp))
        except Exception as exc:
            rejected[str(fp)] = f"error: {exc}"

    if len(embeddings) < args.min_count:
        report = {
            "accepted": len(embeddings),
            "required_min": args.min_count,
            "rejected": rejected,
        }
        raise RuntimeError(
            "Not enough valid owner images for enrollment:\n" + json.dumps(report, ensure_ascii=True, indent=2)
        )

    stack = np.vstack(embeddings).astype("float32")
    np.savez_compressed(output_path, embeddings=stack, files=np.array(accepted_files, dtype=object))

    print(f"Enrollment done. Saved {len(embeddings)} embeddings to: {output_path}")
    if rejected:
        print(f"Rejected files: {len(rejected)}")


if __name__ == "__main__":
    main()
