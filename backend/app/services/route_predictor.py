"""Predicts the track an aircraft will fly.

Order of preference:
1. A recent actual track for the same flight number from an ADS-B history source
   (OpenSky, when credentials are configured). Day-to-day tracks are very similar.
2. Great-circle route between the airports, timed with a standard jet profile.

Both return the same shape: a list of timed RoutePoint dicts."""
from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from typing import Optional

import httpx

from .. import config
from ..geo import Coord, synthesize_route
from .data import airports, aircraft_types


def great_circle(origin: str, destination: str, aircraft_type: Optional[str] = None) -> list[dict]:
    a, b = airports()[origin], airports()[destination]
    ac = aircraft_types().get(aircraft_type or "", {})
    return synthesize_route(
        [Coord(a["lat"], a["lon"]), Coord(b["lat"], b["lon"])],
        origin_elev=a["elev"], dest_elev=b["elev"],
        cruise_alt=ac.get("cruiseAltM", 11_000), cruise_speed=ac.get("cruiseSpeedMs", 240.0),
    )


async def opensky_history(callsign: str, day: date) -> Optional[list[dict]]:
    """Fetch yesterday's (or the most recent) flight for this callsign and resample
    its track to timed points. Returns None when unavailable."""
    if not (config.OPENSKY_USER and config.OPENSKY_PASS):
        return None
    auth = (config.OPENSKY_USER, config.OPENSKY_PASS)
    end = datetime.combine(day, datetime.min.time(), tzinfo=timezone.utc)
    begin = end - timedelta(days=3)
    try:
        async with httpx.AsyncClient(timeout=20, auth=auth) as client:
            # OpenSky's flights endpoint is keyed by aircraft, so we look up recent flights
            # by callsign through the "all" endpoint filtered client-side.
            r = await client.get("https://opensky-network.org/api/flights/all",
                                 params={"begin": int(begin.timestamp()), "end": int(end.timestamp())})
            r.raise_for_status()
            flights = [f for f in r.json() if (f.get("callsign") or "").strip() == callsign]
            if not flights:
                return None
            f = sorted(flights, key=lambda x: x["firstSeen"])[-1]
            t = await client.get("https://opensky-network.org/api/tracks/all",
                                 params={"icao24": f["icao24"], "time": f["firstSeen"]})
            t.raise_for_status()
            path = t.json().get("path", [])
    except Exception:
        return None
    if len(path) < 10:
        return None
    t0 = path[0][0]
    pts = []
    for row in path:
        ts, lat, lon, alt = row[0], row[1], row[2], row[3]
        if lat is None or lon is None:
            continue
        pts.append({"coordinate": {"latitude": lat, "longitude": lon}, "altitudeMeters": alt or 0, "elapsedSeconds": ts - t0})
    return pts


async def predict(flight_number: str, origin: str, destination: str, day: date, aircraft_type: Optional[str]) -> tuple[list[dict], str]:
    hist = await opensky_history(flight_number, day)
    if hist:
        return hist, "Route from a recent actual track of this flight (ADS-B history)."
    return great_circle(origin, destination, aircraft_type), "Route is the great-circle path between the airports; real routes deviate by up to a few hundred kilometres for weather and traffic."
