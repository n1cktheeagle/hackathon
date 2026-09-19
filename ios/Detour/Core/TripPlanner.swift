import Foundation
import Observation

enum PlanningStage { case home, route, finding, suggestions, itinerary }
enum SearchPurpose: String, Identifiable { case origin, destination; var id: String { rawValue } }
enum AppSheet: Identifiable {
    case search(SearchPurpose), custom, preferences, details(PlaceReference), saved, interests
    var id: String {
        switch self {
        case .search(let purpose): "search-\(purpose.rawValue)"
        case .custom: "custom"
        case .preferences: "preferences"
        case .details(let place): "details-\(place.id)"
        case .saved: "saved"
        case .interests: "interests"
        }
    }
}
@MainActor @Observable final class TravelerProfile {
    private let defaults: UserDefaults?
    private static let key = "detour.travelInterests.v1"
    private(set) var interests: [TravelInterest]
    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
        interests = (defaults?.stringArray(forKey: Self.key) ?? []).compactMap(TravelInterest.init(rawValue:))
        if interests.count != 3 || Set(interests).count != 3 { interests = [] }
    }
    func update(_ selection: Set<TravelInterest>) {
        guard selection.count == 3 else { return }
        interests = TravelInterest.allCases.filter(selection.contains)
        defaults?.set(interests.map(\.rawValue), forKey: Self.key)
    }
}
@MainActor @Observable final class TripPlanner {
    let service: any DetourService
    let isDemo: Bool
    let profile: TravelerProfile
    var showingOnboarding = true
    var trip = TripDraft()
    var stage: PlanningStage = .home
    var sheet: AppSheet?
    var route: RoutePlan?
    var directRoute: RoutePlan?
    var detourBranches: [[Coordinate]] = []
    var nearby: [PlaceReference] = []
    var suggestions: [StopSuggestion] = []
    var found: [StopSuggestion] = []
    var batchCount = 0
    var progressMessage = "Looking along your route"
    var isBusy = false
    var loadingNearby = false
    var errorMessage: String?
    var warningMessage: String?
    var toast: String?
    private var work: Task<Void, Never>?
    private var revision = UUID()
    private var nearbyRevision = UUID()
    private var repository: TripRepository?

    var current: StopSuggestion? { suggestions.first }
    var suggestionNumber: Int { max(1, batchCount - suggestions.count + 1) }
    var canDiscover: Bool { isDemo || !trip.preferences.categories.isEmpty || !trip.preferences.customRequest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var nextPlace: PlaceReference? { trip.stops.first(where: { !$0.visited })?.place ?? trip.destination }
    var shareText: String {
        var lines = ["Detour · \(trip.title)", "\(trip.origin?.name ?? "") → \(trip.destination?.name ?? "")", "Leave \(TripFormat.time(trip.departure))"]
        let arrivals = route?.arrivals(for: trip) ?? []
        for (index, stop) in trip.stops.enumerated() {
            let time = arrivals.indices.contains(index) ? " · \(TripFormat.time(arrivals[index]))" : ""
            lines.append("\(index + 1). \(stop.place.name)\(time) · \(stop.visitMinutes) min")
        }
        lines.append("Plan made with Detour. Driving times are estimates.")
        return lines.joined(separator: "\n")
    }
    init(service: any DetourService, isDemo: Bool, profile: TravelerProfile = TravelerProfile()) {
        self.service = service; self.isDemo = isDemo
        self.profile = profile
        if isDemo { trip.origin = Fixtures.capeTown }
    }
    func attach(_ repository: TripRepository) { self.repository = repository }
    func save() {
        do { try repository?.save(trip, isDemo: isDemo) }
        catch { errorMessage = "Your changes could not be saved on this device. Please try again." }
    }
    func select(_ place: PlaceReference, for purpose: SearchPurpose) {
        cancelWork()
        if purpose == .origin { trip.origin = place } else { trip.destination = place }
        trip.stops = []; trip.reviewedIDs = []; route = nil; directRoute = nil; detourBranches = []; suggestions = []; stage = .home
        sheet = nil; save()
        if purpose == .origin { Task { await loadNearby() } }
    }
    func loadNearby() async {
        guard let coordinate = trip.origin?.coordinate else { return }
        let token = UUID(); nearbyRevision = token
        loadingNearby = true
        do {
            let places = try await service.nearby(coordinate)
            guard nearbyRevision == token else { return }
            nearby = places
        } catch { if nearbyRevision == token { errorMessage = "Nearby places are unavailable. You can still plan your trip." } }
        if nearbyRevision == token { loadingNearby = false }
    }
    private func cancelWork() {
        work?.cancel(); work = nil; revision = UUID(); isBusy = false
    }
    private func run(_ action: @escaping @MainActor (UUID) async throws -> Void) {
        cancelWork(); let token = revision
        isBusy = true; errorMessage = nil
        work = Task {
            do { try await action(token) }
            catch {
                guard revision == token, !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            if revision == token { isBusy = false }
        }
    }
    private func valid(_ token: UUID) -> Bool { token == revision && !Task.isCancelled }
    func plan() {
        guard trip.canPlan, let input = trip.routeRequest else { return }
        stage = .route
        run { token in
            let result = try await self.service.route(input)
            guard self.valid(token) else { return }
            self.route = result
            if self.trip.stops.isEmpty { self.directRoute = result; self.detourBranches = [] }
            self.save()
            try await self.discoverStops(token)
        }
    }
    func findStops() {
        if isDemo, trip.stops.count >= 12 { showItinerary(); return }
        guard trip.canPlan, canDiscover, trip.stops.count < 12 else {
            errorMessage = trip.stops.count >= 12 ? "This driving day already has twelve stops." : "Choose a category or describe the stop you want."
            return
        }
        run { token in
            try await self.discoverStops(token)
        }
    }
    private func discoverStops(_ token: UUID) async throws {
        guard valid(token) else { return }
        if trip.stops.count >= 12 { stage = .itinerary; return }
        stage = .finding; found = []; suggestions = []; warningMessage = nil
        progressMessage = "Looking along your route"
        let input = DiscoveryRequest(trip: trip, interests: profile.interests)
            for try await event in self.service.discover(input) {
                guard self.valid(token) else { return }
                switch event.type {
                case "progress": self.progressMessage = event.message ?? "Looking along your route"
                case "candidate": if let candidate = event.suggestion { self.found.append(candidate) }
                case "warning": self.warningMessage = event.message
                case "complete":
                    self.suggestions = event.suggestions ?? self.found
                    self.batchCount = self.suggestions.count
                    self.stage = .suggestions
                    self.save()
                default: break
                }
            }
    }
    func cancelDiscovery() { cancelWork(); stage = .route; found = [] }
    func showFoundStops() {
        cancelWork(); suggestions = found; batchCount = suggestions.count; stage = .suggestions; errorMessage = nil
    }
    func back() {
        cancelWork(); sheet = nil; errorMessage = nil
        switch stage {
        case .home: break
        case .route: stage = .home
        case .finding: stage = .route
        case .suggestions: stage = .route
        case .itinerary: stage = .route
        }
    }
    func skip() {
        guard !isBusy, let suggestion = current else { return }
        trip.reviewedIDs.append(suggestion.id); suggestions.removeFirst(); sheet = nil
        save()
        if suggestions.isEmpty { stage = .itinerary }
        else { run { token in try await self.refreshCurrent(token) } }
    }
    func retryCurrent() { run { token in try await self.refreshCurrent(token) } }
    func add() {
        guard !isBusy, let suggestion = current, !trip.stops.contains(where: { $0.id == suggestion.id }) else { return }
        guard trip.stops.count < 12 else { errorMessage = "This driving day already has twelve stops."; return }
        run { token in
            let index = self.insertionIndex(for: suggestion.place)
            var updated = self.trip
            updated.stops.insert(TripStop(place: suggestion.place, visitMinutes: suggestion.visitMinutes), at: index)
            guard let input = updated.routeRequest else { return }
            let result = try await self.service.route(input)
            guard self.valid(token) else { return }
            updated.reviewedIDs.append(suggestion.id)
            await self.updateDetourBranches(result, token: token)
            guard self.valid(token) else { return }
            self.trip = updated; self.route = result
            self.suggestions.removeAll { $0.id == suggestion.id }
            self.sheet = nil; self.toast = "\(suggestion.place.name) added"; self.save()
            if self.suggestions.isEmpty { self.stage = .itinerary }
            else { try await self.refreshCurrent(token) }
        }
    }
    private func insertionIndex(for place: PlaceReference) -> Int {
        let points = route.map { RouteGeometry.decode($0.encodedPolyline) } ?? []
        let candidate = RouteGeometry.progress(place.coordinate, along: points)
        return trip.stops.filter { RouteGeometry.progress($0.place.coordinate, along: points) <= candidate }.count
    }
    private func refreshCurrent(_ token: UUID) async throws {
        guard var suggestion = current, let baseline = route else { return }
        let index = insertionIndex(for: suggestion.place)
        var proposed = trip
        proposed.stops.insert(TripStop(place: suggestion.place, visitMinutes: suggestion.visitMinutes), at: index)
        guard let input = proposed.routeRequest else { return }
        let result = try await service.route(input)
        guard valid(token) else { return }
        let estimated = isDemo && (result.isIllustrative == true || baseline.isIllustrative == true)
        suggestion.detourSeconds = estimated ? Fixtures.estimatedDetour(suggestion.place, geometry: RouteGeometry.decode(baseline.encodedPolyline)) : max(0, result.durationSeconds - baseline.durationSeconds)
        suggestion.arrivalOffsetSeconds = result.legs.prefix(index + 1).reduce(0) { $0 + $1.durationSeconds } + Double(trip.stops.prefix(index).reduce(0) { $0 + $1.visitMinutes } * 60)
        suggestion.insertionIndex = index
        let proposedGeometry = RouteGeometry.decode(result.encodedPolyline), baselineGeometry = RouteGeometry.decode(baseline.encodedPolyline)
        suggestion.detourBranches = await Task.detached { RouteGeometry.detourSegments(proposedGeometry, baseline: baselineGeometry) }.value
        guard valid(token) else { return }
        if !isDemo {
            suggestion.reason = "A \(suggestion.place.category.rawValue) stop along your journey, adding \(Int(ceil(suggestion.detourSeconds / 60))) min of driving."
        } else if estimated && !suggestion.id.hasPrefix("demo-break|") {
            suggestion.reason = (RouteDiscoveries.recommendationReason(for: suggestion.place, interests: profile.interests) ?? "A smaller stop along your journey.") + " Estimated extra driving time: \(Int(ceil(suggestion.detourSeconds / 60))) minutes."
        }
        if !isDemo && suggestion.detourSeconds > Double(trip.preferences.maxDetourMinutes * 60) {
            suggestions.removeFirst()
            if suggestions.isEmpty { stage = .itinerary }
            else { try await refreshCurrent(token) }
        } else { suggestions[0] = suggestion }
    }
    func removeStop(_ id: String) {
        guard !isBusy else { return }
        run { token in
            var updated = self.trip; updated.stops.removeAll { $0.id == id }
            guard let input = updated.routeRequest else { return }
            let result = try await self.service.route(input)
            guard self.valid(token) else { return }
            await self.updateDetourBranches(result, token: token)
            guard self.valid(token) else { return }
            self.trip = updated; self.route = result
            self.save()
        }
    }
    func visited(_ id: String) {
        guard let index = trip.stops.firstIndex(where: { $0.id == id }) else { return }
        trip.stops[index].visited.toggle(); save()
    }
    func showItinerary() { guard !isBusy else { return }; cancelWork(); sheet = nil; stage = .itinerary; save() }
    func newTrip() {
        cancelWork(); trip = TripDraft(); if isDemo { trip.origin = Fixtures.capeTown }
        route = nil; directRoute = nil; detourBranches = []; suggestions = []; found = []; stage = .home; sheet = nil; errorMessage = nil; warningMessage = nil
        nearbyRevision = UUID(); nearby = []; loadingNearby = false
        if isDemo { Task { await loadNearby() } }
    }
    func restore(_ saved: SavedTrip) {
        let id = saved.id, title = saved.title, payload = saved.payload
        run { token in
            let stored = try JSONDecoder().decode(StoredTrip.self, from: payload)
            func place(_ point: RoutePoint) async throws -> PlaceReference {
                if point.id == "current-location", let coordinate = point.coordinate {
                    return PlaceReference(id: point.id, name: "Saved starting point", subtitle: "", coordinate: coordinate)
                }
                return try await self.service.details(point.id, sessionToken: nil)
            }
            let origin = try await place(stored.origin)
            let destination = try await place(stored.destination)
            var restored = TripDraft(id: id, title: title, origin: origin, destination: destination, departure: stored.departure, preferences: stored.preferences, reviewedIDs: stored.reviewedIDs)
            for stop in stored.stops {
                let details = try await self.service.details(stop.placeID, sessionToken: nil)
                restored.stops.append(TripStop(place: details, visitMinutes: stop.visitMinutes, visited: stop.visited))
            }
            guard let input = restored.routeRequest else { return }
            let route = try await self.service.route(input)
            var direct = input; direct.stops = []
            let directRoute = restored.stops.isEmpty ? route : try await self.service.route(direct)
            guard self.valid(token) else { return }
            self.trip = restored; self.route = route; self.directRoute = directRoute
            await self.updateDetourBranches(route, token: token)
            guard self.valid(token) else { return }
            self.stage = .itinerary; self.sheet = nil
            Task { await self.loadNearby() }
        }
    }
    func toggle(_ category: StopCategory) {
        if trip.preferences.categories.contains(category) { trip.preferences.categories.removeAll { $0 == category } }
        else { trip.preferences.categories.append(category) }
        save()
    }
    private func updateDetourBranches(_ route: RoutePlan, token: UUID) async {
        let proposed = RouteGeometry.decode(route.encodedPolyline)
        let baseline = RouteGeometry.decode((directRoute ?? route).encodedPolyline)
        let branches = await Task.detached { RouteGeometry.detourSegments(proposed, baseline: baseline) }.value
        if valid(token) { detourBranches = branches }
    }
}
