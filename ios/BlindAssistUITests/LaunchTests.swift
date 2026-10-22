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
    /// The main screen has no visible controls; a long press on the reply offers the other screens
    /// (VoiceOver users get the same items as actions on the reply).
    private func openFromMainScreen(_ item: String) {
        let reply = app.staticTexts["companion-reply"]
        XCTAssertTrue(reply.waitForExistence(timeout: 10))
        reply.press(forDuration: 1.2)
        let button = app.buttons[item]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
    }
    private func openSettingsPage(_ link: String) {
        openFromMainScreen("Settings")
        let page = app.buttons[link]
        reveal(page); page.tap()
    }
    func testMainScreenShowsOnlyTheReply() {
        let reply = app.staticTexts["companion-reply"]
        XCTAssertTrue(reply.waitForExistence(timeout: 10))
        XCTAssertFalse(reply.label.isEmpty)
        XCTAssertTrue(app.buttons.allElementsBoundByIndex.filter(\.isHittable).isEmpty, "No buttons on the main screen")
        XCTAssertEqual(app.staticTexts.allElementsBoundByIndex.filter(\.isHittable).count, 1, "Only the reply is readable")
        XCTAssertFalse(app.tabBars.firstMatch.exists && app.tabBars.firstMatch.isHittable)
        XCTAssertFalse(app.buttons["write-message"].exists)
    }
    func testSettingsAndWearableSetupAreReachable() {
        openFromMainScreen("Settings")
        let wearableSetup = app.buttons["wearable-setup"]
        reveal(wearableSetup); wearableSetup.tap()
        XCTAssertTrue(app.buttons["Connect belt & wristband"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Assistant"].tap()
        XCTAssertTrue(app.staticTexts["companion-reply"].waitForExistence(timeout: 5))
    }
    func testPracticeIsAnnouncedAndCanStop() {
        openFromMainScreen("Settings")
        let practice = app.buttons["home-practice"]
        reveal(practice); practice.tap()
        let reply = app.staticTexts["companion-reply"]
        XCTAssertTrue(reply.waitForExistence(timeout: 5))
        openSettingsPage("Camera and sensor details")
        XCTAssertTrue(app.staticTexts["SIMULATION · generated readings"].waitForExistence(timeout: 5))
        let toggle = app.buttons["monitor-toggle"]
        XCTAssertEqual(toggle.label, "Stop monitoring")
        toggle.tap()
        XCTAssertEqual(toggle.label, "Start monitoring")
    }
    func testAccessibleMainModesAndOfflineDefault() {
        openSettingsPage("Camera and sensor details")
        XCTAssertTrue(app.buttons["monitor-toggle"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let ask = app.buttons["Reading and questions"]
        reveal(ask); ask.tap()
        XCTAssertTrue(app.buttons["voice-question"].waitForExistence(timeout: 5))
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
    func testDescribeFocusAndStopControl() {
        openSettingsPage("Reading and questions")
        XCTAssertTrue(app.textFields["Question or target"].exists || app.textViews["Question or target"].exists)
        reveal(app.buttons["stop-descriptions"])
        app.buttons["stop-descriptions"].tap()
        // The production privacy build omits the cloud control entirely.
        let cloudAnswer = app.buttons["cloud-answer"]
        XCTAssertFalse(cloudAnswer.exists && cloudAnswer.isEnabled)
        XCTAssertTrue(app.buttons["stop-descriptions"].exists)
    }
    func testAccessibilityAuditOfMainScreen() throws {
        XCTAssertTrue(app.staticTexts["companion-reply"].waitForExistence(timeout: 10))
        try app.performAccessibilityAudit()
    }
    func testAccessibilityAuditOfGuideAndAsk() throws {
        openSettingsPage("Camera and sensor details")
        try app.performAccessibilityAudit { issue in
            // WCAG exempts inactive controls; retain every other audit finding.
            guard issue.auditType == .contrast, let element = issue.element else { return false }
            return element.identifier == "retrace-session" && !element.isEnabled
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let ask = app.buttons["Reading and questions"]
        reveal(ask); ask.tap()
        try app.performAccessibilityAudit { issue in
            // WCAG exempts inactive controls; retain every other audit finding.
            guard issue.auditType == .contrast, let element = issue.element else { return false }
            return element.identifier == "retrace-session" && !element.isEnabled
        }
    }
    func testOfflineCommunityLibraryKeepsLocalImportAvailable() {
        openFromMainScreen("Places")
        app.buttons["community-maps"].tap()
        let search = app.buttons["community-search"], localImport = app.buttons["community-import"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); XCTAssertFalse(search.isEnabled)
        reveal(localImport)
        let loaded = NSPredicate(format: "enabled == true")
        expectation(for: loaded, evaluatedWith: localImport)
        waitForExpectations(timeout: 5)
    }
    func testEmptyInterestDoesNotBecomeStoredPreference() {
        openSettingsPage("assistant-preferences")
        let save = app.buttons["interest-save"]
        reveal(save); save.tap()
        XCTAssertTrue(app.staticTexts["Use a unique, nonempty preference of at most 300 characters. Up to 16 can be saved."].exists)
    }
}
