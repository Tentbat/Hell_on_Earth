"""Runtime configuration from environment variables. Everything has a safe default
so the server runs locally with no keys at all; keys only add live data."""
from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = Path(os.environ.get("EFA_DATA_DIR", ROOT / "data" / "curated"))
STORAGE_DIR = Path(os.environ.get("EFA_STORAGE_DIR", ROOT / "backend" / "storage"))
DB_PATH = Path(os.environ.get("EFA_DB_PATH", STORAGE_DIR / "efa.sqlite3"))

# Optional third-party keys. Absent keys disable the corresponding live source.
AERODATABOX_KEY = os.environ.get("AERODATABOX_KEY")          # schedules
OPENSKY_USER = os.environ.get("OPENSKY_USER")                # ADS-B live and history
OPENSKY_PASS = os.environ.get("OPENSKY_PASS")
ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY")      # photo explanations

# Feature flags
ENABLE_WEATHER = os.environ.get("EFA_ENABLE_WEATHER", "1") == "1"
ENABLE_WIKIPEDIA_ENRICHMENT = os.environ.get("EFA_ENABLE_WIKIPEDIA", "0") == "1"

CORRIDOR_HALF_WIDTH_M = float(os.environ.get("EFA_CORRIDOR_KM", "150")) * 1000
FREE_EXPLANATIONS_PER_FLIGHT = int(os.environ.get("EFA_FREE_EXPLANATIONS", "3"))
EXPLAIN_MODEL = os.environ.get("EFA_EXPLAIN_MODEL", "claude-opus-5-5")
