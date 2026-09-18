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
        XCTAssertTrue(element.waitForExistence(timeout: seconds))
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: seconds), .completed)
    }
    private func startDiscovery(_ app: XCUIApplication) {
        app.buttons["destination-field"].tap()
        let destination = app.buttons["Knysna, Western Cape"]
        XCTAssertTrue(destination.waitForExistence(timeout: 5)); destination.tap()
        waitEnabled(app.buttons["plan-trip"]); app.buttons["plan-trip"].tap()
        waitEnabled(app.buttons["find-stops"]); app.buttons["find-stops"].tap()
        waitEnabled(app.buttons["add-stop"])
    }
    func testCompleteTripAndSavedResume() {
        let app = launch()
        XCTAssertFalse(app.buttons["plan-trip"].isEnabled)
        startDiscovery(app)
        app.buttons["add-stop"].tap()
        waitEnabled(app.buttons["skip-stop"]); app.buttons["skip-stop"].tap()
        waitEnabled(app.buttons["add-stop"]); app.buttons["add-stop"].tap()
        XCTAssertTrue(app.buttons["start-driving"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["itinerary-stop-0"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Itinerary"; attachment.lifetime = .keepAlways; add(attachment)
        app.buttons["planner-back"].tap(); app.buttons["planner-back"].tap()
        app.buttons["saved-trips"].tap()
        let saved = app.buttons.matching(NSPredicate(format: "label CONTAINS 'My mission'")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5)); saved.tap()
        XCTAssertTrue(app.buttons["start-driving"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["itinerary-stop-1"].exists)
    }
    func testSwipeAddsAndDetailsOpen() {
        let app = launch()
        startDiscovery(app)
        let card = app.staticTexts["Peregrine Farm Stall"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.navigationBars["A closer look"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 140, dy: 0))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertTrue(app.staticTexts["Tredici"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["View itinerary"].exists)
    }
    func testLargeTypeHomeAndSearch() {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.buttons["destination-field"].waitForExistence(timeout: 5))
        app.buttons["destination-field"].tap()
        XCTAssertTrue(app.textFields["place-search"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Large type search"; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testLiveAppleMapRoute() throws {
        guard ProcessInfo.processInfo.environment["DETOUR_LIVE_MAP_TEST"] == "1" else {
            throw XCTSkip("Opt-in network check for Apple Maps directions")
        }
        let app = launch(extra: ["--live-map-test"])
        app.buttons["destination-field"].tap()
        let destination = app.buttons["Knysna, Western Cape"]
        XCTAssertTrue(destination.waitForExistence(timeout: 5)); destination.tap()
        app.buttons["plan-trip"].tap()
        waitEnabled(app.buttons["find-stops"], seconds: 60)
        XCTAssertEqual(app.buttons["find-stops"].label, "Find stops along the way")
        XCTAssertTrue(app.maps.firstMatch.exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Live Apple Maps route"; attachment.lifetime = .keepAlways; add(attachment)
        app.buttons["find-stops"].tap()
        waitEnabled(app.buttons["add-stop"], seconds: 90)
        app.buttons["add-stop"].tap()
        waitEnabled(app.buttons["View itinerary"], seconds: 60)
        app.buttons["View itinerary"].tap()
        XCTAssertTrue(app.buttons["itinerary-stop-0"].waitForExistence(timeout: 5))
        let itinerary = XCTAttachment(screenshot: app.screenshot())
        itinerary.name = "Live Apple Maps itinerary"; itinerary.lifetime = .keepAlways; add(itinerary)
    }
}
