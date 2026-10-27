"""Loads the curated seed data. In production the feature and line sets come
from the data pipeline (OpenStreetMap, Wikidata, GeoNames, dam and power plant
databases, Natural Earth borders); the curated files are the bootstrap."""
from __future__ import annotations

import json
from functools import lru_cache

from .. import config
from ..schemas import Feature, LineFeature


@lru_cache
def features() -> list[Feature]:
    out: list[Feature] = []
    for path in sorted(config.DATA_DIR.glob("features_*.json")):
        out.extend(Feature(**f) for f in json.loads(path.read_text())["features"])
    return out


@lru_cache
def lines() -> list[LineFeature]:
    out: list[LineFeature] = []
    for path in sorted(config.DATA_DIR.glob("lines_*.json")):
        out.extend(LineFeature(**f) for f in json.loads(path.read_text())["lines"])
    return out


@lru_cache
def airports() -> dict:
    return json.loads((config.DATA_DIR / "airports.json").read_text())


@lru_cache
def aircraft_types() -> dict:
    return json.loads((config.DATA_DIR / "aircraft_types.json").read_text())
