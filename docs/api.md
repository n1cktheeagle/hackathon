# Detour API v1

All endpoints except health require `Authorization: Bearer <DETOUR_ACCESS_TOKEN>` when the private development token is configured. JSON field names use lower camel case. Coordinates are `{latitude, longitude}` in decimal degrees. Distances are metres, durations seconds, visits minutes, departures ISO 8601 UTC strings. Errors are `{code, message}` with a non-2xx status. Responses may omit unavailable provider facts; clients must not replace these with invented defaults.

The canonical server contracts and validation are in `backend/src/contracts.ts`; their native equivalents are in `ios/Detour/Core/Models.swift`. Changes must update both and their tests.

| Endpoint | Input | Output |
| --- | --- | --- |
| `GET /health` | — | `{status:"ok",version:1}` |
| `POST /v1/autocomplete` | `{input,sessionToken}`; 2–160 characters and a UUID | Array of `{id,name,subtitle}`; South African results |
| `GET /v1/places/:id` | Optional `?sessionToken=<UUID>` | `PlaceReference` with available details and attribution |
| `POST /v1/nearby` | Coordinate | Up to eight nearby places |
| `POST /v1/photo` | `{name}`; Google photo resource name | `{uri}`; short-lived provider image URL, no image proxy/cache |
| `POST /v1/route` | `RouteRequest` | `RoutePlan` with full polyline and ordered legs |
| `POST /v1/discover` | `DiscoveryRequest` | Newline-delimited JSON event stream |

`RouteRequest`: origin and destination `RoutePoint`s, ordered `stops: [{place: RoutePoint,visitMinutes}]`, and `departure`. A `RoutePoint` contains a provider `id`; `current-location` additionally requires a coordinate. Maximum 12 stops. Route durations intentionally exclude live traffic; departure is used by the native itinerary timeline.

`DiscoveryRequest` adds `preferences: {categories,customRequest,maxDetourMinutes}`, `reviewedIDs` and `coveredCategories`. Categories are `coffee`, `food`, `scenic`, `fuel`, `toilets`, `playgrounds`. Custom requests have a 600-character limit. The server re-fetches the baseline route and checks candidate insertions against it.

`StopSuggestion`: place, additional driving in `detourSeconds`, time from departure in `arrivalOffsetSeconds`, `visitMinutes`, grounded `reason`, `insertionIndex`, and `unverifiedRequirements`. The native app recomputes the next candidate against the current itinerary after decisions that change the route.

Stream events:

- `progress`: `{type,message,count}` describes actual work.
- `candidate`: `{type,suggestion}` identifies a place whose route has been checked.
- `warning`: `{type,message}` reports partial provider failure or AI fallback.
- `complete`: `{type,suggestions}` terminates a successful search, including empty searches.
- `error`: `{type,code,message}` terminates a failed search after streaming begins.

The client treats an ended stream without `complete` as interrupted. Closing the connection aborts provider requests. Superseded native tasks are cancelled and results are also guarded by a trip revision identifier. Provider errors never expose raw API responses, credentials or request bodies.
