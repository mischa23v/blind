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
    private func openTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
    }
    private func openSettingsPage(_ identifier: String) {
        openTab("Settings")
        let page = app.buttons[identifier]
        reveal(page); page.tap()
    }
    func testMainScreenShowsOnlyTheReplyAndTabs() {
        let reply = app.staticTexts["companion-reply"]
        XCTAssertTrue(reply.waitForExistence(timeout: 10))
        XCTAssertFalse(reply.label.isEmpty)
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.exists, "Bottom tab buttons stay on the main screen")
        // Reply, then the five reading tools above the bottom tab buttons; nothing else.
        for id in ["tool-read-text", "tool-read-page", "tool-scan-code", "tool-light", "tool-explore"] {
            XCTAssertTrue(app.buttons[id].exists, id)
        }
        let hittable = app.buttons.allElementsBoundByIndex.filter(\.isHittable)
        XCTAssertEqual(hittable.count, tabs.buttons.count + 5, "Only the reading tools and the bottom tab buttons besides the reply")
        XCTAssertFalse(app.buttons["write-message"].exists)
    }
    func testSettingsAndWearableSetupAreReachable() {
        openSettingsPage("wearable-setup")
        XCTAssertTrue(app.buttons["Connect belt & wristband"].waitForExistence(timeout: 5))
        openTab("Assistant")
        XCTAssertTrue(app.staticTexts["companion-reply"].waitForExistence(timeout: 5))
    }
    func testPracticeIsAnnouncedAndCanStop() {
        openSettingsPage("home-practice")
        XCTAssertTrue(app.staticTexts["companion-reply"].waitForExistence(timeout: 5))
        openSettingsPage("camera-screen")
        XCTAssertTrue(app.staticTexts["SIMULATION · generated readings"].waitForExistence(timeout: 5))
        // There is no off switch; practice ends by itself or with "End practice" and returns to live sensing.
        XCTAssertFalse(app.buttons["Stop monitoring"].exists)
        let end = app.buttons["end-practice"]
        reveal(end); end.tap()
        XCTAssertFalse(app.staticTexts["SIMULATION · generated readings"].exists)
        XCTAssertTrue(app.buttons["monitor-toggle"].label.contains("camera and sensors"))
    }
    func testAccessibleMainModesAndOfflineDefault() {
        openSettingsPage("camera-screen")
        XCTAssertTrue(app.buttons["monitor-toggle"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let ask = app.buttons["ask-screen"]
        reveal(ask); ask.tap()
        XCTAssertTrue(app.buttons["voice-question"].waitForExistence(timeout: 5))
        reveal(app.buttons["local-answer"])
        // The production privacy build contains no photo-upload control. Developer builds
        // may expose it, but offline mode must still disable it.
        if app.buttons["cloud-answer"].exists {
            reveal(app.buttons["cloud-answer"])
            XCTAssertFalse(app.buttons["cloud-answer"].isEnabled)
        }
        openTab("Routes")
        let importMap = app.buttons["Import indoor route JSON"]
        reveal(importMap)
    }
    func testDescribeFocusAndStopControl() {
        openSettingsPage("ask-screen")
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
    func testAccessibilityAuditOfCameraAndAsk() throws {
        openSettingsPage("camera-screen")
        try app.performAccessibilityAudit { issue in
            // WCAG exempts inactive controls; retain every other audit finding.
            guard issue.auditType == .contrast, let element = issue.element else { return false }
            return element.identifier == "retrace-session" && !element.isEnabled
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let ask = app.buttons["ask-screen"]
        reveal(ask); ask.tap()
        try app.performAccessibilityAudit { issue in
            // WCAG exempts inactive controls; retain every other audit finding.
            guard issue.auditType == .contrast, let element = issue.element else { return false }
            return element.identifier == "retrace-session" && !element.isEnabled
        }
    }
    func testOfflineCommunityLibraryKeepsLocalImportAvailable() {
        openTab("Places")
        let community = app.buttons["community-maps"]
        reveal(community); community.tap()
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
