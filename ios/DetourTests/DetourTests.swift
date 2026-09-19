import XCTest
import SwiftData
import UIKit
@testable import Detour

@MainActor final class DetourTests: XCTestCase {
    func testApfelFontsAreRegisteredInTheAppBundle() {
        for name in ["ApfelGrotezk-Regular", "ApfelGrotezk-Mittel", "ApfelGrotezk-Fett"] {
            XCTAssertNotNil(UIFont(name: name, size: 17), name)
        }
    }
    func testInterestIconsUseFilledSystemSymbols() {
        for interest in TravelInterest.allCases {
            XCTAssertTrue(interest.symbol.hasSuffix(".fill"), interest.rawValue)
            XCTAssertNotNil(UIImage(systemName: interest.symbol), interest.symbol)
        }
    }
    func testInterestProfilePersistsExactlyThreeChoices() throws {
        let name = "DetourTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let profile = TravelerProfile(defaults: defaults)
        profile.update([.arts, .sports])
        XCTAssertTrue(profile.interests.isEmpty)
        profile.update([.arts, .sports, .culture])
        XCTAssertEqual(Set(TravelerProfile(defaults: defaults).interests), [.arts, .sports, .culture])
        profile.update([.wildlife, .nature, .food])
        XCTAssertEqual(Set(TravelerProfile(defaults: defaults).interests), [.wildlife, .nature, .food])
    }

    func testDestinationsMatchInterestsAndAllKeepsEditorialOrder() {
        let selected: [TravelInterest] = [.arts, .sports, .culture]
        let tailored = DestinationCatalog.browse(interests: selected, personalized: true)
        XCTAssertEqual(tailored.first?.id, "demo-destination-zeitz")
        XCTAssertEqual(Array(tailored.prefix(2)).map(\.id), ["demo-destination-zeitz", "demo-destination-stadium"])
        XCTAssertTrue(tailored.contains { $0.id == "demo-destination-stadium" })
        XCTAssertTrue(tailored.allSatisfy { !Set(selected).isDisjoint(with: $0.interests) })
        XCTAssertFalse(tailored.contains { $0.id == "demo-destination-boulders" })
        XCTAssertFalse(tailored.contains { $0.id == "demo-destination-table-mountain" })
        XCTAssertFalse(tailored.contains { $0.id == "demo-destination-lions-head" })
        let sports = DestinationCatalog.browse(interests: [.sports], personalized: true)
        XCTAssertEqual(sports.map(\.id), ["demo-destination-stadium"])
        let all = DestinationCatalog.browse(interests: selected, personalized: false)
        XCTAssertEqual(Array(all.prefix(2)).map(\.id), ["demo-destination-table-mountain", "demo-destination-lions-head"])
        XCTAssertTrue(all.contains { $0.id == "demo-destination-boulders" })
        XCTAssertEqual(DestinationCatalog.browse(interests: selected, personalized: false, query: "penguin").first?.id, "demo-destination-boulders")
        let wildlife = DestinationCatalog.browse(interests: [.wildlife, .nature, .food], personalized: true)
        XCTAssertNotEqual(tailored.map(\.id), wildlife.map(\.id))
    }

    func testCuratedDestinationCanPlanAndDiscoverWithCurrentLocation() async throws {
        let service = FixtureService(delay: .zero)
        let location = PlaceReference(id: "current-location", name: "Current location", subtitle: "", coordinate: Fixtures.capeTown.coordinate)
        for idea in DestinationCatalog.places {
            let details = try await service.details(idea.id)
            XCTAssertEqual(details, idea.place)
            let trip = TripDraft(origin: location, destination: idea.place)
            let route = try await service.route(XCTUnwrap(trip.routeRequest))
            var complete: [StopSuggestion] = []
            for try await event in service.discover(DiscoveryRequest(trip: trip)) {
                if event.type == "complete" { complete = event.suggestions ?? [] }
            }
            XCTAssertFalse(complete.isEmpty, idea.place.name)
            XCTAssertTrue(complete.allSatisfy { $0.place.photoName != nil && $0.id != idea.id }, idea.place.name)
            XCTAssertGreaterThan(route.durationSeconds, 0)
        }
    }

    func testDiscoveryFavoursRelevantDetoursWithoutOvershootingDestination() async throws {
        let service = FixtureService(delay: .zero)
        let garden = TripDraft(origin: Fixtures.capeTown, destination: Fixtures.knysna)
        let route = try await service.route(XCTUnwrap(garden.routeRequest))
        let suggestions = try service.recommendations(DiscoveryRequest(trip: garden, interests: [.nature, .wildlife, .history]), geometry: RouteGeometry.decode(route.encodedPolyline), duration: route.durationSeconds)
        let coastalDetour = try XCTUnwrap(suggestions.first { $0.id == "demo-goukamma" })
        XCTAssertEqual(suggestions.first?.id, "demo-goukamma")
        XCTAssertGreaterThan(coastalDetour.detourSeconds, 600)
        XCTAssertTrue(suggestions.contains { $0.id == "demo-drostdy" })
        XCTAssertFalse(suggestions.contains { $0.id == "demo-houw-hoek" })

        let gardens = try XCTUnwrap(DestinationCatalog.details("demo-destination-kirstenbosch"))
        let local = TripDraft(origin: Fixtures.capeTown, destination: gardens)
        let localRoute = try await service.route(XCTUnwrap(local.routeRequest))
        let localSuggestions = try service.recommendations(DiscoveryRequest(trip: local, interests: [.nature, .wildlife, .food]), geometry: RouteGeometry.decode(localRoute.encodedPolyline), duration: localRoute.durationSeconds)
        XCTAssertTrue(localSuggestions.contains { $0.id == "demo-gem-de-waal" })
        XCTAssertTrue(localSuggestions.allSatisfy { !RouteDiscoveries.isMajorAttraction($0.id) }, "The garden destination already supplies the main attraction")
        XCTAssertFalse(localSuggestions.contains { $0.id == "demo-destination-boulders" || $0.id == "demo-cape-point" })
        XCTAssertGreaterThan(localSuggestions.count, 3)
        XCTAssertFalse(localSuggestions.contains { $0.id == "demo-destination-aquarium" || $0.id == "demo-destination-waterfront" })
    }
    func testSmallDiscoveriesArePersonalizedAndDoNotStackMountainAttractions() async throws {
        let service = FixtureService(delay: .zero)
        let gardens = try XCTUnwrap(DestinationCatalog.details("demo-destination-kirstenbosch"))
        let trip = TripDraft(origin: Fixtures.capeTown, destination: gardens)
        let route = try await service.route(XCTUnwrap(trip.routeRequest))
        func discover(_ interests: [TravelInterest]) throws -> [StopSuggestion] {
            try service.recommendations(DiscoveryRequest(trip: trip, interests: interests), geometry: RouteGeometry.decode(route.encodedPolyline), duration: route.durationSeconds)
        }
        let cultural = try discover([.arts, .culture, .shopping])
        let outdoors = try discover([.nature, .wildlife, .sports])
        XCTAssertEqual(cultural.first?.id, "demo-gem-book-lounge")
        XCTAssertEqual(outdoors.first?.id, "demo-gem-de-waal")
        XCTAssertNotEqual(cultural.map(\.id), outdoors.map(\.id))
        XCTAssertTrue(cultural.first?.reason.contains("arts interest") == true)
        XCTAssertGreaterThan(outdoors.count, 3)
        for gem in RouteDiscoveries.places {
            XCTAssertNotNil(UIImage(named: String(try XCTUnwrap(gem.place.photoName).dropFirst(6))), gem.place.name)
            XCTAssertNotNil(Fixtures.mockRatings[gem.id])
            let details = try await service.details(gem.id)
            XCTAssertEqual(details, gem.place)
        }
        var shortJourney = TripDraft(origin: Fixtures.capeTown, destination: try await service.details("demo-gem-green-point"))
        let shortRoute = try await service.route(XCTUnwrap(shortJourney.routeRequest))
        let withLandmark = try service.recommendations(DiscoveryRequest(trip: shortJourney, interests: [.nature, .culture, .history]), geometry: RouteGeometry.decode(shortRoute.encodedPolyline), duration: shortRoute.durationSeconds)
        XCTAssertEqual(withLandmark.filter { RouteDiscoveries.isMajorAttraction($0.id) }.count, 1)
        XCTAssertFalse(RouteDiscoveries.isMajorAttraction(try XCTUnwrap(withLandmark.first).id))
        shortJourney.destination = try XCTUnwrap(DestinationCatalog.details("demo-destination-lions-head"))
        let mountainRoute = try await service.route(XCTUnwrap(shortJourney.routeRequest))
        let mountains = try service.recommendations(DiscoveryRequest(trip: shortJourney, interests: [.nature, .wildlife, .sports]), geometry: RouteGeometry.decode(mountainRoute.encodedPolyline), duration: mountainRoute.durationSeconds)
        XCTAssertFalse(mountains.contains { $0.id == "demo-destination-table-mountain" })
        let timed = StopSuggestion(place: Fixtures.stops[0], detourSeconds: 301, arrivalOffsetSeconds: 0, visitMinutes: 25, reason: "", insertionIndex: 0)
        XCTAssertEqual(timed.addedJourneyMinutes, 31, "The added journey includes the rounded detour and the whole stay")
    }
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
        let uneven = [Coordinate(latitude: 0, longitude: 0), Coordinate(latitude: 0, longitude: 1), Coordinate(latitude: 0, longitude: 4)]
        XCTAssertEqual(RouteGeometry.prefix(uneven, fraction: 0.5).last, Coordinate(latitude: 0, longitude: 2))
        XCTAssertEqual(RouteGeometry.prefix(uneven, fraction: 1), uneven)
        XCTAssertEqual(RouteGeometry.prefix([], fraction: 0.5), [])
        let live = NavigationLinkBuilder.directions(to: Fixtures.stops[0], isDemo: false)!
        let items = URLComponents(url: live, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertEqual(items.first(where: { $0.name == "destination_place_id" })?.value, Fixtures.stops[0].id)
        XCTAssertNil(items.first { $0.name == "travelmode" })
        XCTAssertNil(URLComponents(url: NavigationLinkBuilder.directions(to: Fixtures.stops[0], isDemo: true)!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "destination_place_id" })
    }

    func testDetourGeometryMarksOnlyTheRoadsBetweenDepartureAndRejoin() {
        let start = Coordinate(latitude: 0, longitude: 0)
        let leave = Coordinate(latitude: 0, longitude: 0.01)
        let stop = Coordinate(latitude: 0.005, longitude: 0.015)
        let rejoin = Coordinate(latitude: 0, longitude: 0.02)
        let end = Coordinate(latitude: 0, longitude: 0.03)
        let baseline = [start, leave, rejoin, end]
        XCTAssertEqual(RouteGeometry.detourSegments([start, leave, stop, rejoin, end], baseline: baseline), [[leave, stop, rejoin]])
        XCTAssertTrue(RouteGeometry.detourSegments(baseline, baseline: baseline).isEmpty)
        let laneOffset = Coordinate(latitude: 0.0001, longitude: 0.015)
        XCTAssertTrue(RouteGeometry.detourSegments([start, leave, laneOffset, rejoin, end], baseline: baseline).isEmpty)
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
        XCTAssertEqual(planner.stage, .suggestions)
        XCTAssertEqual(planner.suggestions.count, 6)
        let firstID = try XCTUnwrap(planner.current?.id)
        planner.add(); planner.add() // Repeated taps while recalculating are ignored.
        try await settle(planner)
        XCTAssertEqual(planner.trip.stops.count, 1)
        XCTAssertEqual(planner.trip.stops[0].id, firstID)
        planner.skip(); try await settle(planner)
        planner.add(); try await settle(planner)
        XCTAssertEqual(planner.stage, .suggestions)
        planner.showItinerary()
        XCTAssertEqual(planner.stage, .itinerary)
        XCTAssertEqual(planner.trip.stops.count, 2)
        XCTAssertEqual(planner.route?.legs.count, 3)
        let saved = try XCTUnwrap(repository.all(isDemo: true).first)
        planner.newTrip()
        planner.restore(saved); try await settle(planner)
        XCTAssertEqual(planner.trip.stops.count, 2)
        planner.removeStop(firstID); try await settle(planner)
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
    func testSecondDemoRouteOffersAddableRestorableSampleStops() async throws {
        let planner = TripPlanner(service: FixtureService(delay: .zero), isDemo: true)
        planner.select(Fixtures.johannesburg, for: .origin)
        planner.select(Fixtures.durban, for: .destination)
        planner.plan(); try await settle(planner)
        XCTAssertNotNil(planner.route)
        planner.findStops(); try await settle(planner)
        XCTAssertEqual(planner.suggestions.count, 6)
        XCTAssertNil(planner.warningMessage)
        let sample = try XCTUnwrap(planner.current?.place)
        XCTAssertTrue(sample.subtitle.contains("Suggested break"))
        let restored = try await planner.service.details(sample.id, sessionToken: nil)
        XCTAssertEqual(restored, sample)
        planner.add(); try await settle(planner)
        XCTAssertEqual(planner.trip.stops.first?.place, sample)
        XCTAssertEqual(planner.route?.legs.count, 2)
    }

    func testCurrentLocationGetsGardenRouteRecommendations() async throws {
        let planner = TripPlanner(service: FixtureService(delay: .zero), isDemo: true)
        let location = PlaceReference(id: "current-location", name: "Current location", subtitle: "", coordinate: .init(latitude: -33.93, longitude: 18.43))
        planner.select(location, for: .origin)
        planner.select(Fixtures.knysna, for: .destination)
        planner.plan(); try await settle(planner)
        XCTAssertNil(planner.errorMessage)
        planner.findStops(); try await settle(planner)
        XCTAssertEqual(planner.suggestions.count, 6)
        let firstID = try XCTUnwrap(planner.current?.id)
        XCTAssertFalse(firstID.hasPrefix("demo-break|"))
        XCTAssertNil(planner.warningMessage)
        planner.add(); try await settle(planner)
        XCTAssertEqual(planner.trip.stops.first?.id, firstID)
        XCTAssertNil(planner.errorMessage)
    }

    func testDemoRecommendsAfterSkippingEverythingOrClearingCategories() async throws {
        let service = FixtureService(delay: .zero)
        var trip = TripDraft(origin: Fixtures.capeTown, destination: Fixtures.knysna)
        trip.reviewedIDs = Fixtures.stops.map(\.id)
        let baseline = try await service.route(XCTUnwrap(trip.routeRequest))
        var candidates = try service.recommendations(DiscoveryRequest(trip: trip), geometry: RouteGeometry.decode(baseline.encodedPolyline), duration: baseline.durationSeconds)
        XCTAssertFalse(candidates.isEmpty)
        trip.preferences.categories = []
        trip.stops = Fixtures.stops.map { TripStop(place: $0) }
        candidates = try service.recommendations(DiscoveryRequest(trip: trip), geometry: RouteGeometry.decode(baseline.encodedPolyline), duration: baseline.durationSeconds)
        XCTAssertFalse(candidates.isEmpty)
        XCTAssertTrue(Set(candidates.map(\.id)).isDisjoint(with: Set(trip.stops.map(\.id))))
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
        XCTAssertEqual(found.count, 6)
        XCTAssertTrue(found.allSatisfy { $0.detourSeconds == 600 })
        XCTAssertTrue(found.allSatisfy { $0.arrivalOffsetSeconds == 800 })
        trip.preferences.maxDetourMinutes = 5
        found = []
        for try await event in service.discover(DiscoveryRequest(trip: trip)) {
            if let candidate = event.suggestion { found.append(candidate) }
            if event.type == "complete" { XCTAssertEqual(event.suggestions?.count, 6) }
        }
        XCTAssertTrue(found.allSatisfy { $0.detourSeconds == 600 && $0.reason.contains("beyond your selected detour limit") })
    }

    func testDemoOfflineRoutingAndDiscoveryUseLabelledEstimates() async throws {
        struct Unavailable: RouteProviding {
            func route(_ input: RouteRequest) async throws -> RoutePlan { throw APIProblem(code: "unavailable", message: "Offline") }
        }
        let service = AppleMapDemoService(routes: Unavailable())
        let trip = TripDraft(origin: Fixtures.capeTown, destination: Fixtures.knysna)
        let route = try await service.route(XCTUnwrap(trip.routeRequest))
        XCTAssertEqual(route.isIllustrative, true)
        XCTAssertFalse(RouteGeometry.decode(route.encodedPolyline).isEmpty)
        var found: [StopSuggestion] = []
        for try await event in service.discover(DiscoveryRequest(trip: trip)) {
            if let candidate = event.suggestion { found.append(candidate) }
        }
        XCTAssertEqual(found.count, 6)
        XCTAssertTrue(found.allSatisfy { $0.reason.contains("Estimated extra driving time") })
    }

    func testDemoCandidateRoutingFailureKeepsRecommendations() async throws {
        struct Partial: RouteProviding {
            func route(_ input: RouteRequest) async throws -> RoutePlan {
                if !input.stops.isEmpty { throw APIProblem(code: "unavailable", message: "Offline") }
                return RoutePlan(encodedPolyline: RouteGeometry.encode(Fixtures.spine), durationSeconds: 19200, distanceMeters: 400000,
                                 legs: [.init(durationSeconds: 19200, distanceMeters: 400000)], calculatedAt: "")
            }
        }
        let service = AppleMapDemoService(routes: Partial())
        let trip = TripDraft(origin: Fixtures.capeTown, destination: Fixtures.knysna)
        var found: [StopSuggestion] = []
        for try await event in service.discover(DiscoveryRequest(trip: trip)) {
            if let candidate = event.suggestion { found.append(candidate) }
        }
        XCTAssertEqual(found.count, 6)
        XCTAssertTrue(found.allSatisfy { $0.reason.contains("Estimated extra driving time") })
    }

    func testDetoursReplaceTheVisibleJourneyIncludingNestedPreviews() throws {
        func point(_ x: Double, _ y: Double = 0) -> Coordinate { .init(latitude: y, longitude: x) }
        let baseline = [point(0), point(1), point(2), point(3), point(4)]
        let accepted = [point(1), point(2, 1), point(3)]
        let route = RouteGeometry.replacingDetours(baseline, accepted: [accepted], preview: [])
        XCTAssertEqual(route.count, 3)
        XCTAssertFalse(route[0].detour)
        XCTAssertEqual(route[0].coordinates.last, point(1))
        XCTAssertTrue(route[1].detour)
        XCTAssertFalse(route[1].preview)
        XCTAssertEqual(route[1].coordinates, accepted)
        XCTAssertEqual(route[2].coordinates.first, point(3))
        XCTAssertFalse(route.flatMap(\.coordinates).contains(point(2)), "The replaced main-road section must disappear")

        let preview = [point(1.5, 0.5), point(2, 2), point(2.5, 0.5)]
        let updated = RouteGeometry.replacingDetours(baseline, accepted: [accepted], preview: [preview])
        XCTAssertEqual(updated.filter(\.preview).count, 1)
        XCTAssertFalse(updated.flatMap(\.coordinates).contains(point(2, 1)), "A nested preview must replace the accepted section")
        XCTAssertFalse(updated.flatMap(\.coordinates).contains(point(2)))
        for index in 1..<updated.count {
            XCTAssertEqual(updated[index - 1].coordinates.last, updated[index].coordinates.first, "Every coloured section must connect")
        }
        XCTAssertEqual(updated.first?.coordinates.first, baseline.first)
        XCTAssertEqual(updated.last?.coordinates.last, baseline.last)

        let returnTrip = [point(1), point(1, 1), point(1)]
        let outAndBack = RouteGeometry.replacingDetours(baseline, accepted: [returnTrip], preview: [])
        XCTAssertEqual(outAndBack.count, 3)
        XCTAssertTrue(outAndBack[1].detour)
        XCTAssertTrue(outAndBack[2].coordinates.contains(point(2)), "A return detour keeps the onward road")
    }
}
