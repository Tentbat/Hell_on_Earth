from __future__ import annotations

from datetime import date, datetime, timezone

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import JSONResponse

from ..schemas import FlightSearchResult, LivePosition, dump
from ..services import flights, live

router = APIRouter(prefix="/v1/flights", tags=["flights"])


@router.get("/search")
async def search(flight: str = Query(..., min_length=3), date_: date = Query(..., alias="date")):
    lk = await flights.lookup(flight, date_)
    if lk is None:
        return JSONResponse([])
    r = FlightSearchResult(flightNumber=lk.flight_number, airline=lk.airline, originCode=lk.origin,
                           destinationCode=lk.destination, scheduledDeparture=lk.departure)
    return JSONResponse([dump(r)])


@router.get("/{flight}/live")
async def live_position(flight: str):
    pos = await live.position(flights.normalise(flight))
    if pos is None:
        raise HTTPException(404, "No live position available for this flight.")
    return JSONResponse(dump(pos))
