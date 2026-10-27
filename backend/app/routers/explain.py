from __future__ import annotations

from fastapi import APIRouter, Header, HTTPException
from fastapi.responses import JSONResponse

from .. import config
from ..schemas import ExplainRequest, dump
from ..services import data, explain as explain_service, quota

router = APIRouter(prefix="/v1", tags=["explain"])


@router.post("/explain")
async def explain(req: ExplainRequest, x_device_id: str | None = Header(default=None)):
    if len(req.imageBase64) > 6 * 1024 * 1024:
        raise HTTPException(413, "Image too large; resize to under 1600 px.")
    device = x_device_id or "anonymous"
    if not quota.allow(device, req.flightNumber):
        raise HTTPException(429, f"Free limit of {config.FREE_EXPLANATIONS_PER_FLIGHT} explanations per flight reached.")
    by_id = {f.id: f for f in data.features()}
    candidates = [by_id[c] for c in req.candidates if c in by_id]
    resp = await explain_service.explain(req, candidates)
    return JSONResponse(dump(resp))
