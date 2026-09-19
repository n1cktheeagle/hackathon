import Foundation
import MapKit

/// Real road geometry and travel estimates; no API key or location permission needed.
@MainActor final class AppleRouteProvider: RouteProviding {
    @MainActor private final class ActiveDirections {
        let value: MKDirections
        init(request: MKDirections.Request) { value = MKDirections(request: request) }
    }
    private struct LegResult {
        var coordinates: [Coordinate]
        var leg: RouteLeg
        var fetched: Date
    }
    // Session-only caching avoids requesting unchanged legs when a stop is added.
    private var legs: [String: LegResult] = [:]

    func route(_ input: RouteRequest) async throws -> RoutePlan {
        let points = [input.origin] + input.stops.map(\.place) + [input.destination]
        var geometry: [Coordinate] = []
        var routeLegs: [RouteLeg] = []
        var departure = ISO8601DateFormatter().date(from: input.departure) ?? .now
        for index in 1..<points.count {
            try Task.checkCancellation()
            guard let start = points[index - 1].coordinate, let end = points[index].coordinate else {
                throw APIProblem(code: "missing_coordinate", message: "Choose both locations before calculating a route.")
            }
            let key = "\(start.latitude),\(start.longitude):\(end.latitude),\(end.longitude):\(Int(departure.timeIntervalSince1970 / 1800))"
            let result: LegResult
            if let cached = legs[key], Date.now.timeIntervalSince(cached.fetched) < 300 {
                result = cached
            } else {
                let request = MKDirections.Request()
                request.source = MKMapItem(location: CLLocation(latitude: start.latitude, longitude: start.longitude), address: nil)
                request.destination = MKMapItem(location: CLLocation(latitude: end.latitude, longitude: end.longitude), address: nil)
                request.transportType = .automobile
                request.requestsAlternateRoutes = false
                request.departureDate = departure
                let directions = ActiveDirections(request: request)
                do {
                    let response = try await withTaskCancellationHandler {
                        try await directions.value.calculate()
                    } onCancel: {
                        Task { @MainActor in directions.value.cancel() }
                    }
                    try Task.checkCancellation()
                    guard let route = response.routes.first else {
                        throw APIProblem(code: "no_route", message: "Apple Maps could not find a driving route between these places.")
                    }
                    let coordinates = (0..<route.polyline.pointCount).map { index in
                        let coordinate = route.polyline.points()[index].coordinate
                        return Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    }
                    result = LegResult(coordinates: coordinates,
                                       leg: RouteLeg(durationSeconds: route.expectedTravelTime, distanceMeters: route.distance), fetched: .now)
                    if legs.count >= 100 { legs.removeAll() }
                    legs[key] = result
                } catch {
                    try Task.checkCancellation()
                    if let problem = error as? APIProblem { throw problem }
                    throw APIProblem(code: "apple_route_unavailable", message: "The driving route couldn't load. Check your connection and try planning again.")
                }
            }
            geometry.append(contentsOf: geometry.isEmpty ? result.coordinates : Array(result.coordinates.dropFirst()))
            routeLegs.append(result.leg)
            departure.addTimeInterval(result.leg.durationSeconds)
            if index <= input.stops.count { departure.addTimeInterval(Double(input.stops[index - 1].visitMinutes * 60)) }
        }
        return RoutePlan(encodedPolyline: RouteGeometry.encode(geometry),
                         durationSeconds: routeLegs.reduce(0) { $0 + $1.durationSeconds },
                         distanceMeters: routeLegs.reduce(0) { $0 + $1.distanceMeters },
                         legs: routeLegs, calculatedAt: ISO8601DateFormatter().string(from: .now))
    }
}

/// Demo places use live directions when available, with labelled offline estimates.
struct AppleMapDemoService: DetourService {
    let routes: any RouteProviding
    private let fixtures = FixtureService()
    func search(_ query: String, sessionToken: String) async throws -> [SearchResult] { try await fixtures.search(query, sessionToken: sessionToken) }
    func details(_ id: String, sessionToken: String?) async throws -> PlaceReference { try await fixtures.details(id, sessionToken: sessionToken) }
    func nearby(_ coordinate: Coordinate) async throws -> [PlaceReference] { try await fixtures.nearby(coordinate) }
    func photoURL(_ name: String) async throws -> URL? { nil }
    func route(_ request: RouteRequest) async throws -> RoutePlan {
        func resolved(_ point: RoutePoint) async throws -> RoutePoint {
            if point.coordinate != nil { return point }
            return RoutePoint(id: point.id, coordinate: try await fixtures.details(point.id).coordinate)
        }
        var hydrated = request
        hydrated.origin = try await resolved(request.origin)
        hydrated.destination = try await resolved(request.destination)
        for index in request.stops.indices { hydrated.stops[index].place = try await resolved(request.stops[index].place) }
        do { return try await routes.route(hydrated) }
        catch {
            try Task.checkCancellation()
            return try await fixtures.route(hydrated)
        }
    }
    func discover(_ input: DiscoveryRequest) -> AsyncThrowingStream<DiscoveryEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let baselineInput = RouteRequest(origin: input.origin, destination: input.destination, stops: input.stops, departure: input.departure)
                    let baseline = try await route(baselineInput)
                    let geometry = RouteGeometry.decode(baseline.encodedPolyline)
                    var suggestions: [StopSuggestion] = []
                    var longerDetours: [StopSuggestion] = []
                    for var suggestion in try fixtures.recommendations(input, geometry: geometry, duration: baseline.durationSeconds) {
                        try Task.checkCancellation()
                        continuation.yield(DiscoveryEvent(type: "progress", message: "Checking the drive to \(suggestion.place.name)", count: suggestions.count))
                        let progress = RouteGeometry.progress(suggestion.place.coordinate, along: geometry)
                        var index = 0
                        for stop in input.stops {
                            let coordinate = try Fixtures.coordinate(stop.place)
                            if RouteGeometry.progress(coordinate, along: geometry) <= progress { index += 1 }
                        }
                        var proposed = baselineInput
                        proposed.stops.insert(RouteStop(place: suggestion.place.point, visitMinutes: suggestion.visitMinutes), at: index)
                        let result = try await route(proposed)
                        let proposedGeometry = RouteGeometry.decode(result.encodedPolyline)
                        suggestion.detourBranches = await Task.detached { RouteGeometry.detourSegments(proposedGeometry, baseline: geometry) }.value
                        let estimated = baseline.isIllustrative == true || result.isIllustrative == true
                        suggestion.detourSeconds = estimated ? Fixtures.estimatedDetour(suggestion.place, geometry: geometry) : max(0, result.durationSeconds - baseline.durationSeconds)
                        suggestion.insertionIndex = index
                        suggestion.arrivalOffsetSeconds = result.legs.prefix(index + 1).reduce(0) { $0 + $1.durationSeconds } + Double(input.stops.prefix(index).reduce(0) { $0 + $1.visitMinutes } * 60)
                        if !suggestion.place.id.hasPrefix("demo-break|") {
                            let minutes = Int(ceil(suggestion.detourSeconds / 60))
                            let discovery = RouteDiscoveries.recommendationReason(for: suggestion.place, interests: input.interests) ?? suggestion.reason
                            suggestion.reason = discovery + " " + (estimated ? "Estimated extra driving time: \(minutes) minutes." : "Apple Maps estimates \(minutes) extra minutes of driving.")
                        }
                        if suggestion.detourSeconds > Double(input.preferences.maxDetourMinutes * 60) {
                            suggestion.reason += " A little beyond your selected detour limit."
                            longerDetours.append(suggestion)
                            continue
                        }
                        suggestions.append(suggestion)
                        continuation.yield(DiscoveryEvent(type: "candidate", suggestion: suggestion))
                    }
                    // Demo preferences are a ranking aid: always offer the closest alternatives.
                    if suggestions.isEmpty {
                        suggestions = Array(longerDetours.sorted { $0.detourSeconds < $1.detourSeconds }.prefix(6))
                        for suggestion in suggestions { continuation.yield(DiscoveryEvent(type: "candidate", suggestion: suggestion)) }
                    } else if suggestions.count < 6 {
                        let alternatives = longerDetours.sorted { $0.detourSeconds < $1.detourSeconds }.prefix(6 - suggestions.count)
                        suggestions.append(contentsOf: alternatives)
                        for suggestion in alternatives { continuation.yield(DiscoveryEvent(type: "candidate", suggestion: suggestion)) }
                    }
                    continuation.yield(DiscoveryEvent(type: "complete", suggestions: suggestions))
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
