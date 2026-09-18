import Foundation

// Synthetic content from the supplied design; never substituted for live data.
enum Fixtures {
    static let capeTown = PlaceReference(id: "demo-cape-town", name: "Cape Town", subtitle: "Western Cape", coordinate: .init(latitude: -33.9249, longitude: 18.4241))
    static let knysna = PlaceReference(id: "demo-knysna", name: "Knysna", subtitle: "Western Cape", coordinate: .init(latitude: -34.0351, longitude: 23.0465))
    static let johannesburg = PlaceReference(id: "demo-johannesburg", name: "Johannesburg", subtitle: "Gauteng", coordinate: .init(latitude: -26.2041, longitude: 28.0473))
    static let durban = PlaceReference(id: "demo-durban", name: "Durban", subtitle: "KwaZulu-Natal", coordinate: .init(latitude: -29.8587, longitude: 31.0218))
    static let stops: [PlaceReference] = [
        PlaceReference(id: "demo-peregrine", name: "Peregrine Farm Stall", subtitle: "Grabouw", coordinate: .init(latitude: -34.1694, longitude: 19.0365), category: .coffee, rating: 4.6, ratingCount: 812, photoName: "asset:peregrine", hours: ["Demo hours · 7 am–5 pm"], amenities: ["Coffee", "Pies", "Toilets", "Parking"], goodForChildren: true),
        PlaceReference(id: "demo-tredici", name: "Tredici", subtitle: "Swellendam", coordinate: .init(latitude: -34.0319, longitude: 20.4382), category: .food, rating: 4.5, ratingCount: 1200, photoName: "asset:tredici", amenities: ["Breakfast", "Coffee", "Parking"], goodForChildren: true),
        PlaceReference(id: "demo-dolphin", name: "Dolphin Point lookout", subtitle: "Wilderness", coordinate: .init(latitude: -33.9941, longitude: 22.5718), category: .scenic, rating: 4.7, ratingCount: 342, photoName: "asset:capepoint", amenities: ["Coastal views"]),
        PlaceReference(id: "demo-aloe", name: "Aloe fuel stop", subtitle: "Albertinia · example stop", coordinate: .init(latitude: -34.202, longitude: 21.582), category: .fuel, amenities: ["Fuel", "Toilets"]),
        PlaceReference(id: "demo-park", name: "Riverside picnic spot", subtitle: "Riversdale · example stop", coordinate: .init(latitude: -34.096, longitude: 21.261), category: .playgrounds, photoName: "asset:capepoint", amenities: ["Playground", "Picnic tables"], goodForChildren: true),
        PlaceReference(id: "demo-rest", name: "Garden Route rest stop", subtitle: "Mossel Bay · example stop", coordinate: .init(latitude: -34.184, longitude: 22.113), category: .toilets, amenities: ["Toilets", "Parking"]),
    ]
    static let nearby: [PlaceReference] = [
        PlaceReference(id: "demo-market", name: "Oranjezicht City Farm Market", subtitle: "V&A Waterfront", coordinate: .init(latitude: -33.903, longitude: 18.417), category: .food, photoName: "asset:market", amenities: ["Food", "Coffee"]),
        PlaceReference(id: "demo-cape-point", name: "Cape Point lighthouse walk", subtitle: "Cape Point · a little further out", coordinate: .init(latitude: -34.356, longitude: 18.496), category: .scenic, photoName: "asset:capepoint"),
    ]
    static let all = [capeTown, knysna, johannesburg, durban] + stops + nearby
    static let spine: [Coordinate] = [capeTown.coordinate, .init(latitude: -34.08, longitude: 18.86), stops[0].coordinate, .init(latitude: -34.23, longitude: 19.44), stops[1].coordinate, .init(latitude: -34.09, longitude: 21.25), .init(latitude: -34.2, longitude: 21.58), .init(latitude: -34.18, longitude: 22.11), stops[2].coordinate, .init(latitude: -34.01, longitude: 22.82), knysna.coordinate]
}

struct FixtureService: DetourService {
    var delay: Duration = .milliseconds(350)
    func search(_ query: String, sessionToken: String) async throws -> [SearchResult] {
        try await Task.sleep(for: delay)
        return Fixtures.all.filter { $0.name.localizedCaseInsensitiveContains(query) }.map { SearchResult(id: $0.id, name: $0.name, subtitle: $0.subtitle) }
    }
    func details(_ id: String, sessionToken: String? = nil) async throws -> PlaceReference {
        guard let place = Fixtures.all.first(where: { $0.id == id }) else { throw APIProblem(code: "demo_place", message: "This place is not part of the demo.") }
        return place
    }
    func nearby(_ coordinate: Coordinate) async throws -> [PlaceReference] { Fixtures.nearby }
    func photoURL(_ name: String) async throws -> URL? { nil }
    func route(_ request: RouteRequest) async throws -> RoutePlan {
        try await Task.sleep(for: delay)
        let origin = try await details(request.origin.id)
        let destination = try await details(request.destination.id)
        var locations: [Coordinate] = [origin.coordinate]
        for stop in request.stops { locations.append(try await details(stop.place.id).coordinate) }
        locations.append(destination.coordinate)
        let gardenRoute = request.origin.id == Fixtures.capeTown.id && request.destination.id == Fixtures.knysna.id
        let base = gardenRoute ? 19200.0 : 21600.0
        let spine = gardenRoute ? Fixtures.spine : [origin.coordinate, destination.coordinate]
        let progresses = locations.map { RouteGeometry.progress($0, along: spine) }
        let legs = (1..<locations.count).map { index in
            let fraction = max(0.02, abs(progresses[index] - progresses[index - 1]))
            let seconds = base * fraction + (index < locations.count - 1 ? 240 : 0)
            return RouteLeg(durationSeconds: seconds, distanceMeters: seconds * 26)
        }
        return RoutePlan(encodedPolyline: RouteGeometry.encode(gardenRoute ? Fixtures.spine : locations), durationSeconds: legs.reduce(0) { $0 + $1.durationSeconds }, distanceMeters: legs.reduce(0) { $0 + $1.distanceMeters }, legs: legs, calculatedAt: ISO8601DateFormatter().string(from: .now))
    }
    func discover(_ request: DiscoveryRequest) -> AsyncThrowingStream<DiscoveryEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard request.origin.id == Fixtures.capeTown.id, request.destination.id == Fixtures.knysna.id else {
                        continuation.yield(DiscoveryEvent(type: "warning", message: "The demo has stops for Cape Town to Knysna. Configure live services to discover other routes."))
                        continuation.yield(DiscoveryEvent(type: "complete", suggestions: [])); continuation.finish(); return
                    }
                    let ignored = Set(request.reviewedIDs + request.stops.map(\.place.id))
                    let places = Fixtures.stops.filter { !ignored.contains($0.id) && (request.preferences.categories.contains($0.category) || !request.preferences.customRequest.isEmpty) }
                    var suggestions: [StopSuggestion] = []
                    for place in places {
                        try await Task.sleep(for: delay)
                        let fraction = RouteGeometry.progress(place.coordinate, along: Fixtures.spine)
                        let suggestion = StopSuggestion(place: place, detourSeconds: 240, arrivalOffsetSeconds: 19200 * fraction, visitMinutes: 20,
                            reason: place.id == "demo-peregrine" ? "A first coffee out of Cape Town. Pies, a place to stretch your legs, and barely off the N2." : "A little discovery along the way. Take a break and make the journey part of the day.",
                            insertionIndex: request.stops.count,
                            unverifiedRequirements: request.preferences.customRequest.isEmpty ? [] : ["Custom matching uses sample content in demo mode"])
                        suggestions.append(suggestion)
                        continuation.yield(DiscoveryEvent(type: "candidate", suggestion: suggestion))
                        continuation.yield(DiscoveryEvent(type: "progress", message: "Looking along the N2", count: suggestions.count))
                    }
                    continuation.yield(DiscoveryEvent(type: "complete", suggestions: suggestions))
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
