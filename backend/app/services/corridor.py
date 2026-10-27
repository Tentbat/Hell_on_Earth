"""Selects the features and lines relevant to a route."""
from __future__ import annotations

from ..geo import Coord, distance_to_polyline
from ..schemas import Feature, LineFeature


def route_coords(points: list[dict]) -> list[Coord]:
    return [Coord(p["coordinate"]["latitude"], p["coordinate"]["longitude"]) for p in points]


def features_in_corridor(points: list[dict], features: list[Feature], half_width_m: float) -> list[Feature]:
    line = route_coords(points)
    # Thin the route for the distance test; 1 point per ~40 km is plenty.
    step = max(1, len(line) // 60)
    thin = line[::step] + [line[-1]]
    out = []
    for f in features:
        d = distance_to_polyline(Coord(f.coordinate.latitude, f.coordinate.longitude), thin)
        if d <= half_width_m + f.radiusMeters:
            out.append(f)
    return out


def lines_near_corridor(points: list[dict], lines: list[LineFeature], half_width_m: float) -> list[LineFeature]:
    """Keep lines that have any vertex within reach of the route, or that pass between
    route points (checked by a coarse bounding box overlap)."""
    line = route_coords(points)
    lats = [c.lat for c in line]
    lons = [c.lon for c in line]
    pad = half_width_m / 111_000 * 1.5
    box = (min(lats) - pad, max(lats) + pad, min(lons) - pad, max(lons) + pad)
    out = []
    for lf in lines:
        for p in lf.points:
            if box[0] <= p.latitude <= box[1] and box[2] <= p.longitude <= box[3]:
                out.append(lf)
                break
        else:
            # Long straight lines may have no vertex in the box but still cross it.
            for a, b in zip(lf.points, lf.points[1:]):
                if (min(a.latitude, b.latitude) <= box[1] and max(a.latitude, b.latitude) >= box[0]
                        and min(a.longitude, b.longitude) <= box[3] and max(a.longitude, b.longitude) >= box[2]):
                    out.append(lf)
                    break
    return out
