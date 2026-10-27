"""Assembles a RouteBundle for a flight."""
from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Optional

from .. import config
from ..schemas import FlightInfo, RouteBundle, RouteModel, RoutePoint
from . import aircraft, corridor, data, flights, route_predictor, weather


class FlightNotFound(Exception):
    pass


async def build(flight: str, day: date, include_weather: Optional[bool] = None) -> RouteBundle:
    lk = await flights.lookup(flight, day)
    if lk is None:
        raise FlightNotFound(
            f"Flight {flight} on {day} not found. Without a schedules API key, use a demo flight (AS123, UA1234, DL456, AA100, WN2000) or an airport pair like SEA-DEN.")
    ap = data.airports()
    if lk.origin not in ap or lk.destination not in ap:
        raise FlightNotFound(f"Airport {lk.origin} or {lk.destination} is not in the airport table yet.")

    points, route_note = await route_predictor.predict(lk.flight_number, lk.origin, lk.destination, day, lk.aircraft_type)
    feats = corridor.features_in_corridor(points, data.features(), config.CORRIDOR_HALF_WIDTH_M)
    lines = corridor.lines_near_corridor(points, data.lines(), config.CORRIDOR_HALF_WIDTH_M)

    notes = [route_note,
             f"{len(feats)} points of interest and {len(lines)} borders and rivers within {int(config.CORRIDOR_HALF_WIDTH_M / 1000)} km of the route.",
             "Points of interest are from the curated bootstrap set; coordinates are approximate to a few kilometres."]
    clouds, turb = [], []
    if include_weather if include_weather is not None else config.ENABLE_WEATHER:
        clouds, turb, wnote = await weather.clouds_and_turbulence(points, lk.departure)
        notes.append(wnote)

    o, d = ap[lk.origin], ap[lk.destination]
    return RouteBundle(
        flight=FlightInfo(flightNumber=lk.flight_number, airline=lk.airline, originCode=lk.origin, originName=o["city"],
                          destinationCode=lk.destination, destinationName=d["city"], scheduledDeparture=lk.departure,
                          scheduledArrival=lk.arrival, originTimeZone=o["tz"], destinationTimeZone=d["tz"]),
        aircraft=aircraft.info(lk.aircraft_type, lk.registration),
        route=RouteModel(points=[RoutePoint(**p) for p in points]),
        features=feats, lines=lines, clouds=clouds, turbulence=turb,
        generatedAt=datetime.now(timezone.utc), notes=notes,
    )
