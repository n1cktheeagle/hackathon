import Foundation

// Sample content is confined to demo services, never substituted for production data.
enum Fixtures {
    // Mock presentation data for the hackathon demo; never returned by live services.
    static let mockRatings: [String: Double] = [
        "demo-destination-table-mountain": 4.8, "demo-destination-lions-head": 4.7,
        "demo-destination-zeitz": 4.5, "demo-destination-bokaap": 4.6,
        "demo-destination-boulders": 4.8, "demo-destination-kirstenbosch": 4.8,
        "demo-destination-stadium": 4.6, "demo-destination-aquarium": 4.6,
        "demo-destination-waterfront": 4.5, "demo-destination-castle": 4.4,
        "demo-market": 4.6, "demo-cape-point": 4.8, "demo-peregrine": 4.6,
        "demo-tredici": 4.5, "demo-dolphin": 4.7, "demo-houw-hoek": 4.5,
        "demo-drostdy": 4.6, "demo-map-africa": 4.7, "demo-goukamma": 4.7,
        "demo-aloe": 4.2, "demo-park": 4.5, "demo-rest": 4.3,
        "demo-gem-blue-cafe": 4.6, "demo-gem-book-lounge": 4.8, "demo-gem-a4": 4.7,
        "demo-gem-honest": 4.6, "demo-gem-rosetta": 4.7, "demo-gem-clarkes": 4.5,
        "demo-gem-de-waal": 4.5, "demo-gem-company-garden": 4.5, "demo-gem-green-point": 4.7
    ]
    static let capeTown = PlaceReference(id: "demo-cape-town", name: "Cape Town", subtitle: "Western Cape", coordinate: .init(latitude: -33.9249, longitude: 18.4241))
    static let knysna = PlaceReference(id: "demo-knysna", name: "Knysna", subtitle: "Western Cape", coordinate: .init(latitude: -34.0351, longitude: 23.0465))
    static let johannesburg = PlaceReference(id: "demo-johannesburg", name: "Johannesburg", subtitle: "Gauteng", coordinate: .init(latitude: -26.2041, longitude: 28.0473))
    static let durban = PlaceReference(id: "demo-durban", name: "Durban", subtitle: "KwaZulu-Natal", coordinate: .init(latitude: -29.8587, longitude: 31.0218))
    static let stops: [PlaceReference] = [
        PlaceReference(id: "demo-peregrine", name: "Peregrine Farm Stall", subtitle: "Grabouw", coordinate: .init(latitude: -34.1694, longitude: 19.0365), category: .coffee, photoName: "asset:peregrine", amenities: ["Coffee", "Pies", "Toilets", "Parking"], goodForChildren: true),
        PlaceReference(id: "demo-tredici", name: "Tredici", subtitle: "Swellendam", coordinate: .init(latitude: -34.0319, longitude: 20.4382), category: .food, photoName: "asset:tredici", amenities: ["Breakfast", "Coffee", "Parking"], goodForChildren: true),
        PlaceReference(id: "demo-dolphin", name: "Dolphin Point lookout", subtitle: "Wilderness", coordinate: .init(latitude: -33.9941, longitude: 22.5718), category: .scenic, photoName: "asset:gem-dolphin", photoAttributions: RouteDiscoveries.photoCredits(for: "dolphin"), amenities: ["Coastal views"]),
        PlaceReference(id: "demo-aloe", name: "Aloe fuel stop", subtitle: "Albertinia", coordinate: .init(latitude: -34.202, longitude: 21.582), category: .fuel, amenities: ["Fuel", "Toilets"]),
        PlaceReference(id: "demo-park", name: "Riverside picnic spot", subtitle: "Riversdale", coordinate: .init(latitude: -34.096, longitude: 21.261), category: .playgrounds, photoName: "asset:capepoint", amenities: ["Playground", "Picnic tables"], goodForChildren: true),
        PlaceReference(id: "demo-rest", name: "Garden Route rest stop", subtitle: "Mossel Bay", coordinate: .init(latitude: -34.184, longitude: 22.113), category: .toilets, amenities: ["Toilets", "Parking"]),
    ]
    static let nearby: [PlaceReference] = [
        PlaceReference(id: "demo-market", name: "Oranjezicht City Farm Market", subtitle: "V&A Waterfront", coordinate: .init(latitude: -33.903, longitude: 18.417), category: .food, photoName: "asset:market", amenities: ["Food", "Coffee"]),
        PlaceReference(id: "demo-cape-point", name: "Cape Point lighthouse walk", subtitle: "Cape Point · a little further out", coordinate: .init(latitude: -34.356, longitude: 18.496), category: .scenic, photoName: "asset:capepoint"),
    ]
    // More named Garden Route samples; provider facts and photos remain absent when unverified.
    static let extraStops: [PlaceReference] = [
        PlaceReference(id: "demo-houw-hoek", name: "Houw Hoek Farm Stall", subtitle: "Houw Hoek · N2", coordinate: .init(latitude: -34.2063, longitude: 19.1481), category: .coffee),
        PlaceReference(id: "demo-drostdy", name: "Drostdy Museum", subtitle: "Swellengrebel Street · Swellendam", coordinate: .init(latitude: -34.0195, longitude: 20.4527), category: .scenic, photoName: "asset:gem-drostdy", photoAttributions: RouteDiscoveries.photoCredits(for: "drostdy")),
        PlaceReference(id: "demo-map-africa", name: "Map of Africa viewpoint", subtitle: "Wilderness Heights", coordinate: .init(latitude: -33.9918, longitude: 22.5786), category: .scenic, photoName: "asset:gem-map-africa", photoAttributions: RouteDiscoveries.photoCredits(for: "map-africa")),
        PlaceReference(id: "demo-goukamma", name: "Goukamma Nature Reserve", subtitle: "Buffalo Bay Road · near Knysna", coordinate: .init(latitude: -34.068536, longitude: 22.947858), category: .scenic, photoName: "asset:gem-goukamma", photoAttributions: RouteDiscoveries.photoCredits(for: "goukamma")),
    ]
    static let all = [capeTown, knysna, johannesburg, durban] + stops + extraStops + nearby + RouteDiscoveries.places.map(\.place)
    static let spine: [Coordinate] = [capeTown.coordinate, .init(latitude: -34.08, longitude: 18.86), stops[0].coordinate, .init(latitude: -34.23, longitude: 19.44), stops[1].coordinate, .init(latitude: -34.09, longitude: 21.25), .init(latitude: -34.2, longitude: 21.58), .init(latitude: -34.18, longitude: 22.11), stops[2].coordinate, .init(latitude: -34.01, longitude: 22.82), knysna.coordinate]

    static func coordinate(_ point: RoutePoint) throws -> Coordinate {
        if let coordinate = point.coordinate { return coordinate }
        if let place = all.first(where: { $0.id == point.id }) ?? DestinationCatalog.details(point.id) ?? sampleBreak(point.id) { return place.coordinate }
        throw APIProblem(code: "demo_place", message: "Choose a location for your route.")
    }

    static func isGardenRoute(_ origin: Coordinate, _ destination: Coordinate) -> Bool {
        func close(_ a: Coordinate, _ b: Coordinate) -> Bool {
            hypot(a.latitude - b.latitude, (a.longitude - b.longitude) * cos(a.latitude * .pi / 180)) < 0.6
        }
        return (close(origin, capeTown.coordinate) && close(destination, knysna.coordinate)) ||
            (close(origin, knysna.coordinate) && close(destination, capeTown.coordinate))
    }

    static func estimatedDetour(_ place: PlaceReference, geometry: [Coordinate]) -> Double {
        // An illustrative return trip from the route at 35 km/h, plus time to leave/rejoin it.
        240 + RouteGeometry.distanceFromRoute(place.coordinate, along: geometry) * 2 / (35_000 / 3600)
    }

    // IDs carry the position so generated sample stops can be added and restored.
    static func sampleBreak(_ id: String) -> PlaceReference? {
        let parts = id.split(separator: "|")
        guard parts.count == 5, parts[0] == "demo-break", let category = StopCategory(rawValue: String(parts[1])),
              let latitude = Double(parts[2]), let longitude = Double(parts[3]), let percent = Int(parts[4]) else { return nil }
        let names: [StopCategory: String] = [.coffee: "A coffee break along the way", .food: "A bite on the road", .scenic: "Pause for a view", .fuel: "A refuelling break", .toilets: "Time for a rest break", .playgrounds: "A family stretch break"]
        return PlaceReference(id: id, name: names[category]!, subtitle: "Suggested break · \(percent)% along your route",
                              coordinate: .init(latitude: latitude, longitude: longitude), category: category)
    }
}

struct FixtureService: DetourService {
    var delay: Duration = .milliseconds(350)
    func search(_ query: String, sessionToken: String) async throws -> [SearchResult] {
        try await Task.sleep(for: delay)
        let known = Set(Fixtures.all.map(\.id))
        let places = Fixtures.all + DestinationCatalog.places.map(\.place).filter { !known.contains($0.id) }
        return places.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.subtitle.localizedCaseInsensitiveContains(query) }.map { SearchResult(id: $0.id, name: $0.name, subtitle: $0.subtitle) }
    }
    func details(_ id: String, sessionToken: String? = nil) async throws -> PlaceReference {
        guard let place = Fixtures.all.first(where: { $0.id == id }) ?? DestinationCatalog.details(id) ?? Fixtures.sampleBreak(id) else { throw APIProblem(code: "demo_place", message: "Place details are unavailable. Choose another place.") }
        return place
    }
    func nearby(_ coordinate: Coordinate) async throws -> [PlaceReference] { Fixtures.nearby }
    func photoURL(_ name: String) async throws -> URL? { nil }
    func route(_ request: RouteRequest) async throws -> RoutePlan {
        try await Task.sleep(for: delay)
        let origin = try Fixtures.coordinate(request.origin)
        let destination = try Fixtures.coordinate(request.destination)
        var locations: [Coordinate] = [origin]
        for stop in request.stops { locations.append(try Fixtures.coordinate(stop.place)) }
        locations.append(destination)
        let gardenRoute = Fixtures.isGardenRoute(origin, destination)
        let directMetres = hypot(origin.latitude - destination.latitude, (origin.longitude - destination.longitude) * cos(origin.latitude * .pi / 180)) * 111_000
        let baseDistance = gardenRoute ? 499_000.0 : directMetres * 1.35
        let base = gardenRoute ? 19200.0 : max(600, baseDistance / 12)
        let forward = origin.longitude < destination.longitude
        var spine = gardenRoute ? (forward ? Fixtures.spine : Array(Fixtures.spine.reversed())) : [origin, destination]
        spine[0] = origin; spine[spine.count - 1] = destination
        let progresses = locations.map { RouteGeometry.progress($0, along: spine) }
        let legs = (1..<locations.count).map { index in
            let fraction = max(0.02, abs(progresses[index] - progresses[index - 1]))
            let extra = index < locations.count - 1 ? 240 + RouteGeometry.distanceFromRoute(locations[index], along: spine) * 2 / (35_000 / 3600) : 0
            let seconds = base * fraction + extra
            return RouteLeg(durationSeconds: seconds, distanceMeters: baseDistance * fraction + extra * (35_000 / 3600))
        }
        if gardenRoute {
            for stop in locations.dropFirst().dropLast() where !spine.contains(stop) {
                let progress = RouteGeometry.progress(stop, along: spine)
                let next = spine.indices.dropFirst().first { RouteGeometry.progress(spine[$0], along: spine) > progress } ?? spine.count - 1
                spine.insert(stop, at: next)
            }
        }
        return RoutePlan(encodedPolyline: RouteGeometry.encode(gardenRoute ? spine : locations), durationSeconds: legs.reduce(0) { $0 + $1.durationSeconds }, distanceMeters: legs.reduce(0) { $0 + $1.distanceMeters }, legs: legs, calculatedAt: ISO8601DateFormatter().string(from: .now), isIllustrative: true)
    }

    func recommendations(_ request: DiscoveryRequest, geometry: [Coordinate], duration: Double) throws -> [StopSuggestion] {
        let categories = request.preferences.categories.isEmpty ? [.coffee, .food, .scenic] : request.preferences.categories
        let selected = Set(request.stops.map(\.place.id) + [request.origin.id, request.destination.id])
        let reviewed = Set(request.reviewedIDs)
        let origin = try Fixtures.coordinate(request.origin)
        let destination = try Fixtures.coordinate(request.destination)
        let gardenRoute = Fixtures.isGardenRoute(origin, destination)
        func distance(_ a: Coordinate, _ b: Coordinate) -> Double {
            hypot(a.latitude - b.latitude, (a.longitude - b.longitude) * cos(a.latitude * .pi / 180))
        }
        let cityRoute = distance(origin, Fixtures.capeTown.coordinate) < 0.7 && distance(destination, Fixtures.capeTown.coordinate) < 0.7
        let collection = gardenRoute ? Fixtures.stops + Fixtures.extraStops : (cityRoute ? RouteDiscoveries.places.map(\.place) + DestinationCatalog.places.map(\.place) : [])
        let selection = Set(request.interests)
        let directDistance = distance(origin, destination)
        func extraKilometres(_ place: PlaceReference) -> Double {
            max(0, distance(origin, place.coordinate) + distance(place.coordinate, destination) - directDistance) * 111
        }
        func continuesJourney(_ place: PlaceReference) -> Bool {
            guard cityRoute else { return true }
            let cosine = cos(origin.latitude * .pi / 180)
            let dx = (destination.longitude - origin.longitude) * cosine, dy = destination.latitude - origin.latitude
            let length = dx * dx + dy * dy
            let progress = length > 0 ? ((place.coordinate.longitude - origin.longitude) * cosine * dx + (place.coordinate.latitude - origin.latitude) * dy) / length : 0
            // Allow a worthwhile stop near either end, but exclude attractions far behind or beyond the trip.
            let forward = progress >= 0 || distance(origin, place.coordinate) * 111 < 1
            let beforeDestination = progress <= 1 || distance(destination, place.coordinate) * 111 < 1
            return forward && beforeDestination && extraKilometres(place) <= 20
        }
        func value(_ place: PlaceReference) -> Double {
            let matches = selection.intersection(DestinationCatalog.interests(for: place)).count
            let experience = DestinationCatalog.isDetourExperience(place.id) ? 2.0 : 0
            let detour = experience > 0 ? min(1, RouteGeometry.distanceFromRoute(place.coordinate, along: geometry) / 600) : 0
            // Relevance and the experience outweigh small differences in road convenience.
            let discovery = RouteDiscoveries.details(place.id) != nil ? 12.0 : 0
            let discoveryLabel = RouteDiscoveries.details(place.id)?.label
            let novelty = discoveryLabel == "Hidden gem" ? 6.0 : (discoveryLabel == "Quieter discovery" ? 3.0 : 0)
            return Double(matches) * 4 + discovery + novelty + experience + detour - extraKilometres(place) * 0.05
        }
        let eligible = collection.enumerated().filter { !selected.contains($0.element.id) && continuesJourney($0.element) && (categories.contains($0.element.category) || !request.preferences.customRequest.isEmpty) }.sorted {
            let first = value($0.element), second = value($1.element)
            return first == second ? $0.offset < $1.offset : first > second
        }.map(\.element)
        var places = eligible.filter { !reviewed.contains($0.id) }
        // A fresh search can revisit skipped suggestions once the sample collection is exhausted.
        if places.isEmpty { places = eligible }
        if cityRoute {
            // One occasional landmark, after smaller discoveries. A landmark destination
            // or accepted landmark already fills that role for this journey.
            let alreadyHasLandmark = selected.contains(where: RouteDiscoveries.isMajorAttraction)
            let landmark = alreadyHasLandmark ? nil : places.first {
                RouteDiscoveries.isMajorAttraction($0.id) && !selection.isDisjoint(with: DestinationCatalog.interests(for: $0))
            }
            places.removeAll { RouteDiscoveries.isMajorAttraction($0.id) }
            if let landmark { places.insert(landmark, at: min(4, places.count)) }
        }
        places = Array(places.prefix(6))
        if places.isEmpty {
            let lengths = zip(geometry, geometry.dropFirst()).map { a, b in hypot(b.latitude - a.latitude, (b.longitude - a.longitude) * cos(a.latitude * .pi / 180)) }
            let total = lengths.reduce(0, +)
            let positions = [3, 6, 9, 12, 15, 18] + (1...20).filter { ![3, 6, 9, 12, 15, 18].contains($0) }
            for respectReviewed in [true, false] {
              for (order, position) in positions.enumerated() {
                let fraction = Double(position) / 21
                var remaining = total * fraction
                var coordinate = geometry.first ?? origin
                for index in lengths.indices {
                    if remaining <= lengths[index] || index == lengths.count - 1 {
                        let ratio = lengths[index] > 0 ? min(1, remaining / lengths[index]) : 0
                        coordinate = .init(latitude: geometry[index].latitude + (geometry[index + 1].latitude - geometry[index].latitude) * ratio,
                                           longitude: geometry[index].longitude + (geometry[index + 1].longitude - geometry[index].longitude) * ratio)
                        break
                    }
                    remaining -= lengths[index]
                }
                let category = categories[order % categories.count]
                let id = "demo-break|\(category.rawValue)|\(coordinate.latitude)|\(coordinate.longitude)|\(Int(fraction * 100))"
                if !selected.contains(id), (!respectReviewed || !reviewed.contains(id)), let place = Fixtures.sampleBreak(id) { places.append(place) }
                if places.count == 6 { break }
              }
              if !places.isEmpty { break }
            }
        }
        let stopProgresses = try request.stops.map { RouteGeometry.progress(try Fixtures.coordinate($0.place), along: geometry) }
        return places.map { place in
            let fraction = RouteGeometry.progress(place.coordinate, along: geometry)
            return StopSuggestion(place: place, detourSeconds: Fixtures.estimatedDetour(place, geometry: geometry), arrivalOffsetSeconds: duration * fraction, visitMinutes: RouteDiscoveries.visitMinutes(for: place.id),
                reason: RouteDiscoveries.recommendationReason(for: place, interests: request.interests) ?? (place.id.hasPrefix("demo-break|") ? "A suggested \(place.category.title.lowercased()) break along your journey." : (place.id == "demo-peregrine" ? "A farm-stall coffee and pie break near Grabouw, with local flavours along the N2." : "Take a smaller local break and make the journey part of the day.")),
                insertionIndex: stopProgresses.filter { $0 <= fraction }.count,
                unverifiedRequirements: request.preferences.customRequest.isEmpty ? [] : ["Your custom request has not been confirmed for this stop"])
        }
    }
    func discover(_ request: DiscoveryRequest) -> AsyncThrowingStream<DiscoveryEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let baseline = try await route(RouteRequest(origin: request.origin, destination: request.destination, stops: request.stops, departure: request.departure))
                    let candidates = try recommendations(request, geometry: RouteGeometry.decode(baseline.encodedPolyline), duration: baseline.durationSeconds)
                    var suggestions: [StopSuggestion] = []
                    for var suggestion in candidates {
                        var proposed = RouteRequest(origin: request.origin, destination: request.destination, stops: request.stops, departure: request.departure)
                        proposed.stops.insert(RouteStop(place: suggestion.place.point, visitMinutes: suggestion.visitMinutes), at: suggestion.insertionIndex)
                        let proposedRoute = try await FixtureService(delay: .zero).route(proposed)
                        let proposedGeometry = RouteGeometry.decode(proposedRoute.encodedPolyline), geometry = RouteGeometry.decode(baseline.encodedPolyline)
                        suggestion.detourBranches = await Task.detached { RouteGeometry.detourSegments(proposedGeometry, baseline: geometry) }.value
                        try await Task.sleep(for: delay)
                        suggestions.append(suggestion)
                        continuation.yield(DiscoveryEvent(type: "candidate", suggestion: suggestion))
                        continuation.yield(DiscoveryEvent(type: "progress", message: "Looking along your route", count: suggestions.count))
                    }
                    continuation.yield(DiscoveryEvent(type: "complete", suggestions: suggestions))
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
