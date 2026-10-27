"""Per-device, per-flight quota for online explanations. Entitlements (premium,
flight pass) will come from App Store receipt validation; until then every
device is on the free tier and the limit is a plain counter in SQLite."""
from __future__ import annotations

import sqlite3

from .. import config


def _conn() -> sqlite3.Connection:
    config.STORAGE_DIR.mkdir(parents=True, exist_ok=True)
    c = sqlite3.connect(config.DB_PATH)
    c.execute("CREATE TABLE IF NOT EXISTS quota (device TEXT, flight TEXT, used INTEGER, PRIMARY KEY (device, flight))")
    c.execute("CREATE TABLE IF NOT EXISTS entitlements (device TEXT PRIMARY KEY, plan TEXT, expires TEXT)")
    return c


def is_premium(device: str) -> bool:
    with _conn() as c:
        row = c.execute("SELECT plan FROM entitlements WHERE device=?", (device,)).fetchone()
    return bool(row)


def allow(device: str, flight: str) -> bool:
    if is_premium(device):
        return True
    with _conn() as c:
        row = c.execute("SELECT used FROM quota WHERE device=? AND flight=?", (device, flight)).fetchone()
        used = row[0] if row else 0
        if used >= config.FREE_EXPLANATIONS_PER_FLIGHT:
            return False
        c.execute("INSERT INTO quota(device, flight, used) VALUES (?,?,1) ON CONFLICT(device, flight) DO UPDATE SET used=used+1",
                  (device, flight))
    return True
