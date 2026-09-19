## Latest header, drawer and small-discovery checks · 18 September 2026

Final PR review on 19 September: 21 unit tests and the two affected UI flows passed in `/tmp/detour-derived-data/Logs/Test/Test-Detour-2026.09.19_07-51-23-+0200.xcresult`. The review also validated asset metadata, credential hygiene and diff whitespace; it made the simulator runner executable and removed a custom-stop sheet transition race.

All 21 unit tests passed again after the final quieter-discovery ranking boost in `/tmp/detour-derived-data/Logs/Test/Test-Detour-2026.09.18_23-33-58-+0200.xcresult`. All 21 unit tests and two native UI flows passed in `/tmp/detour-derived-data/Logs/Test/Test-Detour-2026.09.18_23-20-50-+0200.xcresult`. Coverage adds profile-dependent small-discovery ordering, real bundled image availability, venue detail resolution, non-stacked major attractions and added journey time including the stay. The UI checks cover add/skip/save/resume and the header itinerary shortcut, card return, drawer expansion/vertical drag, rating and time breakdown. Following the final estimate-label/photo-height refinement, home/discovery/drawer UI passed again in `Test-Detour-2026.09.18_23-23-18-+0200.xcresult`.

Both affected UI flows passed again in `Test-Detour-2026.09.18_23-37-22-+0200.xcresult`. The subsequent camera-clearance build passed, with normal saved-resume and compact/expanded recommendation screenshots confirming visible markers below the taller header. Live Apple directions showed De Waal Park increasing the total from 17 to 53 minutes (11 extra travel + 25 at the stop). Final captures are `artifacts/hidden-gems/live-*-postfix.png`; before/after and focused comparisons are `final-comparison.png` and `final-detail-comparison.png`.

The current app includes nine Cape Town small discoveries and four actual Garden Route images. Public venue coordinates were checked with Apple's MKLocalSearch; descriptions/addresses and photo sources are recorded in the collection and `docs/route-discovery-photo-credits.json`. Ratings remain the user-authorized mock values. Recommendation time explicitly includes extra travel plus the suggested stay; the shared header total includes accepted stays. The rendered cards retain Apfel, palette, corners and existing buttons. Final settled visual evidence and result are recorded in `design-qa.md`.

# Development verification

## Latest prototype update · Xcode 26.6

On iPhone 17 Pro / iOS 26.5: the full native run passed **19 unit tests and six UI tests**, with the optional live-network UI check skipped. Result: `/tmp/detour-derived-data/Logs/Test/Test-Detour-2026.09.18_22-21-13-+0200.xcresult`. Coverage includes font registration, detour branch departure/rejoin geometry, interest ranking, local-route eligibility, current-location discovery, offline/partial directions failures, cancellation, add/skip, save/resume, interest editing and large text.

The final map-framing adjustment reserves the complete recommendation-panel height. Its focused home/discovery UI check passed: `/tmp/detour-derived-data/Logs/Test/Test-Detour-2026.09.18_22-27-07-+0200.xcresult`. Normal Simulator launch also showed a live Apple Maps route from Cape Town to Kirstenbosch, four eligible recommendations, a Table Mountain detour with visible departure/rejoin nodes, and readable mock ratings. Source colours, card corners and button styles remain intact; typography uses the requested bundled Apfel Grotezk.

Plan my route keeps one map mounted, animates the returned route, and opens recommendations directly. Orange branches preview proposed detours with dashes and display accepted detours as solid lines. Detours splice into the visible journey and remove the main-road section they replace; a preview can also replace part of an accepted detour. Start/Continue do not force a navigation travel mode. Onboarding remains a three-interest picker on each cold launch; For you/All destination browsing reuses existing photo cards. Mock ratings are presentation-only values requested by the user, without Google attribution. Google services remain unconfigured and unverified.

At the user’s subsequent request, product copy removes all demo/sample captions, the home development badge/settings sheet, fabricated fixture hours and the demo footer in shared itineraries. Offline estimates retain the neutral label Estimated route. This is a wording change, not a switch to live Google data. After the copy and single-route refinements, all 20 unit tests passed in `/tmp/detour-derived-data/Logs/Test/Test-Detour-2026.09.18_22-41-29-+0200.xcresult`. The home/discovery and swipe/add/details UI tests passed in the preceding run (`22-38-59`); onboarding/editing UI also passed in the copy-only run (`22-36-14`). The new geometry test initially found floating-point differences at colour joins; shared junction vertices now snap to the same coordinate and the final unit run passes. These focused runs supplement the earlier full six-UI-test run. Visual evidence is in `artifacts/continuous-map/`; see `design-qa.md`.

Observed on 18 September 2026 with Xcode 26.1.1. This is a working development build with a complete fixture-backed journey and implemented live-service adapters. Google/OpenAI live-service acceptance is still pending credentials. The development app now uses Apple Maps for real mapping and driving routes without credentials.

## Earlier passing checks

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

The development map now uses `MKMapView` with interactive pan/zoom, place markers, numbered stops and road-following route overlays. Apple attribution stays visible above the planning panel. `MKDirections` supplies each driving leg; the app sums their actual duration/distance and checks candidate detours against the current itinerary. Demo routing now falls back to a labelled illustrative estimate when directions fail; production service failures remain errors. Cancellation cancels the current directions request. Fixture place content remains separate in the implementation from live geography and driving estimates; product demo/sample captions were later removed at the user’s request.

Live route screenshot: `artifacts/live-map-route/A9C338B7-D226-41AE-B125-7AA86471D86D.png`. All 14 native tests (10 unit, 4 UI) passed on iPhone 17 Pro after this change, including a live Apple route, discovery driving checks, and adding a stop to the itinerary. The live check is included in `testLiveAppleMapRoute` and opt-in via `DETOUR_LIVE_MAP_TEST=1` in the test runner environment.

Final map-validation result bundle: `test_sim_2026-09-18T16-48-17-591Z_pid14700_a9a13a16.xcresult`. Screenshots from the live route and itinerary are exported to `artifacts/map-validation/`.
