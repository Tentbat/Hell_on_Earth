from __future__ import annotations

from fastapi import APIRouter, Header, HTTPException, Query, Request
from fastapi.responses import FileResponse, JSONResponse

from ..schemas import SightingCreate, dump
from ..services import sightings

router = APIRouter(prefix="/v1/sightings", tags=["sightings"])


def _base(request: Request) -> str:
    return str(request.base_url).rstrip("/")


@router.post("")
async def create(req: SightingCreate, request: Request, x_device_id: str | None = Header(default=None)):
    try:
        s = sightings.create(req, x_device_id, _base(request))
    except ValueError as e:
        raise HTTPException(400, str(e))
    return JSONResponse(dump(s))


@router.get("")
async def list_(request: Request, circle: str = Query(..., min_length=6)):
    return JSONResponse([dump(s) for s in sightings.list_for(circle, _base(request))])


@router.get("/{sid}/image")
async def image(sid: str):
    path = sightings.image_path(sid)
    if not path:
        raise HTTPException(404)
    return FileResponse(path, media_type="image/jpeg")
