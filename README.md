# Earth from Above

An iOS app (Android later) that tells you what is outside your aeroplane window.

Tell it your flight and seat, download a route guide on the ground, tap a button at
takeoff, and it will tell you what is coming up on your side of the plane, let you
photograph something and ask "what is that?", and explain the geology, ecology and
human landscape below, with or without a connection. A kid mode turns the flight
into a mission.

## Repository layout

| Path | What it is |
| --- | --- |
| `ios/` | The iOS app. `project.yml` generates the Xcode project with XcodeGen. |
| `ios/Packages/EarthFromAboveCore/` | Pure Swift logic with unit tests: geodesy, route model, position fusion, feature index, photo geometry, crossings, visibility, kid mode. No UIKit, so it is reusable and testable anywhere Swift runs. |
| `ios/EarthFromAbove/` | SwiftUI app: views, sensor services, API client, bundled sample flight and articles. |
| `backend/` | Python FastAPI service: route bundles, flight lookup, live position, photo explanation via the Claude API, friends-and-family sightings. Tests included. |
| `data/curated/` | Bootstrap datasets: 94 North American points of interest, 29 borders and rivers, airports, aircraft types. The data pipeline replaces these with open datasets over time. |
| `content/` | Reference articles (clouds, lightning, lines on the land, spotting guide, geology, human landscape, turbulence, sky optics), each with a kid version. Synced into the app with `scripts/sync_content.sh`. |
| `docs/` | Product brief, architecture, setup guide. |

## Status

First scaffold. The core logic has unit tests; the backend has API tests that pass
offline. The iOS app has not yet been compiled, because this was written in a Linux
session without Xcode. Follow `docs/SETUP.md` on a Mac to generate the project, build,
run the Swift tests and fix whatever the compiler finds.

## Quick start

```sh
# Backend (any machine with Python 3.11+)
cd backend && pip install -r requirements.txt
python -m pytest -q
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# iOS (on a Mac with Xcode 15+)
brew install xcodegen
cd ios && xcodegen generate && open EarthFromAbove.xcodeproj
```

See `docs/SETUP.md` for keys, simulator tips and TestFlight.
