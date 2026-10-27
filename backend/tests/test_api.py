import base64
import os
import tempfile

import pytest
from fastapi.testclient import TestClient

os.environ["EFA_STORAGE_DIR"] = tempfile.mkdtemp()
os.environ["EFA_DB_PATH"] = os.path.join(os.environ["EFA_STORAGE_DIR"], "test.sqlite3")
os.environ["EFA_ENABLE_WEATHER"] = "0"
os.environ.pop("ANTHROPIC_API_KEY", None)

from app import config  # noqa: E402  (after env setup)
from app.main import app  # noqa: E402

client = TestClient(app)

TINY_JPEG = base64.b64encode(b"\xff\xd8\xff\xe0" + b"\x00" * 64 + b"\xff\xd9").decode()


def test_health():
    r = client.get("/health")
    assert r.status_code == 200 and r.json()["ok"]


def test_search_and_bundle():
    r = client.get("/v1/flights/search", params={"flight": "AS 123", "date": "2026-11-01"})
    assert r.status_code == 200 and r.json()[0]["originCode"] == "SEA"
    r = client.get("/v1/bundles", params={"flight": "AS123", "date": "2026-11-01", "weather": "false"})
    assert r.status_code == 200
    j = r.json()
    assert j["flight"]["destinationCode"] == "DEN" and len(j["features"]) > 5
    r = client.get("/v1/bundles", params={"flight": "ZZ1", "date": "2026-11-01"})
    assert r.status_code == 404


def test_explain_offline_fallback_and_quota():
    body = {"imageBase64": TINY_JPEG, "mediaType": "image/jpeg",
            "pose": {"position": {"latitude": 41.1, "longitude": -112.4}, "heightAboveGroundMeters": 9000, "trackDegrees": 130,
                     "side": "left", "depressionDegrees": 25},
            "elapsedSeconds": 4000, "flightNumber": "AS123", "candidates": ["great-salt-lake", "nope"]}
    headers = {"X-Device-Id": "test-device"}
    for i in range(config.FREE_EXPLANATIONS_PER_FLIGHT):
        r = client.post("/v1/explain", json=body, headers=headers)
        assert r.status_code == 200, r.text
        assert r.json()["matchedFeatureID"] == "great-salt-lake"
        assert r.json()["model"] == "offline"
    r = client.post("/v1/explain", json=body, headers=headers)
    assert r.status_code == 429


def test_sightings_roundtrip():
    body = {"circleCode": "weinstein-7f2k", "title": "Rainier!", "note": "Left side, huge", "featureID": "mt-rainier",
            "latitude": 47.0, "longitude": -121.9, "elapsedSeconds": 600, "flightNumber": "AS123", "imageBase64": TINY_JPEG}
    r = client.post("/v1/sightings", json=body)
    assert r.status_code == 200, r.text
    sid = r.json()["id"]
    assert r.json()["imageURL"].endswith(f"/v1/sightings/{sid}/image")
    r = client.get("/v1/sightings", params={"circle": "WEINSTEIN-7F2K"})
    assert r.status_code == 200 and r.json()[0]["title"] == "Rainier!"
    assert client.get(f"/v1/sightings/{sid}/image").status_code == 200
    assert client.get("/v1/sightings", params={"circle": "OTHERS-123"}).json() == []
    r = client.post("/v1/sightings", json={**body, "circleCode": "abc"})
    assert r.status_code == 400
