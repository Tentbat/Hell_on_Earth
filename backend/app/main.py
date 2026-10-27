"""Earth from Above backend.

Run locally:  uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
Docs:         http://localhost:8000/docs
"""
from __future__ import annotations

from fastapi import FastAPI

from . import config
from .routers import bundles, explain, flights, sightings

app = FastAPI(title="Earth from Above API", version="0.1.0",
              description="Route bundles, live flight data, photo explanations and shared sightings.")
app.include_router(flights.router)
app.include_router(bundles.router)
app.include_router(explain.router)
app.include_router(sightings.router)


@app.get("/health")
async def health():
    return {"ok": True,
            "schedules": "aerodatabox" if config.AERODATABOX_KEY else "static demo table",
            "adsb": "opensky (authenticated)" if config.OPENSKY_USER else "opensky (anonymous, live only)",
            "explain": config.EXPLAIN_MODEL if config.ANTHROPIC_API_KEY else "offline fallback (no ANTHROPIC_API_KEY)",
            "weather": "open-meteo" if config.ENABLE_WEATHER else "disabled"}
