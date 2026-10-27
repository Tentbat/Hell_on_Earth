# Setup

## 1. Backend (works anywhere, no keys needed)

```sh
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python -m pytest -q                 # 14 tests, all offline
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Then open http://localhost:8000/docs. Try:

- `GET /v1/bundles?flight=AS123&date=2026-11-01` (demo flight Seattle to Denver)
- `GET /v1/bundles?flight=LAX-JFK&date=2026-11-01` (any airport pair in `data/curated/airports.json`)

Optional environment variables, each unlocking a live source:

| Variable | Unlocks | Where to get it |
| --- | --- | --- |
| `ANTHROPIC_API_KEY` | Photo explanations | console.anthropic.com |
| `AERODATABOX_KEY` | Real flight schedules and aircraft type | RapidAPI, AeroDataBox |
| `OPENSKY_USER`, `OPENSKY_PASS` | Historical tracks and better live position | opensky-network.org (free account) |
| `EFA_ENABLE_WEATHER=0` | Turns off the Open-Meteo call (on by default, no key needed) | |

Rebuild the sample bundle shipped in the app after changing curated data:

```sh
python scripts/build_sample_bundle.py
```

## 2. iOS app (Mac with Xcode 15 or newer)

```sh
brew install xcodegen
cd ios
xcodegen generate
open EarthFromAbove.xcodeproj
```

In Xcode:

1. Select the `EarthFromAbove` target, Signing and Capabilities, pick your team
   (your personal Apple ID works for the simulator and your own device before you enrol
   in the Developer Program).
2. Product, Test (Cmd-U) runs the core package's unit tests.
3. Run on a simulator to see the UI with the sample flight. Run on a real iPhone to use
   GPS, barometer and camera.

Expect compiler errors on the first build. The code was written without a compiler to
hand; the fixes should be local and small. Run the tests first, since the core package
is the part most worth getting right.

### Pointing the app at your backend

The app reads `EFA_BACKEND_URL` from `Info.plist` (set in `project.yml`, default
`http://localhost:8000`). On a physical phone, set it in the app's Settings screen to
your Mac's LAN address, for example `http://192.168.1.20:8000`. iOS blocks plain HTTP
to arbitrary hosts in release builds; for development, add an App Transport Security
exception in `project.yml` or use HTTPS once deployed.

### Testing in-flight behaviour on the ground

- Load the sample flight, tap the takeoff button. Dead reckoning runs the whole
  Seattle to Denver flight in real time.
- In the simulator, Features, Location, Custom Location moves the GPS; the estimator
  will re-anchor to wherever you put it along the route.
- The barometer and gyroscope only exist on a device.

## 3. Apple Developer Program (individual)

Enrol at developer.apple.com with your Apple ID. Individual enrolment is usually
approved within a day or two. Then in `project.yml` set `DEVELOPMENT_TEAM` to your team
ID, regenerate, and archive to TestFlight from Xcode (Product, Archive, Distribute App).

## 4. Hosting the backend

```sh
brew install flyctl
fly auth signup
fly launch --no-deploy --copy-config --dockerfile backend/Dockerfile
fly volumes create efa_data --size 1
fly secrets set ANTHROPIC_API_KEY=sk-ant-...
fly deploy
```

Then set the deployed `https://...fly.dev` URL in the app's Settings screen, or as the
`EFA_BACKEND_URL` default in `project.yml` for a TestFlight build.

## 5. Editing content

Articles live in `content/*.md` with `_kids.md` variants. After editing, run
`scripts/sync_content.sh` to copy them into the app. The app's reader handles headings,
bullet lists and inline bold and italics.
