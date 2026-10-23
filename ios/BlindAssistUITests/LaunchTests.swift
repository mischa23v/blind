import XCTest

final class LaunchTests: XCTestCase {
    private var app: XCUIApplication!
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<8 where !element.isHittable { app.swipeUp() }
        for _ in 0..<8 where !element.isHittable { app.swipeDown() }
        XCTAssertTrue(element.isHittable)
    }
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(); app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-background-conversation", "NO", "-camera-awareness", "NO"]
        app.launch()
    }
    private func openTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
    }
    private func openSettingsPage(_ identifier: String) {
        openTab("Settings")
        for _ in 0..<8 where !app.buttons["settings-details"].exists {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        let landing = ["conversation-controls", "settings-reading", "settings-details", "settings-map-tools"]
        if !landing.contains(identifier) { app.buttons["settings-details"].tap() }
        let page = app.buttons[identifier]
        reveal(page); page.tap()
    }
    func testMainScreenContainsOnlyReplyAndTabButtons() {
        let reply = app.staticTexts["companion-reply"]
        XCTAssertTrue(reply.waitForExistence(timeout: 10))
        XCTAssertFalse(reply.label.isEmpty)
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.exists)
        XCTAssertEqual(app.buttons.allElementsBoundByIndex.filter(\.isHittable).count, tabs.buttons.count)
        for id in ["write-message", "tool-read-text", "tool-read-page", "tool-scan-code", "tool-light", "tool-explore", "start-conversation", "mute-conversation", "end-conversation"] {
            XCTAssertFalse(app.buttons[id].exists, id)
        }
        XCTAssertFalse(app.switches["camera-awareness"].exists)
        XCTAssertFalse(app.staticTexts["home-status"].exists)
    }
    func testReadingAndConversationControlsAreReachableInSettings() {
        openSettingsPage("conversation-controls")
        reveal(app.buttons["write-message"])
        for id in ["tool-read-text", "tool-read-page", "tool-scan-code", "tool-light", "tool-explore"] {
            reveal(app.buttons[id])
        }
    }
    func testRoomsShowSavedRoomsAndExplicitStartScan() {
        openTab("Rooms")
        XCTAssertTrue(app.buttons["room-scan-start"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["room-scan-name"].exists)
        XCTAssertFalse(app.buttons["community-maps"].exists)
        XCTAssertFalse(app.buttons["room-scan-stop"].exists)
        XCTAssertFalse(app.buttons["room-scan-start"].isEnabled, "No scan starts with the camera preference off")
    }
    func testWritingIsAvailableWithoutMicrophoneCapture() {
        openSettingsPage("conversation-controls")
        let write = app.buttons["write-message"]
        reveal(write); write.tap()
        let send = app.buttons["send-companion-message"]
        XCTAssertTrue(send.waitForExistence(timeout: 5))
        XCTAssertFalse(send.isEnabled, "Empty input cannot be submitted")
        XCTAssertTrue(app.textFields["companion-message"].exists || app.textViews["companion-message"].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["write-message"].exists)
    }
    func testAssistantPreferencesAndConversationMemoryRemainReachable() {
        openSettingsPage("settings-details")
        reveal(app.switches["background-conversation"])
        XCTAssertEqual(app.switches["background-conversation"].value as? String, "0", "The explicit background-voice off preference is respected")
        reveal(app.descendants(matching: .any)["assistant-audience"])
        let memory = app.buttons["conversation-memory"]
        reveal(memory); memory.tap()
        XCTAssertTrue(app.buttons["forget-conversation"].waitForExistence(timeout: 5))
    }
    func testPhotoExplorerCanBeDismissedWithoutStartingCamera() {
        openSettingsPage("conversation-controls")
        let explore = app.buttons["tool-explore"]
        reveal(explore); explore.tap()
        XCTAssertTrue(app.buttons["explore-library"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["explore-capture"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["write-message"].exists)
        XCTAssertFalse(app.buttons["explore-library"].exists)
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
        // Ending practice respects the separate camera preference, rather than forcing sensors on.
        let end = app.buttons["end-practice"]
        reveal(end); end.tap()
        XCTAssertFalse(app.staticTexts["SIMULATION · generated readings"].exists)
        XCTAssertEqual(app.buttons["monitor-toggle"].label, "Start monitoring")
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
        app.buttons["route-tools"].tap()
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
        openSettingsPage("settings-map-tools")
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
