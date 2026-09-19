# Detour

Native iPhone road-trip planner, built with SwiftUI for iOS 26+. The app follows the supplied [Paper direction B](https://app.paper.design/file/01M2TAYV18Q1X0VH7BP6C2NSHH/p-1-0/15E-0).

## Run the iPhone app

Open the Xcode project **inside your current checkout** so Run builds the files you are editing.

After each Swift change, press **⌘R** in Xcode to build and relaunch. Simulator has no browser-style refresh. For layout work, open `HomeView.swift` and its **Home · stationary** SwiftUI preview in Xcode's canvas. The preview uses sample content and skips the location permission prompt.

Alternatively, from the repository root:

```sh
bash scripts/run-simulator.sh
```

The script reuses `/tmp/detour-derived-data`, builds the current checkout, installs it on a booted iPhone simulator (or an available iPhone), and relaunches it. Only run one checkout's build at a time when sharing that cache. Override `DETOUR_SIMULATOR_ID` or `DETOUR_DERIVED_DATA` if needed. Pass `--demo` to force sample services.

For Xcode to reuse the same cache, choose **File → Project Settings → Derived Data → Custom Location**, set `/tmp/detour-derived-data`, and click Done. This is a per-user setting, not a committed project setting. Keep the simulator booted between iterations. Use previews for layout tweaks and focused checks for changed behavior; reserve the full test suite for larger milestones.

The home map fills the screen behind From / Where to? and discovery cards. Location access is optional; searching for an origin still works when permission is denied. Simulator location is synthetic: choose one in Simulator's location controls when testing. The product omits demo/sample captions at the user’s request; the bundled place collection is still Cape Town content, even when the selected origin is elsewhere.

To use **Google Maps on home** without configuring the backend yet, copy `ios/Local.xcconfig.example` to `ios/Local.xcconfig`, set `GOOGLE_MAPS_API_KEY` to your restricted Maps SDK for iOS key, and rebuild. With no map key the app uses Apple Maps. Routing remains Apple Maps while services are in demo mode. Never commit `Local.xcconfig`.

Every launch starts with the two-column interest picker. Choose exactly three interests and continue; previous selections are remembered on this device. The top-right interests icon on home lets you change them without resetting your trip. **Where to?** opens ranked photo cards: **For you** includes places matching the selected interests, ranked by the number and specificity of matches; **All** preserves the curated Cape Town collection. Search also finds demo cities such as Knysna. Changing interests inside the destination browser updates its collection immediately. Demo route discovery also uses the profile to favour relevant attractions and worthwhile detours over small differences in road convenience. Cards show the strongest recommendations first; accepted stops are inserted in journey order.

The destination browser bundles ten licensed attraction photos (about 2 MB) for immediate, reliable demo display; author/source/licence links are available under **Photo credits**. Metadata is recorded in `docs/destination-photo-credits.json`. The existing live-service photo loader fetches Google Places photos at runtime when live services are configured; the bundled collection is confined to demo browsing.

Table Mountain's cableway and Lion's Head's trail match **Nature** and use the **Scenic** stop category; **Sports** matches DHL Stadium. Demo destination and recommendation cards display mock ratings from a separate presentation-only collection, as requested for the hackathon. These are not Google ratings and have no Google attribution or invented review counts. Connected cards can display actual Google ratings and review counts supplied by live services. The backend already requests Google `rating` and `userRatingCount`; connecting the curated destination browser to live Places records requires resolving its destinations to actual Google place IDs.

**Plan my route** keeps the same native map on screen, draws the returned route over 1.4 seconds, and automatically discovers recommendations. Default demo searches offer six swipeable cards; narrow filters can have fewer eligible places. A compact route summary and selected filters sit in the shared top header, with the sliders opening optional preferences. The header itinerary icon works before adding a stop and displays a stop-count badge afterward. Recommendations and Skip/Add stop actions share a bottom drawer; tap or drag its handle up to expand. Itinerary uses the same header/drawer with More stops/Start actions and an X control to return to the remaining recommendations. Ratings and approximate added journey minutes appear over each photo. Each card identifies its discovery type, explains the interest match, and splits added time into extra travel plus the suggested stay. The shared header duration includes accepted stays. **View itinerary** is available without reviewing every card; **Start** and **Continue** open directions without forcing a travel mode. Reduce Motion shows the complete route immediately.

The map shows one continuous journey: main-road sections stay ink-coloured, and detours replace the relevant section with orange roads. Replaced main-road segments disappear; previews can also replace a section of an accepted detour. Small white-bordered orange markers indicate departure and rejoin points. Suggested detours are dashed; accepted detours are solid. Geometry comparison uses a 35-metre tolerance for lane offsets and polyline rounding. Preview geometry reuses the directions checks already needed for the time estimate; it makes no extra live routing request.

Garden Route demo discoveries include a coastal detour to [Goukamma Nature Reserve](https://www.capenature.co.za/reserves/goukamma-nature-reserve), using CapeNature's published coordinates on Buffalo Bay Road. Drostdy Museum and Map of Africa also offer experiences beyond a roadside break. Short Cape Town journeys exclude attractions substantially behind or beyond the endpoints. Apple Maps checks the actual additional driving time; offline demo estimates scale with the stop's distance from the route.

The app bundles **Apfel Grotezk Regular, Mittel and Fett** from [Collletttivo's official repository](https://github.com/collletttivo/apfel-grotezk), under the SIL Open Font License 1.1. The existing type hierarchy, colour tokens and shared controls are retained, with Dynamic Type scaling. Font files and the licence are in `ios/Detour/Resources/Fonts/`.

Open `ios/Detour.xcodeproj`, select the **Detour** scheme and an iOS 26 simulator, then Run. Google Maps 10.15.0 is pinned through Swift Package Manager. Xcode 26+ is required.

With no local configuration, the app uses fixture stop content and a **real, interactive Apple Maps map**. User-facing demo/sample captions and the development settings badge have been removed at the user’s request. Apple Maps calculates driving routes, distances and travel times over actual roads, including accepted stops. No API key is needed. If directions are unavailable, demo mode uses an illustrative route labelled **Estimated**; map tiles still require a connection or cached tiles. Cape Town ↔ Knysna has curated stop suggestions, including when the origin is a nearby GPS location; mock ratings and sample amenities remain illustrative. Cape Town-area routes use a separate small-discovery collection, ranked using the interest profile and forward route progress. Major destinations stay in Where to. Thirteen actual discovery images are bundled, including seven Wikimedia Commons photos with linked licences and venue-provided imagery credited to its published source; no broad reuse licence is claimed for venue imagery. Credits are recorded in docs/route-discovery-photo-credits.json and available in the app. Other routes receive suggested break locations rather than verified venues. Demo searches revisit skipped samples when needed and offer alternatives beyond a restrictive detour limit, retaining the actual extra driving time. Accepted stops and route endpoints are excluded from recommendations. Configuring all live services switches mapping and routing to Google.

For command-line builds, keep DerivedData outside iCloud Documents to avoid Finder metadata interfering with code signing:

```sh
xcodebuild -project ios/Detour.xcodeproj -scheme Detour \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/detour-derived-data build
```

The project is checked in and needs no generator to open. To regenerate it after adding source files, run `ruby scripts/generate-project.rb` with the `xcodeproj` gem installed. This replaces the generated project; put custom build settings in the generator or configuration files.

## Connect live services

The native app calls the TypeScript backend. Only the backend calls OpenAI, Google Places and Google Routes. The app contains only its iOS-restricted Google map key and, for this private MVP, a development access token.

1. In Google Cloud, enable billing and **Maps SDK for iOS**, **Places API (New)** and **Routes API**.
2. Create two keys: an iOS Maps key restricted to `com.steph.detour`, and a separate backend key restricted to Places/Routes. Do not put the backend key or OpenAI key in the app.
3. Copy `backend/.env.example` to `backend/.env` and fill in the backend Google key, OpenAI key and a random development access token.
4. Install and start the backend:

```sh
cd backend
npm ci
npm run build
node --env-file=.env dist/server.js
```

5. Copy `ios/Local.xcconfig.example` to `ios/Local.xcconfig`. Set the backend URL, iOS map key and matching development token. `localhost:8080` works from Simulator; a physical iPhone needs a reachable HTTPS backend.
6. Rebuild. The app enters live mode when both its backend URL and map key are configured. Live failures remain errors; they never silently substitute demo content. `--demo` selects sample places with Apple Maps routing and labelled estimates when directions are unavailable. Automated UI tests use `--uitesting` to make routing deterministic; the opt-in `--live-map-test` flag enables Apple routing during a test.

All local credential files are ignored. In Release builds, use an HTTPS backend. The development access token is extractable from a distributed app and is **not a public-app authentication solution**. Replace it with attested installation tokens before public distribution.

## Backend deployment

`backend/Dockerfile` builds a non-root Node 22 container for Cloud Run. It listens on `PORT` and exposes `GET /health`. Production startup requires `DETOUR_ACCESS_TOKEN`. Store credentials in Secret Manager, not image build arguments or source files.

Example deployment, after creating the named secrets in your own Google Cloud project:

```sh
gcloud run deploy detour-api --source backend --region africa-south1 \
  --allow-unauthenticated --max-instances 2 --concurrency 20 \
  --timeout 120 --memory 512Mi \
  --set-env-vars NODE_ENV=production,OPENAI_MODEL=gpt-5-mini \
  --set-secrets OPENAI_API_KEY=detour-openai-key:latest,GOOGLE_MAPS_API_KEY=detour-google-key:latest,DETOUR_ACCESS_TOKEN=detour-access-token:latest
```

Cloud Run accepts HTTP transport requests, while the application requires the development bearer token on every paid endpoint. Rate limits apply per instance (90 requests/minute, 6 discovery requests/minute per IP); configure provider quotas and billing alerts as well. This is a private development deployment, not a hardened public service. Deployment has not been performed by this build.

## Behaviour

- Search is limited to South African place suggestions. One origin, one destination, up to 12 stops per driving day.
- Categories and a custom request determine searches. OpenAI's official TypeScript SDK uses the Responses API with Zod structured output to interpret user intent. It never receives Google photos, reviews or place records.
- Google supplies facts. Missing hours, ratings or amenities remain missing. Explicitly incompatible dog/child results are excluded; unconfirmed requested amenities are identified.
- Discovery checks at most six place queries and 18 candidate routes; six suggestions are returned per batch. Reviewed place IDs are excluded.
- Adding/removing stops recalculates the complete route. Extra driving and visit time are separate. Google estimates use `TRAFFIC_UNAWARE` consistently. Apple Maps development estimates use the selected departure time and may reflect traffic. Apple route legs are cached in memory for up to five minutes to avoid repeating unchanged requests while planning.
- Hours describe provider-reported current/weekly hours, not a guarantee that the place is open on arrival.
- Departure and visit durations drive the timeline. Times use `Africa/Johannesburg`.
- Navigation opens Google Maps to the next unvisited stop. The user marks visits in Detour; no background tracking or automatic completion occurs.
- SwiftData saves user inputs, stable place IDs, order, visit durations and visit state. Provider descriptions, photos, reviews, ratings and geometry are not persisted. Reopening requires network access to hydrate provider details and recalculate; offline maps are out of scope.
- Demo and live saved trips are kept separate.

## Tests and verification

```sh
cd backend
npm run check
npm test
npm run build
```

```sh
xcodebuild -project ios/Detour.xcodeproj -scheme Detour \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/detour-derived-data \
  -parallel-testing-enabled NO test
```

Backend tests use injected provider doubles and need no keys. Native unit tests cover itinerary arithmetic, state transitions, cancellation, persistence boundaries and navigation links. UI tests launch with `--demo --uitesting` and use an in-memory trip store. The opt-in `testLiveAppleMapRoute` test uses real Apple directions when the test runner environment has `DETOUR_LIVE_MAP_TEST=1`; it is skipped by default.

See `docs/verification.md` for observed results and remaining live/device checks, and `docs/api.md` for the client contract.
