"""Flight lookup: turns a flight number and date into origin, destination,
schedule and aircraft type.

Providers are tried in order. With no API key configured, the static table
below answers for a handful of demo flights and anything else must be given
as 'ORIGIN-DEST' (for example 'SEA-DEN') so the app still works."""
from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import date, datetime, time, timezone
from typing import Optional

import httpx

from .. import config
from .data import airports


@dataclass
class FlightLookup:
    flight_number: str
    airline: Optional[str]
    origin: str
    destination: str
    departure: Optional[datetime]
    arrival: Optional[datetime]
    aircraft_type: Optional[str]
    registration: Optional[str] = None
    source: str = "static"


AIRLINES = {
    "AS": "Alaska Airlines", "UA": "United Airlines", "DL": "Delta Air Lines", "AA": "American Airlines",
    "WN": "Southwest Airlines", "B6": "JetBlue", "NK": "Spirit Airlines", "F9": "Frontier Airlines",
    "HA": "Hawaiian Airlines", "AC": "Air Canada", "WS": "WestJet", "AM": "Aeromexico", "Y4": "Volaris",
}

# Demo schedules for development without a schedules API key. Times are local-ish UTC placeholders.
STATIC = {
    "AS123": ("SEA", "DEN", time(14, 0), "B738"),
    "UA1234": ("SFO", "ORD", time(15, 0), "B739"),
    "DL456": ("SLC", "SEA", time(16, 30), "A321"),
    "AA100": ("JFK", "LAX", time(13, 0), "B772"),
    "WN2000": ("DEN", "LAS", time(18, 0), "B737"),
}

FLIGHT_RE = re.compile(r"^([A-Z0-9]{2,3})\s*(\d{1,4})$")
PAIR_RE = re.compile(r"^([A-Z]{3})-([A-Z]{3})$")


def normalise(flight: str) -> str:
    return flight.replace(" ", "").upper()


async def lookup(flight: str, day: date) -> Optional[FlightLookup]:
    f = normalise(flight)
    if m := PAIR_RE.match(f):
        o, d = m.group(1), m.group(2)
        if o in airports() and d in airports():
            return FlightLookup(f, None, o, d, datetime.combine(day, time(12, 0), tzinfo=timezone.utc), None, None, source="pair")
        return None
    if config.AERODATABOX_KEY:
        if r := await _aerodatabox(f, day):
            return r
    if f in STATIC:
        o, d, t, ac = STATIC[f]
        m = FLIGHT_RE.match(f)
        airline = AIRLINES.get(m.group(1)) if m else None
        return FlightLookup(f, airline, o, d, datetime.combine(day, t, tzinfo=timezone.utc), None, ac)
    return None


async def _aerodatabox(flight: str, day: date) -> Optional[FlightLookup]:
    """AeroDataBox via RapidAPI. Returns None on any failure so the caller falls back."""
    url = f"https://aerodatabox.p.rapidapi.com/flights/number/{flight}/{day.isoformat()}"
    headers = {"X-RapidAPI-Key": config.AERODATABOX_KEY, "X-RapidAPI-Host": "aerodatabox.p.rapidapi.com"}
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            r = await client.get(url, headers=headers, params={"withAircraftImage": "false", "withLocation": "false"})
            r.raise_for_status()
            legs = r.json()
    except Exception:
        return None
    if not legs:
        return None
    leg = legs[0]
    dep = leg.get("departure", {})
    arr = leg.get("arrival", {})

    def parse(block):
        s = (block.get("scheduledTime") or {}).get("utc")
        return datetime.fromisoformat(s.replace("Z", "+00:00")) if s else None

    return FlightLookup(
        flight_number=flight,
        airline=(leg.get("airline") or {}).get("name"),
        origin=(dep.get("airport") or {}).get("iata", ""),
        destination=(arr.get("airport") or {}).get("iata", ""),
        departure=parse(dep), arrival=parse(arr),
        aircraft_type=(leg.get("aircraft") or {}).get("model"),
        registration=(leg.get("aircraft") or {}).get("reg"),
        source="aerodatabox",
    )
