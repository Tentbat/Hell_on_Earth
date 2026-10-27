"""Spherical geodesy mirroring the Swift Geodesy enum, so the backend and the app
agree on where things are."""
from __future__ import annotations

import math
from dataclasses import dataclass

R = 6_371_008.8


@dataclass(frozen=True)
class Coord:
    lat: float
    lon: float


def distance(a: Coord, b: Coord) -> float:
    p1, p2 = math.radians(a.lat), math.radians(b.lat)
    dp = p2 - p1
    dl = math.radians(b.lon - a.lon)
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * R * math.asin(min(1.0, math.sqrt(h)))


def bearing(a: Coord, b: Coord) -> float:
    p1, p2 = math.radians(a.lat), math.radians(b.lat)
    dl = math.radians(b.lon - a.lon)
    y = math.sin(dl) * math.cos(p2)
    x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl)
    return math.degrees(math.atan2(y, x)) % 360


def destination(start: Coord, bearing_deg: float, dist_m: float) -> Coord:
    d = dist_m / R
    t = math.radians(bearing_deg)
    p1, l1 = math.radians(start.lat), math.radians(start.lon)
    p2 = math.asin(math.sin(p1) * math.cos(d) + math.cos(p1) * math.sin(d) * math.cos(t))
    l2 = l1 + math.atan2(math.sin(t) * math.sin(d) * math.cos(p1), math.cos(d) - math.sin(p1) * math.sin(p2))
    lon = math.degrees(l2)
    if lon > 180:
        lon -= 360
    if lon < -180:
        lon += 360
    return Coord(math.degrees(p2), lon)


def intermediate(a: Coord, b: Coord, f: float) -> Coord:
    p1, l1 = math.radians(a.lat), math.radians(a.lon)
    p2, l2 = math.radians(b.lat), math.radians(b.lon)
    d = distance(a, b) / R
    if d < 1e-12:
        return a
    A = math.sin((1 - f) * d) / math.sin(d)
    B = math.sin(f * d) / math.sin(d)
    x = A * math.cos(p1) * math.cos(l1) + B * math.cos(p2) * math.cos(l2)
    y = A * math.cos(p1) * math.sin(l1) + B * math.cos(p2) * math.sin(l2)
    z = A * math.sin(p1) + B * math.sin(p2)
    return Coord(math.degrees(math.atan2(z, math.sqrt(x * x + y * y))), math.degrees(math.atan2(y, x)))


def cross_track(point: Coord, start: Coord, end: Coord) -> float:
    """Signed cross-track distance in metres; negative is left of the track."""
    d13 = distance(start, point) / R
    t13 = math.radians(bearing(start, point))
    t12 = math.radians(bearing(start, end))
    return math.asin(math.sin(d13) * math.sin(t13 - t12)) * R


def along_track(point: Coord, start: Coord, end: Coord) -> float:
    d13 = distance(start, point) / R
    xt = cross_track(point, start, end) / R
    c = math.cos(d13) / math.cos(xt)
    return math.acos(max(-1.0, min(1.0, c))) * R


def distance_to_polyline(point: Coord, line: list[Coord]) -> float:
    """Shortest distance from a point to a polyline, in metres."""
    best = float("inf")
    for a, b in zip(line, line[1:]):
        seg = distance(a, b)
        if seg < 1:
            best = min(best, distance(a, point))
            continue
        at = along_track(point, a, b)
        f = max(0.0, min(1.0, at / seg))
        p = intermediate(a, b, f)
        best = min(best, distance(p, point))
    return best


def synthesize_route(waypoints: list[Coord], origin_elev: float = 0, dest_elev: float = 0,
                     cruise_alt: float = 11_000, cruise_speed: float = 240.0,
                     climb_rate: float = 10.0, descent_rate: float = 8.0,
                     climb_speed: float = 160.0, descent_speed: float = 170.0,
                     spacing_m: float = 10_000) -> list[dict]:
    """Timed route points, same model as RouteModel.synthesize in Swift."""
    dense: list[Coord] = []
    for a, b in zip(waypoints, waypoints[1:]):
        n = max(1, int(distance(a, b) / spacing_m))
        for k in range(n):
            dense.append(intermediate(a, b, k / n))
    dense.append(waypoints[-1])
    cum = [0.0]
    for a, b in zip(dense, dense[1:]):
        cum.append(cum[-1] + distance(a, b))
    total = cum[-1]
    climb_h = max(0.0, cruise_alt - origin_elev)
    desc_h = max(0.0, cruise_alt - dest_elev)
    climb_d = climb_h / climb_rate * climb_speed
    desc_d = desc_h / descent_rate * descent_speed
    if climb_d + desc_d > total:
        s = total / (climb_d + desc_d)
        climb_d *= s
        desc_d *= s
        top = origin_elev + climb_d / climb_speed * climb_rate
    else:
        top = cruise_alt
    cruise_start, cruise_end = climb_d, total - desc_d
    climb_t = climb_d / climb_speed
    cruise_t = max(0.0, cruise_end - cruise_start) / cruise_speed
    pts = []
    for c, s in zip(dense, cum):
        if s <= cruise_start:
            f = s / climb_d if climb_d > 0 else 1
            t = s / climb_speed
            alt = origin_elev + (top - origin_elev) * f
        elif s <= cruise_end:
            t = climb_t + (s - cruise_start) / cruise_speed
            alt = top
        else:
            f = (s - cruise_end) / desc_d if desc_d > 0 else 1
            t = climb_t + cruise_t + (s - cruise_end) / descent_speed
            alt = top - (top - dest_elev) * f
        pts.append({"coordinate": {"latitude": c.lat, "longitude": c.lon}, "altitudeMeters": alt, "elapsedSeconds": t})
    return pts
