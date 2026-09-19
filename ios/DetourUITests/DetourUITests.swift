import XCTest

@MainActor final class DetourUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--uitesting"] + extra
        app.launch()
        return app
    }
    private func waitEnabled(_ element: XCUIElement, seconds: TimeInterval = 10) {
        let exists = element.waitForExistence(timeout: seconds)
        if !exists {
            let app = XCUIApplication()
            let screen = XCTAttachment(screenshot: app.screenshot()); screen.name = "Missing control"; screen.lifetime = .keepAlways; add(screen)
            let tree = XCTAttachment(string: app.debugDescription); tree.name = "Missing control hierarchy"; tree.lifetime = .keepAlways; add(tree)
        }
        XCTAssertTrue(exists)
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: seconds), .completed)
    }
    private func startDiscovery(_ app: XCUIApplication) {
        chooseKnysna(app)
        waitEnabled(app.buttons["plan-trip"]); app.buttons["plan-trip"].tap()
        waitEnabled(app.buttons["add-stop"])
    }
    private func chooseKnysna(_ app: XCUIApplication) {
        app.buttons["destination-field"].tap()
        let search = app.textFields["place-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 10)); search.tap(); search.typeText("Knysna")
        let destination = app.buttons["search-result-demo-knysna"]
        XCTAssertTrue(destination.waitForExistence(timeout: 10)); destination.tap()
    }
    func testCompleteTripAndSavedResume() {
        let app = launch()
        XCTAssertTrue(app.buttons["choose-destination"].isEnabled)
        XCTAssertFalse(app.buttons["plan-trip"].exists)
        startDiscovery(app)
        app.buttons["add-stop"].tap()
        waitEnabled(app.buttons["skip-stop"]); app.buttons["skip-stop"].tap()
        waitEnabled(app.buttons["add-stop"]); app.buttons["add-stop"].tap()
        waitEnabled(app.buttons["review-itinerary"])
        app.buttons["review-itinerary"].tap()
        XCTAssertTrue(app.buttons["start-driving"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["start-driving"].label, "Start")
        XCTAssertTrue(app.buttons["itinerary-stop-0"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Itinerary"; attachment.lifetime = .keepAlways; add(attachment)
        app.buttons["planner-back"].tap(); app.buttons["planner-back"].tap()
        app.buttons["saved-trips"].tap()
        let saved = app.buttons.matching(NSPredicate(format: "label CONTAINS 'My mission'")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5)); saved.tap()
        XCTAssertTrue(app.buttons["start-driving"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["itinerary-stop-1"].exists)
    }
    func testHomeDiscoveryBecomesARoute() {
        let app = launch()
        XCTAssertTrue(app.maps.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["origin-field"].exists)
        XCTAssertTrue(app.buttons["destination-field"].exists)
        let market = app.buttons["nearby-demo-market"]
        XCTAssertTrue(market.waitForExistence(timeout: 5)); market.tap()
        let choose = app.buttons["Make this the destination"]
        XCTAssertTrue(choose.waitForExistence(timeout: 5)); choose.tap()
        waitEnabled(app.buttons["plan-trip"]); app.buttons["plan-trip"].tap()
        waitEnabled(app.buttons["add-stop"])
        XCTAssertTrue(app.maps.firstMatch.exists)
        XCTAssertTrue(app.staticTexts["recommendation-count"].label.contains("of 6"))
        XCTAssertFalse(app.staticTexts["Sample rating"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["recommendation-rating"].exists)
        XCTAssertFalse(app.buttons["find-stops"].exists)
        XCTAssertTrue(app.staticTexts["recommendation-time-breakdown"].label.contains("Adds about"))
        XCTAssertTrue(app.staticTexts["recommendation-kind"].exists)
        XCTAssertTrue(app.staticTexts["recommendation-reason"].exists)
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Continuous map recommendations"; capture.lifetime = .keepAlways; add(capture)
        let review = app.buttons["review-itinerary"]
        XCTAssertTrue(review.isHittable, "Itinerary is available in the header even before adding a stop")
        XCTAssertLessThan(review.frame.maxY, app.maps.firstMatch.frame.midY)
        review.tap()
        XCTAssertTrue(app.staticTexts["itinerary-title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["start-driving"].isHittable)
        app.buttons["close-itinerary"].tap()
        waitEnabled(app.buttons["add-stop"])
        let handle = app.buttons["trip-drawer-handle"]
        handle.tap()
        XCTAssertEqual(handle.value as? String, "Expanded")
        XCTAssertTrue(app.buttons["add-stop"].isHittable)
        let expanded = XCTAttachment(screenshot: app.screenshot()); expanded.name = "Expanded recommendation drawer"; expanded.lifetime = .keepAlways; add(expanded)
        let grip = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        grip.press(forDuration: 0.1, thenDragTo: grip.withOffset(CGVector(dx: 0, dy: 110)))
        XCTAssertEqual(handle.value as? String, "Compact")
        XCTAssertTrue(app.buttons["add-stop"].isHittable)
    }
    func testCurrentLocationDiscoveryAlwaysOffersStops() {
        let app = launch()
        app.buttons["origin-field"].tap()
        let location = app.buttons["search-current-location"]
        XCTAssertTrue(location.waitForExistence(timeout: 10)); location.tap()
        startDiscovery(app)
        XCTAssertTrue(app.staticTexts["recommendation-title"].exists)
        XCTAssertFalse(app.staticTexts["A little further off the beaten track?"].exists)
        app.buttons["add-stop"].tap()
        waitEnabled(app.buttons["skip-stop"])
        app.buttons["review-itinerary"].tap()
        XCTAssertTrue(app.buttons["itinerary-stop-0"].waitForExistence(timeout: 5))
    }
    func testOnboardingPersonalizesDestinationsAndCanChangeInterests() {
        let app = launch(extra: ["--onboarding-test"])
        let continueButton = app.buttons["interests-continue"]
        let ready = continueButton.waitForExistence(timeout: 10)
        if !ready {
            let screen = XCTAttachment(screenshot: app.screenshot()); screen.name = "Onboarding failure"; screen.lifetime = .keepAlways; add(screen)
            let hierarchy = XCTAttachment(string: app.debugDescription); hierarchy.name = "Onboarding hierarchy"; hierarchy.lifetime = .keepAlways; add(hierarchy)
        }
        XCTAssertTrue(ready)
        XCTAssertFalse(continueButton.isEnabled)
        app.buttons["interest-arts"].tap()
        app.buttons["interest-culture"].tap()
        XCTAssertFalse(continueButton.isEnabled)
        app.buttons["interest-sports"].tap()
        XCTAssertTrue(continueButton.isEnabled)
        let onboarding = XCTAttachment(screenshot: app.screenshot()); onboarding.name = "Three interests"; onboarding.lifetime = .keepAlways; add(onboarding)
        continueButton.tap()
        XCTAssertTrue(app.buttons["edit-interests"].waitForExistence(timeout: 10))
        app.buttons["destination-field"].tap()
        let zeitz = app.buttons["destination-demo-destination-zeitz"]
        XCTAssertTrue(zeitz.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["destination-demo-destination-boulders"].exists)
        let tailored = XCTAttachment(screenshot: app.screenshot()); tailored.name = "For you destinations"; tailored.lifetime = .keepAlways; add(tailored)
        let scrollStart = zeitz.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        scrollStart.press(forDuration: 0.1, thenDragTo: scrollStart.withOffset(CGVector(dx: 0, dy: -120)))
        XCTAssertTrue(app.navigationBars["Where to?"].exists, "Scrolling a destination row must not select it")
        XCTAssertFalse(app.buttons["plan-trip"].exists)
        app.buttons["destinations-all"].tap()
        let mountain = app.buttons["destination-demo-destination-table-mountain"]
        XCTAssertTrue(mountain.waitForExistence(timeout: 5))
        let all = XCTAttachment(screenshot: app.screenshot()); all.name = "All destinations"; all.lifetime = .keepAlways; add(all)
        app.buttons["destination-interests"].tap()
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        app.buttons["interest-arts"].tap()
        app.buttons["interest-culture"].tap()
        app.buttons["interest-wildlife"].tap()
        app.swipeUp()
        app.buttons["interest-nature"].tap()
        continueButton.tap()
        XCTAssertTrue(app.buttons["destinations-for-you"].waitForExistence(timeout: 10))
        app.buttons["destinations-for-you"].tap()
        XCTAssertFalse(zeitz.exists)
        XCTAssertTrue(app.buttons["destination-demo-destination-table-mountain"].exists)
        app.buttons["destination-demo-destination-table-mountain"].tap()
        waitEnabled(app.buttons["plan-trip"]); app.buttons["plan-trip"].tap()
        waitEnabled(app.buttons["add-stop"])
    }
    func testSwipeAddsAndDetailsOpen() {
        let app = launch()
        startDiscovery(app)
        let card = app.staticTexts["recommendation-title"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let initialTitle = card.label
        card.tap()
        XCTAssertTrue(app.navigationBars["A closer look"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 140, dy: 0))
        start.press(forDuration: 0.1, thenDragTo: end)
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", initialTitle), object: card)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 8), .completed)
        XCTAssertTrue(app.buttons["review-itinerary"].exists)
        waitEnabled(app.buttons["review-itinerary"])
        app.buttons["review-itinerary"].tap()
        XCTAssertTrue(app.buttons["itinerary-stop-0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["itinerary-stop-0"].label.contains(initialTitle))
    }
    func testLargeTypeHomeAndSearch() {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.buttons["destination-field"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["nearby-demo-market"].waitForExistence(timeout: 5))
        let choose = app.buttons["choose-destination"]
        XCTAssertTrue(choose.exists)
        app.swipeUp()
        XCTAssertTrue(choose.isHittable)
        let home = XCTAttachment(screenshot: app.screenshot()); home.name = "Large type home"; home.lifetime = .keepAlways; add(home)
        choose.tap()
        XCTAssertTrue(app.textFields["place-search"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Large type search"; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testLiveAppleMapRoute() throws {
        guard ProcessInfo.processInfo.environment["DETOUR_LIVE_MAP_TEST"] == "1" else {
            throw XCTSkip("Opt-in network check for Apple Maps directions")
        }
        let app = launch(extra: ["--live-map-test"])
        chooseKnysna(app)
        app.buttons["plan-trip"].tap()
        waitEnabled(app.buttons["add-stop"], seconds: 90)
        XCTAssertTrue(app.maps.firstMatch.exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Live Apple Maps route"; attachment.lifetime = .keepAlways; add(attachment)
        waitEnabled(app.buttons["add-stop"], seconds: 90)
        app.buttons["add-stop"].tap()
        waitEnabled(app.buttons["review-itinerary"], seconds: 60)
        app.buttons["review-itinerary"].tap()
        XCTAssertTrue(app.buttons["itinerary-stop-0"].waitForExistence(timeout: 5))
        let itinerary = XCTAttachment(screenshot: app.screenshot())
        itinerary.name = "Live Apple Maps itinerary"; itinerary.lifetime = .keepAlways; add(itinerary)
    }
}
