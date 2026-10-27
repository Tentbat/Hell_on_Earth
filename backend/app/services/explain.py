"""Photo explanation through the Claude API.

The model receives the photo plus everything the app already knows: where the
aircraft was, which way the camera pointed, how high, what season and time, and
the geometric candidates from the bundle. It returns a structured answer that
the app renders directly. Kid mode constrains tone and vocabulary and refuses
off-topic questions."""
from __future__ import annotations

import json
from typing import Optional

import anthropic

from .. import config
from ..schemas import ExplainRequest, ExplainResponse, Feature

SYSTEM = """You are the in-flight guide inside the Earth from Above app. A passenger has photographed the view from an airliner window and wants to know what they are looking at.

You are given the aircraft position, altitude above ground, camera pointing direction and the patch of ground the frame should cover, plus a ranked list of named features from our database that the geometry says could be in frame. The list can be wrong: the position may be off by tens of kilometres, and the photo may show something not in the database at all (a cloud formation, a river pattern, irrigation circles, a wildfire plume, a wind farm, a mine).

Rules:
- Identify what is actually visible in the image first. Use the candidate list to name things, but only when the image is consistent with them. Say when you are unsure.
- Explain the most interesting thing in the frame: what it is, how it formed or why it is there, and one detail worth looking for. Be concrete and accurate. If the image is mostly cloud, explain the cloud type and what it says about the weather.
- Keep the explanation under 180 words unless the passenger asked a specific question that needs more.
- Offer up to three short follow-up questions the passenger might ask next.
- Never guess a specific place name with high confidence if the evidence is weak. Use confidence "low" when identifying by position only.
"""

KID_RULES = {
    "explorer": "The passenger is a child aged about 5 to 8, with a parent. Use very simple words and short sentences, one or two ideas, a warm friendly tone, no scary content. Under 70 words. If the question is not about the view, the sky, flying or geography, gently say you can only talk about what is out the window.",
    "navigator": "The passenger is aged about 9 to 13. Use clear language a curious 11-year-old enjoys, one vivid comparison, no jargon without explaining it. Under 120 words. If the question is not about the view, the sky, flying or geography, say you can only help with what is out the window.",
}

SCHEMA = {
    "type": "object",
    "properties": {
        "title": {"type": "string", "description": "Short name for what is in the photo, e.g. 'Great Salt Lake, north arm'"},
        "explanation": {"type": "string"},
        "matchedFeatureID": {"type": ["string", "null"], "description": "ID from the candidate list if one matches, else null"},
        "confidence": {"type": "string", "enum": ["high", "medium", "low"]},
        "followUps": {"type": "array", "items": {"type": "string"}, "maxItems": 3},
    },
    "required": ["title", "explanation", "matchedFeatureID", "confidence", "followUps"],
    "additionalProperties": False,
}


def _context(req: ExplainRequest, candidates: list[Feature]) -> str:
    p = req.pose
    lines = [
        f"Flight {req.flightNumber}, {int(req.elapsedSeconds // 60)} minutes after takeoff.",
        f"Aircraft at {p.position.latitude:.3f}, {p.position.longitude:.3f}, about {int(p.heightAboveGroundMeters)} m above the ground, track {int(p.trackDegrees)} degrees.",
        f"Camera out the {p.side} window, {int(p.depressionDegrees)} degrees below the horizon, field of view {int(p.horizontalFOVDegrees)} degrees.",
        "Candidates from geometry, best first:" if candidates else "No database features fall inside the camera footprint.",
    ]
    for f in candidates:
        lines.append(f"- id={f.id}: {f.name} ({f.category}), radius {int(f.radiusMeters / 1000)} km. {f.summary}")
    if req.question:
        lines.append(f"Passenger's question: {req.question}")
    return "\n".join(lines)


def offline_fallback(req: ExplainRequest, candidates: list[Feature]) -> ExplainResponse:
    """Used when no API key is configured, so the endpoint still answers."""
    if candidates:
        f = candidates[0]
        return ExplainResponse(title=f.name, explanation=f.kidSummary if (req.kidBand == "explorer" and f.kidSummary) else f.summary,
                               matchedFeatureID=f.id, confidence="low",
                               followUps=[f"What else is near {f.name}?", "Why does it look like that from up here?"], model="offline")
    return ExplainResponse(title="Unidentified view", explanation="Nothing from the guide falls inside this frame, and the server has no model key configured to describe the scene.",
                           confidence="low", followUps=[], model="offline")


async def explain(req: ExplainRequest, candidates: list[Feature]) -> ExplainResponse:
    if not config.ANTHROPIC_API_KEY:
        return offline_fallback(req, candidates)
    client = anthropic.AsyncAnthropic(api_key=config.ANTHROPIC_API_KEY)
    system = SYSTEM + ("\n" + KID_RULES[req.kidBand] if req.kidBand else "")
    messages = [{
        "role": "user",
        "content": [
            {"type": "image", "source": {"type": "base64", "media_type": req.mediaType, "data": req.imageBase64}},
            {"type": "text", "text": _context(req, candidates)},
        ],
    }]
    kwargs = dict(model=config.EXPLAIN_MODEL, max_tokens=2000, system=system, messages=messages,
                  output_config={"format": {"type": "json_schema", "schema": SCHEMA}})
    try:
        # Server-side refusal fallback keeps the request alive if a safety classifier declines.
        response = await client.beta.messages.create(betas=["server-side-fallback-2026-07-01"], fallbacks="default", **kwargs)
    except (TypeError, anthropic.BadRequestError):
        response = await client.messages.create(**kwargs)

    if response.stop_reason == "refusal":
        return ExplainResponse(title="Can't help with that one", explanation="The model declined to answer this request. Try a plain question about the view.",
                               confidence="low", followUps=[], model=response.model)
    text = "".join(block.text for block in response.content if getattr(block, "type", "") == "text")
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        data = {"title": "View from the window", "explanation": text[:1200], "matchedFeatureID": None, "confidence": "low", "followUps": []}
    ids = {f.id for f in candidates}
    match = data.get("matchedFeatureID")
    return ExplainResponse(title=data.get("title", "View"), explanation=data.get("explanation", ""),
                           matchedFeatureID=match if match in ids else None,
                           confidence=data.get("confidence", "low"), followUps=(data.get("followUps") or [])[:3],
                           model=response.model)
