# Architecture

Five modules on the phone, one small backend. The modules talk through plain
value types defined in `EarthFromAboveCore`, so each can be tested alone.

## On the phone

```
 Sensors                    Core (pure Swift)                    UI (SwiftUI)
 ─────────                  ─────────────────                    ────────────
 GPS ──────────┐
 Barometer ────┼──▶ PositionEstimator ──▶ PositionEstimate ──▶ Live window, Map
 Airline feed ─┤          ▲                                     Notifications
 ADS-B ────────┘          │
                    RouteModel (timed track, from the bundle)
                          │
 Route bundle ──▶ FeatureIndex ──▶ LookoutPlanner ──▶ timeline / upcoming / now
    (JSON)        LineFeatures ──▶ Crossings        ──▶ KidMode (bingo, briefing)
                  CloudSamples ──▶ VisibilityModel
                          │
 Camera + gyro ──▶ CameraPose ──▶ CameraGeometry ──▶ footprint ──▶ candidates
                                                                  │
                                                       (online) APIClient.explain
```

### Position estimator

`PositionEstimator` holds a `RouteModel` and a takeoff time. It accepts fixes from
any source (`gps`, `airlineFeed`, `adsb`) and never lets a worse source displace a
fresher better one. A fresh fix is used directly and extrapolated along its own track
for up to ten minutes. Every fix also measures how far ahead of or behind schedule the
aircraft is (`scheduleOffsetSeconds`), so when fixes stop, dead reckoning from the route
continues from the corrected position rather than the published schedule. If the user
never presses the takeoff button but a GPS fix shows the aircraft airborne, the takeoff
time is inferred from where the fix lands on the route.

Uncertainty is tracked as a single radius in metres and surfaced to the user as a
traffic light. Dead reckoning starts at about 15 km and grows with time since the last
anchor.

### Flight phase

`FlightPhaseDetector` uses only the barometer. Cabin pressure is regulated, but cabin
altitude still climbs on climb, plateaus in cruise and descends on descent, which is
enough to detect phases and to auto-detect takeoff as a backup for the button.

### Camera geometry

The compass is unusable inside the fuselage, so the camera's bearing is derived from
aircraft track plus the window side. Device pitch and roll from the gyroscope give the
depression angle. `CameraGeometry.footprint` projects the four corners of the frame onto
the ground (flat-earth per ray, clamped at the refracted horizon) and `candidates` ranks
features inside the footprint by salience, apparent size and closeness to the centre.

Imported photos lack pose; they are placed on the route by timestamp with a wider field
of view and lower confidence.

### Bundle format

`RouteBundle` is one JSON document: flight info, aircraft, timed route, features, lines
(borders, rivers, divides), cloud samples, turbulence samples, notes. The backend's
pydantic models mirror the Swift Codable types field for field. Dates are ISO 8601 UTC
without fractional seconds because that is what Swift's default decoder accepts.

## Backend

FastAPI, Python 3.11+. Endpoints:

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/v1/flights/search?flight=&date=` | Resolve a flight number to origin, destination, schedule. |
| GET | `/v1/flights/{flight}/live` | Live ADS-B position for the user's own flight. |
| GET | `/v1/bundles?flight=&date=&weather=` | Build a route bundle. |
| POST | `/v1/explain` | Photo plus pose plus candidates to a structured explanation (Claude API). Free-tier quota per device per flight. |
| POST, GET | `/v1/sightings` | Friends-and-family shared sightings keyed by a circle code. |
| GET | `/health` | Which live sources are configured. |

Services:

- `flights`: schedule lookup. AeroDataBox when a key is set; otherwise a demo table and
  `ORIGIN-DEST` airport pairs.
- `route_predictor`: a recent actual track for the flight number from OpenSky when
  credentials are set; otherwise great circle timed with a jet profile that mirrors the
  Swift `RouteModel.synthesize`.
- `corridor`: selects features within 150 km of the track and lines near it.
- `weather`: Open-Meteo cloud cover (low and mid cloud hide the ground) and a wind-shear
  heuristic for turbulence. Never raises; a missing forecast becomes a note in the bundle.
- `explain`: Claude API call with the image, context and a JSON schema for the answer.
  Kid bands change the system prompt. With no key the endpoint falls back to the
  candidate list so the app still works end to end.
- `sightings` and `quota`: SQLite in the bootstrap. Swap for Postgres and object storage
  when hosting (see `docs/SETUP.md`).

## Data pipeline (to build)

The curated files in `data/curated/` are a bootstrap. The planned pipeline:

1. Points of interest: OpenStreetMap (natural, water, man_made, power), Wikidata and
   geotagged Wikipedia for names and summaries (CC BY-SA attribution kept per feature),
   GeoNames for populated places, Smithsonian GVP for volcanoes, Earth Impact Database for
   craters, Global Dam Watch for reservoirs, WRI Global Power Plant Database, Protected
   Planet.
2. Lines: Natural Earth admin boundaries, HydroSHEDS rivers, USGS watershed boundaries
   for the continental divides, time-zone boundaries.
3. Terrain: Copernicus GLO-30 downsampled per corridor, for height above ground and
   later for terrain-aware ray casting.
4. Imagery: NASA GIBS near-real-time cloud imagery for visibility; Landsat and Sentinel-2
   archives for then-and-now comparisons.
5. Offline map tiles: vector tiles cut to the corridor.

Each produces the same `Feature` and `LineFeature` shapes, so the app does not change
as sources improve.

## Hosting

Fly.io for the API (containers, scale to zero), Neon for Postgres with PostGIS,
Cloudflare R2 for bundles and photos (no egress fees, a CDN in front). All three have
free or near-free development tiers. `backend/fly.toml` and `backend/Dockerfile` are
ready; the SQLite bootstrap runs on a Fly volume until Postgres is wired in.

## Privacy and kids

- No account is needed to use the app. Sign in with Apple arrives with purchases.
- Photos leave the device only for an online explanation or a shared sighting, both
  explicit taps. In kid mode online explanations are off until a parent turns them on.
- Child profiles live under the parent. There is a parental gate (arithmetic) to leave
  kid mode.
- Shared sightings are visible only to holders of the same circle code (minimum six
  characters). Public sharing, with moderation, is a later release.
