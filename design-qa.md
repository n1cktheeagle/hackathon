# Map-first home design QA

## Target and references

Help a stationary user begin a route from their current location or choose a discovery as their destination. This adapts Uber's input and map layering patterns to Detour; it is not a pixel-for-pixel Uber clone.

- [Uber route inputs on Mobbin](https://mobbin.com/screens/94eef071-be28-4652-8ac7-3986c77722c7): linked origin dot and destination square, stacked inputs, destination emphasis.
- [Uber map-led screen on Mobbin](https://mobbin.com/screens/a580c48b-f52a-4a3c-87c7-7bb8aa4056cc): floating search control and cards over an interactive map.

Full-resolution references and implementation captures are local in ignored `artifacts/home-map/`. `reference-comparison.png` compares the two references and implementation at 402 × 874. The Mobbin footer is excluded from the normalized reference viewport; images preserve their aspect ratio.

## Visual checks

- Full-screen neighborhood map, clear central map area, visible selected/current position.
- White floating From / Where to? controls above the map, with connected origin/destination symbols and accessible search actions.
- Detour wordmark, existing ink/muted palette, shared type hierarchy, actual project photos, and native map tiles. The latest update replaces the rounded system font with the requested Apfel Grotezk family.
- Discovery cards and the destination/route button float above the map; Apple attribution and Legal remain visible.
- Bundled places are Cape Town fixture content; simulated GPS does not imply live recommendations at that position. The latest copy request removes user-facing demo/sample captions.
- Choosing a discovery opens existing details; selecting it as destination enables route planning.
- Automatic location is optional and guarded against replacing a manually selected origin or destination after a late response. Location denial leaves manual search available.
- Largest accessibility text uses vertical scrolling and text-only discovery cards, preserving readable controls and destination selection.

## Validation

- iPhone 17 Pro, iOS 26.5 simulator: successful build, installation and launch.
- Native suite: 10 unit tests + 4 UI tests passed, 0 failures. The optional live Apple routing test was skipped.
- Home discovery and large-text UI checks repeated after the accessibility layout change.
- A strengthened large-text test swiped to the destination button, verified it was hittable, and opened search successfully. Its screenshot shows the complete two-line button label. Captures are in `artifacts/home-map/large-text-check/`.
- Simulator run script executed successfully; shell syntax and `git diff --check` passed.
- Per-user Xcode DerivedData points to the script's `/tmp/detour-derived-data` cache. A cached build/install/relaunch with no source changes measured 18.33 seconds; this is not a guarantee for builds after edits.

## Intentional differences and remaining service setup

Detour retains its own typography, branding and stop-discovery content. The home screen combines the reference patterns in the initial idle state, without Uber's keyboard or ride-booking controls. Native Apple map tiles provide the working development preview. A configured Maps SDK for iOS key enables the Google home renderer independently of backend setup; Google rendering has not been live-verified because no key is configured. Demo routing continues to use Apple Maps.

## Interest onboarding and destination browser

Target: preserve Detour's existing card system while helping a stationary user choose a destination that matches three interests. Onboarding appears at every cold launch, remembers previous choices, and offers eight icon cards in a two-column scrolling grid with a pinned Continue button. The top-right interests control on home and in destination browsing allows changes without losing the trip.

- [Tripadvisor attraction list reference](https://mobbin.com/screens/11728e5b-86ab-469f-b137-7b23d85c5807): photographs on the left, clear attraction names, vertically browseable rows. The implementation keeps Detour's muted card backgrounds, 16-point corners, type hierarchy, wordmark and ink CTA.
- Source and normalized comparison: `artifacts/destination-browser/tripadvisor-attractions.webp` and `reference-comparison.png`, at a shared 390 × 848 viewport. `screen-preview.png` shows onboarding, For you, and All. Reference normalization removes the Mobbin footer and preserves aspect ratio.
- For you includes matching places and favours dedicated interest matches; selecting Arts, Culture and Sports puts Zeitz MOCAA and DHL Stadium first. All starts with Table Mountain and Lion's Head. Match labels explain each personalised row.
- Table Mountain's cableway/viewpoint and Lion's Head's hiking trail are Nature destinations, with Scenic as their route-stop category. Neither matches Sports on its own; DHL Stadium is the dedicated sports destination. The interest regression check verifies this distinction.
- Shared discovery cards support Google ratings and review counts in connected mode when supplied by the service, with accessible spoken labels. At the user's subsequent request, demo cards now use a separate mock rating collection without a Sample caption, Google attribution or invented review counts. No live Google rating has been fetched or verified without configured services.
- Destinations reuse `PlaceDiscoveryRow` with the home cards, plus existing `PlacePhoto`, `PrimaryButton` and theme tokens. Ten licensed photos are bundled; sources/licences are recorded in `docs/destination-photo-credits.json` and accessible through Photo credits.
- Onboarding's last interest row remains browseable through scrolling. The Continue CTA remains visible and enables at exactly three selections. Largest text uses readable scrolling layouts and text-only destination rows.
- A container accessibility identifier that overrode Continue's identifier was removed after the UI regression caught it; the affected onboarding flow then passed twice.

## Demo reliability validation

- Fixed coordinate-aware Garden Route matching, including Current location and the reverse route. Current location can also plan and add stops through the deterministic test service.
- Short Cape Town-area routes recommend named attractions with photos. Other routes use suggested break locations backed by fixture coordinates. Endpoints and accepted stops are excluded; exhausted skipped samples can be revisited.
- Demo discovery retains closest alternatives beyond tight detour preferences with truthful extra-drive labels. Offline directions use Estimated route; cancellation still cancels work. Production service errors are unchanged.
- Final native checks: 16 unit tests passed after the local-route recommendation change. Six UI tests passed across the full run and affected-flow retries; the optional live-network test was skipped. Tests cover GPS discovery/addition, save/resume, search, interest selection/change, destination ranking, local destination planning, offline/partial-provider failure and large text.
- After correcting Nature/Sports tags, all 16 unit tests passed again. Following the optional live-rating card display change, the destination regression and complete onboarding/browsing/editing/route UI flow passed again. Final captures are in `artifacts/destination-browser/realistic-captures/`.
- Normal demo launch and three-interest selection were visually inspected in Simulator, followed by GPS-based map-first home. No Google key/backend is configured, so Google photo and map rendering remain unverified.

## Continuous map, detours and typography · 18 September

The supplied `Screenshot 2026-09-18 at 21.36.46.png` is a cropped example of the previous route summary, not a full-screen design to clone. The requested changes retain its duration/distance/endpoint hierarchy in a compact floating card and carry the home map through planning, recommendations and itinerary. The Uber and Tripadvisor references above remain the layout references.

| Surface | Design retained | Requested refinement |
| --- | --- | --- |
| Map and layering | Native muted tiles, interactive map, existing wordmark and circular controls | One mounted map through the trip, 1.4-second route reveal, cards float above it |
| Route summary | Ink duration, muted distance and endpoints, existing sliders | Smaller floating summary with selected filter chips; no mandatory preference screen |
| Recommendation card | Existing `PlacePhoto`, white fill, 24-point corners, 16-point body padding | Rating and extra-minute capsules over the photo; concise attraction description |
| Colour and actions | Original ink/muted palette, 52-point `PrimaryButton`, 12-point button corners | Existing orange accent marks detour roads and departure/rejoin nodes; dashed preview, solid accepted route |
| Typography | Existing text roles and Dynamic Type | Bundled Apfel Regular/Mittel/Fett, matching 17-point semibold From/To values, custom navigation titles |

- Cards now prioritize interest relevance and worthwhile experiences, with a modest bonus for attractions off the main road. Accepted stops remain inserted in journey order. Default detour allowance is 30 minutes; the extra time is visible before adding a stop.
- Short Cape Town journeys exclude substantially backward or beyond-destination attractions. Cape Town → Kirstenbosch offers four eligible named discoveries; Garden Route/default destination browsing can offer six. Fewer genuinely eligible places are preferable to padding with unrelated venues.
- Goukamma uses CapeNature's published coordinates on Buffalo Bay Road. New Garden Route venues retain the existing photo placeholder where a licensed photograph is not bundled; they do not borrow another venue's photograph.
- Mock ratings are presentation-only demo data, requested by the user. No Sample rating caption, Google rating attribution or invented review counts appear in demo cards. Live Google cards continue to use provider fields.
- Native branch detection has a 35-metre matching tolerance for encoded geometry and lane offsets. Departure/rejoin nodes snap to the baseline geometry. Camera correction is bounded to three passes after MapKit applies the camera, then normal pan/zoom resumes.
- First implementation captures in `artifacts/continuous-map/first-captures/` exposed covered endpoints and clipped metadata. Rating and detour capsules were moved onto the photograph, and concise text restored the reason for stopping. Subsequent camera captures are retained to document the framing correction.
- A fast itinerary review exposed a save race during asynchronous branch calculation. Stop updates now commit after calculation; review waits while the update is busy. Save/resume and the repeated-add guard are covered by native checks.
- Apfel's three PostScript names are checked against the app bundle in the native font-registration test. The unmodified fonts and OFL 1.1 licence are bundled together.

## Latest copy and single-route refinement

- Removed the Curated demo collection caption, home Demo badge/development settings sheet, Sample discoveries subtitle, place-detail demo notice and shared-itinerary demo footer. Offline route labels read Estimated route. Generated breaks say Suggested break; custom requests retain a neutral not-confirmed message. Unverified fixture opening hours were removed instead of presented as actual hours. Photo credits remain accessible.
- Detour composition splices orange geometry into the visible journey and removes the replaced section. A preview can splice into an already accepted orange detour, so overlapping old routes are removed. Out-and-back detours preserve the onward road after rejoining the same junction.
- The baseline remains available for geometry comparison but is not rendered as an alternative route. Both native map renderers use the same composed strokes. Orange styles and departure/rejoin nodes retain the existing design tokens.
- The copy-only UI run passed both home-to-recommendations and onboarding/browsing/editing flows. One old unit assertion expected the removed Sample stop caption; it was updated to Suggested break before the final geometry run.

## Final result

Passed on the rebuilt iPhone 17 Pro / iOS 26.5 Simulator. Normal launch retained the three selected interests. Home shows consistent smaller From/To values without a development badge or sample caption. Destination search shows Photo credits as its only collection footer. Cape Town → Kirstenbosch returned a live road route, four recommendations and a Table Mountain detour with visible leave/rejoin dots. The original black section disappears during preview; adding Table Mountain retains a solid orange segment, one numbered stop and a connected onward black road. The next Bo-Kaap recommendation remains swipeable with rating and additional minutes visible.

Final evidence:
- `artifacts/continuous-map/screen-preview.png`: home, destination browsing, collection footer and live single-route preview, normalized to a shared 402 × 874 viewport without cropping.
- `artifacts/continuous-map/detour-comparison.png`: earlier overlapping paths, current single-route preview and accepted stop with the next preview at the same viewport.
- `artifacts/continuous-map/single-route-live-preview-final.png` and `single-route-live-accepted-final.png`: full-resolution live road screenshots.
- `artifacts/continuous-map/framing-comparison.png`: earlier covered endpoints versus corrected card/map framing before the subsequent single-route refinement.
- Latest 20-unit run: `/tmp/detour-derived-data/Logs/Test/Test-Detour-2026.09.18_22-41-29-+0200.xcresult`, zero failures. The new nested-preview test first found floating-point differences at join vertices; both adjoining strokes now use the same snapped coordinate.
- Home/discovery and swipe/add/details UI checks passed in the `22-38-59` result bundle. Onboarding/browsing/editing passed in the copy-only `22-36-14` run. These focused checks supplement the full 19-unit/six-UI run at `22-21-13` and the map-framing retry at `22-27-07`.

Intentional differences from the supplied summary crop: compact title3 duration, inline distance, smaller endpoint text, optional filter chips, orange single-route detours and the requested Apfel font. Existing white cards, corners, spacing, ink buttons and palette are retained. Mock ratings remain requested presentation data; Google live services and renderer have not been verified because credentials are unavailable.


## Integrated header and shared drawer · latest layout pass

Source visual: user-supplied `Screenshot 2026-09-18 at 22.45.18.png` (not committed), plus current-run before captures `artifacts/header-drawer/01-recommendations-before.png` and `02-itinerary-before.png`. The user screenshot shows the previous layout to improve, not a new full-screen target to copy unchanged. Current-run before captures contain two accepted scenic stops and a Castle of Good Hope recommendation; the supplied image contains one accepted stop and Bo-Kaap. Compare the matched current-run states for layout; do not infer data mismatches from those counts.

Requested fixes: move duration/distance/endpoints/filters into one app header; group recommendation/photo/actions on a bottom drawer; relocate itinerary review to the header; use that same drawer/header for itinerary. The existing native map remains mounted. Camera padding reserves measured header height and explicit drawer height, including expanded mode. The drawer supports tap, vertical drag and accessibility adjustment; itinerary can return to the remaining cards without restarting discovery.

Initial audit findings: [P1] disconnected floating summary/card/actions; [P2] itinerary changes hierarchy and leaves a bottom map strip; [P2] duplicate footer actions reduce useful map area. Fixes preserve Apfel roles, palette, photos, 24-point card/drawer corners and 52-point buttons. Photo cards use the existing border token to stay distinguishable on the drawer's white surface. Itinerary uses a compact title, muted rounded list and parallel footer actions. Full current-run audit notes: `docs/header-drawer-review.md`.

First native layout run exposed inherited accessibility identifiers on the header/drawer containers; child identifiers were restored and the handle given a 44-point target. Header itinerary shortcut, returning to the cards, drawer tap/vertical drag and saved resume then passed. The first visual capture showed a covered endpoint and attribution; native margins reserve attribution space and camera correction now projects its actual margin-adjusted screen anchor. The first hidden-gem capture (`artifacts/hidden-gems/first-captures/`) also showed the recommendation reason below the compact viewport and insufficient expanded-map space. The compact drawer now uses 52% of the available height, the estimate label sits alongside the duration/distance instead of on its own row, the photo is 110 points high, expanded mode reserves 160 points of central map, and the fit respects the smaller available coordinate area rather than forcing an 80-point minimum. The later settled normal-launch captures below confirm these fixes.

Subsequent content request is part of this pass: prioritise small discoveries, limit landmarks and show total added journey minutes with detour/stay components. Nine real Cape Town discoveries and four Garden Route photographs replace attraction-heavy cards and missing/mismatched pictures. Venue addresses/descriptions use published venue/City sources; Cape Town coordinates were checked with MKLocalSearch. The same Apfel fonts, colour tokens, photo-card border/corners and primary/secondary buttons remain. Ratings are the user's requested mock presentation values. Where to keeps major destinations.

A normal saved-resume check then exposed [P2] an origin marker covered by the taller header after accepting a 25-minute stop. Removing overlapping camera animations alone did not resolve it. Native fitting now waits for MapKit to apply each correction before projecting the next pass, instead of recursively fitting from region callbacks with stale screen positions. That alone was insufficient; increasing the marker reserve above the projected route from 44 to 72 points keeps the full marker below the taller header. `artifacts/hidden-gems/live-itinerary-sequential.png` records the insufficient first retry; `live-itinerary-postfix.png`, `live-recommendation-postfix.png` and `live-expanded-postfix.png` show the corrected settled states.

### Final comparison

Source truth: the supplied screenshot and `artifacts/header-drawer/01-recommendations-before.png` / `02-itinerary-before.png`. Implementation: `artifacts/hidden-gems/live-recommendation-postfix.png`, `live-itinerary-postfix.png` and `live-expanded-postfix.png`. Device: iPhone 17 Pro / iOS 26.5, light theme, native 402 × 874-point screen at @3 density. Before and after screenshots are 1206 × 2622 pixels. `artifacts/hidden-gems/final-comparison.png` combines both source and implementation at 402 × 874 per column, with no device bezel, cropping or aspect-ratio distortion; the added 36-pixel caption band is outside each app viewport. `final-detail-comparison.png` combines actual source card and implementation card/header/itinerary crops for readable type, controls and imagery inspection.

State difference is intentional: both comparisons use Cape Town → Kirstenbosch. The earlier layout has two mountain stops; the revised capture has one De Waal Park stop and a Blue Café recommendation. Stop count, times, photos, route geometry and native adaptive map labels therefore differ. The current header includes accepted stays, whereas the old recommendation summary showed road time alone. This comparison judges the requested layout and design preservation, not pixel-identical trip data.

| Required surface | Visible result |
| --- | --- |
| Fonts / typography | Apfel is retained throughout, with the existing script wordmark. Ink semibold duration/title, smaller muted metadata and consistent button type remain clear. Endpoints and the full two-line interest reason fit; rating and added minutes are legible over the photo. Font registration is independently tested. |
| Spacing / layout rhythm | Route summary is integrated beneath the header controls. The shared rounded drawer contains the card and both 52-point actions. The itinerary uses that same header/drawer, with a muted list and parallel actions. The footer review link is replaced by the header shortcut. Compact and expanded captures retain readable card text, actions, attribution and markers. |
| Colours / tokens | Existing white surfaces, ink CTA/text, muted text and pale category chips are preserved. Orange remains the sole detour accent. Card borders use the existing muted border token; no new palette or gradient is introduced. |
| Image quality | Blue Café shows the actual venue, with a stable wide crop and no stretched image, placeholder or synthetic substitute. Its supplied image is softer than the original high-resolution landmark photograph but adequate at the native card size; published attribution remains available. All nine city images resolve from the app bundle; the four Garden Route additions show their actual locations. |
| Copy / content | “Hidden gem · Culture,” the interest-specific reason, prominent mock rating and “Adds about 38 min · 8 min detour + 30 min stop” communicate the recommendation. Header total and “Includes 25 min at stops” agree with itinerary. Start is mode-neutral. Product copy contains no demo/sample collection caption or invented opening hours/review counts. |

No actionable P0/P1/P2 findings remain in the reviewed states. Earlier accessibility identifier, clipped metadata, covered attribution and covered-marker findings are fixed with the post-fix evidence above. The normal live-road check observed De Waal Park adding about 36 minutes: 11 minutes of detour and a 25-minute stay, increasing the displayed total from 17 to 53 minutes. More stops returned six suggestions, with Blue Café first for the selected Culture/Wildlife/Nature profile.

Validation: 21 unit tests passed in `Test-Detour-2026.09.18_23-33-58-+0200.xcresult`. Both affected UI flows passed in `Test-Detour-2026.09.18_23-37-22-+0200.xcresult`: home/discovery/header review/card return/drawer tap and drag, and add/skip/save/resume/start. The subsequent camera-clearance changes built successfully and were checked in normal saved-resume, compact recommendation and expanded recommendation states. `git diff --check` passes.

P3 follow-up: nearby native markers can overlap at the overview zoom, especially in expanded mode. The card/list still identifies each stop; map pan/zoom remains available. Full VoiceOver, all Dynamic Type sizes and physical-device review remain outside this focused check. Google live services remain unconfigured; current ratings are the explicitly requested mock values.

Implementation checklist: header integration, shared drawer, itinerary shortcut, small-discovery ranking, non-stacked landmarks, total added-time breakdown, real bundled photographs and post-fix map framing are complete.

Final result: passed

## Onboarding and stationary polish · 19 September 2026

Source truth: the current implementation before this request, captured in `artifacts/destination-browser/onboarding.png` and `artifacts/home-map/home-stationary.png`. Implementation: `artifacts/polish/onboarding-after.png` and `home-after.png`. `artifacts/polish/final-comparison.png` places the matched 402 × 874-point states side by side without cropping or aspect-ratio distortion. The differing clock and remembered origin reflect separate launches and do not affect the reviewed components.

| Required surface | Visible result |
| --- | --- |
| Fonts / typography | Apfel remains registered and visible. Semibold UI text now resolves to Apfel Mittel, and From/Where to plus interest-card titles explicitly use the medium role. Bold remains available for the few strongest hierarchy points. |
| Spacing / layout rhythm | Removing the onboarding badge and footer status row gives the interest grid and CTA a quieter vertical rhythm. Removing the promotional location pill lets the map breathe between route inputs and the stationary discovery drawer. Existing margins, two-column cards, rounded inputs and pinned CTA remain aligned. |
| Colours / tokens | Existing ink, white, muted grey and map colours are unchanged. Filled category symbols use the current foreground treatment in both selected and unselected cards. |
| Image quality | Existing attraction photographs and their crops are unchanged; the home card remains sharp at the native card size. |
| Copy / content | “Made for you,” “Ready to explore,” the 3-of-3 counter and “Your next good stop starts here” are absent. Stationary discovery reads “Explore Cape Town.” My Trips uses a filled suitcase. The route-recommendation state retains “Worth a stop,” where the phrase describes an active journey. |

The destination regression drags directly on a result row and verifies that scrolling leaves the Where to browser open without selecting a destination. The interest-symbol regression verifies that every configured SF Symbol is both filled and available. All 22 unit tests and the focused UI flow passed in `Test-Detour-2026.09.19_09-03-14-+0200.xcresult`.

No actionable P0/P1/P2 findings remain in the reviewed onboarding, stationary home or destination-scroll states. Full VoiceOver, all Dynamic Type sizes and physical-device review remain outside this focused pass.

Final result: passed
