"""Friends-and-family shared sightings. A 'circle' is just a shared code; anyone
with the code can read and post. SQLite plus local image files for the
bootstrap; swap for Postgres and object storage when hosting."""
from __future__ import annotations

import base64
import sqlite3
import uuid
from datetime import datetime, timezone
from typing import Optional

from .. import config
from ..schemas import Sighting, SightingCreate

MAX_IMAGE_BYTES = 4 * 1024 * 1024


def _conn() -> sqlite3.Connection:
    config.STORAGE_DIR.mkdir(parents=True, exist_ok=True)
    c = sqlite3.connect(config.DB_PATH)
    c.execute("""CREATE TABLE IF NOT EXISTS sightings (
        id TEXT PRIMARY KEY, circle TEXT NOT NULL, feature_id TEXT, title TEXT NOT NULL, note TEXT,
        lat REAL, lon REAL, elapsed REAL, flight TEXT, created_at TEXT NOT NULL, image_path TEXT, device TEXT)""")
    c.execute("CREATE INDEX IF NOT EXISTS idx_circle ON sightings(circle, created_at)")
    return c


def normalise_code(code: str) -> str:
    return "".join(ch for ch in code.upper() if ch.isalnum() or ch == "-")


def create(req: SightingCreate, device_id: Optional[str], base_url: str) -> Sighting:
    circle = normalise_code(req.circleCode)
    if len(circle) < 6:
        raise ValueError("Circle codes need at least 6 letters or digits, so they are hard to guess.")
    sid = uuid.uuid4().hex
    image_path = None
    if req.imageBase64:
        raw = base64.b64decode(req.imageBase64)
        if len(raw) > MAX_IMAGE_BYTES:
            raise ValueError("Image too large.")
        if not raw.startswith(b"\xff\xd8"):
            raise ValueError("Only JPEG images are accepted.")
        img_dir = config.STORAGE_DIR / "images"
        img_dir.mkdir(parents=True, exist_ok=True)
        image_path = f"images/{sid}.jpg"
        (config.STORAGE_DIR / image_path).write_bytes(raw)
    now = datetime.now(timezone.utc)
    with _conn() as c:
        c.execute("INSERT INTO sightings VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
                  (sid, circle, req.featureID, req.title[:120], (req.note or "")[:1000] or None, req.latitude, req.longitude,
                   req.elapsedSeconds, req.flightNumber, now.isoformat(), image_path, device_id))
    return Sighting(id=sid, featureID=req.featureID, title=req.title[:120], note=req.note, latitude=req.latitude,
                    longitude=req.longitude, elapsedSeconds=req.elapsedSeconds, flightNumber=req.flightNumber,
                    createdAt=now, imageURL=f"{base_url}/v1/sightings/{sid}/image" if image_path else None)


def list_for(circle_code: str, base_url: str, limit: int = 100) -> list[Sighting]:
    circle = normalise_code(circle_code)
    with _conn() as c:
        rows = c.execute("SELECT id, feature_id, title, note, lat, lon, elapsed, flight, created_at, image_path FROM sightings "
                         "WHERE circle=? ORDER BY created_at DESC LIMIT ?", (circle, limit)).fetchall()
    return [Sighting(id=r[0], featureID=r[1], title=r[2], note=r[3], latitude=r[4], longitude=r[5], elapsedSeconds=r[6],
                     flightNumber=r[7], createdAt=datetime.fromisoformat(r[8]),
                     imageURL=f"{base_url}/v1/sightings/{r[0]}/image" if r[9] else None) for r in rows]


def image_path(sid: str) -> Optional[str]:
    with _conn() as c:
        row = c.execute("SELECT image_path FROM sightings WHERE id=?", (sid,)).fetchone()
    return str(config.STORAGE_DIR / row[0]) if row and row[0] else None
