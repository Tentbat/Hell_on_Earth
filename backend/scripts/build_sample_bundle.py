"""Builds the sample bundle shipped inside the iOS app (Seattle to Denver), with
no network access needed. Run from the backend directory:
    python scripts/build_sample_bundle.py
"""
from __future__ import annotations

import asyncio
import json
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.schemas import CloudSample, TurbulenceSample, dump  # noqa: E402
from app.services import bundle_builder  # noqa: E402

OUT = Path(__file__).resolve().parents[2] / "ios" / "EarthFromAbove" / "Resources" / "SampleBundle.json"


def main() -> None:
    b = asyncio.run(bundle_builder.build("AS123", date(2026, 11, 1), include_weather=False))
    total = b.route.points[-1].elapsedSeconds
    # Illustrative weather so the sample shows the visibility strip and ride outlook.
    b.clouds = [CloudSample(elapsedSeconds=t * total, cloudFraction=f) for t, f in
                [(0, 0.8), (0.1, 0.6), (0.25, 0.2), (0.5, 0.1), (0.7, 0.3), (0.85, 0.5), (1.0, 0.2)]]
    b.turbulence = [TurbulenceSample(elapsedSeconds=0.05 * total, level="light", cause="lowLevel"),
                    TurbulenceSample(elapsedSeconds=0.4 * total, level="smooth", cause="unknown"),
                    TurbulenceSample(elapsedSeconds=0.8 * total, level="moderate", cause="mountainWave"),
                    TurbulenceSample(elapsedSeconds=0.95 * total, level="light", cause="lowLevel")]
    b.notes.append("Sample bundle built into the app. Cloud and turbulence values are illustrative.")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(dump(b), indent=1))
    print(f"wrote {OUT} ({OUT.stat().st_size // 1024} KB, {len(b.features)} features, {len(b.lines)} lines)")


if __name__ == "__main__":
    main()
