# In-Flight Window Companion: Product Brief (pre-code)

Status: draft for discussion. No app code yet. This document captures the proposed
scope, the technical realities that shape it, open questions, a feature brainstorm,
and a proposed freemium split. iOS first, Android later.

---

## 1. What the app does, in one paragraph

You tell the app which flight you are on and which side of the plane you are sitting on.
It downloads a "route bundle" before takeoff (predicted track, terrain, points of
interest, weather). You tap "We're off" at takeoff. From then on it knows roughly where
the plane is, even with no connectivity, and it tells you what is coming up outside your
window, lets you photograph something and asks "what is that?", and explains it. With
in-flight Wi-Fi it gets sharper (live position, live weather, richer explanations). A kid
mode turns the same data into a mission: prepare before the flight, spot things during it.

---

## 2. Technical realities that shape the design

These are the facts that decide what is feasible offline versus online.

### 2.1 Where is the plane?

A ladder of position sources, best first. The app should fuse whatever is available and
show its confidence.

1. **Phone GPS.** This is the surprise: a phone's GPS works at cruise altitude in a
   window seat, with no network at all. Commercial jets fly well below the receiver
   speed and altitude limits that disable consumer GPS. A fix usually takes 30 to 90
   seconds near the window. This is the primary offline source, not Wi-Fi.
2. **Airline Wi-Fi flight-data feed.** Most in-flight Wi-Fi portals expose a small JSON
   feed with position, altitude, ground speed, and time to destination. These feeds are
   undocumented and vary by provider, so they are a bonus source, not a dependency.
3. **Internet ADS-B tracking.** If the Wi-Fi gives real internet access, public ADS-B
   aggregators report the aircraft's own position. Free and paid tiers exist.
4. **Dead reckoning.** Takeoff timestamp (the button) plus the predicted route and a
   typical climb, cruise, and descent speed profile. The barometer detects flight phase
   (climb, cruise, descent) without any network. The accelerometer can also detect the
   takeoff roll automatically as a backup if the user forgets the button.

Caveat: the magnetic compass is unreliable inside a metal fuselage. Camera heading must
come from the aircraft track plus the side of the plane, not from the magnetometer. Device
pitch and roll from the gyroscope are fine.

### 2.2 Which side am I on?

Seat letter "A" is the left (port) side on essentially every airline, and the highest
letter in the row is the right side. So the seat number gives the side for every window
seat. The user can also just tap left or right.

### 2.3 Where will the plane go?

Predicted track, in order of preference:

1. Recent actual tracks of the same flight number (ADS-B history). Flights fly very
   similar routes day to day, with weather-driven deviations.
2. The filed route for today, where obtainable.
3. Great-circle path between the airports, as a fallback.

The app downloads a corridor around the predicted track (say 150 km each side) rather
than the whole world. That is what makes offline mode small enough to ship.

### 2.4 What is in the photo?

Two complementary methods, which is the key design decision:

- **Geometric lookup (works offline).** Position, altitude, aircraft track, side of
  plane, and device pitch and roll give a camera ray. Intersecting that ray with a
  terrain model gives the patch of ground in the frame. The app then lists the named
  features inside that patch from the downloaded database, ranked by size and salience.
  This is deterministic and explainable: "you were here, pointing there, and this is
  what is there."
- **Vision model explanation (needs connectivity).** The photo plus the candidate list
  and context (altitude, time, season, weather) goes to a multimodal model, which picks
  the match, explains it, and handles things with no database entry (a dust storm, a
  wildfire plume, cloud streets, contrails, a glory, braided river channels).
- **On-device classifier (offline, modest).** A Core ML model that labels broad
  categories from oblique window photos: center-pivot irrigation, open-pit mine,
  reservoir and dam, wind farm, solar farm, volcano, braided river, meander scars, salt
  flat, glacier, coral reef, urban grid, port. This is a stretch goal that needs training
  data; the geometric lookup carries offline mode at launch.

Photos taken inside the app capture pose at the shutter. Photos imported from the Photos
app have only a timestamp (and sometimes a GPS fix), so the app places them on the track
by time and assumes the user's window side, giving a wider, less certain footprint.

### 2.5 Weather, visibility, and turbulence

Free government feeds cover most of this: pilot reports, significant weather advisories,
turbulence forecast grids, airport observations and forecasts, and near-real-time
satellite cloud imagery. Satellite cloud cover along the corridor is what predicts whether
you will see the ground at all; the app should say "likely under cloud from 14:10 to 14:40"
rather than listing features you cannot see. Turbulence products plus terrain (mountain
wave) and convection give a "bumps likely, seatbelt sign probable" forecast, with honest
uncertainty. Weather is downloaded with the bundle and refreshed whenever connectivity
appears.

### 2.6 Data sources to pull from

- Points of interest: OpenStreetMap, Wikidata and geotagged Wikipedia, GeoNames.
- Natural features: global volcano database, impact crater database, protected areas,
  Ramsar wetlands, World Heritage sites, plate boundaries and fault lines.
- Built environment: global dam and reservoir databases, global power plant database
  (wind, solar, nuclear, hydro), ports, mines, major bridges, airports.
- Terrain: open 30 m elevation models, downsampled for the corridor.
- Imagery: open daily satellite tiles for cloud cover; archive satellite imagery for
  "then and now" comparisons (glacier retreat, reservoir filling, deforestation fronts,
  the Aral Sea, urban growth).
- Flight data: schedules, ADS-B live and historical, aircraft type.
- Astronomy: sun and moon position (computed on device), aurora activity index.

---

## 3. Core features (your list, made concrete)

1. **Flight setup.** Enter flight number and date, or pick from a calendar or boarding
   pass scan. Confirm seat. Choose interests via checklist (see interest taxonomy below).
2. **Pre-flight download.** One tap builds and fetches the route bundle. Shows size and
   what is included. Works on home or airport Wi-Fi.
3. **Takeoff button.** Big, obvious. Also auto-detects the takeoff roll as a fallback and
   asks "did we just take off?"
4. **Live window view.** A strip or map showing where you are, what is visible on your
   side now, and what is next with a countdown. Confidence indicator for position.
5. **Look-out list.** The whole flight's highlights at once, filtered by interests and
   by predicted cloud cover, with "left side / right side" labels and estimated times.
6. **Real-time alerts.** Local notifications, Live Activity on the lock screen, and an
   Apple Watch glance: "In 6 min on your left: Lake Powell and Glen Canyon Dam."
7. **Photo identification.** Shoot in app or import. Offline: ranked candidates with
   short offline encyclopedia entries. Online: full explanation, follow-up questions.
8. **Weather and ride.** Cloud cover timeline, visibility outlook, turbulence outlook,
   sunrise or sunset timing in your window, glare warning.
9. **Kid mode.** Covered in section 5.

### Interest taxonomy (the checklist)

- Geology: volcanoes, faults and plate boundaries, craters, glaciers and glacial
  landforms, canyons, deserts and dunes, salt flats, karst, river forms (braids, meanders,
  oxbows, deltas, alluvial fans).
- Ecology and biomes: forests and deforestation fronts, wetlands, coral reefs, biome
  transitions, wildfire scars, migration flyways, protected areas.
- Water: lakes, reservoirs and dams, rivers, coastlines, estuaries, sea ice.
- Human landscape: cities, irrigation patterns, farms and feedlots, mines, energy
  (wind, solar, nuclear, oil and gas), ports and shipping, bridges, airports, highways
  and railways, borders.
- History and culture: ancient sites, battlefields, ghost towns, geoglyphs, World
  Heritage sites.
- Sky and atmosphere: cloud types, contrails, glories and halos, sunrise and sunset,
  moon, aurora, lightning, city lights at night, other aircraft.

---

## 4. Brainstorm: other functionality that is natural here

Ordered roughly by how much they add relative to effort.

**High value, low to medium effort**

- **Seat recommender before booking.** Given a flight and date: which side sees the
  mountains, the coast, the sunset, the moonrise, the aurora. Also which side avoids
  glare. A natural reason to open the app days before flying and a natural upsell.
- **Flight logbook.** Every flight with its track, your photos pinned where they were
  taken, and what you spotted. Shareable cards: "Grand Coulee Dam, 37,000 ft, 14:32."
- **"Why is it bumpy?"** Plain-language explanation of the current turbulence from
  jet stream, mountain wave, or convection, with what is likely next.
- **Auto-captioned photos exported to Photos** with location and caption metadata.
- **Approach and departure guide.** What you see on climb-out and on final approach,
  which runway is likely given the wind, and landmarks on the way in.
- **Night mode.** City lights identification, lightning, aurora alerts, planets and
  bright stars through the window, moon phase.
- **Audio narration.** Short spoken segments through headphones as features come up.
  Also an accessibility feature.
- **Trip stats.** Borders crossed, time zones crossed, bodies of water crossed, highest
  terrain passed, distance and ETA computed without network.

**High value, higher effort**

- **Then and now imagery.** Swipe between archive satellite imagery and current for
  the feature below you: glacier retreat, reservoir filling, deforestation edges,
  urban sprawl. Strong educational hook and a premium differentiator.
- **Other aircraft spotting.** With connectivity: "the plane passing below is a 787
  from Tokyo to Chicago." Very popular feature in flight-tracking apps.
- **Group mode without Wi-Fi.** Family on the same flight share sightings and photos
  device to device over local peer networking.
- **Crowdsourced sightings.** Users confirm "visible on this route" and add photos,
  improving the database for everyone. Needs moderation.
- **Cloud and sky identification.** Cloud types, cloud streets, anvils and their distance,
  lenticulars signalling mountain wave.

**Speculative**

- Pilot-style announcements voice for kids. Printable pre-flight pack. Classroom
  edition for school trips. Airline partnership for seatback integration.

---

## 5. Kid mode

Two bands, chosen by the parent:

- **Explorer (about 5 to 8, with a parent).** Very large tap targets, pictures over text,
  spoken labels, a bingo card of 9 things to spot on this flight, stickers for each one
  found. The parent holds the phone; the child points.
- **Navigator (about 9 to 13, unsupervised).** A "mission briefing" before the flight,
  a live map, a checklist with short explanations written for the age, a quiz at the
  end, badges across flights.

Preparation before the flight is the heart of it: the briefing is built from the route
bundle, so it works on the drive to the airport.

Safety and compliance constraints for anything aimed at children under 13:

- No account required for a child. Parent sets up profiles under the parent's account.
- Parental gate before purchases, external links, or leaving the app.
- No third-party advertising or analytics in kid mode.
- Free-text questions to the vision model are off by default for the Explorer band and
  on with a parental toggle for the Navigator band, with constrained prompts.
- Photos are processed on device unless the parent enables online explanations.

---

## 6. Freemium: proposed division

Usage is episodic. Most people fly a few times a year, so a pure annual subscription will
churn. A per-flight pass fits the behaviour and converts at the moment of highest
motivation (sitting at the gate). The subscription is for frequent flyers and families.

**Free**

- One active flight at a time, with a basic route bundle (track, top 25 highlights,
  low-resolution terrain).
- Takeoff button, side of plane, live window strip, the full look-out list for the
  current flight.
- Photo identification: offline candidate list, plus a small number of online
  explanations per flight (for example three).
- Kid mode Explorer band, one child profile.
- Logbook of the last three flights.

**Flight Pass (one flight, one price)**

- Everything in Premium for that flight only.

**Premium (annual, with a family option)**

- Full-resolution route bundles with full point-of-interest database and imagery.
- Unlimited online photo explanations and follow-up questions.
- Weather, cloud-cover timeline, turbulence and seatbelt outlook.
- Real-time alerts, Live Activity, Apple Watch.
- Seat recommender for upcoming flights.
- Then-and-now imagery, other-aircraft spotting, night mode.
- Unlimited logbook, export with captions, shareable cards.
- Both kid bands, multiple child profiles, group mode.

**Other channels**

- Education licence for schools and youth groups.
- Airline or in-flight Wi-Fi provider partnership (bundled pass).

A rule for deciding what stays free: anything that proves the core trick ("it knows what
is out my window with no signal") stays free, because that is what gets the app
recommended. Anything that is depth, breadth, or ongoing cost (online model calls, large
imagery, live data) is paid.

---

## 7. Proposed architecture

Keep the number of interacting parts small and the interfaces clean. Five modules on the
phone, one small backend.

On device:

1. **Position estimator.** Fuses GPS, airline feed, ADS-B, and dead reckoning into a
   position, track, altitude, flight phase, and confidence. Everything else consumes this
   and nothing else.
2. **Route model.** The predicted track with time along it, loaded from the bundle,
   corrected as real positions arrive.
3. **Feature index.** The downloaded points of interest with geometry, salience, and
   offline text. Spatial queries by footprint, by side, by time window.
4. **Photo geometry.** Camera ray to ground footprint using the terrain model.
5. **Explainer.** Offline: templates plus encyclopedia snippets. Online: calls the
   backend, which calls the vision model with the candidates and context.

Backend (small, serverless-friendly):

- Route bundle builder: takes flight number and date, predicts the track, cuts the
  corridor, packages features, terrain, imagery, and weather.
- Live aggregator: ADS-B position for the user's flight, weather refresh.
- Model proxy: holds API keys, enforces quotas for free versus paid, applies the kid-mode
  prompt constraints.
- Entitlements: receipt validation for passes and subscriptions.

Stack recommendation: native Swift and SwiftUI for the iOS client (sensors, Core ML,
offline maps, Live Activities, and Watch all favour native). Backend in a language we can
share with the Android port later. The data pipeline and backend are the bulk of the
reusable work; the Android client is a second UI over the same bundles and APIs.

---

## 8. Open questions

See the accompanying message. The ones that change the build the most are: native versus
cross-platform client, whether we run a backend, launch region, in-app camera versus
import, and the monetisation shape.

---

## 9. Suggested MVP (first TestFlight build)

1. Flight entry, seat side, interest checklist.
2. Route bundle download for US domestic flights (expand afterwards).
3. Takeoff button with barometric phase detection and GPS when available.
4. Live window strip and the look-out list with left and right labels.
5. In-app photo capture with geometric identification, online explanation when connected.
6. Local notifications for upcoming features.
7. Kid mode Navigator band with the mission briefing and checklist.

Deferred to the second release: weather and turbulence, seat recommender, logbook,
Explorer band, Watch and Live Activity, then-and-now imagery, other aircraft.
