from __future__ import annotations

from datetime import date

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import JSONResponse

from ..schemas import dump
from ..services import bundle_builder

router = APIRouter(prefix="/v1/bundles", tags=["bundles"])


@router.get("")
async def get_bundle(flight: str = Query(..., min_length=3), date_: date = Query(..., alias="date"),
                     weather: bool = Query(True)):
    try:
        b = await bundle_builder.build(flight, date_, include_weather=weather)
    except bundle_builder.FlightNotFound as e:
        raise HTTPException(404, str(e))
    return JSONResponse(dump(b))
