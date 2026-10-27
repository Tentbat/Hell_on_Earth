"""Aircraft type details and, later, registry lookup (FAA registry for N-numbers)."""
from __future__ import annotations

from typing import Optional

from ..schemas import AircraftInfo
from .data import aircraft_types

ALIASES = {"737-800": "B738", "737 MAX 8": "B38M", "737-900": "B739", "737-700": "B737", "A320neo": "A20N",
           "A321neo": "A21N", "787-9": "B789", "787-8": "B788", "E175": "E175", "E170": "E170", "CRJ900": "CRJ9",
           "A220-300": "BCS3", "A220-100": "BCS1", "777-300ER": "B77W", "777-200": "B772", "757-200": "B752"}


def info(type_code_or_name: Optional[str], registration: Optional[str] = None) -> Optional[AircraftInfo]:
    if not type_code_or_name:
        return None
    key = type_code_or_name.strip()
    types = aircraft_types()
    code = key.upper() if key.upper() in types else ALIASES.get(key)
    if code is None:
        for alias, c in ALIASES.items():
            if alias.lower() in key.lower():
                code = c
                break
    if code is None or code not in types:
        return AircraftInfo(typeCode=key, typeName=key, registration=registration)
    t = types[code]
    year = None
    if registration and registration.upper().startswith("N"):
        year = None  # FAA registry lookup goes here (https://registry.faa.gov); omitted in the bootstrap.
    return AircraftInfo(typeCode=code, typeName=t["name"], registration=registration, manufacturedYear=year,
                        engines=t.get("engines"), seatLettersPerRow=t.get("seats"), notes=t.get("notes"),
                        typicalCruiseAltitudeMeters=t.get("cruiseAltM"), typicalCruiseSpeedMetersPerSecond=t.get("cruiseSpeedMs"))
