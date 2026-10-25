import XCTest
import UIKit

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
        openSettingsPage("camera-screen")
        XCTAssertEqual(app.buttons["monitor-toggle"].label, "Start monitoring", "The explicit camera-off launch preference is respected before practice")
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
    // Test-only layout evidence. The dedicated CI helper sets the simulator category
    // before a fresh runner/app launch; production has no content-size override.
    @MainActor func testPracticeLayoutAtDefaultSize() throws {
        try recordPracticeLayout(expectedCategory: .large)
    }
    @MainActor func testPracticeLayoutAtLargestAccessibilitySize() throws {
        try recordPracticeLayout(expectedCategory: .accessibilityExtraExtraExtraLarge)
    }
    @MainActor private func recordPracticeLayout(expectedCategory: UIContentSizeCategory) throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BLIND_LAYOUT_DIAGNOSTIC"] == "1",
            "Dedicated layout probe only; use practice-layout-diagnostic.sh to configure its isolated simulator")
        let category = UIApplication.shared.preferredContentSizeCategory
        print("PRACTICE_LAYOUT category=\(category.rawValue) expected=\(expectedCategory.rawValue) runnerBodyPoints=\(UIFont.preferredFont(forTextStyle: .body).pointSize)")
        XCTAssertEqual(category, expectedCategory, "The fresh test runner must observe the requested system category")
        openSettingsPage("camera-screen")
        let sizeName = expectedCategory == .large ? "large" : "accessibility-extra-extra-extra-large"
        defer { recordPracticeLayoutAttachment("final-" + sizeName) }
        let footer = "Practice pauses live sensors and ends by itself after two minutes. Live monitoring resumes only if the camera control is on, and requires calibration. Keep using your cane or guide dog."
        let footerMatches = app.staticTexts.matching(NSPredicate(format: "label == %@", footer))
        let footerElement = footerMatches.firstMatch
        let controls: [(String, XCUIElement)] = [
            ("button", app.buttons["start-simulation"]),
            ("header", app.staticTexts["Practice"]),
            ("footer", footerElement)
        ]
        for (role, element) in controls {
            let existedBeforeReveal = element.exists
            print("PRACTICE_LAYOUT beforeReveal category=\(expectedCategory.rawValue) role=\(role) exists=\(existedBeforeReveal)")
            if existedBeforeReveal {
                print("PRACTICE_LAYOUT materialized category=\(expectedCategory.rawValue) role=\(role) frame=\(element.frame) hittable=\(element.isHittable) label=\(element.label)")
            }
            revealPracticeDiagnosticElement(element)
            if role == "footer" {
                XCTAssertEqual(footerMatches.count, 1, "The exact practice safety footer must be unique")
                XCTAssertEqual(element.label, footer)
            } else {
                XCTAssertEqual(element.label, role == "button" ? "Try practice (2 minutes)" : "Practice")
            }
            let screen = app.windows.firstMatch.frame
            print("PRACTICE_LAYOUT afterReveal category=\(expectedCategory.rawValue) role=\(role) frame=\(element.frame) screen=\(screen) visibleIntersection=\(element.frame.intersection(screen)) hittable=\(element.isHittable) label=\(element.label)")
            recordPracticeLayoutAttachment(sizeName + "-" + role)
        }
        recordPracticeFooterEnd(footerElement, expectedLabel: footer, sizeName: sizeName)
    }
    @MainActor private func recordPracticeFooterEnd(_ footer: XCUIElement, expectedLabel: String, sizeName: String) {
        let navigation = app.navigationBars.firstMatch
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(navigation.exists)
        XCTAssertTrue(tabs.exists)
        // Only the bottom of the paragraph must enter the unobscured viewport;
        // a tall accessible paragraph need not fit on one screen.
        func endIsVisible() -> Bool {
            guard footer.exists else { return false }
            return footer.frame.maxY > navigation.frame.maxY && footer.frame.maxY <= tabs.frame.minY
        }
        for _ in 0..<8 {
            if endIsVisible() { break }
            app.swipeUp()
        }
        for _ in 0..<8 {
            if endIsVisible() { break }
            app.swipeDown()
        }
        // Preserve the endpoint image even when the bounded reachability check fails.
        recordPracticeLayoutAttachment(sizeName + "-footer-end")
        XCTAssertTrue(footer.exists)
        print("PRACTICE_LAYOUT footerEnd size=\(sizeName) frame=\(footer.frame) unobscuredTop=\(navigation.frame.maxY) unobscuredBottom=\(tabs.frame.minY) endVisible=\(endIsVisible())")
        XCTAssertTrue(endIsVisible(), "Final practice warning must scroll above the tab bar and below the navigation bar")
        XCTAssertTrue(footer.isHittable)
        XCTAssertEqual(footer.label, expectedLabel)
    }
    @MainActor private func revealPracticeDiagnosticElement(_ element: XCUIElement) {
        // Form may materialize a row only after scrolling. Do not request its
        // frame or label before it exists, and stop immediately when reachable.
        for _ in 0..<8 {
            if element.exists && element.isHittable { break }
            app.swipeUp()
        }
        for _ in 0..<8 {
            if element.exists && element.isHittable { break }
            app.swipeDown()
        }
        XCTAssertTrue(element.waitForExistence(timeout: 10))
        XCTAssertTrue(element.isHittable)
    }
    @MainActor private func recordPracticeLayoutAttachment(_ name: String) {
        // Only --ui-testing synthetic state, no user library or camera frames.
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "practice-layout-" + name
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let boundedHierarchy = String(app.debugDescription.prefix(16000))
        print("PRACTICE_LAYOUT hierarchy=\(name) \(boundedHierarchy.replacingOccurrences(of: "\n", with: " | "))")
        let hierarchy = XCTAttachment(string: boundedHierarchy)
        hierarchy.name = "practice-hierarchy-" + name
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }
    func testAccessibilityAuditOfMainScreen() throws {
        XCTAssertTrue(app.staticTexts["companion-reply"].waitForExistence(timeout: 10))
        try app.performAccessibilityAudit()
    }
    func testAccessibilityAuditOfCameraAndAsk() throws {
        openSettingsPage("camera-screen")
        try app.performAccessibilityAudit { issue in
            // Synthetic UI-test state only. Keep the failure and expose the affected control.
            print("ACCESSIBILITY_AUDIT=type:\(issue.auditType),element:\(String((issue.element?.debugDescription ?? "unidentified").prefix(1200)).replacingOccurrences(of: "\n", with: " | "))")
            // WCAG exempts inactive controls; retain every other audit finding.
            guard issue.auditType == .contrast, let element = issue.element else { return false }
            return element.identifier == "retrace-session" && !element.isEnabled
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let ask = app.buttons["ask-screen"]
        reveal(ask); ask.tap()
        try app.performAccessibilityAudit { issue in
            // Synthetic UI-test state only. Keep the failure and expose the affected control.
            print("ACCESSIBILITY_AUDIT=type:\(issue.auditType),element:\(String((issue.element?.debugDescription ?? "unidentified").prefix(1200)).replacingOccurrences(of: "\n", with: " | "))")
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
