"""Live position of the user's own flight from an ADS-B network, used when the
in-flight Wi-Fi gives real internet access. OpenSky anonymous access works with
rate limits; credentials raise them."""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

import httpx

from .. import config
from ..schemas import LivePosition


async def position(callsign: str) -> Optional[LivePosition]:
    auth = (config.OPENSKY_USER, config.OPENSKY_PASS) if config.OPENSKY_USER else None
    try:
        async with httpx.AsyncClient(timeout=10, auth=auth) as client:
            r = await client.get("https://opensky-network.org/api/states/all")
            r.raise_for_status()
            states = r.json().get("states") or []
    except Exception:
        return None
    for s in states:
        if (s[1] or "").strip().upper() == callsign.upper():
            if s[6] is None or s[5] is None:
                return None
            return LivePosition(latitude=s[6], longitude=s[5], altitudeMeters=s[13] or s[7], trackDegrees=s[10],
                                groundSpeedMetersPerSecond=s[9], time=datetime.fromtimestamp(s[3] or s[4], tz=timezone.utc))
    return None
