import asyncio
import json
from datetime import date

import pytest

from app.schemas import RouteBundle, dump
from app.services import bundle_builder, corridor, data


def test_seed_data_loads():
    assert len(data.features()) > 50
    assert len(data.lines()) > 10
    assert "SEA" in data.airports() and "DEN" in data.airports()


def test_bundle_sea_den_offline():
    b = asyncio.run(bundle_builder.build("AS123", date(2026, 11, 1), include_weather=False))
    assert b.flight.originCode == "SEA" and b.flight.destinationCode == "DEN"
    assert b.aircraft and b.aircraft.typeCode == "B738" and b.aircraft.seatLettersPerRow == 6
    names = {f.name for f in b.features}
    assert "Mount Rainier" in names
    assert "Great Salt Lake" in names or "Yellowstone" in names
    assert "Manhattan" not in names
    line_ids = {l.id for l in b.lines}
    assert "continental-divide" in line_ids
    assert "wa-or" in line_ids
    # Swift-compatible JSON: camelCase keys, ISO dates without fractions, no nulls.
    j = dump(b)
    s = json.dumps(j)
    assert "null" not in s
    assert j["generatedAt"].endswith("Z") and "." not in j["generatedAt"]
    assert j["route"]["points"][0]["coordinate"]["latitude"] == pytest.approx(47.449, abs=0.01)
    # Round trip through the schema.
    RouteBundle(**j)


def test_airport_pair_fallback():
    b = asyncio.run(bundle_builder.build("LAX-JFK", date(2026, 11, 1), include_weather=False))
    assert b.flight.originCode == "LAX" and b.flight.destinationCode == "JFK"
    assert b.route.points[-1].elapsedSeconds > 4 * 3600


def test_unknown_flight_raises():
    with pytest.raises(bundle_builder.FlightNotFound):
        asyncio.run(bundle_builder.build("ZZ9999", date(2026, 11, 1), include_weather=False))


def test_corridor_excludes_far_features():
    pts = asyncio.run(bundle_builder.build("AS123", date(2026, 11, 1), include_weather=False)).route.points
    raw = [p.model_dump() for p in pts]
    feats = corridor.features_in_corridor(raw, data.features(), 150_000)
    assert all(f.coordinate.longitude < -100 for f in feats)
