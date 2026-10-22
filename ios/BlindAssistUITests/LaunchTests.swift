import XCTest

final class LaunchTests: XCTestCase {
    private var app: XCUIApplication!
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<8 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.exists)
    }
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(); app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }
    func testAccessibleMainModesAndOfflineDefault() {
        XCTAssertTrue(app.buttons["monitor-toggle"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Ask"].tap()
        XCTAssertTrue(app.buttons["voice-question"].exists)
        reveal(app.buttons["local-answer"])
        // The production privacy build contains no photo-upload control. Developer builds
        // may expose it, but offline mode must still disable it.
        if app.buttons["cloud-answer"].exists {
            reveal(app.buttons["cloud-answer"])
            XCTAssertFalse(app.buttons["cloud-answer"].isEnabled)
        }
        app.tabBars.buttons["Routes"].tap()
        XCTAssertTrue(app.buttons["Import indoor route JSON"].exists)
    }
    func testSimulationIsExplicitAndCanStop() {
        let simulation = app.buttons["start-simulation"]
        for _ in 0..<8 where !simulation.isHittable { app.swipeUp() }
        XCTAssertTrue(simulation.isHittable); simulation.tap()
        for _ in 0..<8 where !app.buttons["monitor-toggle"].isHittable { app.swipeDown() }
        XCTAssertTrue(app.staticTexts["SIMULATION · generated readings"].exists)
        XCTAssertEqual(app.buttons["monitor-toggle"].label, "Stop monitoring")
        app.buttons["monitor-toggle"].tap()
        XCTAssertEqual(app.buttons["monitor-toggle"].label, "Start monitoring")
    }
    func testDescribeFocusAndStopControl() {
        app.tabBars.buttons["Ask"].tap()
        XCTAssertTrue(app.textFields["Question or target"].exists || app.textViews["Question or target"].exists)
        reveal(app.buttons["stop-descriptions"])
        app.buttons["stop-descriptions"].tap()
        XCTAssertFalse(app.buttons["cloud-answer"].isEnabled)
    }
    func testAccessibilityAuditOfGuideAndAsk() throws {
        try app.performAccessibilityAudit()
        app.tabBars.buttons["Ask"].tap()
        try app.performAccessibilityAudit()
    }
    func testOfflineCommunityLibraryKeepsLocalImportAvailable() {
        app.tabBars.buttons["Places"].tap()
        app.buttons["community-maps"].tap()
        let search = app.buttons["community-search"], localImport = app.buttons["community-import"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); XCTAssertFalse(search.isEnabled)
        reveal(localImport)
        let loaded = NSPredicate(format: "enabled == true")
        expectation(for: loaded, evaluatedWith: localImport)
        waitForExpectations(timeout: 5)
    }
    func testEmptyInterestDoesNotBecomeStoredPreference() {
        app.tabBars.buttons["Settings"].tap()
        app.buttons["assistant-preferences"].tap()
        let save = app.buttons["interest-save"]
        reveal(save); save.tap()
        XCTAssertTrue(app.staticTexts["Use a unique, nonempty preference of at most 300 characters. Up to 16 can be saved."].exists)
    }
}
