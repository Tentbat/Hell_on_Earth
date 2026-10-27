from app.geo import Coord, bearing, cross_track, distance, distance_to_polyline, synthesize_route

SEA = Coord(47.449, -122.309)
DEN = Coord(39.856, -104.673)


def test_distance_sea_den():
    assert abs(distance(SEA, DEN) / 1000 - 1640) < 15


def test_bearing_southeast():
    assert 90 < bearing(SEA, DEN) < 180


def test_cross_track_sign():
    assert cross_track(Coord(0.1, 0.5), Coord(0, 0), Coord(0, 1)) < 0
    assert cross_track(Coord(-0.1, 0.5), Coord(0, 0), Coord(0, 1)) > 0


def test_synthesized_route_profile():
    pts = synthesize_route([SEA, DEN], origin_elev=130, dest_elev=1655)
    assert pts[0]["altitudeMeters"] == 130
    assert abs(pts[-1]["altitudeMeters"] - 1655) < 1
    mid = pts[len(pts) // 2]
    assert abs(mid["altitudeMeters"] - 11000) < 1
    assert 110 * 60 < pts[-1]["elapsedSeconds"] < 160 * 60
    assert all(b["elapsedSeconds"] > a["elapsedSeconds"] for a, b in zip(pts, pts[1:]))


def test_distance_to_polyline():
    line = [Coord(0, 0), Coord(0, 1), Coord(0, 2)]
    d = distance_to_polyline(Coord(0.1, 1.5), line)
    assert abs(d - 11_100) < 150
