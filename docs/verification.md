# Development verification

Observed on 18 September 2026 with Xcode 26.1.1. This is a working development build with a complete fixture-backed journey and implemented live-service adapters. Google/OpenAI live-service acceptance is still pending credentials. The development app now uses Apple Maps for real mapping and driving routes without credentials.

## Passing checks

- SwiftUI app builds and launches on iPhone 17 Pro Simulator with the pinned Google Maps package.
- Native suite: **8 unit tests and 3 UI tests pass** on iPhone 16e Simulator. The earlier iPhone 17 Pro run passed the seven unit tests and three UI tests present at that point; the disk-reopen test was added afterward.
- After accessibility polish, the largest Dynamic Type search UI test passed again on iPhone 17 Pro. The exported screenshot was visually inspected: search and result icons fit, labels wrap, and results remain scrollable.
- Backend: **13 tests pass**, TypeScript type-check passes, and production compilation passes.
- Visually compared home, route setup, discovery, suggestions, details and itinerary with Paper direction B. Preserved the exported wordmark and demo images. The initial schematic demo map has been replaced with Apple Maps. Configured production services use Google's native map view.

Native coverage includes timeline arithmetic with all visits and the final driving leg; navigation URL construction; add/skip/remove/restore; duplicate-add protection; stale route and discovery cancellation; persistence of user choices without Google content; and reopening a disk-backed SwiftData store. UI coverage follows the Cape Town → Knysna fixture flow through saving/resuming and exercises both the add button and a real swipe gesture.

Backend coverage includes input validation and typed errors; private-development authorization; NDJSON completion; polyline projection; deduplication and exclusions; detour limits and batch size; category fallback after AI failure; unknown amenities; incompatible dog preferences; cancellation; missing provider facts; explicit provider-failure errors; and ranking equally matched verified stops by additional driving. Ranking uses bounded groups of three route checks so results can stream promptly, with category coverage and distance from accepted stops contributing to initial ranking.

## Still requiring live services

Google and OpenAI credentials were unavailable during this build. No Google place, route, photo or OpenAI response has been validated. Apple Maps has been checked live: Cape Town → Knysna returned a road route of 488 km and approximately 5 h 36 min. Actual estimates vary by departure time and traffic. Configure the ignored local files described in the README, then:

1. Complete Cape Town → Knysna and Johannesburg → Durban using live places and routes.
2. Add and remove multiple stops; compare geometry, driving duration, distance, visits and arrival/departure times against the returned route legs.
3. Try custom requests for pies, child-friendly stops, dogs and EV charging. Confirm that unsupported amenities stay unknown and explicitly incompatible results are excluded.
4. Exercise no route, empty results, missing photos/hours, provider outages, cancellation and rapid destination changes. Check that saved trips refresh their details after a cold launch.
5. Measure first verified result and complete-batch latency, along with actual Google/OpenAI usage. Bounds are implemented (six searches, eighteen candidate route checks); live cost and latency have not been measured.

The Cloud Run container and deployment instructions are supplied. Deployment and an image build have not been performed.

## Still requiring device/manual checks

A paired iPhone 12 Pro Max was listed, but its detail query timed out and no valid local signing identity was found. Physical-device installation, location-permission behavior and Google Maps app/browser handoff remain unverified. Choose an Apple development team in Xcode before installing.

Controls have accessibility labels, native text input, Dynamic Type support, and button equivalents for swipe actions. A full VoiceOver walkthrough, Reduce Motion walkthrough and the entire flow at every supported text size still require manual verification. The tested Simulator layouts are iPhone 16e and iPhone 17 Pro; this is not a claim of exhaustive device coverage.

## Local evidence

Xcode result bundles are stored under `~/Library/Developer/XcodeBuildMCP/workspaces/detour-899917efe059/result-bundles/`:

- iPhone 16e full suite: `test_sim_2026-09-18T16-32-25-358Z_pid14700_23ed2a9b.xcresult`
- Final large-text check: `test_sim_2026-09-18T16-39-15-966Z_pid14700_bbdf6bea.xcresult`

Exported screenshots are in the ignored `artifacts/test-attachments/` and `artifacts/accessibility-check/` folders. DerivedData uses `/private/tmp/detour-derived-data` to avoid iCloud Finder metadata interfering with code signing.

## Real map update

The development map now uses `MKMapView` with interactive pan/zoom, place markers, numbered stops and road-following route overlays. Apple attribution stays visible above the planning panel. `MKDirections` supplies each driving leg; the app sums their actual duration/distance and checks candidate detours against the current itinerary. Failures show an error and never substitute the previous illustrative route. Cancellation cancels the current directions request. Sample place content remains explicitly separate from real geography and driving estimates.

Live route screenshot: `artifacts/live-map-route/A9C338B7-D226-41AE-B125-7AA86471D86D.png`. All 14 native tests (10 unit, 4 UI) passed on iPhone 17 Pro after this change, including a live Apple route, discovery driving checks, and adding a stop to the itinerary. The live check is included in `testLiveAppleMapRoute` and opt-in via `DETOUR_LIVE_MAP_TEST=1` in the test runner environment.

Final map-validation result bundle: `test_sim_2026-09-18T16-48-17-591Z_pid14700_a9a13a16.xcresult`. Screenshots from the live route and itinerary are exported to `artifacts/map-validation/`.
