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
    private func openTools(_ tab: String) {
        app.buttons["home-more"].tap()
        app.buttons["open-settings"].tap()
        XCTAssertTrue(app.buttons["close-tools"].waitForExistence(timeout: 5))
        if tab != "Settings" { app.buttons[tab].tap() }
    }
    func testEverydayHomeKeepsSetupOutOfTheWay() {
        XCTAssertTrue(app.buttons["home-talk"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["home-repeat"].exists)
        XCTAssertTrue(app.buttons["home-start-stop"].exists)
        XCTAssertFalse(app.staticTexts["Wearables"].exists)
        XCTAssertFalse(app.buttons["Connect belt & wristband"].exists)
        XCTAssertFalse(app.buttons["Calibrate belt"].exists)
        XCTAssertFalse(app.textFields["Question or target"].exists)
        XCTAssertFalse(app.buttons["cloud-answer"].exists)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
    }
    func testMapsAndWearableSetupAreReachableFromMore() {
        app.buttons["home-more"].tap()
        app.buttons["open-maps"].tap()
        XCTAssertTrue(app.buttons["Import indoor route JSON"].waitForExistence(timeout: 5))
        app.buttons["Settings"].tap()
        let wearableSetup = app.buttons["wearable-setup"]
        reveal(wearableSetup); wearableSetup.tap()
        XCTAssertTrue(app.buttons["Connect belt & wristband"].waitForExistence(timeout: 5))
        app.buttons["close-tools"].tap()
        XCTAssertTrue(app.buttons["home-talk"].waitForExistence(timeout: 5))
    }
    func testPracticeStopsFromEverydayHome() {
        app.buttons["home-more"].tap()
        app.buttons["home-practice"].tap()
        XCTAssertTrue(app.staticTexts["practice-status"].waitForExistence(timeout: 5))
        let stop = app.buttons["home-start-stop"]
        reveal(stop)
        XCTAssertEqual(stop.label, "Stop")
        stop.tap()
        XCTAssertEqual(stop.label, "Start")
        XCTAssertFalse(app.staticTexts["practice-status"].exists)
    }
    func testAccessibleMainModesAndOfflineDefault() {
        openTools("Guide")
        XCTAssertTrue(app.buttons["monitor-toggle"].waitForExistence(timeout: 10))
        app.buttons["Ask"].tap()
        XCTAssertTrue(app.buttons["voice-question"].exists)
        reveal(app.buttons["local-answer"])
        // The production privacy build contains no photo-upload control. Developer builds
        // may expose it, but offline mode must still disable it.
        if app.buttons["cloud-answer"].exists {
            reveal(app.buttons["cloud-answer"])
            XCTAssertFalse(app.buttons["cloud-answer"].isEnabled)
        }
        app.buttons["Routes"].tap()
        XCTAssertTrue(app.buttons["Import indoor route JSON"].exists)
    }
    func testSimulationIsExplicitAndCanStop() {
        openTools("Guide")
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
        openTools("Ask")
        app.buttons["Ask"].tap()
        XCTAssertTrue(app.textFields["Question or target"].exists || app.textViews["Question or target"].exists)
        reveal(app.buttons["stop-descriptions"])
        app.buttons["stop-descriptions"].tap()
        // The production privacy build omits the cloud control entirely.
        let cloudAnswer = app.buttons["cloud-answer"]
        XCTAssertFalse(cloudAnswer.exists && cloudAnswer.isEnabled)
        XCTAssertTrue(app.buttons["stop-descriptions"].exists)
    }
    func testAccessibilityAuditOfEverydayHome() throws {
        try app.performAccessibilityAudit()
    }
    func testAccessibilityAuditOfGuideAndAsk() throws {
        openTools("Guide")
        try app.performAccessibilityAudit { issue in
            // WCAG exempts inactive controls; retain every other audit finding.
            guard issue.auditType == .contrast, let element = issue.element else { return false }
            return element.identifier == "retrace-session" && !element.isEnabled
        }
        app.buttons["Ask"].tap()
        try app.performAccessibilityAudit { issue in
            // WCAG exempts inactive controls; retain every other audit finding.
            guard issue.auditType == .contrast, let element = issue.element else { return false }
            return element.identifier == "retrace-session" && !element.isEnabled
        }
    }
    func testOfflineCommunityLibraryKeepsLocalImportAvailable() {
        openTools("Places")
        app.buttons["Places"].tap()
        app.buttons["community-maps"].tap()
        let search = app.buttons["community-search"], localImport = app.buttons["community-import"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); XCTAssertFalse(search.isEnabled)
        reveal(localImport)
        let loaded = NSPredicate(format: "enabled == true")
        expectation(for: loaded, evaluatedWith: localImport)
        waitForExpectations(timeout: 5)
    }
    func testEmptyInterestDoesNotBecomeStoredPreference() {
        openTools("Settings")
        app.buttons["Settings"].tap()
        app.buttons["assistant-preferences"].tap()
        let save = app.buttons["interest-save"]
        reveal(save); save.tap()
        XCTAssertTrue(app.staticTexts["Use a unique, nonempty preference of at most 300 characters. Up to 16 can be saved."].exists)
    }
}
