from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Calibrate MQ-2 threshold from baseline samples.")
    parser.add_argument(
        "--samples",
        required=True,
        help="Path to text/csv file containing one gas_value per line.",
    )
    parser.add_argument(
        "--sigma",
        type=float,
        default=3.0,
        help="Threshold = mean + sigma * std.",
    )
    return parser.parse_args()


def load_samples(path: Path) -> np.ndarray:
    values: list[float] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        line = line.split(",")[0].strip()
        values.append(float(line))
    if not values:
        raise RuntimeError("No numeric samples found.")
    return np.array(values, dtype=np.float64)


def main() -> None:
    args = parse_args()
    path = Path(args.samples)
    if not path.exists():
        raise FileNotFoundError(path)

    samples = load_samples(path)
    mean = float(np.mean(samples))
    std = float(np.std(samples))
    p95 = float(np.percentile(samples, 95))
    suggested = max(mean + args.sigma * std, p95 * 1.1)

    print(f"Samples       : {len(samples)}")
    print(f"Mean          : {mean:.2f}")
    print(f"Std           : {std:.2f}")
    print(f"P95           : {p95:.2f}")
    print(f"Suggested thr : {suggested:.2f}")


if __name__ == "__main__":
    main()

