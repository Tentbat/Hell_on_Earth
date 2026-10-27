"""Pydantic models matching the Swift Codable types in EarthFromAboveCore.
Field names are camelCase on purpose: Swift's default Codable keys are the
property names, and the iOS decoder uses plain ISO 8601 without fractional
seconds, so dates are serialised by `iso_z`."""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field


def iso_z(dt: datetime) -> str:
    """ISO 8601 in UTC with no fractional seconds, which Swift's .iso8601 strategy requires."""
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


class Model(BaseModel):
    model_config = ConfigDict(populate_by_name=True)


class Coordinate(Model):
    latitude: float
    longitude: float


class RoutePoint(Model):
    coordinate: Coordinate
    altitudeMeters: float
    elapsedSeconds: float


class RouteModel(Model):
    points: list[RoutePoint]


Category = Literal[
    "volcano", "faultLine", "crater", "glacier", "canyon", "desert", "saltFlat", "karst", "riverForm", "mountain",
    "forest", "wetland", "reef", "biomeTransition", "wildfireScar", "protectedArea",
    "lake", "reservoirDam", "river", "coastline", "estuary", "seaIce",
    "city", "irrigation", "agriculture", "mine", "windFarm", "solarFarm", "powerPlant", "port", "bridge", "airport",
    "highway", "railway", "border",
    "historicSite", "battlefield", "ghostTown", "geoglyph", "worldHeritage",
    "cloud", "contrail", "opticalPhenomenon", "sunriseSunset", "aurora", "lightning", "cityLights", "otherAircraft",
]


class Feature(Model):
    id: str
    name: str
    category: Category
    coordinate: Coordinate
    radiusMeters: float = 2000
    salience: float = 0.5
    summary: str
    detail: Optional[str] = None
    kidSummary: Optional[str] = None
    attribution: Optional[str] = None
    wikipediaTitle: Optional[str] = None
    spottingTip: Optional[str] = None
    elevationMeters: Optional[float] = None


class LineFeature(Model):
    id: str
    name: str
    category: Category
    points: list[Coordinate]
    summary: str
    kidSummary: Optional[str] = None
    leftRegion: Optional[str] = None
    rightRegion: Optional[str] = None


class CloudSample(Model):
    elapsedSeconds: float
    cloudFraction: float
    cloudTopMeters: Optional[float] = None


class TurbulenceSample(Model):
    elapsedSeconds: float
    level: Literal["smooth", "light", "moderate", "severe"]
    cause: Literal["jetStream", "mountainWave", "convection", "clearAir", "lowLevel", "unknown"]


class FlightInfo(Model):
    flightNumber: str
    airline: Optional[str] = None
    originCode: str
    originName: str
    destinationCode: str
    destinationName: str
    scheduledDeparture: Optional[datetime] = None
    scheduledArrival: Optional[datetime] = None
    originTimeZone: Optional[str] = None
    destinationTimeZone: Optional[str] = None


class AircraftInfo(Model):
    typeCode: str
    typeName: str
    registration: Optional[str] = None
    manufacturedYear: Optional[int] = None
    engines: Optional[str] = None
    seatLettersPerRow: Optional[int] = None
    notes: Optional[str] = None
    typicalCruiseAltitudeMeters: Optional[float] = None
    typicalCruiseSpeedMetersPerSecond: Optional[float] = None


class RouteBundle(Model):
    formatVersion: int = 1
    flight: FlightInfo
    aircraft: Optional[AircraftInfo] = None
    route: RouteModel
    features: list[Feature]
    lines: list[LineFeature] = Field(default_factory=list)
    clouds: list[CloudSample] = Field(default_factory=list)
    turbulence: list[TurbulenceSample] = Field(default_factory=list)
    generatedAt: datetime
    notes: list[str] = Field(default_factory=list)


def dump(model: BaseModel) -> dict:
    """JSON-ready dict with Swift-compatible dates and no nulls for optionals."""
    data = model.model_dump(mode="python", exclude_none=True)
    return _convert(data)


def _convert(v):
    if isinstance(v, datetime):
        return iso_z(v)
    if isinstance(v, dict):
        return {k: _convert(x) for k, x in v.items()}
    if isinstance(v, list):
        return [_convert(x) for x in v]
    return v


# ---- API request/response models (match APIClient in the app) ----

class FlightSearchResult(Model):
    flightNumber: str
    airline: Optional[str] = None
    originCode: str
    destinationCode: str
    scheduledDeparture: Optional[datetime] = None


class LivePosition(Model):
    latitude: float
    longitude: float
    altitudeMeters: Optional[float] = None
    trackDegrees: Optional[float] = None
    groundSpeedMetersPerSecond: Optional[float] = None
    time: datetime


class CameraPose(Model):
    position: Coordinate
    heightAboveGroundMeters: float
    trackDegrees: float
    side: Literal["left", "right"]
    depressionDegrees: float
    yawOffsetDegrees: float = 0
    horizontalFOVDegrees: float = 69
    verticalFOVDegrees: float = 54


class ExplainRequest(Model):
    imageBase64: str
    mediaType: str = "image/jpeg"
    pose: CameraPose
    elapsedSeconds: float
    flightNumber: str
    candidates: list[str] = Field(default_factory=list)
    kidBand: Optional[Literal["explorer", "navigator"]] = None
    question: Optional[str] = None


class ExplainResponse(Model):
    title: str
    explanation: str
    matchedFeatureID: Optional[str] = None
    confidence: Literal["high", "medium", "low"]
    followUps: list[str] = Field(default_factory=list)
    model: Optional[str] = None


class SightingCreate(Model):
    circleCode: str
    title: str
    note: Optional[str] = None
    featureID: Optional[str] = None
    latitude: float
    longitude: float
    elapsedSeconds: float
    flightNumber: str
    imageBase64: Optional[str] = None


class Sighting(Model):
    id: str
    featureID: Optional[str] = None
    title: str
    note: Optional[str] = None
    latitude: float
    longitude: float
    elapsedSeconds: float
    flightNumber: str
    createdAt: datetime
    imageURL: Optional[str] = None
