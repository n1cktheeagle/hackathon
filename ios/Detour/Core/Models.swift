import Foundation

struct Coordinate: Codable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double
}

enum StopCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case coffee, food, scenic, fuel, toilets, playgrounds
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .coffee: "cup.and.saucer"
        case .food: "fork.knife"
        case .scenic: "mountain.2"
        case .fuel: "fuelpump"
        case .toilets: "figure.stand"
        case .playgrounds: "figure.play"
        }
    }
}

struct Attribution: Codable, Hashable, Sendable {
    var name: String
    var uri: String?
    var photoURI: String?
}
struct PlaceReview: Codable, Hashable, Sendable {
    var text: String
    var author: Attribution
    var relativeTime: String
    var uri: String?
}
struct PlaceReference: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var subtitle: String
    var coordinate: Coordinate
    var category: StopCategory = .scenic
    var rating: Double?
    var ratingCount: Int?
    var mapsURI: String = ""
    var photoName: String?
    var photoURI: String?
    var photoAttributions: [Attribution] = []
    var hours: [String] = []
    var openNow: Bool?
    var amenities: [String] = []
    var allowsDogs: Bool?
    var goodForChildren: Bool?
    var reviews: [PlaceReview] = []
    var point: RoutePoint { RoutePoint(id: id, coordinate: id == "current-location" ? coordinate : nil) }
}
struct SearchResult: Codable, Identifiable, Sendable {
    var id: String
    var name: String
    var subtitle: String
}
struct TripPreferences: Codable, Equatable, Sendable {
    var categories: [StopCategory] = [.coffee, .food, .scenic]
    var customRequest = ""
    var maxDetourMinutes = 20
}
struct TripStop: Codable, Identifiable, Sendable {
    var place: PlaceReference
    var visitMinutes = 20
    var visited = false
    var id: String { place.id }
}
struct TripDraft: Sendable {
    var id = UUID()
    var title = "My mission"
    var origin: PlaceReference?
    var destination: PlaceReference?
    var departure = Date()
    var preferences = TripPreferences()
    var stops: [TripStop] = []
    var reviewedIDs: [String] = []
    var canPlan: Bool { origin != nil && destination != nil && origin?.id != destination?.id }
    var visitSeconds: Double { Double(stops.reduce(0) { $0 + $1.visitMinutes } * 60) }
    var routeRequest: RouteRequest? {
        guard let origin, let destination else { return nil }
        return RouteRequest(origin: origin.point, destination: destination.point,
                            stops: stops.map { RouteStop(place: $0.place.point, visitMinutes: $0.visitMinutes) },
                            departure: ISO8601DateFormatter().string(from: departure))
    }
}
struct RoutePoint: Codable, Sendable { var id: String; var coordinate: Coordinate? }
struct RouteStop: Codable, Sendable { var place: RoutePoint; var visitMinutes: Int }
struct RouteRequest: Codable, Sendable {
    var origin: RoutePoint
    var destination: RoutePoint
    var stops: [RouteStop]
    var departure: String
}
struct DiscoveryRequest: Encodable, Sendable {
    var origin: RoutePoint
    var destination: RoutePoint
    var stops: [RouteStop]
    var departure: String
    var preferences: TripPreferences
    var reviewedIDs: [String]
    var coveredCategories: [StopCategory]
    init(trip: TripDraft) {
        let route = trip.routeRequest!
        origin = route.origin; destination = route.destination; stops = route.stops; departure = route.departure
        preferences = trip.preferences; reviewedIDs = Array(trip.reviewedIDs.suffix(300))
        coveredCategories = Array(Set(trip.stops.map(\.place.category)))
    }
}
struct RouteLeg: Codable, Hashable, Sendable { var durationSeconds: Double; var distanceMeters: Double }
struct RoutePlan: Codable, Hashable, Sendable {
    var encodedPolyline: String
    var durationSeconds: Double
    var distanceMeters: Double
    var legs: [RouteLeg]
    var calculatedAt: String

    func arrivals(for trip: TripDraft) -> [Date] {
        var cursor = trip.departure
        return legs.enumerated().map { index, leg in
            cursor = cursor.addingTimeInterval(leg.durationSeconds)
            let arrival = cursor
            if index < trip.stops.count { cursor = cursor.addingTimeInterval(Double(trip.stops[index].visitMinutes * 60)) }
            return arrival
        }
    }
}
struct StopSuggestion: Codable, Identifiable, Sendable {
    var place: PlaceReference
    var detourSeconds: Double
    var arrivalOffsetSeconds: Double
    var visitMinutes: Int
    var reason: String
    var insertionIndex: Int
    var unverifiedRequirements: [String] = []
    var id: String { place.id }
}
struct DiscoveryEvent: Decodable, Sendable {
    var type: String
    var message: String?
    var count: Int?
    var suggestion: StopSuggestion?
    var suggestions: [StopSuggestion]?
    var code: String?
}
struct APIProblem: Decodable, Error, LocalizedError, Sendable {
    var code: String
    var message: String
    var errorDescription: String? { message }
}

enum TripFormat {
    static func duration(_ seconds: Double) -> String {
        let minutes = max(0, Int(seconds / 60.0))
        return minutes >= 60 ? "\(minutes / 60) h\(minutes % 60 > 0 ? " \(minutes % 60) min" : "")" : "\(minutes) min"
    }
    static func distance(_ metres: Double) -> String { "\(Int((metres / 1000).rounded())) km" }
    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_ZA")
        formatter.timeZone = TimeZone(identifier: "Africa/Johannesburg")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date).lowercased()
    }
}
