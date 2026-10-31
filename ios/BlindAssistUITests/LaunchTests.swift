import XCTest
import UIKit

final class LaunchTests: XCTestCase {
    private var app: XCUIApplication!
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<8 {
            if element.isHittable { break }
            app.swipeUp()
        }
        for _ in 0..<8 {
            if element.isHittable { break }
            app.swipeDown()
        }
        XCTAssertTrue(element.isHittable)
    }
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(); app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-background-conversation", "NO", "-camera-awareness", "NO"]
        // Observe only the existing full audit and dedicated endpoint probes.
        // No category override, new launch, wait, or audit filtering.
        if ["testAccessibilityAuditOfCameraAndAsk", "testPracticeLayoutAtDefaultSize",
            "testPracticeLayoutAtLargestAccessibilitySize"].contains(where: { name.contains($0) }) {
            app.launchArguments.append("--ask-layout-trace")
        }
        app.launch()
    }
    private func openTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
    }
    private func openSettingsPage(_ identifier: String) {
        openTab("Settings")
        for _ in 0..<8 {
            if app.buttons["settings-details"].exists { break }
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

    func testQuietDescriptionsCanResumeWithoutStartingMicrophoneOrCamera() {
        openSettingsPage("conversation-controls")
        let descriptions = app.buttons["conversation-descriptions"]
        reveal(descriptions)
        XCTAssertEqual(descriptions.label, "Resume descriptions")
        XCTAssertEqual(descriptions.value as? String, "Descriptions quiet")
        descriptions.tap()
        XCTAssertEqual(descriptions.label, "Quiet descriptions, keep alerts")
        XCTAssertEqual(descriptions.value as? String, "Descriptions on")
        descriptions.tap()
        XCTAssertEqual(descriptions.label, "Resume descriptions")
        XCTAssertEqual(descriptions.value as? String, "Descriptions quiet")
        XCTAssertTrue(app.staticTexts["microphone-status"].exists)
        XCTAssertEqual(app.staticTexts["microphone-status"].label, "Microphone is not listening.")
        XCTAssertTrue(app.staticTexts["camera-status"].label.hasPrefix("Camera off."))
        XCTAssertTrue(app.buttons["write-message"].exists)
    }

    func testAskControlsAndUnavailableReasonRemainReachableWithoutCamera() {
        openSettingsPage("ask-screen")
        let answer = app.buttons["local-answer"]
        reveal(answer)
        XCTAssertFalse(answer.isEnabled)
        let reason = app.staticTexts["local-answer-unavailable-reason"]
        reveal(reason)
        XCTAssertEqual(reason.label, "Camera monitoring is not running. Open Camera and safety to start it.")
        let repeatAnswer = app.buttons["repeat-answer"]
        reveal(repeatAnswer)
        XCTAssertEqual(repeatAnswer.label, "Repeat answer")
        XCTAssertFalse(repeatAnswer.isEnabled, "Readable styling must not enable an empty answer")
        XCTAssertTrue(app.descendants(matching: .any)["ask-focus"].exists)
        let goal = app.descendants(matching: .any)["ask-goal"]
        reveal(goal)
        XCTAssertTrue(goal.exists)
        let question = app.descendants(matching: .any)["ask-question"]
        reveal(question)
        XCTAssertTrue(question.exists)
        XCTAssertFalse(answer.isEnabled, "Scrolling and selecting text must not start camera monitoring")
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
    func testPracticeNavigationRemainsReachable() {
        openSettingsPage("camera-screen")
        XCTAssertEqual(app.buttons["monitor-toggle"].label, "Start monitoring", "The explicit camera-off launch preference is respected before practice")
        openSettingsPage("home-practice")
        let reply = app.staticTexts["companion-reply"]
        XCTAssertTrue(reply.waitForExistence(timeout: 5))
        XCTAssertTrue(reply.isHittable, "Practice navigation must expose the companion reply")
        // Navigation reachability is separate from cancellation. This check does
        // not prove audible speech or active practice after the navigation delay.
    }
    func testPracticeIsAnnouncedAndCanStop() {
        // This explicit test owns the synthetic receipt. Do not depend on
        // XCTest's display-name formatting to decide whether to enable it.
        let runID = UUID().uuidString
        app.terminate()
        app.launchArguments.append("--practice-runtime-diagnostic")
        app.launchEnvironment["BLIND_PRACTICE_TRACE_TEST"] = "LaunchTests/testPracticeIsAnnouncedAndCanStop"
        app.launchEnvironment["BLIND_PRACTICE_TRACE_RUN"] = runID
        print("PRACTICE_RUNTIME_RUN test=LaunchTests/testPracticeIsAnnouncedAndCanStop run=\(runID)")
        app.launch()
        openSettingsPage("camera-screen")
        XCTAssertEqual(app.buttons["monitor-toggle"].label, "Start monitoring", "The explicit camera-off launch preference is respected before practice")
        let start = app.buttons["start-simulation"]
        reveal(start)
        // Start before synthesizing the tap: this overestimates elapsed practice
        // time. Keep a 30-second margin below the unchanged production 120s expiry.
        let startedBeforeTap = ProcessInfo.processInfo.systemUptime
        let cancellationEvidenceLimit: TimeInterval = 90
        start.tap()
        let practiceStatus = app.staticTexts["practice-active-status"]
        XCTAssertTrue(practiceStatus.waitForExistence(timeout: 5))
        reveal(practiceStatus)
        // Ending practice respects the separate camera preference, rather than forcing sensors on.
        let end = app.buttons["end-practice"]
        reveal(end)
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - startedBeforeTap, cancellationEvidenceLimit,
                          "Automation consumed the cancellation evidence window; natural expiry cannot count as Stop")
        end.tap()
        XCTAssertFalse(practiceStatus.exists)
        XCTAssertEqual(app.buttons["monitor-toggle"].label, "Start monitoring")
        let elapsed = ProcessInfo.processInfo.systemUptime - startedBeforeTap
        XCTAssertLessThan(elapsed, cancellationEvidenceLimit,
                          "Postconditions must precede natural expiry; a late observation is not cancellation evidence")
        print("PRACTICE_CANCEL elapsedUpperBound=\(elapsed) limit=\(cancellationEvidenceLimit) explicitEndTap=true")
    }
    func testAccessibleMainModesAndOfflineDefault() {
        openSettingsPage("camera-screen")
        XCTAssertTrue(app.buttons["monitor-toggle"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let ask = app.buttons["ask-screen"]
        reveal(ask); ask.tap()
        XCTAssertTrue(app.buttons["voice-question"].waitForExistence(timeout: 5))
        reveal(app.buttons["local-answer"])
        XCTAssertFalse(app.buttons["local-answer"].isEnabled, "Readable unavailable action must not start the camera")
        let unavailableReason = app.staticTexts["local-answer-unavailable-reason"]
        reveal(unavailableReason)
        XCTAssertEqual(unavailableReason.label, "Camera monitoring is not running. Open Camera and safety to start it.")
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
        recordAskLayout(sizeName: sizeName)
    }
    @MainActor private func recordAskLayout(sizeName: String) {
        // Same system-selected category and synthetic app as the Practice probe.
        // Observe real Form rows at this size; do not override fonts or the audit.
        openSettingsPage("ask-screen")
        let action = app.buttons["local-answer"]
        let reason = app.staticTexts["local-answer-unavailable-reason"]
        let expectedReason = "Camera monitoring is not running. Open Camera and safety to start it."
        for (role, element) in [("ask-action", action), ("ask-reason", reason)] {
            let existedBeforeReveal = element.exists
            print("ASK_LAYOUT beforeReveal size=\(sizeName) role=\(role) exists=\(existedBeforeReveal)")
            revealPracticeDiagnosticElement(element)
            recordPracticeLayoutAttachment(sizeName + "-" + role)
            print("ASK_LAYOUT afterReveal size=\(sizeName) role=\(role) frame=\(element.frame) hittable=\(element.isHittable) enabled=\(element.isEnabled) label=\(element.label)")
            XCTAssertEqual(element.label, role == "ask-action" ? "Ask about the camera view" : expectedReason)
        }
        XCTAssertFalse(action.isEnabled, "Readable unavailable action must not start the camera")
        let navigation = app.navigationBars.firstMatch
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(navigation.exists)
        XCTAssertTrue(tabs.exists)
        func endIsVisible() -> Bool {
            guard reason.exists else { return false }
            return reason.frame.maxY > navigation.frame.maxY && reason.frame.maxY <= tabs.frame.minY
        }
        for _ in 0..<8 {
            if endIsVisible() { break }
            app.swipeUp()
        }
        for _ in 0..<8 {
            if endIsVisible() { break }
            app.swipeDown()
        }
        recordPracticeLayoutAttachment(sizeName + "-ask-reason-end")
        XCTAssertTrue(reason.exists)
        print("ASK_LAYOUT reasonEnd size=\(sizeName) frame=\(reason.frame) unobscuredTop=\(navigation.frame.maxY) unobscuredBottom=\(tabs.frame.minY) endVisible=\(endIsVisible())")
        XCTAssertTrue(endIsVisible(), "Full unavailable reason must scroll above the tab bar and below the navigation bar")
        XCTAssertTrue(reason.isHittable)
        XCTAssertEqual(reason.label, expectedReason)
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
    @MainActor
    private func recordFullAuditEvidence(_ phase: String, _ point: String) {
        // Only the existing synthetic --ui-testing launch, never production user content.
        XCTAssertTrue(app.launchArguments.contains("--ui-testing"))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "full-audit-\(phase)-\(point)"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("ACCESSIBILITY_AUDIT_EVIDENCE phase=\(phase) point=\(point) category=\(UIApplication.shared.preferredContentSizeCategory.rawValue) window=\(app.windows.firstMatch.frame)")
        let controls: [(String, XCUIElement)] = [
            ("navigation", app.navigationBars.firstMatch),
            ("tabs", app.tabBars.firstMatch),
            ("monitor", app.buttons["monitor-toggle"]),
            ("return", app.buttons["retrace-session"]),
            ("practice", app.buttons["start-simulation"]),
            ("practice-header", app.staticTexts.matching(NSPredicate(format: "label == %@", "Practice")).firstMatch),
            ("practice-footer", app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Practice pauses live sensors and ends by itself after two minutes.")).firstMatch),
            ("local-answer", app.buttons["local-answer"]),
            ("repeat-answer", app.buttons["repeat-answer"]),
            ("local-answer-unavailable-reason", app.staticTexts["local-answer-unavailable-reason"]),
            ("voice-question", app.buttons["voice-question"])
        ]
        for (role, element) in controls {
            if element.exists {
                print("ACCESSIBILITY_AUDIT_FRAME phase=\(phase) point=\(point) role=\(role) exists=true frame=\(element.frame) hittable=\(element.isHittable) enabled=\(element.isEnabled) label=\(element.label.prefix(512))")
            } else {
                print("ACCESSIBILITY_AUDIT_FRAME phase=\(phase) point=\(point) role=\(role) exists=false")
            }
        }
    }

    @MainActor
    private func recordAuditIssueObservation(_ issue: XCUIAccessibilityAuditIssue, phase: String, observedFindings: inout Int) {
        // Only synthetic test content. This is callback-time UI, not the audit's
        // historical failing-size state; image and snapshot are not atomic.
        guard app.launchArguments.contains("--ui-testing"),
              phase == "camera" || phase == "ask" else { return }
        // Do not observe or spend the capture budget on the existing exemption.
        // The callback below still owns its original, unchanged return decision.
        if issue.auditType == .contrast, let element = issue.element,
           element.identifier == "retrace-session", !element.isEnabled { return }
        observedFindings += 1
        guard observedFindings <= 2 else {
            print("ACCESSIBILITY_AUDIT_CAPTURE_OMITTED phase=\(phase) index=\(observedFindings) limit=2")
            return
        }
        let index = observedFindings
        let name = "full-audit-\(phase)-issue-\(index)"
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name + "-screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        var metadata: [String: Any] = [
            "schema": 1, "timing": "callback_observation_not_historical_failure_state",
            "phase": phase, "index": index, "auditType": issue.auditType.rawValue,
            "compact": String(issue.compactDescription.prefix(512)),
            "detailed": String(issue.detailedDescription.prefix(1024)),
            "elementPresent": issue.element != nil, "snapshotStatus": "not_available"
        ]
        if let element = issue.element {
            do {
                // One public snapshot; serialize root attributes only, never descendants.
                let snapshot = try element.snapshot()
                metadata["snapshotStatus"] = "captured"
                metadata["element"] = [
                    "identifier": String(snapshot.identifier.prefix(256)),
                    "label": String(snapshot.label.prefix(256)),
                    "elementType": snapshot.elementType.rawValue,
                    "frame": NSCoder.string(for: snapshot.frame), "enabled": snapshot.isEnabled
                ]
            } catch {
                metadata["snapshotStatus"] = "failed"
                metadata["snapshotErrorType"] = String(describing: type(of: error)).prefix(128).description
            }
        }
        do {
            var data = try JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys])
            if data.count > 16 * 1024 {
                metadata.removeValue(forKey: "compact")
                metadata.removeValue(forKey: "detailed")
                metadata.removeValue(forKey: "element")
                metadata["metadataTruncated"] = true
                data = try JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys])
            }
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = name + "-metadata"
            attachment.lifetime = .keepAlways
            add(attachment)
        } catch {
            // Preserve the original audit decision even if diagnostic encoding fails.
            print("ACCESSIBILITY_AUDIT_CAPTURE_ERROR phase=\(phase) index=\(index) kind=metadata_encoding")
        }
    }

    @MainActor
    private func auditFullDestination(_ phase: String, title: String, requiredControl: String) throws {
        let previousContinueAfterFailure = continueAfterFailure
        defer {
            // Keep the original audit failure, but allow its after-state evidence
            // to be retained before restoring this test's fail-fast policy.
            recordFullAuditEvidence(phase, "after")
            continueAfterFailure = previousContinueAfterFailure
        }
        // Required destination UI, not a sleep, scroll, altered state or audit exemption.
        let titleReady = app.navigationBars[title].waitForExistence(timeout: 10)
        let controlReady = app.buttons[requiredControl].waitForExistence(timeout: 10)
        print("ACCESSIBILITY_AUDIT_READINESS phase=\(phase) titleReady=\(titleReady) controlReady=\(controlReady)")
        recordFullAuditEvidence(phase, "before")
        XCTAssertTrue(titleReady, "Expected destination navigation title")
        XCTAssertTrue(controlReady, "Expected destination control")
        // XCTest records audit failures normally; only abort-on-first-failure is
        // delayed inside this scope so the diagnostic defer can execute.
        continueAfterFailure = true
        var observedFindings = 0
        try app.performAccessibilityAudit { issue in
            print("ACCESSIBILITY_AUDIT=type:\(issue.auditType),phase:\(phase),compact:\(issue.compactDescription.prefix(2048)),detailed:\(issue.detailedDescription.prefix(4096)),element:\(String((issue.element?.debugDescription ?? "unidentified").prefix(1200)).replacingOccurrences(of: "\n", with: " | "))")
            self.recordAuditIssueObservation(issue, phase: phase, observedFindings: &observedFindings)
            // WCAG exempts inactive controls; retain every other audit finding.
            guard issue.auditType == .contrast, let element = issue.element else { return false }
            return element.identifier == "retrace-session" && !element.isEnabled
        }
    }

    @MainActor
    func testAccessibilityAuditOfCameraAndAsk() throws {
        openSettingsPage("camera-screen")
        try auditFullDestination("camera", title: "Camera and safety", requiredControl: "monitor-toggle")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let ask = app.buttons["ask-screen"]
        reveal(ask); ask.tap()
        try auditFullDestination("ask", title: "Ask and goals", requiredControl: "local-answer")
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

