import XCTest
import SwiftData
@testable import Detour

@MainActor final class DetourTests: XCTestCase {
    func testItineraryArithmeticIncludesEveryVisitAndFinalLeg() {
        let departure = Date(timeIntervalSince1970: 0)
        let stops = [TripStop(place: Fixtures.stops[0], visitMinutes: 20), TripStop(place: Fixtures.stops[1], visitMinutes: 40)]
        let trip = TripDraft(origin: Fixtures.capeTown, destination: Fixtures.knysna, departure: departure, stops: stops)
        let route = RoutePlan(encodedPolyline: "", durationSeconds: 600, distanceMeters: 10000, legs: [.init(durationSeconds: 100, distanceMeters: 1), .init(durationSeconds: 200, distanceMeters: 1), .init(durationSeconds: 300, distanceMeters: 1)], calculatedAt: "")
        XCTAssertEqual(route.arrivals(for: trip).map { $0.timeIntervalSince1970 }, [100, 1500, 4200])
        XCTAssertEqual(trip.visitSeconds, 3600)
    }
    func testPolylineAndNavigationLink() {
        XCTAssertEqual(RouteGeometry.decode(RouteGeometry.encode(Fixtures.spine)), Fixtures.spine)
        XCTAssertEqual(RouteGeometry.decode("_"), [])
        XCTAssertEqual(RouteGeometry.progress(Fixtures.capeTown.coordinate, along: Fixtures.spine), 0)
        XCTAssertEqual(RouteGeometry.progress(Fixtures.knysna.coordinate, along: Fixtures.spine), 1)
        let live = NavigationLinkBuilder.directions(to: Fixtures.stops[0], isDemo: false)!
        let items = URLComponents(url: live, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertEqual(items.first(where: { $0.name == "destination_place_id" })?.value, Fixtures.stops[0].id)
        XCTAssertNil(URLComponents(url: NavigationLinkBuilder.directions(to: Fixtures.stops[0], isDemo: true)!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "destination_place_id" })
    }
    func testSaveContainsIDsAndUserChoicesButNoProviderContent() throws {
        let container = try ModelContainer(for: SavedTrip.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let repository = TripRepository(context: container.mainContext)
        var trip = TripDraft(origin: Fixtures.capeTown, destination: Fixtures.knysna)
        trip.stops = [TripStop(place: Fixtures.stops[0], visitMinutes: 30, visited: true)]
        try repository.save(trip, isDemo: true)
        let record = try XCTUnwrap(repository.all(isDemo: true).first)
        let stored = try JSONDecoder().decode(StoredTrip.self, from: record.payload)
        XCTAssertEqual(stored.stops[0].placeID, Fixtures.stops[0].id)
        XCTAssertEqual(stored.stops[0].visitMinutes, 30)
        XCTAssertTrue(stored.stops[0].visited)
        let text = String(decoding: record.payload, as: UTF8.self)
        XCTAssertFalse(text.contains("Peregrine Farm Stall"))
        XCTAssertFalse(text.contains("rating"))
        XCTAssertFalse(text.contains("photoName"))
        XCTAssertNil(stored.origin.coordinate)
        XCTAssertEqual(try repository.all(isDemo: false).count, 0)
        trip.title = "Garden Route"
        try repository.save(trip, isDemo: true)
        XCTAssertEqual(try repository.all(isDemo: true).count, 1)
        XCTAssertEqual(record.title, "Garden Route")
    }
    func testSavedTripSurvivesReopeningTheDiskStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("trips.store")
        func write() throws {
            let container = try ModelContainer(for: SavedTrip.self, configurations: ModelConfiguration(url: url))
            let repository = TripRepository(context: container.mainContext)
            var trip = TripDraft(origin: Fixtures.capeTown, destination: Fixtures.knysna)
            trip.title = "Weekend escape"
            trip.stops = [TripStop(place: Fixtures.stops[0], visitMinutes: 25)]
            try repository.save(trip, isDemo: true)
        }
        try write()
        let reopened = try ModelContainer(for: SavedTrip.self, configurations: ModelConfiguration(url: url))
        let repository = TripRepository(context: reopened.mainContext)
        let record = try XCTUnwrap(repository.all(isDemo: true).first)
        XCTAssertEqual(record.title, "Weekend escape")
        XCTAssertEqual(try JSONDecoder().decode(StoredTrip.self, from: record.payload).stops.first?.visitMinutes, 25)
    }
    func testAddSkipRemoveAndRestoreFlow() async throws {
        let container = try ModelContainer(for: SavedTrip.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let repository = TripRepository(context: container.mainContext)
        let planner = TripPlanner(service: FixtureService(delay: .zero), isDemo: true)
        planner.attach(repository)
        planner.select(Fixtures.knysna, for: .destination)
        planner.plan(); try await settle(planner)
        XCTAssertEqual(planner.stage, .route)
        planner.findStops(); try await settle(planner)
        XCTAssertEqual(planner.suggestions.count, 3)
        planner.add(); planner.add() // Repeated taps while recalculating are ignored.
        try await settle(planner)
        XCTAssertEqual(planner.trip.stops.count, 1)
        XCTAssertEqual(planner.trip.stops[0].id, Fixtures.stops[0].id)
        planner.skip(); try await settle(planner)
        planner.add(); try await settle(planner)
        XCTAssertEqual(planner.stage, .itinerary)
        XCTAssertEqual(planner.trip.stops.count, 2)
        XCTAssertEqual(planner.route?.legs.count, 3)
        let saved = try XCTUnwrap(repository.all(isDemo: true).first)
        planner.newTrip()
        planner.restore(saved); try await settle(planner)
        XCTAssertEqual(planner.trip.stops.count, 2)
        planner.removeStop(Fixtures.stops[0].id); try await settle(planner)
        XCTAssertEqual(planner.trip.stops.count, 1)
        XCTAssertEqual(planner.route?.legs.count, 2)
    }
    func testChangingDestinationCancelsOldRoute() async throws {
        let planner = TripPlanner(service: FixtureService(delay: .milliseconds(50)), isDemo: true)
        planner.select(Fixtures.knysna, for: .destination)
        planner.plan()
        planner.select(Fixtures.durban, for: .destination)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(planner.stage, .home)
        XCTAssertNil(planner.route)
        XCTAssertEqual(planner.trip.destination?.id, Fixtures.durban.id)
    }
    func testCancelDiscoveryDoesNotShowLateResults() async throws {
        let planner = TripPlanner(service: FixtureService(delay: .milliseconds(30)), isDemo: true)
        planner.select(Fixtures.knysna, for: .destination)
        planner.findStops(); planner.cancelDiscovery()
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(planner.stage, .route)
        XCTAssertTrue(planner.found.isEmpty)
        XCTAssertTrue(planner.suggestions.isEmpty)
    }
    func testSecondRouteDemoIsExplicitlyLimited() async throws {
        let planner = TripPlanner(service: FixtureService(delay: .zero), isDemo: true)
        planner.select(Fixtures.johannesburg, for: .origin)
        planner.select(Fixtures.durban, for: .destination)
        planner.plan(); try await settle(planner)
        XCTAssertNotNil(planner.route)
        planner.findStops(); try await settle(planner)
        XCTAssertTrue(planner.suggestions.isEmpty)
        XCTAssertNotNil(planner.warningMessage)
    }
    private func settle(_ planner: TripPlanner) async throws {
        for _ in 0..<200 {
            if !planner.isBusy { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Planner did not settle")
    }

    func testAppleDemoResolvesPlaceIDsAndUsesVerifiedDetours() async throws {
        struct Routes: RouteProviding {
            func route(_ input: RouteRequest) async throws -> RoutePlan {
                XCTAssertNotNil(input.origin.coordinate)
                XCTAssertNotNil(input.destination.coordinate)
                XCTAssertTrue(input.stops.allSatisfy { $0.place.coordinate != nil })
                let total = 1000.0 + Double(input.stops.count) * 600
                return RoutePlan(encodedPolyline: RouteGeometry.encode(Fixtures.spine), durationSeconds: total, distanceMeters: 400000,
                                 legs: Array(repeating: RouteLeg(durationSeconds: total / Double(input.stops.count + 1), distanceMeters: 200000), count: input.stops.count + 1), calculatedAt: "")
            }
        }
        var trip = TripDraft(origin: Fixtures.capeTown, destination: Fixtures.knysna)
        let service = AppleMapDemoService(routes: Routes())
        var found: [StopSuggestion] = []
        for try await event in service.discover(DiscoveryRequest(trip: trip)) {
            if event.type == "candidate", let suggestion = event.suggestion { found.append(suggestion) }
        }
        XCTAssertEqual(found.count, 3)
        XCTAssertTrue(found.allSatisfy { $0.detourSeconds == 600 })
        XCTAssertTrue(found.allSatisfy { $0.arrivalOffsetSeconds == 800 })
        trip.preferences.maxDetourMinutes = 5
        for try await event in service.discover(DiscoveryRequest(trip: trip)) {
            XCTAssertNotEqual(event.type, "candidate")
            if event.type == "complete" { XCTAssertEqual(event.suggestions?.count, 0) }
        }
    }

    func testAppleRoutingFailureDoesNotSubstituteIllustrativeGeometry() async throws {
        struct Unavailable: RouteProviding {
            func route(_ input: RouteRequest) async throws -> RoutePlan { throw APIProblem(code: "unavailable", message: "Offline") }
        }
        let service = AppleMapDemoService(routes: Unavailable())
        let trip = TripDraft(origin: Fixtures.capeTown, destination: Fixtures.knysna)
        do {
            _ = try await service.route(XCTUnwrap(trip.routeRequest))
            XCTFail("Expected a routing error")
        } catch { XCTAssertEqual((error as? APIProblem)?.code, "unavailable") }
    }
}
