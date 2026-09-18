import Foundation
import SwiftData

// Persist user-authored choices and stable provider IDs, never place photos,
// reviews, ratings, opening hours, route geometry or copied place descriptions.
struct StoredStop: Codable {
    var placeID: String
    var visitMinutes: Int
    var visited: Bool
}
struct StoredTrip: Codable {
    var origin: RoutePoint
    var destination: RoutePoint
    var departure: Date
    var preferences: TripPreferences
    var stops: [StoredStop]
    var reviewedIDs: [String]
}
@Model final class SavedTrip {
    @Attribute(.unique) var id: UUID
    var title: String
    var updatedAt: Date
    var payload: Data
    var isDemo: Bool
    init(id: UUID, title: String, payload: Data, isDemo: Bool) {
        self.id = id; self.title = title; self.payload = payload; self.isDemo = isDemo; self.updatedAt = .now
    }
}
@MainActor final class TripRepository {
    let context: ModelContext
    init(context: ModelContext) { self.context = context }
    func save(_ trip: TripDraft, isDemo: Bool) throws {
        guard let origin = trip.origin, let destination = trip.destination else { return }
        let stored = StoredTrip(origin: origin.point, destination: destination.point, departure: trip.departure,
                                preferences: trip.preferences,
                                stops: trip.stops.map { StoredStop(placeID: $0.id, visitMinutes: $0.visitMinutes, visited: $0.visited) },
                                reviewedIDs: trip.reviewedIDs)
        let payload = try JSONEncoder().encode(stored)
        let id = trip.id
        let descriptor = FetchDescriptor<SavedTrip>(predicate: #Predicate { $0.id == id })
        if let saved = try context.fetch(descriptor).first {
            saved.title = trip.title; saved.payload = payload; saved.updatedAt = .now
        } else { context.insert(SavedTrip(id: id, title: trip.title, payload: payload, isDemo: isDemo)) }
        try context.save()
    }
    func all(isDemo: Bool) throws -> [SavedTrip] {
        let descriptor = FetchDescriptor<SavedTrip>(predicate: #Predicate { $0.isDemo == isDemo }, sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return try context.fetch(descriptor)
    }
    func delete(_ trip: SavedTrip) throws { context.delete(trip); try context.save() }
    func rename(_ trip: SavedTrip, to title: String) throws {
        trip.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "My mission" : title
        try context.save()
    }
}
