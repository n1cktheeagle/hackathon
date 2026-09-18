# Detour

Native iPhone road-trip planner, built with SwiftUI for iOS 26+. The app follows the supplied [Paper direction B](https://app.paper.design/file/01M2TAYV18Q1X0VH7BP6C2NSHH/p-1-0/15E-0).

## Run the iPhone app

Open `ios/Detour.xcodeproj`, select the **Detour** scheme and an iOS 26 simulator, then Run. Google Maps 10.15.0 is pinned through Swift Package Manager. Xcode 26+ is required.

With no local configuration, the app displays **Demo** for its sample stop content, while showing a **real, interactive Apple Maps map**. Apple Maps calculates driving routes, distances and travel times over actual roads, including accepted stops. No API key is needed for this development map; an internet connection is required. Cape Town → Knysna has sample stop suggestions from Paper; their photos, ratings and amenities remain illustrative. Other demo destinations support real routes but do not simulate live recommendations. Configuring all live services switches mapping and routing to Google.

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
6. Rebuild. The app enters live mode when both its backend URL and map key are configured. Live failures remain errors; they never silently substitute demo content. `--demo` selects sample places with real Apple Maps routing. Automated UI tests use `--uitesting` to make routing deterministic; the opt-in `--live-map-test` flag enables Apple routing during a test.

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
