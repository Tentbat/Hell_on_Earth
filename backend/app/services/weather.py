"""Cloud cover and a turbulence heuristic along the route from Open-Meteo, a free
forecast API needing no key. Production adds NOAA pilot reports, SIGMETs and
the graphical turbulence guidance grid; this is the baseline that always works."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Optional

import httpx

from ..schemas import CloudSample, TurbulenceSample


def _sample_indices(points: list[dict], n: int) -> list[int]:
    if len(points) <= n:
        return list(range(len(points)))
    step = (len(points) - 1) / (n - 1)
    return [round(i * step) for i in range(n)]


async def clouds_and_turbulence(points: list[dict], departure: Optional[datetime], samples: int = 12
                                ) -> tuple[list[CloudSample], list[TurbulenceSample], str]:
    """Returns cloud samples, turbulence samples and a note. Never raises."""
    dep = departure or datetime.now(timezone.utc)
    if dep.tzinfo is None:
        dep = dep.replace(tzinfo=timezone.utc)
    idx = _sample_indices(points, samples)
    lats = ",".join(f"{points[i]['coordinate']['latitude']:.3f}" for i in idx)
    lons = ",".join(f"{points[i]['coordinate']['longitude']:.3f}" for i in idx)
    params = {
        "latitude": lats, "longitude": lons,
        "hourly": "cloud_cover,cloud_cover_low,cloud_cover_mid,cloud_cover_high,wind_speed_250hPa,wind_speed_300hPa",
        "forecast_days": 3, "timezone": "UTC", "wind_speed_unit": "ms",
    }
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            r = await client.get("https://api.open-meteo.com/v1/forecast", params=params)
            r.raise_for_status()
            data = r.json()
    except Exception as e:  # network blocked, API down, etc.
        return [], [], f"No weather data: {type(e).__name__}. Refresh the guide with a connection."
    if isinstance(data, dict):
        data = [data]
    clouds, turb = [], []
    for i, loc in zip(idx, data):
        elapsed = points[i]["elapsedSeconds"]
        when = dep + timedelta(seconds=elapsed)
        hourly = loc.get("hourly", {})
        times = hourly.get("time", [])
        if not times:
            continue
        key = when.strftime("%Y-%m-%dT%H:00")
        h = times.index(key) if key in times else min(range(len(times)), key=lambda k: abs(_parse(times[k]) - when))
        low = (hourly.get("cloud_cover_low") or [None])[h]
        mid = (hourly.get("cloud_cover_mid") or [None])[h]
        total = (hourly.get("cloud_cover") or [None])[h]
        # Ground is hidden by low and mid cloud; high cloud is usually above or near cruise level.
        hidden = max(low or 0, mid or 0) if (low is not None or mid is not None) else (total or 0)
        clouds.append(CloudSample(elapsedSeconds=elapsed, cloudFraction=min(1.0, hidden / 100.0)))
        w250 = (hourly.get("wind_speed_250hPa") or [None])[h]
        w300 = (hourly.get("wind_speed_300hPa") or [None])[h]
        wind = max(w250 or 0, w300 or 0)
        shear = abs((w250 or 0) - (w300 or 0))
        alt = points[i]["altitudeMeters"]
        if alt < 3000:
            turb.append(TurbulenceSample(elapsedSeconds=elapsed, level="light", cause="lowLevel"))
        elif shear > 20 or wind > 70:
            turb.append(TurbulenceSample(elapsedSeconds=elapsed, level="moderate", cause="jetStream"))
        elif shear > 12 or wind > 55:
            turb.append(TurbulenceSample(elapsedSeconds=elapsed, level="light", cause="jetStream"))
        else:
            turb.append(TurbulenceSample(elapsedSeconds=elapsed, level="smooth", cause="unknown"))
    return clouds, turb, "Cloud cover and winds aloft from the Open-Meteo forecast at departure time; turbulence is a wind-shear heuristic, not an official forecast."


def _parse(s: str) -> datetime:
    return datetime.fromisoformat(s).replace(tzinfo=timezone.utc)
